# =============================================================
# MikroTik RouterOS — Backup-Script
# =============================================================
# Gilt für: MikroTik Router (DHCP/NTP/Routing) der Farm-Insel
#           MikroTik wAP LR8 kit (LoRaWAN-Gateway)
#
# Ausführung im RouterOS-Terminal (Winbox oder SSH):
#   /import file=mikrotik-backup.rsc
#
# ODER manuell die einzelnen Befehle ausführen.
# =============================================================

# ── 1) Konfigurations-Export (lesbares Textformat) ────────────
# Erzeugt eine .rsc-Datei, die wieder importiert werden kann.
# Diese Datei auf dem Computer sichern!

/export file=farm-router-config
# Datei liegt dann als: farm-router-config.rsc auf dem Router
# Herunterladen via Winbox: Files → farm-router-config.rsc → Download
# Oder via SCP:
#   scp admin@192.168.10.1/farm-router-config.rsc ./

# ── 2) Binär-Backup (vollständige Systemsicherung) ────────────
# Enthält auch Passwörter und Zertifikate.
# Nur lokal sichern, nicht in öffentliche Repos!

/system backup save name=farm-router-backup
# Datei: farm-router-backup.backup

# ── 3) Automatischer Export per Scheduler ─────────────────────
# Wöchentlicher Export jeden Montag um 03:00 Uhr

/system scheduler
add name=weekly-config-export \
    on-event="/export file=farm-router-config-auto" \
    start-date=jan/01/2026 \
    start-time=03:00:00 \
    interval=7d \
    comment="Wöchentlicher Konfigurations-Export"

# ── 4) Wiederherstellung ──────────────────────────────────────
# Option A: Konfigurations-Import (empfohlen bei Firmware-Update)
#   /import file=farm-router-config.rsc
#
# Option B: Komplettes Restore (gleiche RouterOS-Version nötig)
#   /system backup load name=farm-router-backup
