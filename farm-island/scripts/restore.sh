#!/usr/bin/env bash
# =============================================================
# Farm Island — Restore Script
# =============================================================
# Restores a complete backup snapshot.
#
# Usage:   ./scripts/restore.sh <backup-archive.tar.gz>
# Example: ./scripts/restore.sh ~/farm-backups/farm-island_2026-03-21_02-00.tar.gz
#
# WARNING: Overwrites all current data!
#          Always review the current state before restoring.
# =============================================================

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
log()   { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[✗]${NC} $*" >&2; }
head()  { echo -e "\n${BOLD}$*${NC}"; }

# ── Check arguments ───────────────────────────────────────────
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <backup-archive.tar.gz>"
  echo ""
  echo "Available backups:"
  ls -lht ~/farm-backups/*.tar.gz 2>/dev/null \
    | awk '{print "  " $5 "  " $9}' \
    || echo "  (no backups found)"
  exit 1
fi

ARCHIVE="$1"
COMPOSE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "$ARCHIVE" ]]; then
  err "Archive not found: $ARCHIVE"
  exit 1
fi

# ── Safety confirmation ───────────────────────────────────────
echo ""
echo -e "${RED}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  WARNING: All current data will be overwritten!      ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  Archive:  $(basename "$ARCHIVE")"
echo "  Size:     $(du -sh "$ARCHIVE" | cut -f1)"
echo "  Target:   $COMPOSE_DIR"
echo ""
read -r -p "Really restore? (yes/N): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Aborted."
  exit 0
fi

# ── Extract archive ───────────────────────────────────────────
RESTORE_TMP=$(mktemp -d)
trap 'rm -rf "$RESTORE_TMP"' EXIT

log "Extracting archive..."
tar xzf "$ARCHIVE" -C "$RESTORE_TMP"
BACKUP_DIR=$(find "$RESTORE_TMP" -mindepth 1 -maxdepth 1 -type d | head -1)

if [[ -z "$BACKUP_DIR" ]]; then
  err "No backup directory found in archive."
  exit 1
fi

log "Backup snapshot: $(basename "$BACKUP_DIR")"
echo ""
echo "Contained files:"
cat "$BACKUP_DIR/manifest.txt" 2>/dev/null | head -20 || ls -lh "$BACKUP_DIR/"
echo ""

cd "$COMPOSE_DIR"

# ── Stop stack ────────────────────────────────────────────────
head "Step 1/5 — Stop containers"
docker compose down
log "All containers stopped"

# ── Restore configuration files ───────────────────────────────
head "Step 2/5 — Restore configuration files"
if [[ -f "$BACKUP_DIR/config.tar.gz" ]]; then
  tar xzf "$BACKUP_DIR/config.tar.gz" -C "$COMPOSE_DIR"
  log "config.tar.gz restored"
fi
if [[ -f "$BACKUP_DIR/env.secret" ]]; then
  cp "$BACKUP_DIR/env.secret" "$COMPOSE_DIR/.env"
  chmod 600 "$COMPOSE_DIR/.env"
  log ".env restored"
else
  warn ".env not in backup — keeping existing .env"
fi

# ── Restore Docker Volumes ────────────────────────────────────
head "Step 3/5 — Restore Docker Volumes"

restore_volume() {
  local volume_name="$1"
  local archive_name="$2"
  local full_name="farm-island_${volume_name}"
  local archive_path="$BACKUP_DIR/$archive_name"

  if [[ ! -f "$archive_path" ]]; then
    warn "  No backup for $volume_name — skipping"
    return
  fi

  # Recreate volume (clears old content)
  docker volume rm "$full_name" 2>/dev/null || true
  docker volume create "$full_name" > /dev/null

  docker run --rm \
    -v "${full_name}:/data" \
    -v "$BACKUP_DIR:/backup:ro" \
    alpine \
    sh -c "cd /data && tar xzf /backup/${archive_name}"

  log "  ✓ $volume_name"
}

restore_volume "nodered-data"     "nodered-data.tar.gz"
restore_volume "grafana-data"     "grafana-data.tar.gz"
restore_volume "chirpstack-data"  "chirpstack-data.tar.gz"
restore_volume "erpnext-sites"    "erpnext-sites.tar.gz"
restore_volume "erpnext-logs"     "erpnext-logs.tar.gz"
restore_volume "mosquitto-data"   "mosquitto-data.tar.gz"

# ── Start stack (for DB restore) ─────────────────────────────
head "Step 4/5 — Restore databases"

log "Starting database containers..."
docker compose up -d postgres mariadb
sleep 10   # wait until DBs are ready

# PostgreSQL (ChirpStack)
if [[ -f "$BACKUP_DIR/chirpstack-postgres.sql.gz" ]]; then
  log "Restoring PostgreSQL (ChirpStack)..."
  CHIRPSTACK_DB_PASS=$(grep CHIRPSTACK_DB_PASS .env | cut -d= -f2)

  # Drop and recreate schema
  docker compose exec -T postgres psql -U chirpstack -c \
    "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" chirpstack 2>/dev/null || true

  gunzip -c "$BACKUP_DIR/chirpstack-postgres.sql.gz" \
    | docker compose exec -T postgres psql -U chirpstack chirpstack
  log "  → PostgreSQL restored"
else
  warn "  No PostgreSQL dump found"
fi

# MariaDB (ERPNext)
if [[ -f "$BACKUP_DIR/erpnext-mariadb-all.sql.gz" ]]; then
  log "Restoring MariaDB (ERPNext)..."
  MARIADB_ROOT_PASS=$(grep MARIADB_ROOT_PASS .env | cut -d= -f2)

  gunzip -c "$BACKUP_DIR/erpnext-mariadb-all.sql.gz" \
    | docker compose exec -T mariadb mysql -u root -p"${MARIADB_ROOT_PASS}"
  log "  → MariaDB restored"
else
  warn "  No MariaDB dump found"
fi

# ── Start all services ────────────────────────────────────────
head "Step 5/5 — Start full stack"
docker compose up -d
sleep 5
log "All services started"

echo ""
docker compose ps
echo ""
log "Restore completed!"
echo ""
echo "Services available at:"
echo "  ChirpStack : http://$(hostname -I | awk '{print $1}'):8080"
echo "  Node-RED   : http://$(hostname -I | awk '{print $1}'):1880"
echo "  Grafana    : http://$(hostname -I | awk '{print $1}'):3000"
echo "  ERPNext    : http://$(hostname -I | awk '{print $1}'):8000"
