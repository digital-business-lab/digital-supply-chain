#!/bin/bash
# =============================================================================
# deploy.sh — GitOps Deployment for the Farm Island
# =============================================================================
# Pulls the current version from the Git remote and applies changes.
# Only restarts Docker services if relevant files have changed.
#
# Usage:
#   ./deploy.sh              # Normal deploy (main branch)
#   ./deploy.sh --force      # Force restart even without changes
#   ./deploy.sh --dry-run    # Only show what would have changed
# =============================================================================

set -euo pipefail

ISLAND="farm-island"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISLAND_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(git -C "$ISLAND_DIR" rev-parse --show-toplevel)"
LOG_FILE="/var/log/digital-supply-chain/${ISLAND}-deploy.log"
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
log "Deploy started for: $ISLAND"
log "Repo: $REPO_DIR | Branch: $BRANCH"
$DRY_RUN && log "MODE: dry-run — no changes will be applied"
$FORCE   && log "MODE: force  — restart will be forced"

# --- Safety check: no local changes ---
if ! git -C "$REPO_DIR" diff --quiet; then
  log "WARNING: Uncommitted local changes detected. Deploy aborted."
  log "Please run 'git stash' or commit the changes, then try again."
  exit 1
fi

# --- Record current commit ---
COMMIT_BEFORE=$(git -C "$REPO_DIR" rev-parse HEAD)
log "Current commit: $COMMIT_BEFORE"

# --- Git Pull ---
log "Pulling changes from remote..."
if ! $DRY_RUN; then
  git -C "$REPO_DIR" fetch origin "$BRANCH"
  git -C "$REPO_DIR" merge --ff-only "origin/$BRANCH"
fi

COMMIT_AFTER=$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null || echo "$COMMIT_BEFORE")
log "New commit:     $COMMIT_AFTER"

if [ "$COMMIT_BEFORE" = "$COMMIT_AFTER" ] && ! $FORCE; then
  log "No new commits. Deploy not needed."
  exit 0
fi

# --- Check changed files in the island directory ---
CHANGED_FILES=$(git -C "$REPO_DIR" diff --name-only "$COMMIT_BEFORE" "$COMMIT_AFTER" \
  | grep "^${ISLAND}/" || true)

if [ -z "$CHANGED_FILES" ] && ! $FORCE; then
  log "No changes in /$ISLAND. Deploy not needed."
  exit 0
fi

log "Changed files:"
echo "$CHANGED_FILES" | while read -r f; do log "  • $f"; done

# --- Check if docker-compose.yml or images changed ---
COMPOSE_CHANGED=false
CONFIG_CHANGED=false

echo "$CHANGED_FILES" | grep -q "docker-compose.yml"       && COMPOSE_CHANGED=true || true
echo "$CHANGED_FILES" | grep -q "^${ISLAND}/config/"       && CONFIG_CHANGED=true  || true

# --- Apply deploy ---
cd "$ISLAND_DIR"

if $DRY_RUN; then
  log "Dry-run: would run 'docker compose up -d' (compose_changed=$COMPOSE_CHANGED)"
  exit 0
fi

# Pull new images if compose file changed
if $COMPOSE_CHANGED || $FORCE; then
  log "Pulling new Docker images..."
  docker compose pull --quiet
fi

# Update stack (only changed containers are restarted)
log "Restarting stack (docker compose up -d)..."
docker compose up -d --remove-orphans

log "Deploy completed."
log "Compose changed: $COMPOSE_CHANGED | Config changed: $CONFIG_CHANGED"

# --- Quick health check ---
log "Waiting 15 seconds, then health check..."
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
  log "WARNING: The following services are not healthy:"
  echo "$UNHEALTHY" | while read -r line; do log "  ! $line"; done
else
  log "All services are running."
fi

log "========================================"
