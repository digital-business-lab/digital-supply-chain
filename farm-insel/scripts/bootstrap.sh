#!/usr/bin/env bash
# =============================================================
# Farm-Insel — Bootstrap-Skript
# =============================================================
# Richtet die Farm-Insel auf einem frischen Ubuntu 22.04 LTS
# vollautomatisch ein.
#
# Voraussetzung:
#   - Ubuntu 22.04 LTS Desktop installiert
#   - Dieser Ordner (farm-insel/) auf die Workstation kopiert
#   - Internetverbindung aktiv
#
# Aufruf (aus dem farm-insel/-Verzeichnis):
#   chmod +x scripts/bootstrap.sh
#   ./scripts/bootstrap.sh
# =============================================================

set -euo pipefail

# ── Farben & Hilfsfunktionen ──────────────────────────────────
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
echo "  ║         Farm-Insel — Bootstrap-Skript             ║"
echo "  ║      Open-Source-Lieferkette  ·  SCM Labor        ║"
echo "  ╚═══════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "  Dieses Skript richtet folgende Dienste ein:"
echo "  ChirpStack · Node-RED · Grafana · ERPNext"
echo "  Mosquitto · PostgreSQL · MariaDB"
echo ""
echo "  Compose-Verzeichnis: $COMPOSE_DIR"
echo ""
read -r -p "  Weiter? (Enter zum Starten, Strg+C zum Abbrechen) "

# ── Prüfungen ─────────────────────────────────────────────────
heading "Schritt 1/6 — Systemprüfung"

# Betriebssystem
if ! grep -q "22.04" /etc/os-release 2>/dev/null; then
  warn "Kein Ubuntu 22.04 erkannt — Skript ist für Ubuntu 22.04 LTS optimiert."
  warn "Fortfahren auf eigene Gefahr."
fi

# Nicht als root
if [[ $EUID -eq 0 ]]; then
  err "Bitte NICHT als root ausführen. Starte als normaler Benutzer."
  exit 1
fi

# sudo verfügbar
if ! sudo -n true 2>/dev/null; then
  info "sudo-Passwort wird benötigt..."
  sudo -v
fi

# Internetverbindung
if ! curl -sf --max-time 5 https://download.docker.com > /dev/null; then
  err "Keine Internetverbindung — kann Docker nicht herunterladen."
  exit 1
fi

# compose-Verzeichnis
if [[ ! -f "$COMPOSE_DIR/docker-compose.yml" ]]; then
  err "docker-compose.yml nicht gefunden in: $COMPOSE_DIR"
  err "Stelle sicher, dass du das Skript aus dem farm-insel/-Verzeichnis startest."
  exit 1
fi

log "Systemprüfung bestanden"

# ── Docker installieren ───────────────────────────────────────
heading "Schritt 2/6 — Docker installieren"

if command -v docker &>/dev/null; then
  log "Docker bereits installiert: $(docker --version)"
else
  info "Installiere Docker..."
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
  log "Docker installiert: $(docker --version)"
  warn "Benutzer zur docker-Gruppe hinzugefügt — gilt ab der nächsten Anmeldung."
  warn "Für diese Session: 'newgrp docker' ausführen oder neu anmelden."
  # Gruppe für aktuelle Session laden
  exec sg docker "$0" "$@"
fi

if ! docker compose version &>/dev/null; then
  err "Docker Compose (Plugin) nicht gefunden."
  exit 1
fi
log "Docker Compose: $(docker compose version)"

# ── Zusatzpakete ──────────────────────────────────────────────
info "Installiere Hilfsprogramme..."
sudo apt-get install -y -qq \
  git curl wget htop net-tools openssh-server \
  chromium-browser unclutter 2>/dev/null || true
log "Hilfsprogramme installiert"

# ── Kiosk-Modus (Grafana auf Touchscreen) ────────────────────
heading "Schritt 3/6 — Grafana-Kiosk einrichten"

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
  log "Grafana-Kiosk-Autostart eingerichtet"
