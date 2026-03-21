#!/bin/bash
# =============================================================================
# deploy.sh — GitOps Deployment für die Farm-Insel
# =============================================================================
# Zieht die aktuelle Version vom Git-Remote und wendet Änderungen an.
# Startet Docker-Dienste nur neu, wenn sich relevante Dateien geändert haben.
#
# Verwendung:
#   ./deploy.sh              # Normaler Deploy (main branch)
#   ./deploy.sh --force      # Neustart erzwingen, auch ohne Änderungen
#   ./deploy.sh --dry-run    # Nur zeigen, was sich geändert hätte
# =============================================================================

set -euo pipefail

ISLAND="farm-insel"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISLAND_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(git -C "$ISLAND_DIR" rev-parse --show-toplevel)"
LOG_FILE="/var/log/scm-labor/${ISLAND}-deploy.log"
BRANCH="main"

FORCE=false
DRY_RUN=false

for arg in "$@"; do
  case $arg in
    --force)   FORCE=true ;;
    --dry-run) DRY_RUN=true ;;
  esac
done

# --- Logging ---
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || LOG_FILE="/tmp/${ISLAND}-deploy.log"

log() {
  local ts
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$ts] $*" | tee -a "$LOG_FILE"
}

log "========================================"
log "Deploy gestartet für: $ISLAND"
log "Repo: $REPO_DIR | Branch: $BRANCH"
$DRY_RUN && log "MODUS: dry-run — keine Änderungen werden angewendet"
$FORCE   && log "MODUS: force  — Neustart wird erzwungen"

# --- Sicherheitscheck: keine lokalen Änderungen ---
if ! git -C "$REPO_DIR" diff --quiet; then
  log "WARNUNG: Lokale nicht-committete Änderungen erkannt. Deploy abgebrochen."
  log "Bitte 'git stash' oder Änderungen committen, dann erneut starten."
  exit 1
fi

# --- Aktuellen Commit merken ---
COMMIT_BEFORE=$(git -C "$REPO_DIR" rev-parse HEAD)
log "Aktueller Commit: $COMMIT_BEFORE"

# --- Git Pull ---
log "Ziehe Änderungen vom Remote..."
if ! $DRY_RUN; then
  git -C "$REPO_DIR" fetch origin "$BRANCH"
  git -C "$REPO_DIR" merge --ff-only "origin/$BRANCH"
fi

COMMIT_AFTER=$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null || echo "$COMMIT_BEFORE")
log "Neuer Commit:    $COMMIT_AFTER"

if [ "$COMMIT_BEFORE" = "$COMMIT_AFTER" ] && ! $FORCE; then
  log "Keine neuen Commits. Deploy nicht nötig."
  exit 0
fi

# --- Geänderte Dateien im Island-Verzeichnis prüfen ---
CHANGED_FILES=$(git -C "$REPO_DIR" diff --name-only "$COMMIT_BEFORE" "$COMMIT_AFTER" \
  | grep "^${ISLAND}/" || true)

if [ -z "$CHANGED_FILES" ] && ! $FORCE; then
  log "Keine Änderungen in /$ISLAND. Deploy nicht nötig."
  exit 0
fi

log "Geänderte Dateien:"
echo "$CHANGED_FILES" | while read -r f; do log "  • $f"; done

# --- Prüfen ob docker-compose.yml oder Images geändert ---
COMPOSE_CHANGED=false
CONFIG_CHANGED=false

echo "$CHANGED_FILES" | grep -q "docker-compose.yml"       && COMPOSE_CHANGED=true || true
echo "$CHANGED_FILES" | grep -q "^${ISLAND}/config/"       && CONFIG_CHANGED=true  || true

# --- Deploy anwenden ---
cd "$ISLAND_DIR"

if $DRY_RUN; then
  log "Dry-run: würde 'docker compose up -d' ausführen (compose_changed=$COMPOSE_CHANGED)"
  exit 0
fi

# Neue Images ziehen, wenn compose-Datei geändert
if $COMPOSE_CHANGED || $FORCE; then
  log "Ziehe neue Docker-Images..."
  docker compose pull --quiet
fi

# Stack aktualisieren (nur geänderte Container werden neu gestartet)
log "Starte Stack neu (docker compose up -d)..."
docker compose up -d --remove-orphans

log "Deploy abgeschlossen."
log "Geänderter Compose: $COMPOSE_CHANGED | Geänderter Config: $CONFIG_CHANGED"

# --- Kurzer Health-Check ---
log "Warte 15 Sekunden, dann Health-Check..."
sleep 15

UNHEALTHY=$(docker compose ps --format json \
  | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        s = json.loads(line)
        if s.get('Health') not in ('healthy', 'running', ''):
            print(s.get('Name','?'), '->', s.get('Health','?'))
    except:
        pass
" 2>/dev/null || true)

if [ -n "$UNHEALTHY" ]; then
  log "WARNUNG: Folgende Dienste sind nicht healthy:"
  echo "$UNHEALTHY" | while read -r line; do log "  ! $line"; done
else
  log "Alle Dienste laufen."
fi

log "========================================"
