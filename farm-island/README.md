# Farm Island — Coffee Farm

The Farm Island represents the origin of the supply chain: a coffee farm. It is the only island with field-level sensor infrastructure, measuring growing conditions and logging harvest batches via ERPNext.

→ [Full architecture overview](../docs/architecture.md) | [LoRaWAN details](../docs/lorawan.md) | [GitOps workflow](../docs/gitops.md)

---

## Hardware

| Component | Model / Spec | Function |
|---|---|---|
| Linux workstation | Dell, Core i7, 16 GB RAM, 256 GB SSD | Main compute node for all Docker services |
| Touch display | — | Grafana sensor dashboard (kiosk mode) |
| LoRaWAN gateway | MikroTik wAP LR8 kit | Receives sensor radio packets, forwards to ChirpStack |
| Router | MikroTik | DHCP, NTP, routing for all island devices |
| Sensors | Dragino LHT65, LDDS75 / Seeed SenseCAP S2103 | Soil moisture, temperature, CO₂, fill level |

**Network:** The workstation receives a fixed DHCP reservation by MAC address (e.g. `192.168.10.10`) so the wAP LR8 packet forwarder always has a stable target IP.

---

## Services (Docker)

| Service | Port | Function |
|---|---|---|
| ChirpStack | 8080 | LoRaWAN Network Server — authentication, decoding, MQTT output |
| ChirpStack Gateway Bridge | 1700/udp | Translates UDP packets from wAP LR8 to MQTT |
| Mosquitto | 1883 | MQTT broker (island-internal) |
| Node-RED | 1880 | MQTT → ERPNext + Kafka + Fabric peer integration |
| Grafana | 3000 | Sensor dashboard on the touch display |
| ERPNext | 8000 | ERP: inventory, batch tracking, quality assurance |
| Fabric Peer Node | 7051 | Writes harvest batch events to the shared Fabric ledger |
| PostgreSQL | internal | Database for ChirpStack |
| MariaDB | internal | Database for ERPNext |

---

## Internal Data Flow

```
LoRaWAN sensors (868 MHz)
    ↓
MikroTik wAP LR8  →  UDP:1700
    ↓
ChirpStack Gateway Bridge  →  MQTT
    ↓
ChirpStack (auth, decode)  →  MQTT (Mosquitto)
    ↓
Node-RED
    ├─→ ERPNext    (REST — inventory & batch bookings)
    ├─→ Kafka      (internal event processing)
    └─→ Fabric Peer Node  (harvest batch event on ledger)
```

---

## Initial Setup

```bash
# Clone the repository on the farm workstation
git clone https://github.com/digital-business-lab/digital-supply-chain.git /opt/scm-lab
cd /opt/scm-lab

# Copy and fill in secrets
cp farm-island/.env.example farm-island/.env
nano farm-island/.env

# Run bootstrap (installs Docker, sets up systemd timers, starts services)
chmod +x farm-island/scripts/bootstrap.sh
./farm-island/scripts/bootstrap.sh
```

For a detailed step-by-step guide see `farm-island/docs/Farm-Island_Setup-Guide.docx`.

---

## Key Scripts

| Script | Purpose |
|---|---|
| `scripts/bootstrap.sh` | Initial setup — run once on a fresh workstation |
| `scripts/deploy.sh` | GitOps deploy: `git pull` + `docker compose up -d` |
| `scripts/install-deploy-timer.sh` | Installs systemd timer for auto-deploy every 15 min |
| `scripts/backup.sh` | Full backup to `~/farm-backups/` (databases + volumes) |
| `scripts/restore.sh` | Restore a backup archive |
| `scripts/install-backup-timer.sh` | Installs systemd timer for daily 02:00 backup |
| `scripts/mikrotik-backup.rsc` | RouterOS backup commands for the MikroTik |

---

## Folder Structure

```
farm-island/
  docker-compose.yml
  .env.example
  docs/
    Farm-Island_Setup-Guide.docx
  config/
    chirpstack/chirpstack.toml
    chirpstack-gateway-bridge/chirpstack-gateway-bridge.toml
    grafana/provisioning/datasources/
    mosquitto/mosquitto.conf
    postgres/init.sql
  scripts/
    bootstrap.sh
    deploy.sh · install-deploy-timer.sh · farm-deploy.service · farm-deploy.timer
    backup.sh · restore.sh · install-backup-timer.sh · farm-backup.service · farm-backup.timer
    mikrotik-backup.rsc
```
