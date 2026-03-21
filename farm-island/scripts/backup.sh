#!/usr/bin/env bash
# =============================================================
# Farm Island — Backup Script
# =============================================================
# Backs up: PostgreSQL (ChirpStack), MariaDB (ERPNext),
#           Docker Volumes (Node-RED, Grafana, ERPNext Sites),
#           Configuration files
#
# Usage:   ./scripts/backup.sh
# Cron:    Runs automatically via systemd timer (see
#          scripts/farm-backup.timer)
#
# Target:  $BACKUP_ROOT/<YYYY-MM-DD_HH-MM>/
# Retention: Last 7 days are kept, older ones deleted
# =============================================================

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────
COMPOSE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_ROOT="${BACKUP_ROOT:-$HOME/farm-backups}"
KEEP_DAYS=7

# Optional sync to network share (leave empty = disabled)
# Example: REMOTE_DEST="user@nas.local:/backups/farm-island"
REMOTE_DEST="${REMOTE_DEST:-}"

# ── Colors for log output ─────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*" >&2; }

# ── Create backup directory ───────────────────────────────────
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"
mkdir -p "$BACKUP_DIR"

log "Starting backup: $BACKUP_DIR"
log "Compose directory: $COMPOSE_DIR"
cd "$COMPOSE_DIR"

# ── 1) PostgreSQL dump (ChirpStack) ──────────────────────────
log "Backing up PostgreSQL (ChirpStack)..."
if docker compose ps postgres | grep -q "running"; then
  docker compose exec -T postgres pg_dump \
    -U chirpstack \
    --no-password \
    chirpstack \
    | gzip > "$BACKUP_DIR/chirpstack-postgres.sql.gz"
  log "  → chirpstack-postgres.sql.gz"
else
  warn "  postgres container is not running — skipping DB dump"
fi

# ── 2) MariaDB dump (ERPNext) ─────────────────────────────────
log "Backing up MariaDB (ERPNext)..."
if docker compose ps mariadb | grep -q "running"; then
  MARIADB_ROOT_PASS=$(grep MARIADB_ROOT_PASS .env | cut -d= -f2)
  docker compose exec -T mariadb mysqldump \
    -u root \
    -p"${MARIADB_ROOT_PASS}" \
    --all-databases \
    --single-transaction \
    --quick \
    | gzip > "$BACKUP_DIR/erpnext-mariadb-all.sql.gz"
  log "  → erpnext-mariadb-all.sql.gz"
else
  warn "  mariadb container is not running — skipping DB dump"
fi

# ── 3) Docker Volumes (file-based) ───────────────────────────
log "Backing up Docker Volumes..."

backup_volume() {
  local volume_name="$1"   # e.g. farm-island_nodered-data
  local archive_name="$2"  # e.g. nodered-data.tar.gz
  local full_name="farm-island_${volume_name}"

  if docker volume inspect "$full_name" &>/dev/null; then
    docker run --rm \
      -v "${full_name}:/data:ro" \
      -v "$BACKUP_DIR:/backup" \
      alpine \
      tar czf "/backup/${archive_name}" -C /data .
    log "  → ${archive_name}"
  else
    warn "  Volume $full_name not found — skipping"
  fi
}

backup_volume "nodered-data"     "nodered-data.tar.gz"
backup_volume "grafana-data"     "grafana-data.tar.gz"
backup_volume "chirpstack-data"  "chirpstack-data.tar.gz"
backup_volume "erpnext-sites"    "erpnext-sites.tar.gz"
backup_volume "erpnext-logs"     "erpnext-logs.tar.gz"
backup_volume "mosquitto-data"   "mosquitto-data.tar.gz"

# ── 4) Configuration files ────────────────────────────────────
log "Backing up configuration files..."
tar czf "$BACKUP_DIR/config.tar.gz" \
  --exclude=".env" \
  docker-compose.yml \
  config/ \
  scripts/ \
  2>/dev/null || true

# .env separately (contains passwords — local backup only!)
if [[ -f .env ]]; then
  cp .env "$BACKUP_DIR/env.secret"
  chmod 600 "$BACKUP_DIR/env.secret"
  log "  → config.tar.gz + env.secret (local only)"
fi

# ── 5) Create manifest ────────────────────────────────────────
log "Creating manifest..."
{
  echo "Backup timestamp: $(date)"
  echo "Hostname:         $(hostname)"
  echo "Compose version:  $(docker compose version 2>/dev/null || echo 'unknown')"
  echo ""
  echo "Files:"
  ls -lh "$BACKUP_DIR/"
  echo ""
  echo "Docker container status:"
  docker compose ps
} > "$BACKUP_DIR/manifest.txt"

# ── 6) Compress backup (everything into one archive) ─────────
log "Creating full archive..."
ARCHIVE="$BACKUP_ROOT/farm-island_${TIMESTAMP}.tar.gz"
tar czf "$ARCHIVE" -C "$BACKUP_ROOT" "$TIMESTAMP"
rm -rf "$BACKUP_DIR"
log "  → $(basename "$ARCHIVE")  ($(du -sh "$ARCHIVE" | cut -f1))"

# ── 7) Clean up old backups ───────────────────────────────────
log "Cleaning up backups older than ${KEEP_DAYS} days..."
find "$BACKUP_ROOT" -maxdepth 1 -name "farm-island_*.tar.gz" \
  -mtime "+${KEEP_DAYS}" -delete -print \
  | while read -r f; do warn "  Deleted: $(basename "$f")"; done

# ── 8) Optional sync to network share ────────────────────────
if [[ -n "$REMOTE_DEST" ]]; then
  log "Syncing to $REMOTE_DEST ..."
  # env.secret is not synced (passwords stay local)
  rsync -av --exclude="*env.secret*" \
    "$BACKUP_ROOT/" "$REMOTE_DEST/" \
    && log "  Sync successful" \
    || warn "  Sync failed — local backup is available"
fi

# ── Done ──────────────────────────────────────────────────────
echo ""
log "Backup completed: $ARCHIVE"
echo ""
echo "Available backups:"
ls -lht "$BACKUP_ROOT"/*.tar.gz 2>/dev/null \
  | awk '{print "  " $5 "  " $9}' \
  || echo "  (none)"