else
  log "Grafana-Kiosk-Autostart bereits vorhanden"
fi

# ── Umgebungsvariablen konfigurieren ─────────────────────────
heading "Schritt 4/6 — Passwörter konfigurieren"

cd "$COMPOSE_DIR"

if [[ -f .env ]]; then
  warn ".env existiert bereits — überspringe."
  warn "Zum Zurücksetzen: rm .env && ./scripts/bootstrap.sh"
else
  cp .env.example .env

  echo ""
  ask "Bitte Passwörter festlegen (Eingabe leer lassen = Zufallswert):"
  echo ""

  # Hilfsfunktion: Passwort einlesen oder zufällig generieren
  read_or_random() {
    local label="$1"
    local var="$2"
    local random_val
    random_val=$(openssl rand -hex 16)
    read -r -p "  $label [$random_val]: " input
    echo "${input:-$random_val}"
  }

  CHIRPSTACK_DB_PASS=$(read_or_random "ChirpStack DB-Passwort" "CHIRPSTACK_DB_PASS")
  CHIRPSTACK_API_SECRET=$(openssl rand -hex 32)
  log "  ChirpStack API-Secret: automatisch generiert"
  GRAFANA_ADMIN_PASS=$(read_or_random "Grafana Admin-Passwort" "GRAFANA_ADMIN_PASS")
  MARIADB_ROOT_PASS=$(read_or_random "MariaDB Root-Passwort" "MARIADB_ROOT_PASS")

  # In .env eintragen
  sed -i "s|CHIRPSTACK_DB_PASS=.*|CHIRPSTACK_DB_PASS=${CHIRPSTACK_DB_PASS}|" .env
  sed -i "s|CHIRPSTACK_API_SECRET=.*|CHIRPSTACK_API_SECRET=${CHIRPSTACK_API_SECRET}|" .env
  sed -i "s|GRAFANA_ADMIN_PASS=.*|GRAFANA_ADMIN_PASS=${GRAFANA_ADMIN_PASS}|" .env
  sed -i "s|MARIADB_ROOT_PASS=.*|MARIADB_ROOT_PASS=${MARIADB_ROOT_PASS}|" .env

  chmod 600 .env
  log ".env konfiguriert"

  # Passwörter sicher anzeigen (einmalig)
  echo ""
  echo -e "${BOLD}  ┌─ Zugangsdaten (bitte notieren!) ──────────────────────┐${NC}"
  echo "  │  ChirpStack Web-UI    http://$(hostname -I | awk '{print $1}'):8080"
  echo "  │  Grafana Web-UI       http://$(hostname -I | awk '{print $1}'):3000"
  echo "  │  ERPNext Web-UI       http://$(hostname -I | awk '{print $1}'):8000"
  echo "  │"
  echo "  │  ChirpStack DB-Pass:  $CHIRPSTACK_DB_PASS"
  echo "  │  Grafana Admin-Pass:  $GRAFANA_ADMIN_PASS"
  echo "  │  MariaDB Root-Pass:   $MARIADB_ROOT_PASS"
  echo -e "${BOLD}  └────────────────────────────────────────────────────────┘${NC}"
  echo ""
  read -r -p "  Zugangsdaten notiert? (Enter zum Fortfahren) "
fi

# ── Stack starten ─────────────────────────────────────────────
heading "Schritt 5/7 — Stack starten"

chmod +x scripts/backup.sh scripts/restore.sh \
         scripts/install-backup-timer.sh \
         scripts/deploy.sh \
         scripts/install-deploy-timer.sh 2>/dev/null || true

info "Lade Docker Images herunter (kann einige Minuten dauern)..."
docker compose pull

info "Starte alle Dienste..."
docker compose up -d

info "Warte auf Initialisierung (30 Sekunden)..."
sleep 30

echo ""
docker compose ps
echo ""

