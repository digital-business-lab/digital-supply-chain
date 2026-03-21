#!/usr/bin/env bash
# =============================================================
# Installiert den systemd-Backup-Timer auf der Farm-Insel
# Aufruf: sudo ./scripts/install-backup-timer.sh
# =============================================================

set -euo pipefail

COMPOSE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CURRENT_USER="${SUDO_USER:-$USER}"

echo "Installiere Farm-Backup systemd-Timer..."

# Skripte ausführbar machen
chmod +x "$COMPOSE_DIR/scripts/backup.sh"
chmod +x "$COMPOSE_DIR/scripts/restore.sh"

# systemd-Units kopieren und Pfad anpassen
sed "s|/home/farm|/home/$CURRENT_USER|g" \
  "$COMPOSE_DIR/scripts/farm-backup.service" \
  > /etc/systemd/system/farm-backup.service

cp "$COMPOSE_DIR/scripts/farm-backup.timer" \
   /etc/systemd/system/farm-backup.timer

# Backup-Verzeichnis anlegen
mkdir -p "/home/$CURRENT_USER/farm-backups"
chown "$CURRENT_USER:$CURRENT_USER" "/home/$CURRENT_USER/farm-backups"

# Timer aktivieren
systemctl daemon-reload
systemctl enable --now farm-backup.timer

echo ""
echo "Fertig! Backup-Timer ist aktiv:"
systemctl status farm-backup.timer --no-pager
echo ""
echo "Nächster Backup-Lauf:"
systemctl list-timers farm-backup.timer --no-pager
echo ""
echo "Manuell testen:"
echo "  sudo systemctl start farm-backup.service"
echo "  journalctl -u farm-backup.service -f"
