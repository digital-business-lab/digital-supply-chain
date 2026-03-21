#!/usr/bin/env bash
# =============================================================
# Farm-Insel — Backup-Skript
# =============================================================
# Sichert: PostgreSQL (ChirpStack), MariaDB (ERPNext),
#          Docker Volumes (Node-RED, Grafana, ERPNext Sites),
#          Konfigurationsdateien
#
# Aufruf:  ./scripts/backup.sh
# Cron:    Läuft automatisch via systemd-Timer (siehe
#          scripts/farm-backup.timer)
#
# Ziel:    $BACKUP_ROOT/<YYYY-MM-DD_HH-MM>/
# Aufbew.: Letzte 7 Tage werden behalten, ältere gelöscht
# =============================================================

set -euo pipefail

# ── Konfiguration ─────────────────────────────────────────────
COMPOSE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_ROOT="${BACKUP_ROOT:-$HOME/farm-backups}"
KEEP_DAYS=7

# Optionaler Sync auf Netzlaufwerk (leer lassen = deaktiviert)
# Beispiel: REMOTE_DEST="user@nas.local:/backups/farm-insel"
REMOTE_DEST="${REMOTE_DEST:-}"

# ── Farben für Log-Output ─────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*" >&2; }

# ── Backup-Verzeichnis anlegen ────────────────────────────────
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"
mkdir -p "$BACKUP_DIR"

log "Starte Backup: $BACKUP_DIR"
log "Compose-Verzeichnis: $COMPOSE_DIR"
cd "$COMPOSE_DIR"

# ── 1) PostgreSQL-Dump (ChirpStack) ──────────────────────────
log "Sichere PostgreSQL (ChirpStack)..."
if docker compose ps postgres | grep -q "running"; then
  docker compose exec -T postgres pg_dump \
    -U chirpstack \
    --no-password \
    chirpstack \
    | gzip > "$BACKUP_DIR/chirpstack-postgres.sql.gz"
  log "  → chirpstack-postgres.sql.gz"
else
  warn "  postgres-Container läuft nicht — überspringe DB-Dump"
fi

# ── 2) MariaDB-Dump (ERPNext) ─────────────────────────────────
log "Sichere MariaDB (ERPNext)..."
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
  warn "  mariadb-Container läuft nicht — überspringe DB-Dump"
fi

# ── 3) Docker Volumes (dateibasiert) ─────────────────────────
log "Sichere Docker Volumes..."

backup_volume() {
  local volume_name="$1"   # z.B. farm-insel_nodered-data
  local archive_name="$2"  # z.B. nodered-data.tar.gz
  local full_name="farm-insel_${volume_name}"

  if docker volume inspect "$full_name" &>/dev/null; then
    docker run --rm \
      -v "${full_name}:/data:ro" \
      -v "$BACKUP_DIR:/backup" \
      alpine \
      tar czf "/backup/${archive_name}" -C /data .
    log "  → ${archive_name}"
  else
    warn "  Volume $full_name nicht gefunden — überspringe"
  fi
}

backup_volume "nodered-data"     "nodered-data.tar.gz"
backup_volume "grafana-data"     "grafana-data.tar.gz"
backup_volume "chirpstack-data"  "chirpstack-data.tar.gz"
backup_volume "erpnext-sites"    "erpnext-sites.tar.gz"
backup_volume "erpnext-logs"     "erpnext-logs.tar.gz"
backup_volume "mosquitto-data"   "mosquitto-data.tar.gz"

# ── 4) Konfigurationsdateien ──────────────────────────────────
log "Sichere Konfigurationsdateien..."
tar czf "$BACKUP_DIR/config.tar.gz" \
  --exclude=".env" \
  docker-compose.yml \
  config/ \
  scripts/ \
  2>/dev/null || true

# .env separat (enthält Passwörter — nur lokal sichern!)
if [[ -f .env ]]; then
  cp .env "$BACKUP_DIR/env.secret"
  chmod 600 "$BACKUP_DIR/env.secret"
  log "  → config.tar.gz + env.secret (nur lokal)"
fi

# ── 5) Manifest erstellen ─────────────────────────────────────
log "Erstelle Manifest..."
{
  echo "Backup-Zeitpunkt: $(date)"
  echo "Hostname:         $(hostname)"
  echo "Compose-Version:  $(docker compose version 2>/dev/null || echo 'unbekannt')"
  echo ""
  echo "Dateien:"
  ls -lh "$BACKUP_DIR/"
  echo ""
  echo "Docker-Container-Status:"
  docker compose ps
} > "$BACKUP_DIR/manifest.txt"

# ── 6) Backup komprimieren (optional, alles in ein Archiv) ────
log "Erstelle Gesamt-Archiv..."
ARCHIVE="$BACKUP_ROOT/farm-insel_${TIMESTAMP}.tar.gz"
tar czf "$ARCHIVE" -C "$BACKUP_ROOT" "$TIMESTAMP"
rm -rf "$BACKUP_DIR"
log "  → $(basename "$ARCHIVE")  ($(du -sh "$ARCHIVE" | cut -f1))"

# ── 7) Alte Backups aufräumen ─────────────────────────────────
log "Räume Backups älter als ${KEEP_DAYS} Tage auf..."
find "$BACKUP_ROOT" -maxdepth 1 -name "farm-insel_*.tar.gz" \
  -mtime "+${KEEP_DAYS}" -delete -print \
  | while read -r f; do warn "  Gelöscht: $(basename "$f")"; done

# ── 8) Optionaler Sync auf Netzlaufwerk ──────────────────────
if [[ -n "$REMOTE_DEST" ]]; then
  log "Sync auf $REMOTE_DEST ..."
  # env.secret wird nicht synchronisiert (Passwörter bleiben lokal)
  rsync -av --exclude="*env.secret*" \
    "$BACKUP_ROOT/" "$REMOTE_DEST/" \
    && log "  Sync erfolgreich" \
    || warn "  Sync fehlgeschlagen — lokales Backup vorhanden"
fi

# ── Fertig ────────────────────────────────────────────────────
echo ""
log "Backup abgeschlossen: $ARCHIVE"
echo ""
echo "Vorhandene Backups:"
ls -lht "$BACKUP_ROOT"/*.tar.gz 2>/dev/null \
  | awk '{print "  " $5 "  " $9}' \
  || echo "  (keine)"
