# SCM Lab — Digital Open-Source Supply Chain

A teaching and research project simulating a multi-tier B2B supply chain.
Three independent lab islands — **Farm · Factory · Distributor** — communicate exclusively via REST APIs, entirely built on open-source software.

---

## Project Status (March 2026)

### Completed
- Overall concept drafted (`docs/Supply-Chain_Concept.docx`)
- SVG overview of the three lab islands (`docs/lab-islands_overview_1.html`)
- Farm island fully specified:
  - `docker-compose.yml` with all services
  - Configuration files (ChirpStack, Mosquitto, Grafana, PostgreSQL)
  - Bootstrap script for quick setup (`scripts/bootstrap.sh`)
  - Backup and restore scripts including systemd timer
  - MikroTik RouterOS backup script
  - Setup guide as DOCX (`farm-island/docs/`)

### Open
- Build Factory island and Distributor island analogously
- Define REST API endpoints between the three islands
- Develop Node-RED flows for ERPNext integration
- Draft curriculum and use-case collection for seminars
- Create VM golden image after first production setup

---

## Folder Structure

```
SCM Lab/
  README.md                        ← this file
  docs/
    Supply-Chain_Concept.docx       ← overall concept (9 chapters)
    lab-islands_overview_1.html  ← architecture overview (SVG)
  farm-island/
    docker-compose.yml             ← full service stack
    .env.example                   ← template for passwords
    docs/
      Farm-Island_Setup-Guide.docx
    config/
      chirpstack/                  ← chirpstack.toml
      chirpstack-gateway-bridge/   ← chirpstack-gateway-bridge.toml
      grafana/provisioning/        ← datasource provisioning
      mosquitto/                   ← mosquitto.conf
      postgres/                    ← init.sql
    scripts/
      bootstrap.sh                 ← initial setup (run once on the workstation)
      deploy.sh                    ← GitOps deploy (git pull + docker compose up)
      install-deploy-timer.sh      ← sets up automatic pulling (every 15 min)
      farm-deploy.service/.timer   ← systemd units for auto-deploy
      backup.sh                    ← data backup (databases + volumes)
      restore.sh                   ← restore from backup
      install-backup-timer.sh      ← sets up backup timer
      farm-backup.service/.timer   ← systemd units for backup (daily 02:00)
      mikrotik-backup.rsc          ← RouterOS backup commands
```

Factory and Distributor islands will be created analogously as `factory-island/` and `distributor-island/`.

---

## Architecture

### The Three Lab Islands

| Island | Role | Special Feature |
|---|---|---|
| Farm | Origin of the supply chain | LoRaWAN sensors, IoT stack |
| Factory | Processing | 2× Dobot robots, MES |
| Distributor | Warehouse & Logistics | WMS, VROOM route planning |

Each island = an independent company with its own ERPNext, its own Kafka, and its own MikroTik router. **B2B communication exclusively via REST APIs.**

### Farm Island in Detail

**Hardware:** Dell Workstation (Core i7, 16 GB RAM, 265 GB SSD), touchscreen, MikroTik wAP LR8 kit as LoRaWAN gateway, MikroTik router (DHCP/NTP/routing for all island devices).

**Network:** All devices are DHCP clients on the MikroTik router. The workstation receives a fixed DHCP reservation by MAC address (e.g. `192.168.10.10`) so the wAP LR8 can point the packet forwarder to a fixed IP.

**Services (Docker):**

| Service | Port | Function |
|---|---|---|
| ChirpStack | 8080 | LoRaWAN Network Server |
| ChirpStack Gateway Bridge | 1700/udp | Translates UDP→MQTT (MikroTik wAP LR8) |
| Mosquitto | 1883 | MQTT broker (internal) |
| Node-RED | 1880 | MQTT→ERPNext integration |
| Grafana | 3000 | Sensor dashboard (touchscreen, kiosk mode) |
| ERPNext | 8000 | ERP: inventory, batches, QA |
| PostgreSQL | internal | Database for ChirpStack |
| MariaDB | internal | Database for ERPNext |

**Data flow:**
LoRaWAN sensors → MikroTik wAP LR8 (UDP:1700) → ChirpStack Gateway Bridge → Mosquitto (MQTT) → ChirpStack → Node-RED → ERPNext + Kafka

---

## Decisions Made

**ChirpStack instead of TTN (The Things Network)**
TTN was initially planned as a cloud solution, then replaced with local ChirpStack. Rationale: offline capability in lab operation, full visibility of the pipeline for students (didactic value), data sovereignty for research, no dependency on an external service.

**No VM operation on the workstation**
The Farm island runs natively on Ubuntu + Docker, without a hypervisor. Rationale: 16 GB RAM is too tight for VM + ERPNext, touchscreen kiosk works more easily natively. However, VMs make sense for **teaching** on a separate lab server: a golden image after the first setup allows an isolated environment to be provisioned for each student group in minutes.

**No SSH remote access by Claude**
Outgoing TCP connections are blocked in the Claude sandbox. Setup is instead handled via the bootstrap script (`scripts/bootstrap.sh`), which is executed on the workstation.

**Backup strategy: script-based instead of VM snapshots**
SQL dumps (pg_dump, mysqldump) + Docker volume archives, automated via systemd timer, 7-day retention. More reliable than block-level snapshots of a running database.

**GitOps for deployment**
All configurations and scripts are stored in the Git repository. A `deploy.sh` script on each island pulls new commits via `git pull` and applies them (`docker compose up -d`). A systemd timer automates polling every 15 minutes. Database content is excluded (volumes, backups). Benefits: rollback via `git revert`, audit trail of all changes, consistent rollout across all three islands, didactic value (students see change history).

---

## GitOps Workflow

All configurations, compose files, and scripts are versioned through this repository. Each island pulls changes independently from the remote.

**What lives in Git:**
- `docker-compose.yml` and all configuration files
- Deployment, backup, and bootstrap scripts
- Documentation

**What does NOT live in Git:**
- `.env` (passwords) — stored locally, never committed
- Docker volumes / database data — backed up via `backup.sh`

**Deploying a change:**
```bash
# On the development machine
git commit -m "Description of change"
git push

# On the island (automatically every 15 min or manually)
./farm-island/scripts/deploy.sh
```

**Setting up automatic pulling (once on the island):**
```bash
sudo ./farm-island/scripts/install-deploy-timer.sh
```
After this, the island automatically pulls new commits every 15 minutes and only restarts changed services.

**Trigger manually / view logs:**
```bash
sudo systemctl start farm-deploy.service        # immediate deploy
journalctl -u farm-deploy.service -f            # follow logs
cat /var/log/scm-lab/farm-island-deploy.log      # deploy log
```

---

## Quick Start Farm Island (Initial Setup)

```bash
# 1. Clone repo to the workstation
git clone https://github.com/YOUR-USER/scm-lab.git /opt/scm-lab
cd /opt/scm-lab

# 2. Run bootstrap script (sets up everything including deploy timer)
chmod +x farm-island/scripts/bootstrap.sh && ./farm-island/scripts/bootstrap.sh
```

---

## Technology Stack (fully open source)

LoRaWAN: MikroTik wAP LR8 · ChirpStack · Mosquitto
Integration: Node-RED · Apache Kafka
ERP: ERPNext (Frappe)
Databases: PostgreSQL · MariaDB · Redis
Dashboard: Grafana
Robotics: Dobot Python SDK · ROS2 (optional)
Logistics: VROOM (route optimization)
Network: MikroTik RouterOS
