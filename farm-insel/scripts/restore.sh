#!/usr/bin/env bash
# =============================================================
# Farm-Insel — Restore-Skript
# =============================================================
# Stellt einen vollständigen Backup-Stand wieder her.
#
# Aufruf:  ./scripts/restore.sh <backup-archiv.tar.gz>
# Beispiel: ./scripts/restore.sh ~/farm-backups/farm-insel_2026-03-21_02-00.tar.gz
#
# WARNUNG: Überschreibt alle aktuellen Daten!
#          Vor einem Restore immer aktuellen Stand prüfen.
# =============================================================

set -euo pipefail

# ── Farben ────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
log()   { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[✗]${NC} $*" >&2; }
head()  { echo -e "\n${BOLD}$*${NC}"; }

# ── Argumente prüfen ──────────────────────────────────────────
if [[ $# -ne 1 ]]; then
  echo "Aufruf: $0 <backup-archiv.tar.gz>"
  echo ""
  echo "Verfügbare Backups:"
  ls -lht ~/farm-backups/*.tar.gz 2>/dev/null \
    | awk '{print "  " $5 "  " $9}' \
    || echo "  (keine Backups gefunden)"
  exit 1
fi

ARCHIVE="$1"
COMPOSE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "$ARCHIVE" ]]; then
  err "Archiv nicht gefunden: $ARCHIVE"
  exit 1
fi

# ── Sicherheitsabfrage ────────────────────────────────────────
echo ""
echo -e "${RED}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  WARNUNG: Alle aktuellen Daten werden überschrieben! ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  Archiv:  $(basename "$ARCHIVE")"
echo "  Größe:   $(du -sh "$ARCHIVE" | cut -f1)"
echo "  Ziel:    $COMPOSE_DIR"
echo ""
read -r -p "Wirklich wiederherstellen? (yes/N): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Abgebrochen."
  exit 0
fi

# ── Archiv entpacken ──────────────────────────────────────────
RESTORE_TMP=$(mktemp -d)
trap 'rm -rf "$RESTORE_TMP"' EXIT

log "Entpacke Archiv..."
tar xzf "$ARCHIVE" -C "$RESTORE_TMP"
BACKUP_DIR=$(find "$RESTORE_TMP" -mindepth 1 -maxdepth 1 -type d | head -1)

if [[ -z "$BACKUP_DIR" ]]; then
  err "Kein Backup-Verzeichnis im Archiv gefunden."
  exit 1
fi

log "Backup-Stand: $(basename "$BACKUP_DIR")"
echo ""
echo "Enthaltene Dateien:"
cat "$BACKUP_DIR/manifest.txt" 2>/dev/null | head -20 || ls -lh "$BACKUP_DIR/"
echo ""

cd "$COMPOSE_DIR"

# ── Stack stoppen ─────────────────────────────────────────────
head "Schritt 1/5 — Container stoppen"
docker compose down
log "Alle Container gestoppt"

# ── Konfigurationsdateien wiederherstellen ────────────────────
head "Schritt 2/5 — Konfigurationsdateien wiederherstellen"
if [[ -f "$BACKUP_DIR/config.tar.gz" ]]; then
  tar xzf "$BACKUP_DIR/config.tar.gz" -C "$COMPOSE_DIR"
  log "config.tar.gz wiederhergestellt"
fi
if [[ -f "$BACKUP_DIR/env.secret" ]]; then
  cp "$BACKUP_DIR/env.secret" "$COMPOSE_DIR/.env"
  chmod 600 "$COMPOSE_DIR/.env"
  log ".env wiederhergestellt"
else
  warn ".env nicht im Backup — vorhandene .env wird beibehalten"
fi

# ── Docker Volumes wiederherstellen ──────────────────────────
head "Schritt 3/5 — Docker Volumes wiederherstellen"

restore_volume() {
  local volume_name="$1"
  local archive_name="$2"
  local full_name="farm-insel_${volume_name}"
  local archive_path="$BACKUP_DIR/$archive_name"

  if [[ ! -f "$archive_path" ]]; then
    warn "  Kein Backup für $volume_name — überspringe"
    return
  fi

  # Volume neu erstellen (löscht alten Inhalt)
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

# ── Stack starten (für DB-Restore) ───────────────────────────
head "Schritt 4/5 — Datenbanken wiederherstellen"

log "Starte Datenbank-Container..."
docker compose up -d postgres mariadb
sleep 10   # warten bis DBs bereit sind

# PostgreSQL (ChirpStack)
if [[ -f "$BACKUP_DIR/chirpstack-postgres.sql.gz" ]]; then
  log "Stelle PostgreSQL (ChirpStack) wieder her..."
  CHIRPSTACK_DB_PASS=$(grep CHIRPSTACK_DB_PASS .env | cut -d= -f2)

  # Datenbank leeren und neu befüllen
  docker compose exec -T postgres psql -U chirpstack -c \
    "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" chirpstack 2>/dev/null || true

  gunzip -c "$BACKUP_DIR/chirpstack-postgres.sql.gz" \
    | docker compose exec -T postgres psql -U chirpstack chirpstack
  log "  → PostgreSQL wiederhergestellt"
else
  warn "  Kein PostgreSQL-Dump gefunden"
fi

# MariaDB (ERPNext)
if [[ -f "$BACKUP_DIR/erpnext-mariadb-all.sql.gz" ]]; then
  log "Stelle MariaDB (ERPNext) wieder her..."
  MARIADB_ROOT_PASS=$(grep MARIADB_ROOT_PASS .env | cut -d= -f2)

  gunzip -c "$BACKUP_DIR/erpnext-mariadb-all.sql.gz" \
    | docker compose exec -T mariadb mysql -u root -p"${MARIADB_ROOT_PASS}"
  log "  → MariaDB wiederhergestellt"
else
  warn "  Kein MariaDB-Dump gefunden"
fi

# ── Alle Dienste starten ──────────────────────────────────────
head "Schritt 5/5 — Stack vollständig starten"
docker compose up -d
sleep 5
log "Alle Dienste gestartet"

echo ""
docker compose ps
echo ""
log "Restore abgeschlossen!"
echo ""
echo "Dienste erreichbar unter:"
echo "  ChirpStack : http://$(hostname -I | awk '{print $1}'):8080"
echo "  Node-RED   : http://$(hostname -I | awk '{print $1}'):1880"
echo "  Grafana    : http://$(hostname -I | awk '{print $1}'):3000"
echo "  ERPNext    : http://$(hostname -I | awk '{print $1}'):8000"
