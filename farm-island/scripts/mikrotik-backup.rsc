# =============================================================
# MikroTik RouterOS — Backup Script
# =============================================================
# Applies to: MikroTik Router (DHCP/NTP/routing) of the Farm Island
#             MikroTik wAP LR8 kit (LoRaWAN gateway)
#
# Run in RouterOS terminal (Winbox or SSH):
#   /import file=mikrotik-backup.rsc
#
# OR run individual commands manually.
# =============================================================

# ── 1) Configuration export (human-readable text format) ──────
# Creates a .rsc file that can be re-imported.
# Save this file on your computer!

/export file=farm-router-config
# File will be saved as: farm-router-config.rsc on the router
# Download via Winbox: Files → farm-router-config.rsc → Download
# Or via SCP:
#   scp admin@192.168.10.1/farm-router-config.rsc ./

# ── 2) Binary backup (full system backup) ─────────────────────
# Also contains passwords and certificates.
# Store locally only — do not commit to public repos!

/system backup save name=farm-router-backup
# File: farm-router-backup.backup

# ── 3) Automatic export via scheduler ─────────────────────────
# Weekly export every Monday at 03:00

/system scheduler
add name=weekly-config-export \
    on-event="/export file=farm-router-config-auto" \
    start-date=jan/01/2026 \
    start-time=03:00:00 \
    interval=7d \
    comment="Weekly configuration export"

# ── 4) Restore ────────────────────────────────────────────────
# Option A: Configuration import (recommended after firmware update)
#   /import file=farm-router-config.rsc
#
# Option B: Full restore (requires same RouterOS version)
#   /system backup load name=farm-router-backup
