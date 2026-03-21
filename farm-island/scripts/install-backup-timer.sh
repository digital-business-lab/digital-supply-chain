#!/usr/bin/env bash
# =============================================================
# Installs the systemd backup timer on the Farm Island
# Usage: sudo ./scripts/install-backup-timer.sh
# =============================================================

set -euo pipefail

COMPOSE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CURRENT_USER="${SUDO_USER:-$USER}"

echo "Installing farm backup systemd timer..."

# Make scripts executable
chmod +x "$COMPOSE_DIR/scripts/backup.sh"
chmod +x "$COMPOSE_DIR/scripts/restore.sh"

# Copy systemd units and adjust path
sed "s|/home/farm|/home/$CURRENT_USER|g" \
  "$COMPOSE_DIR/scripts/farm-backup.service" \
  > /etc/systemd/system/farm-backup.service

cp "$COMPOSE_DIR/scripts/farm-backup.timer" \
   /etc/systemd/system/farm-backup.timer

# Create backup directory
mkdir -p "/home/$CURRENT_USER/farm-backups"
chown "$CURRENT_USER:$CURRENT_USER" "/home/$CURRENT_USER/farm-backups"

# Enable timer
systemctl daemon-reload
systemctl enable --now farm-backup.timer

echo ""
echo "Done! Backup timer is active:"
systemctl status farm-backup.timer --no-pager
echo ""
echo "Next backup run:"
systemctl list-timers farm-backup.timer --no-pager
echo ""
echo "Test manually:"
echo "  sudo systemctl start farm-backup.service"
echo "  journalctl -u farm-backup.service -f"
