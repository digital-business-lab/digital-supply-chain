#!/usr/bin/env bash
# =============================================================
# Farm Island — Bootstrap Script
# =============================================================
# Sets up the Farm Island on a fresh Ubuntu 22.04 LTS
# fully automatically.
#
# Prerequisites:
#   - Ubuntu 22.04 LTS Desktop installed
#   - This folder (farm-island/) copied to the workstation
#   - Internet connection active
#
# Usage (from the farm-island/ directory):
#   chmod +x scripts/bootstrap.sh
#   ./scripts/bootstrap.sh
# =============================================================

set -euo pipefail

# ── Colors & helper functions ─────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log()     { echo -e "${GREEN}[✓]${NC} $*"; }
info()    { echo -e "${BLUE}[→]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
err()     { echo -e "${RED}[✗]${NC} $*" >&2; }
heading() { echo -e "\n${BOLD}━━━ $* ━━━${NC}"; }
ask()     { echo -e "${YELLOW}[?]${NC} $*"; }

COMPOSE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Banner ────────────────────────────────────────────────────
clear
echo -e "${BOLD}"
echo "  ╔═══════════════════════════════════════════════════╗"
echo "  ║         Farm Island — Bootstrap Script            ║"
echo "  ║      Open-Source Supply Chain  ·  SCM Lab         ║"
echo "  ╚═══════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "  This script sets up the following services:"
echo "  ChirpStack · Node-RED · Grafana · ERPNext"
echo "  Mosquitto · PostgreSQL · MariaDB"
echo ""
echo "  Compose directory: $COMPOSE_DIR"
echo ""
read -r -p "  Continue? (Enter to start, Ctrl+C to cancel) "

# ── Checks ────────────────────────────────────────────────────
heading "Step 1/6 — System check"

# Operating system
if ! grep -q "22.04" /etc/os-release 2>/dev/null; then
  warn "Ubuntu 22.04 not detected — script is optimized for Ubuntu 22.04 LTS."
  warn "Proceeding at your own risk."
fi

# Not as root
if [[ $EUID -eq 0 ]]; then
  err "Please do NOT run as root. Run as a regular user."
  exit 1
fi

# sudo available
if ! sudo -n true 2>/dev/null; then
  info "sudo password required..."
  sudo -v
fi

# Internet connection
if ! curl -sf --max-time 5 https://download.docker.com > /dev/null; then
  err "No internet connection — cannot download Docker."
  exit 1
fi

# Compose directory
if [[ ! -f "$COMPOSE_DIR/docker-compose.yml" ]]; then
  err "docker-compose.yml not found in: $COMPOSE_DIR"
  err "Make sure you run the script from the farm-island/ directory."
  exit 1
fi

log "System check passed"

# ── Install Docker ────────────────────────────────────────────
heading "Step 2/6 — Install Docker"

if command -v docker &>/dev/null; then
  log "Docker already installed: $(docker --version)"
else
  info "Installing Docker..."
  sudo apt-get update -qq
  sudo apt-get install -y -qq ca-certificates curl gnupg

  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update -qq
  sudo apt-get install -y -qq \
    docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin

  sudo usermod -aG docker "$USER"
  log "Docker installed: $(docker --version)"
  warn "User added to docker group — takes effect after next login."
  warn "For this session: run 'newgrp docker' or log out and back in."
  # Load group for current session
  exec sg docker "$0" "$@"
fi

if ! docker compose version &>/dev/null; then
  err "Docker Compose (plugin) not found."
  exit 1
fi
log "Docker Compose: $(docker compose version)"

# ── Additional packages ───────────────────────────────────────
info "Installing utilities..."
sudo apt-get install -y -qq \
  git curl wget htop net-tools openssh-server \
  chromium-browser unclutter 2>/dev/null || true
log "Utilities installed"

# ── Kiosk mode (Grafana on touchscreen) ──────────────────────
heading "Step 3/6 — Set up Grafana kiosk"

AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

KIOSK_FILE="$AUTOSTART_DIR/grafana-kiosk.desktop"
if [[ ! -f "$KIOSK_FILE" ]]; then
  cat > "$KIOSK_FILE" << 'EOF'
[Desktop Entry]
Type=Application
Name=Grafana Kiosk
Exec=chromium-browser --kiosk --noerrdialogs --disable-infobars \
  --no-first-run http://localhost:3000
X-GNOME-Autostart-enabled=true
EOF
  log "Grafana kiosk autostart configured"
else
  log "Grafana kiosk autostart already present"
fi

# ── Configure environment variables ──────────────────────────
heading "Step 4/6 — Configure passwords"

cd "$COMPOSE_DIR"

if [[ -f .env ]]; then
  warn ".env already exists — skipping."
  warn "To reset: rm .env && ./scripts/bootstrap.sh"
else
  cp .env.example .env

  echo ""
  ask "Please set passwords (leave empty for a random value):"
  echo ""

  # Helper: read password or generate random one
  read_or_random() {
    local label="$1"
    local var="$2"
    local random_val
    random_val=$(openssl rand -hex 16)
    read -r -p "  $label [$random_val]: " input
    echo "${input:-$random_val}"
  }

  CHIRPSTACK_DB_PASS=$(read_or_random "ChirpStack DB password" "CHIRPSTACK_DB_PASS")
  CHIRPSTACK_API_SECRET=$(openssl rand -hex 32)
  log "  ChirpStack API secret: generated automatically"
  GRAFANA_ADMIN_PASS=$(read_or_random "Grafana admin password" "GRAFANA_ADMIN_PASS")
  MARIADB_ROOT_PASS=$(read_or_random "MariaDB root password" "MARIADB_ROOT_PASS")

  # Write to .env
  sed -i "s|CHIRPSTACK_DB_PASS=.*|CHIRPSTACK_DB_PASS=${CHIRPSTACK_DB_PASS}|" .env
  sed -i "s|CHIRPSTACK_API_SECRET=.*|CHIRPSTACK_API_SECRET=${CHIRPSTACK_API_SECRET}|" .env
  sed -i "s|GRAFANA_ADMIN_PASS=.*|GRAFANA_ADMIN_PASS=${GRAFANA_ADMIN_PASS}|" .env
  sed -i "s|MARIADB_ROOT_PASS=.*|MARIADB_ROOT_PASS=${MARIADB_ROOT_PASS}|" .env

  chmod 600 .env
  log ".env configured"

  # Display credentials securely (one time only)
  echo ""
  echo -e "${BOLD}  ┌─ Credentials (please note these down!) ───────────────┐${NC}"
  echo "  │  ChirpStack Web UI    http://$(hostname -I | awk '{print $1}'):8080"
  echo "  │  Grafana Web UI       http://$(hostname -I | awk '{print $1}'):3000"
  echo "  │  ERPNext Web UI       http://$(hostname -I | awk '{print $1}'):8000"
  echo "  │"
  echo "  │  ChirpStack DB pass:  $CHIRPSTACK_DB_PASS"
  echo "  │  Grafana admin pass:  $GRAFANA_ADMIN_PASS"
  echo "  │  MariaDB root pass:   $MARIADB_ROOT_PASS"
  echo -e "${BOLD}  └────────────────────────────────────────────────────────┘${NC}"
  echo ""
  read -r -p "  Credentials noted down? (Enter to continue) "
fi

# ── Start stack ───────────────────────────────────────────────
heading "Step 5/7 — Start stack"

chmod +x scripts/backup.sh scripts/restore.sh \
         scripts/install-backup-timer.sh \
         scripts/deploy.sh \
         scripts/install-deploy-timer.sh 2>/dev/null || true

info "Downloading Docker images (this may take a few minutes)..."
docker compose pull

info "Starting all services..."
docker compose up -d

info "Waiting for initialization (30 seconds)..."
sleep 30

echo ""
docker compose ps
echo ""

# Quick check: are the main ports reachable?
check_port() {
  local name="$1" port="$2"
  if curl -sf --max-time 3 "http://localhost:$port" > /dev/null 2>&1; then
    log "$name reachable on port $port"
  else
    warn "$name on port $port not yet reachable (may still be starting)"
  fi
}

check_port "ChirpStack" 8080
check_port "Node-RED"   1880
check_port "Grafana"    3000

# ── Set up backup timer ───────────────────────────────────────
heading "Step 6/7 — Set up backup timer"

mkdir -p "$HOME/farm-backups"

echo ""
ask "Should the automatic backup timer be set up? (daily at 02:00)"
read -r -p "  [y/N]: " INSTALL_TIMER

if [[ "${INSTALL_TIMER,,}" == "y" ]]; then
  sudo bash scripts/install-backup-timer.sh
else
  warn "Backup timer skipped. Set it up later with:"
  warn "  sudo ./scripts/install-backup-timer.sh"
fi

# ── Set up GitOps deploy timer ────────────────────────────────
heading "Step 7/7 — Set up GitOps deploy timer"

echo ""
info "The deploy timer automatically pulls new commits from the"
info "GitHub repository every 15 minutes and applies changes."
echo ""
ask "Should the GitOps deploy timer be set up?"
read -r -p "  [Y/n]: " INSTALL_DEPLOY

if [[ "${INSTALL_DEPLOY,,}" != "n" ]]; then
  # Check if Git repo is present
  REPO_DIR="$(git -C "$COMPOSE_DIR" rev-parse --show-toplevel 2>/dev/null || echo "")"
  if [[ -z "$REPO_DIR" ]]; then
    warn "No Git repository detected."
    warn "Please clone the repo first: git clone https://github.com/... /opt/scm-lab"
    warn "The deploy timer can then be set up manually:"
    warn "  sudo ./scripts/install-deploy-timer.sh"
  else
    info "Git repository found: $REPO_DIR"
    sudo bash scripts/install-deploy-timer.sh
  fi
else
  warn "Deploy timer skipped. Set it up later with:"
  warn "  sudo ./scripts/install-deploy-timer.sh"
fi

# ── Done ──────────────────────────────────────────────────────
HOST_IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}${BOLD}"
echo "  ╔═══════════════════════════════════════════════════╗"
echo "  ║           Farm Island is ready!                   ║"
echo "  ╚═══════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "  Services available at:"
echo ""
echo "    ChirpStack   →  http://$HOST_IP:8080"
echo "    Node-RED     →  http://$HOST_IP:1880"
echo "    Grafana      →  http://$HOST_IP:3000"
echo "    ERPNext      →  http://$HOST_IP:8000"
echo ""
echo "  Next steps:"
echo "    1. ChirpStack: register MikroTik wAP LR8 as gateway"
echo "    2. ChirpStack: create device profile + sensors"
echo "    3. MikroTik wAP LR8: point packet forwarder to $HOST_IP:1700"
echo "    4. Node-RED: set up MQTT flow"
echo "    5. Grafana: build dashboard"
echo ""
echo "  Useful commands:"
echo "    docker compose ps              # status of all services"
echo "    docker compose logs -f         # follow logs"
echo "    ./scripts/backup.sh            # manual backup"
echo "    ./scripts/deploy.sh            # manual GitOps deploy"
echo "    ./scripts/deploy.sh --dry-run  # preview: what would change?"
echo ""