# Kurzcheck: sind die wichtigsten Ports erreichbar?
check_port() {
  local name="$1" port="$2"
  if curl -sf --max-time 3 "http://localhost:$port" > /dev/null 2>&1; then
    log "$name erreichbar auf Port $port"
  else
    warn "$name auf Port $port noch nicht erreichbar (ggf. noch am Starten)"
  fi
}

check_port "ChirpStack" 8080
check_port "Node-RED"   1880
check_port "Grafana"    3000

# ── Backup-Timer einrichten ───────────────────────────────────
heading "Schritt 6/7 — Backup-Timer einrichten"

mkdir -p "$HOME/farm-backups"

echo ""
ask "Soll der automatische Backup-Timer eingerichtet werden? (täglich 02:00 Uhr)"
read -r -p "  [j/N]: " INSTALL_TIMER

if [[ "${INSTALL_TIMER,,}" == "j" ]]; then
  sudo bash scripts/install-backup-timer.sh
else
  warn "Backup-Timer übersprungen. Später einrichten mit:"
  warn "  sudo ./scripts/install-backup-timer.sh"
fi

# ── GitOps Deploy-Timer einrichten ────────────────────────────
heading "Schritt 7/7 — GitOps Deploy-Timer einrichten"

echo ""
info "Der Deploy-Timer zieht alle 15 Minuten automatisch neue"
info "Commits vom GitHub-Repository und wendet Änderungen an."
echo ""
ask "Soll der GitOps Deploy-Timer eingerichtet werden?"
read -r -p "  [J/n]: " INSTALL_DEPLOY

if [[ "${INSTALL_DEPLOY,,}" != "n" ]]; then
  # Prüfen ob Git-Repo vorhanden
  REPO_DIR="$(git -C "$COMPOSE_DIR" rev-parse --show-toplevel 2>/dev/null || echo "")"
  if [[ -z "$REPO_DIR" ]]; then
    warn "Kein Git-Repository erkannt."
    warn "Bitte Repo zuerst klonen: git clone https://github.com/... /opt/scm-labor"
    warn "Deploy-Timer kann dann manuell eingerichtet werden:"
    warn "  sudo ./scripts/install-deploy-timer.sh"
  else
    info "Git-Repository gefunden: $REPO_DIR"
    sudo bash scripts/install-deploy-timer.sh
  fi
else
  warn "Deploy-Timer übersprungen. Später einrichten mit:"
  warn "  sudo ./scripts/install-deploy-timer.sh"
fi

# ── Fertig ────────────────────────────────────────────────────
HOST_IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}${BOLD}"
echo "  ╔═══════════════════════════════════════════════════╗"
echo "  ║           Farm-Insel ist bereit!                  ║"
echo "  ╚═══════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "  Dienste erreichbar unter:"
echo ""
echo "    ChirpStack   →  http://$HOST_IP:8080"
echo "    Node-RED     →  http://$HOST_IP:1880"
echo "    Grafana      →  http://$HOST_IP:3000"
echo "    ERPNext      →  http://$HOST_IP:8000"
echo ""
echo "  Nächste Schritte:"
echo "    1. ChirpStack: MikroTik wAP LR8 als Gateway eintragen"
echo "    2. ChirpStack: Device Profile + Sensoren anlegen"
echo "    3. MikroTik wAP LR8: Paketforwarder auf $HOST_IP:1700 zeigen"
echo "    4. Node-RED: MQTT-Flow einrichten"
echo "    5. Grafana: Dashboard aufbauen"
echo ""
echo "  Hilfreiche Befehle:"
echo "    docker compose ps              # Status aller Dienste"
echo "    docker compose logs -f         # Logs verfolgen"
echo "    ./scripts/backup.sh            # Manuelles Backup"
echo "    ./scripts/deploy.sh            # Manueller GitOps-Deploy"
echo "    ./scripts/deploy.sh --dry-run  # Vorschau: was würde sich ändern?"
echo ""
