# SCM Lab — Digital Open-Source Supply Chain (Coffee)

A teaching and research project simulating a multi-tier B2B supply chain using **coffee as the example product**. Four independent lab islands — **Farm · Factory · Distributor · Coffee House** — communicate via REST APIs, entirely built on open-source software. A shared **Hyperledger Fabric** ledger provides tamper-proof batch traceability across all tiers.

**Central idea:** A customer in the Coffee House can trace their cup of coffee all the way back to the farm — seeing which beans were harvested, how and when they were roasted, which distributor delivered them, and with which brewing parameters their specific cup was prepared.

---

## Table of Contents

1. [Project Status](#1-project-status)
2. [Objective](#2-objective)
3. [Folder Structure](#3-folder-structure)
4. [The Four Lab Islands](#4-the-four-lab-islands)
   - [4.1 Farm Island](#41-farm-island-coffee-farm)
   - [4.2 Factory Island](#42-factory-island-coffee-processing)
   - [4.3 Distributor Island](#43-distributor-island-coffee-trader)
   - [4.4 Coffee House Island](#44-coffee-house-island-consumer-endpoint)
5. [Lab Cloud](#5-lab-cloud)
6. [Hyperledger Fabric: End-to-End Traceability](#6-hyperledger-fabric-end-to-end-traceability)
7. [B2B Communication Between Companies](#7-b2b-communication-between-companies)
8. [LoRaWAN Architecture (Farm Island)](#8-lorawan-architecture-farm-island)
9. [Didactic Scenarios](#9-didactic-scenarios)
10. [Network Architecture](#10-network-architecture)
11. [Operations & Backup](#11-operations--backup)
12. [Decisions Made](#12-decisions-made)
13. [GitOps Workflow](#13-gitops-workflow)
14. [Quick Start Farm Island](#14-quick-start-farm-island)
15. [Technology Stack](#15-technology-stack)

---

## 1. Project Status

### Completed
- Overall concept in English with coffee theme, 4 islands, Lab Cloud, Hyperledger Fabric — integrated into this README
- Visual architecture overview — 4 islands + Lab Cloud (`docs/lab-islands_overview_2.html`)
- Farm island fully specified:
  - `docker-compose.yml` with all services
  - Configuration files (ChirpStack, Mosquitto, Grafana, PostgreSQL)
  - Bootstrap script for quick setup (`scripts/bootstrap.sh`)
  - Backup and restore scripts including systemd timer
  - MikroTik RouterOS backup script
  - Setup guide as DOCX (`farm-island/docs/`)

### Open
- Build Factory island and Distributor island analogously to Farm island
- Build Coffee House island (POS module, Traceability Display, IoT connector)
- Set up Lab Cloud server (Fabric orderer, Coffee House IoT backend, central Grafana)
- Define REST API endpoints between all four islands
- Configure Hyperledger Fabric network (channels, endorsement policies, peer nodes on all B2B islands)
- Develop Node-RED flows for ERPNext + Fabric integration on Factory and Distributor islands
- Build POS Module for Coffee House (lightweight web application)
- Build Traceability Display web application
- Integrate coffee machine sensor interface (MQTT / serial) with Lab Cloud IoT backend
- Develop curriculum and use-case collection for seminars
- Create VM golden images after first production setup of each island
- Evaluate Hyperledger Explorer as a visual blockchain browser for students

---

## 2. Objective

This system simulates a realistic, multi-tier supply chain illustrating the full journey of a product from origin to consumption, using coffee as the example. Four independent entities participate: a Coffee Farm, a Coffee Processing Factory, a Coffee Distributor, and a Coffee House.

```
Coffee Farm  →  Coffee Processing  →  Coffee Trader  →  Coffee House
   (Farm)          (Factory)           (Distributor)    (Consumer endpoint)
```

The central didactic idea is **end-to-end traceability**: a customer sitting in the Coffee House can scan a QR code or RFID tag and trace the complete supply chain for their cup of coffee — from which farm the beans originated, how and when they were processed, which distributor delivered them, and even with which brewing parameters their specific cup was prepared.

Each entity is built as an independent lab island and communicates with the others exclusively via defined REST APIs, mirroring real-world B2B integration between independent companies. A shared Hyperledger Fabric ledger records batch events across all islands, enabling tamper-proof traceability without requiring direct API calls between non-adjacent parties.

The fourth island — the Coffee House — is intentionally lean: a real coffee house has no IT department, no ERP system, and no middleware infrastructure. Its technical footprint is limited to a POS system, a customer display, and a connection to the Lab Cloud for IoT data processing.

Educators can demonstrate individual islands in isolation or the complete system end-to-end. Researchers can test data flows, disruptions, and optimisation algorithms experimentally.

---

## 3. Folder Structure

```
SCM Lab/
  README.md                            ← this file (complete project documentation)
  docs/
    lab-islands_overview_2.html        ← architecture overview, 4 islands + Lab Cloud (SVG)
    lab-islands_overview_1.html        ← original 3-island overview (superseded)
  farm-island/
    docker-compose.yml                 ← full service stack
    .env.example                       ← template for passwords
    docs/
      Farm-Island_Setup-Guide.docx
    config/
      chirpstack/                      ← chirpstack.toml
      chirpstack-gateway-bridge/       ← chirpstack-gateway-bridge.toml
      grafana/provisioning/            ← datasource provisioning
      mosquitto/                       ← mosquitto.conf
      postgres/                        ← init.sql
    scripts/
      bootstrap.sh                     ← initial setup (run once on the workstation)
      deploy.sh                        ← GitOps deploy (git pull + docker compose up)
      install-deploy-timer.sh          ← sets up automatic pulling (every 15 min)
      farm-deploy.service/.timer       ← systemd units for auto-deploy
      backup.sh                        ← data backup (databases + volumes)
      restore.sh                       ← restore from backup
      install-backup-timer.sh          ← sets up backup timer
      farm-backup.service/.timer       ← systemd units for backup (daily 02:00)
      mikrotik-backup.rsc              ← RouterOS backup commands
```

Factory, Distributor, and Coffee House islands will be created as `factory-island/`, `distributor-island/`, and `coffeehouse-island/`. The Lab Cloud configuration will live in `lab-cloud/`.

---

## 4. The Four Lab Islands

| Island | Role | Coffee Context | Key Infrastructure |
|---|---|---|---|
| Farm | Origin of the supply chain | Coffee farm (e.g. Ethiopia / Colombia) | LoRaWAN sensors, ChirpStack, ERPNext, Fabric peer |
| Factory | Processing | Roasting & packaging | 2× Dobot robots, MES, OPC-UA, ERPNext, Fabric peer |
| Distributor | Warehouse & Logistics | Coffee trader | ERPNext WMS, VROOM, Fabric peer |
| Coffee House | Consumer endpoint | Café / coffee bar | POS, Traceability Display, no ERP, no Fabric peer |

Each B2B island (Farm, Factory, Distributor) = an independent company with its own ERPNext, its own Kafka, its own MikroTik router, and its own Hyperledger Fabric peer node. **B2B communication exclusively via REST APIs.**

The Coffee House is intentionally lean — no ERP, no Kafka, no Fabric peer node. It consumes managed services from the Lab Cloud.

---

### 4.1 Farm Island (Coffee Farm)

The Farm Island represents the origin of the supply chain: a coffee farm. It is the only island with field-level sensor infrastructure, measuring growing conditions and logging harvest batches via ERPNext.

**Hardware**

- LoRaWAN sensors (e.g. Dragino LHT65, Seeed SenseCAP): soil moisture, temperature, air humidity, light, CO₂
- MikroTik wAP LR8 kit: receives radio signals from sensors and forwards them as UDP packets to ChirpStack
- Linux workstation (Dell, Core i7, 16 GB RAM, 256 GB SSD): main compute node for all software components
- Touch display: real-time field dashboard (Grafana, kiosk mode)
- MikroTik router: DHCP/NTP/routing for all island devices

**Network:** All devices are DHCP clients on the MikroTik router. The workstation receives a fixed DHCP reservation by MAC address (e.g. `192.168.10.10`) so the wAP LR8 can point the packet forwarder to a fixed IP.

**Services (Docker)**

| Service | Port | Function |
|---|---|---|
| ChirpStack | 8080 | LoRaWAN Network Server |
| ChirpStack Gateway Bridge | 1700/udp | Translates UDP→MQTT (MikroTik wAP LR8) |
| Mosquitto | 1883 | MQTT broker (internal) |
| Node-RED | 1880 | MQTT→ERPNext + Kafka + Fabric peer integration |
| Grafana | 3000 | Sensor dashboard (touchscreen, kiosk mode) |
| ERPNext | 8000 | ERP: inventory, batches, quality assurance |
| Fabric Peer Node | 7051 | Hyperledger Fabric peer — writes harvest events |
| PostgreSQL | internal | Database for ChirpStack |
| MariaDB | internal | Database for ERPNext |

**Internal data flow:**
LoRaWAN sensors → MikroTik wAP LR8 (UDP:1700) → ChirpStack Gateway Bridge → Mosquitto (MQTT) → ChirpStack → Node-RED → ERPNext + Kafka + Fabric peer node

---

### 4.2 Factory Island (Coffee Processing)

The Factory Island is the didactic centrepiece: two Dobot robots demonstrate physical processing steps (sorting green beans, roasting, quality control, packaging) that are directly reported back to the ERP system.

**Hardware**

- 2× Dobot Magician: pick & place (sorting green beans) and quality control + packaging
- Linux workstation: robot control and MES
- Touch display: MES operator interface for production orders

**Services (Docker)**

| Service | Function |
|---|---|
| Dobot Python SDK | Direct robot control via USB/TCP |
| ROS2 (optional) | Advanced robot path programming for research contexts |
| OPC-UA server | Machine status exposure to ERPNext MES |
| ERPNext Manufacturing (MES) | Production orders, bills of materials, quality records |
| Apache Kafka | Internal event processing (island-internal only) |
| Fabric Peer Node | Writes roasting/processing batch events to shared ledger |
| Grafana | Production dashboard on the touch display |

**Internal data flow:**
ERPNext order → Python SDK → Dobot 1 (sorting) → Dobot 2 (QC + packaging) → OPC-UA → ERPNext booking + Fabric peer node

---

### 4.3 Distributor Island (Coffee Trader)

The Distributor coordinates warehousing, picking, and route planning — purely software-driven, which makes the contrast with the physical Factory Island didactically valuable. It is also the direct supplier to the Coffee House.

**Hardware**

- Linux workstation: WMS and logistics planning
- Touch display: picking list and stock overview
- USB barcode / RFID scanner: goods receipt capture

**Services (Docker)**

| Service | Function |
|---|---|
| ERPNext WMS | Warehouse FIFO bookings, stock management |
| VROOM | Delivery route optimisation (open source) |
| Apache Kafka | Internal event processing (island-internal only) |
| Grafana | Warehouse dashboard on the touch display |
| Fabric Peer Node | Writes shipment batch events to shared ledger |

---

### 4.4 Coffee House Island (Consumer Endpoint)

The Coffee House is the consumer endpoint of the supply chain. It is intentionally lean: a real coffee house has no IT department, no ERP system, and no middleware of its own. Its role is to receive coffee deliveries, serve customers, and make the complete supply chain visible to the customer — from farm to cup.

The island consists of **three independent software modules** that can run on a single machine or on separate hardware. IoT processing is fully delegated to the Lab Cloud.

**Hardware**

- Linux PC: serves as POS, can also run the Traceability Display module
- RFID / barcode scanner: scans incoming delivery bags (goods receipt) and optionally customer receipts
- Customer-facing display: shows the Traceability Display web application
- Smart coffee machine with sensors: reports grind level, temperature, bean type, water volume, water hardness, and extraction time

**Three independent software modules**

| Module | Function | Interface |
|---|---|---|
| POS Module | Sales, goods receipt (RFID/barcode scan triggers Distributor REST call to confirm delivery and fetch batch metadata), reorder management | Calls Distributor REST API |
| Traceability Display | Read-only web app: queries Lab Cloud Fabric Gateway for batch history (Farm → Factory → Distributor → Coffee House) and Lab Cloud IoT backend for real-time brew parameters; displays both to the customer | Reads from Lab Cloud REST endpoints |
| IoT Connector | Coffee machine sends sensor data via MQTT or serial interface directly to Lab Cloud IoT backend — no local server required | MQTT/serial out to Lab Cloud |

**What the Coffee House does NOT have**

- No ERP system
- No Kafka or internal message broker
- No Hyperledger Fabric peer node (read-only access via Lab Cloud Fabric Gateway)
- No local IoT processing infrastructure

---

## 5. Lab Cloud

The Lab Cloud is a dedicated infrastructure layer running on a **lab server on-premise** — not in Azure, AWS, or any public cloud. It provides managed services that individual islands consume without needing to operate server infrastructure themselves. This models the reality of small businesses subscribing to managed cloud services from a provider.

From the perspective of the Coffee House, the Lab Cloud is a black box: the coffee machine sends data out, and a REST endpoint delivers processed results back. No configuration of the Lab Cloud is required from the Coffee House side.

**Services on the Lab Cloud**

| Service | Technology | Purpose |
|---|---|---|
| Hyperledger Fabric Orderer | RAFT consensus | Coordinates consensus for the shared blockchain network |
| Fabric Gateway REST API | Hyperledger Fabric Gateway SDK | Exposes batch history as a REST endpoint; consumed by the Coffee House Traceability Display |
| MQTT Broker | Mosquitto | Receives sensor data from the coffee machine |
| Sensor processing | Node-RED | Normalises sensor readings, validates, routes to storage |
| Time-series storage | InfluxDB | Stores brew parameters per extraction event |
| Brew parameter API | REST endpoint | Serves latest brew data to the Traceability Display |
| Central monitoring | Grafana | Cross-island dashboard for instructors |
| Blockchain browser | Hyperledger Explorer | Visual browser for all Fabric transactions |

**Didactic significance:** The Lab Cloud demonstrates three complementary deployment patterns within one system: fully local infrastructure (per-island ERPNext, Kafka), distributed peer-to-peer consensus (Fabric peer nodes on each island), and centralised managed services (Lab Cloud). Students encounter all three patterns in a single, coherent scenario.

---

## 6. Hyperledger Fabric: End-to-End Traceability

Hyperledger Fabric is the backbone of the traceability system. It provides a shared, immutable ledger of supply chain events that any party can query — without requiring direct API calls between non-adjacent companies. The Coffee House does not need to know the Farm's API address, and the Farm does not need to know the Coffee House exists.

**Why blockchain for this use case**

The alternative — having the Coffee House call the Distributor, which calls the Factory, which calls the Farm, in sequence at query time — has two problems: it creates runtime dependencies between all parties simultaneously, and it provides no cryptographic guarantee that the data has not been modified. For traceability claims (origin, processing conditions), tamper-evidence matters both technically and commercially.

**Events written to the ledger**

Each island writes one batch event per supply chain step:

| Island | Event type | Key fields |
|---|---|---|
| Farm | `harvest` | batch_id, origin, altitude_m, cooperative, picker_count, harvest_date, sensor_summary |
| Factory | `roast` | batch_id, roast_profile, peak_temp_c, duration_min, output_kg, roast_date |
| Distributor | `ship` | batch_id, destination, dispatch_date, estimated_delivery, transport_mode |
| Coffee House | `receive` | batch_id, received_date, bag_count, rfid_ids[] |

Coffee machine brewing parameters (grind level, temperature, water volume, water hardness, extraction time) are intentionally **not** written to the chain — they are per-cup operational data, not supply chain events. They are stored in InfluxDB on the Lab Cloud and served directly to the Traceability Display.

**Network topology**

| Node | Location | Role |
|---|---|---|
| Fabric Peer Node | Farm island (Docker) | Endorses and commits harvest events |
| Fabric Peer Node | Factory island (Docker) | Endorses and commits roasting events |
| Fabric Peer Node | Distributor island (Docker) | Endorses and commits shipment events |
| Fabric Orderer (RAFT) | Lab Cloud | Coordinates consensus across all peer nodes |
| Fabric Gateway REST API | Lab Cloud | Read-only endpoint for Coffee House Traceability Display |
| Fabric Client | Coffee House | Queries via Lab Cloud Gateway — no local peer node |

**Integration with Node-RED:** On Farm, Factory, and Distributor islands, Node-RED flows that already write data to ERPNext are extended to additionally submit a transaction to the Fabric peer node. This is a parallel write, not a replacement: ERPNext remains the system of record for each island's internal data, and Fabric holds only the inter-party batch events.

---

## 7. B2B Communication Between Companies

Each lab island represents an independent company. Inter-company communication uses **REST APIs exclusively** — not shared middleware such as Kafka. This design is intentional: students learn explicitly which data one company shares with another, and which data remains internal. Kafka remains a company-internal tool on each island.

Authentication uses API keys per company for the lab context. OAuth2 can be added for research scenarios requiring stronger access control. ERPNext provides a REST API out of the box.

| Sender | Receiver | Message | Trigger |
|---|---|---|---|
| Farm | Factory | Delivery notice (batch, quantity, quality) | Harvest completed |
| Factory | Farm | Purchase order (green beans, quantity) | Production order created |
| Factory | Distributor | Delivery notice (roasted coffee, batch) | Roasting completed |
| Distributor | Factory | Purchase order (roasted coffee, quantity) | Customer order received |
| Distributor | Coffee House | Delivery notice (coffee bags, batch ID, RFID tags) | Delivery dispatched |
| Coffee House | Distributor | Purchase order (coffee bags, quantity) | Stock running low |

---

## 8. LoRaWAN Architecture (Farm Island)

The LoRaWAN integration on the Farm Island follows a clearly separated four-layer architecture.

**Layer 1 — Sensors (Field Level)**

Battery-powered LoRa sensors transmit encrypted packets in the 868 MHz band (Europe). Typical measurement intervals: 5–15 minutes. Recommended hardware: Dragino LHT65 (temperature/humidity), Dragino LDDS75 (fill level/distance), Seeed SenseCAP S2103 (CO₂). All sensors report data contextually meaningful for coffee farming: soil moisture, microclimate temperature, CO₂ levels in storage, and canopy light.

**Layer 2 — Gateway (MikroTik)**

The MikroTik wAP LR8 kit receives radio signals from all sensors in the 868 MHz band and forwards them as UDP packets to ChirpStack. The device does not interpret packet content — it is pure packet forwarding. A single gateway can serve an unlimited number of sensors.

**Layer 3 — Network Server (ChirpStack, local)**

ChirpStack runs locally via Docker on the Farm Island's Linux workstation and handles: sensor authentication via AppKey/DevEUI, deduplication, payload decoding via JavaScript decoder. Output: clean JSON messages via a local MQTT broker (Mosquitto). Running ChirpStack locally (instead of The Things Network) ensures offline capability, full pipeline visibility for students, data sovereignty, and no dependency on an external service.

**Layer 4 — Integration (Node-RED)**

Node-RED subscribes to the MQTT topic from ChirpStack and distributes data to ERPNext (automatic bookings), Kafka (internal further processing), and the Fabric peer node (harvest batch events). The visual programming interface is directly accessible to students without programming experience.

---

## 9. Didactic Scenarios

### Foundational Courses

- Trace a coffee batch end-to-end: from harvest on the farm through roasting, distribution, to the customer's cup
- Observe the bullwhip effect: how delays at one tier amplify through the entire chain
- Analyse REST API communication: what data does one company share with another?
- Understand the IoT pipeline: from sensor measurement to ERP booking
- Experience traceability from the customer's perspective: scan a QR code at the Coffee House and see the full chain

### Advanced Courses

- Demand forecasting: train ML algorithms on real sensor data from the Farm
- Inventory optimisation: implement EOQ models and dynamic ordering policies
- Robot programming: optimise Dobot paths with ROS2
- Blockchain configuration: set up Hyperledger Fabric channels, define endorsement policies, query batch history
- Coffee House IoT: analyse brewing parameter data in InfluxDB, build custom Grafana dashboards
- Modular deployment: deploy the three Coffee House modules (POS, Display, IoT connector) on separate hardware and understand the interface contracts between them

### Research Scenarios

- Disruption experiments: simulate failure of one island and measure supply chain resilience
- Optimisation algorithms: compare VROOM routing against custom heuristics
- Data quality: investigate the impact of sensor dropouts on ERP bookings and Fabric transactions
- Privacy and data sovereignty: which data is on-chain vs. off-chain, and why?
- Lab Cloud vs. public cloud: compare latency and cost of on-premise Lab Cloud services against a real Azure deployment

---

## 10. Network Architecture

All Linux workstations and the MikroTik LoRaWAN gateway are connected via LAN. The Lab Cloud server is on the same LAN. Each island's REST APIs are reachable over the LAN; in a production-realistic configuration they can be exposed via a reverse proxy (e.g. Traefik) to simulate internet-facing B2B APIs.

The Coffee House island connects to the Lab Cloud for IoT data (MQTT) and blockchain queries (Fabric Gateway REST). It connects to the Distributor island for goods receipt and purchase orders (REST). It has no direct network connection to the Farm or Factory.

| Component | Runs on | Protocol | Access |
|---|---|---|---|
| ChirpStack | Farm workstation | MQTT (local) | Farm-internal only |
| ERPNext Farm | Farm workstation | REST API | Farm-internal + Factory via API key |
| ERPNext Factory | Factory workstation | REST API | Factory-internal + Farm / Distributor via API key |
| ERPNext Distributor | Distributor workstation | REST API | Distributor-internal + Factory / Coffee House via API key |
| POS System | Coffee House PC | REST API (client) | Calls Distributor API for orders / goods receipt |
| Kafka (per island) | Each workstation | Kafka protocol | Island-internal only |
| Fabric Peer Node (×3) | Farm / Factory / Distributor | gRPC (Fabric) | Connects to Lab Cloud orderer |
| Fabric Orderer | Lab Cloud server | gRPC (Fabric) | Accepts endorsements from all three peer nodes |
| Fabric Gateway API | Lab Cloud server | REST API | Read-only batch history; consumed by Coffee House Traceability Display |
| Coffee IoT Backend | Lab Cloud server | MQTT / REST | Receives sensor data from coffee machine; serves REST to Traceability Display |
| Grafana (per island) | Each workstation | HTTP | Touch display on each island |
| Grafana (central) | Lab Cloud server | HTTP | Cross-island dashboard for instructors |

---

## 11. Operations & Backup

### Backup Strategy

Each lab island automatically backs up its data state via a shell script executed as a systemd timer daily at 02:00. Items backed up: database dumps (PostgreSQL for ChirpStack, MariaDB for ERPNext), all Docker volumes (Node-RED flows, Grafana dashboards, ERPNext sites), and configuration files. Backups are stored locally on the workstation; backups older than 7 days are automatically deleted. Optionally, backups can be synchronised to a shared network drive via rsync.

- `backup.sh`: backs up all data to a timestamped archive under `~/farm-backups/` (analogous scripts for other islands)
- `restore.sh`: fully restores a chosen backup state (container stop → volumes → DBs → restart)
- MikroTik router and wAP LR8: weekly configuration export via RouterOS scheduler

### VM Templates for Teaching

In production operation, each island runs natively on Ubuntu + Docker — without hypervisor overhead, with full access to RAM and touch screen. For teaching, however, a VM-based approach on a separate lab server is recommended in addition: after the first complete setup of an island, a "Golden Image" VM snapshot is created. This image serves as the starting point for practicals and seminars.

The distinction from backup is conceptual: while the backup preserves the running operational state, the VM template freezes a defined teaching state. Students can modify or misconfigure an island freely — restoring the initial state takes minutes rather than hours.

- Recommended platform: KVM/QEMU with Virt-Manager on a dedicated lab server (minimum 32 GB RAM for three island VMs simultaneously)
- Golden image: create VM snapshot after full setup; export as base template
- Practical operation: start one copy of the template per student group — fully isolated, no mutual interference
- Research operation: run experiments (failure simulation, algorithm tests) in VM copies without risk to the production setup

---

## 12. Decisions Made

**Coffee as the example product**
All four islands are framed around coffee: the farm grows it, the factory roasts it, the distributor trades it, the coffee house serves it. This makes abstract supply chain concepts tangible and enables a compelling traceability demonstration for students and visitors.

**Fourth island: Coffee House as lean consumer endpoint**
The Coffee House deliberately has no ERP, no Kafka, and no Fabric peer node. A real coffee house has no IT department. This asymmetry is didactically valuable: students see that the digital supply chain reaches the end consumer without requiring them to operate complex infrastructure. IoT processing is delegated to the Lab Cloud (analogous to a managed cloud service).

**Lab Cloud instead of public cloud**
IoT processing for the Coffee House and the Hyperledger Fabric orderer run on an on-premise lab server rather than Azure or AWS. This gives students full visibility into all layers (no black-box cloud), keeps the setup offline-capable, and avoids cost and data sovereignty issues. Architecturally it models the same pattern as a managed cloud service.

**Hyperledger Fabric as integral component (not optional)**
Fabric is the backbone of the traceability system. Each B2B island runs a Fabric peer node; the Lab Cloud runs the orderer. The Coffee House reads batch history via a Fabric Gateway REST endpoint. This replaces the approach of cascading REST calls across all islands at query time, which would have created runtime dependencies and provided no tamper-evidence.

**Three independent modules in the Coffee House**
POS, Traceability Display, and IoT connector are designed as loosely coupled modules with defined REST interfaces. They can run on one machine or on separate hardware. This lets instructors demonstrate the same logical architecture on different physical configurations.

**Brewing parameters off-chain**
Coffee machine sensor data (grind, temperature, water, etc.) is stored in InfluxDB on the Lab Cloud, not on the Hyperledger Fabric ledger. These are per-cup operational data, not supply chain events — writing them to the chain would be too granular and would mix operational telemetry with inter-company batch records.

**ChirpStack instead of TTN (The Things Network)**
TTN was initially planned as a cloud solution, then replaced with local ChirpStack. Rationale: offline capability in lab operation, full pipeline visibility for students (didactic value), data sovereignty for research, no dependency on an external service.

**No VM operation on the workstation**
The Farm island runs natively on Ubuntu + Docker, without a hypervisor. Rationale: 16 GB RAM is too tight for VM + ERPNext, touchscreen kiosk works more easily natively. VMs make sense for teaching on a separate lab server: a golden image after the first setup allows an isolated environment to be provisioned for each student group in minutes.

**Backup strategy: script-based instead of VM snapshots**
SQL dumps (pg_dump, mysqldump) + Docker volume archives, automated via systemd timer, 7-day retention. More reliable than block-level snapshots of a running database.

**GitOps for deployment**
All configurations and scripts are stored in the Git repository. A `deploy.sh` script on each island pulls new commits via `git pull` and applies them (`docker compose up -d`). A systemd timer automates polling every 15 minutes. Database content is excluded (volumes, backups). Benefits: rollback via `git revert`, audit trail of all changes, consistent rollout across all islands, didactic value (students see change history).

---

## 13. GitOps Workflow

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

## 14. Quick Start Farm Island (Initial Setup)

```bash
# 1. Clone repo to the workstation
git clone https://github.com/YOUR-USER/scm-lab.git /opt/scm-lab
cd /opt/scm-lab

# 2. Run bootstrap script (sets up everything including deploy timer)
chmod +x farm-island/scripts/bootstrap.sh && ./farm-island/scripts/bootstrap.sh
```

---

## 15. Technology Stack (Fully Open Source)

| Layer | Technology | Location | Purpose |
|---|---|---|---|
| Field layer | LoRaWAN sensors | Farm | Soil moisture, temperature, CO₂, light data |
| IoT gateway | MikroTik + ChirpStack | Farm | LoRa to IP, sensor authentication |
| Integration | Node-RED | Farm, Factory, Distributor, Lab Cloud | MQTT bridge, data routing, ERPNext + Fabric integration |
| ERP / MES / WMS | ERPNext (Frappe) | Farm, Factory, Distributor | Stock management, MES, WMS, accounting |
| Internal messaging | Apache Kafka | Per island | Internal event processing (not shared between islands) |
| Robot control | Dobot Python SDK / ROS2 | Factory | Pick & place, sorting, QC |
| Machine data | OPC-UA | Factory | Machine status exposure to MES |
| Route planning | VROOM | Distributor | Delivery route optimisation |
| IoT backend (Coffee House) | Mosquitto + Node-RED + InfluxDB | Lab Cloud | Coffee machine sensor ingestion and storage |
| Blockchain / Traceability | Hyperledger Fabric | Lab Cloud (orderer) + per island (peer) | Tamper-proof batch ledger across all supply chain tiers |
| Blockchain browser | Hyperledger Explorer | Lab Cloud | Visual transaction browser for instructors and students |
| Monitoring | Grafana + Prometheus | Per island + Lab Cloud | Real-time dashboards, cross-island visibility |
| Databases | PostgreSQL + MariaDB + Redis | Per island | ChirpStack data, ERPNext data, cache |
| POS (Coffee House) | Custom web application | Coffee House | Sales, goods receipt, order management |
| Traceability UI | Web application (Node.js / Python) | Coffee House | Customer-facing supply chain + brew parameter display |
| Infrastructure | Docker + Docker Compose | All locations | Service isolation, reproducible deployment |
| Network | MikroTik RouterOS | Per island | DHCP, NTP, routing, LoRaWAN gateway |
