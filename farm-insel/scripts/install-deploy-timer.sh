#!/bin/bash
# =============================================================================
# install-deploy-timer.sh — GitOps Deploy-Timer installieren
# =============================================================================
# Installiert einen systemd-Timer, der alle 15 Minuten prüft ob neue Commits
# auf GitHub verfügbar sind und diese automatisch anwendet.
#
# Voraussetzungen:
#   - Git SSH-Key oder HTTPS-Credentials für GitHub konfiguriert
#   - docker und docker compose verfügbar
#   - Skript als root ausführen
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISLAND_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(git -C "$ISLAND_DIR" rev-parse --show-toplevel)"
INSTALL_BASE="/opt/scm-labor"
SYSTEMD_DIR="/etc/systemd/system"

echo "=== GitOps Deploy-Timer Installation ==="
echo "Repo:        $REPO_DIR"
echo "Install-Dir: $INSTALL_BASE"
echo ""

if [ "$(id -u)" -ne 0 ]; then
  echo "Fehler: Dieses Skript muss als root ausgeführt werden."
  echo "Bitte 'sudo ./install-deploy-timer.sh' verwenden."
  exit 1
fi

# --- Repo-Symlink unter /opt anlegen ---
echo "[1/4] Verlinke Repo nach $INSTALL_BASE ..."
mkdir -p "$INSTALL_BASE"
if [ ! -e "$INSTALL_BASE/farm-insel" ]; then
  ln -s "$REPO_DIR/farm-insel" "$INSTALL_BASE/farm-insel"
  echo "      Symlink erstellt: $INSTALL_BASE/farm-insel -> $REPO_DIR/farm-insel"
else
  echo "      Symlink existiert bereits, wird übersprungen."
fi

chmod +x "$SCRIPT_DIR/deploy.sh"

# --- GitHub SSH-Konfiguration prüfen ---
echo "[2/4] Prüfe Git Remote-Konfiguration ..."
REMOTE_URL=$(git -C "$REPO_DIR" remote get-url origin 2>/dev/null || echo "")
echo "      Remote: $REMOTE_URL"

if echo "$REMOTE_URL" | grep -q "^https://"; then
  echo ""
  echo "      HINWEIS: Remote verwendet HTTPS. Für unbeaufsichtigtes Pulling"
  echo "      empfiehlt sich ein GitHub Personal Access Token (PAT) oder SSH."
  echo "      SSH-Umstellung: git remote set-url origin git@github.com:USER/REPO.git"
  echo ""
fi

# Test-Pull
if git -C "$REPO_DIR" fetch origin main --dry-run 2>/dev/null; then
  echo "      Git-Zugriff: OK"
else
  echo "      WARNUNG: Git fetch fehlgeschlagen. Bitte Credentials prüfen."
fi

# --- Systemd-Units installieren ---
echo "[3/4] Installiere systemd-Units ..."
cp "$SCRIPT_DIR/farm-deploy.service" "$SYSTEMD_DIR/"
cp "$SCRIPT_DIR/farm-deploy.timer"   "$SYSTEMD_DIR/"

systemctl daemon-reload
systemctl enable farm-deploy.timer
systemctl start  farm-deploy.timer

echo "      Timer aktiviert."

# --- Log-Verzeichnis ---
mkdir -p /var/log/scm-labor
echo "      Log-Verzeichnis: /var/log/scm-labor/"

# --- Status ---
echo ""
echo "[4/4] Installation abgeschlossen."
echo ""
echo "Timer-Status:"
systemctl status farm-deploy.timer --no-pager || true
echo ""
echo "Nächster geplanter Lauf:"
systemctl list-timers farm-deploy.timer --no-pager || true
echo ""
echo "Manuellen Deploy auslösen:  sudo systemctl start farm-deploy.service"
echo "Logs verfolgen:             journalctl -u farm-deploy.service -f"
echo "Timer stoppen:              sudo systemctl stop farm-deploy.timer"
