#!/bin/bash
# =============================================================================
# install-deploy-timer.sh — Install GitOps Deploy Timer
# =============================================================================
# Installs a systemd timer that checks every 15 minutes for new commits
# on GitHub and applies them automatically.
#
# Prerequisites:
#   - Git SSH key or HTTPS credentials for GitHub configured
#   - docker and docker compose available
#   - Run script as root
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISLAND_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(git -C "$ISLAND_DIR" rev-parse --show-toplevel)"
INSTALL_BASE="/opt/scm-lab"
SYSTEMD_DIR="/etc/systemd/system"

echo "=== GitOps Deploy Timer Installation ==="
echo "Repo:        $REPO_DIR"
echo "Install dir: $INSTALL_BASE"
echo ""

if [ "$(id -u)" -ne 0 ]; then
  echo "Error: This script must be run as root."
  echo "Please use 'sudo ./install-deploy-timer.sh'."
  exit 1
fi

# --- Create repo symlink under /opt ---
echo "[1/4] Linking repo to $INSTALL_BASE ..."
mkdir -p "$INSTALL_BASE"
if [ ! -e "$INSTALL_BASE/farm-island" ]; then
  ln -s "$REPO_DIR/farm-island" "$INSTALL_BASE/farm-island"
  echo "      Symlink created: $INSTALL_BASE/farm-island -> $REPO_DIR/farm-island"
else
  echo "      Symlink already exists, skipping."
fi

chmod +x "$SCRIPT_DIR/deploy.sh"

# --- Check GitHub SSH configuration ---
echo "[2/4] Checking Git remote configuration ..."
REMOTE_URL=$(git -C "$REPO_DIR" remote get-url origin 2>/dev/null || echo "")
echo "      Remote: $REMOTE_URL"

if echo "$REMOTE_URL" | grep -q "^https://"; then
  echo ""
  echo "      NOTE: Remote uses HTTPS. For unattended pulling,"
  echo "      a GitHub Personal Access Token (PAT) or SSH is recommended."
  echo "      Switch to SSH: git remote set-url origin git@github.com:USER/REPO.git"
  echo ""
fi

# Test pull
if git -C "$REPO_DIR" fetch origin main --dry-run 2>/dev/null; then
  echo "      Git access: OK"
else
  echo "      WARNING: Git fetch failed. Please check credentials."
fi

# --- Install systemd units ---
echo "[3/4] Installing systemd units ..."
cp "$SCRIPT_DIR/farm-deploy.service" "$SYSTEMD_DIR/"
cp "$SCRIPT_DIR/farm-deploy.timer"   "$SYSTEMD_DIR/"

systemctl daemon-reload
systemctl enable farm-deploy.timer
systemctl start  farm-deploy.timer

echo "      Timer enabled."

# --- Log directory ---
mkdir -p /var/log/scm-lab
echo "      Log directory: /var/log/scm-lab/"

# --- Status ---
echo ""
echo "[4/4] Installation complete."
echo ""
echo "Timer status:"
systemctl status farm-deploy.timer --no-pager || true
echo ""
echo "Next scheduled run:"
systemctl list-timers farm-deploy.timer --no-pager || true
echo ""
echo "Trigger manual deploy:  sudo systemctl start farm-deploy.service"
echo "Follow logs:            journalctl -u farm-deploy.service -f"
echo "Stop timer:             sudo systemctl stop farm-deploy.timer"
