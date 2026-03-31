# Project Instructions for Agents

## Repository

- **GitHub organisation:** digital-business-lab
- **Repository:** digital-supply-chain
- **URL:** https://github.com/digital-business-lab/digital-supply-chain
- **GitHub Pages:** https://digital-business-lab.github.io/digital-supply-chain/

## Language

- Communicate with the user in **German**
- All files, documentation, and code comments in **English**

## Documentation Structure

This project uses GitHub-native documentation:

- `README.md` — slim overview and navigation hub only (no detailed content)
- `docs/*.md` — one file per topic; these are the authoritative content source
- `farm-island/README.md`, `factory-island/README.md`, etc. — island-specific docs rendered by GitHub when navigating to the subfolder
- `mkdocs.yml` — MkDocs config; GitHub Action builds and deploys to GitHub Pages on every push to `main`
- `AGENTS.md` — this file; always read first when working on this project

**Rule:** Never put detailed content directly into `README.md`. Always put it in the appropriate `docs/*.md` file and link from `README.md`.

## Maintaining AGENTS.md

`AGENTS.md` is a living document. After every session it must reflect the current state of agreements and decisions:

- **Update after every significant decision** — if a technology choice, architectural direction, naming convention, or workflow is agreed upon during a conversation, add or revise the relevant entry in this file before the session ends.
- **Record the rationale, not just the outcome** — note briefly *why* a decision was made (constraint, trade-off, experiment result), so future sessions can judge whether the decision still holds.
- **Remove or flag outdated entries** — if a previous decision is superseded, either update the entry or mark it `(superseded)` with the replacement noted.
- **Keep entries concise** — one to two sentences per item; link to the relevant `docs/*.md` file for deeper context.

## Scientific and Self-Critical Working Practice

All design decisions, technology choices, and implementation proposals must follow a scientific, self-critical approach:

- **State assumptions explicitly** — before proposing a solution, name the assumptions it rests on (load estimates, student skill level, hardware availability, etc.).
- **Consider alternatives** — for non-trivial decisions, briefly acknowledge at least one alternative and explain why it was not chosen.
- **Identify open questions and risks** — flag anything that has not yet been validated (e.g. "untested with actual LoRa range", "Shelly relay model not yet confirmed").
- **Prefer reversible decisions** — when two options are comparable, prefer the one that is easier to change later.
- **Distinguish fact from assumption** — use precise language: *"the sensor measures …"* (fact) vs. *"the sensor is expected to measure …"* (assumption).

## Architecture Decisions (summary)

- **Coffee** is the example product throughout — farm → factory → distributor → coffee house
- **Hyperledger Fabric** is a core component (not optional): Farm, Factory, Distributor each run a peer node; Lab Cloud runs the orderer
- **Lab Cloud** is on-premise (not Azure/AWS): hosts Fabric orderer, Coffee House IoT backend (Mosquitto + Node-RED + InfluxDB), central Grafana
- **Coffee House** is intentionally lean: no ERP, no Kafka, no Fabric peer node; three independent modules (POS, Traceability Display, IoT connector)
- **Brewing parameters** (grind, temp, water) are off-chain: stored in InfluxDB, not on Fabric
- **B2B communication** exclusively via REST APIs — Kafka is island-internal only
- **TurtleBot4 Lite** is the last-mile delivery robot, organisationally part of the Distributor Island; uses ROS2 Humble + Nav2 for autonomous navigation. See `docs/islands/distributor.md`.
- **ERP–ROS2 bridge** uses `rosbridge_suite` (WebSocket) + Node-RED — consistent with the existing Node-RED integration pattern on the island; a standalone polling service was considered but rejected. Both ROS2 Docker containers run with `network_mode: host` to enable DDS multicast over the island LAN.
- **Farm: LED grow light and automated irrigation** (Shelly relay + pump) are controlled via Node-RED based on LoRaWAN sensor readings. Shelly relay model not yet confirmed (tbc). See `docs/islands/farm.md`.
- **Factory Island physical structure:** aluminium profile rack, three levels. **Only the top level has a stainless-steel Lochblech** (perforated grid); mid and lower levels are solid multiplex. Top level hosts both Dobot robots and the 6×6 cm snap-in containers; mid = storage; lower = compute. See `docs/islands/factory.md`.
- **Factory Dobot configuration:** Dobot #1 is mounted on a **linear axis** (traverses all station zones: IN → SRT → RST → QC → OUT); Dobot #2 has **Vision Studio + camera** (fixed at QC zone, detects roast level and defects by colour/shape). Seeed Grove sensor inventory pending — temperature, proximity, and colour sensors are planned integration points.
- **Factory MES didactic concept:** five defined scenarios (standard run, quality reject, bottleneck, material shortage, traceability/recall) map MES functions (production order lifecycle, BoM, routing, OEE, non-conformance) to physical robot actions. Roasting is simulated via container movement + time-temperature profile + colour-coded tokens inspected by Vision Studio.
- **Farm → Factory material flow:** manual carry by student/operator; goods receipt scanned (QR code or NFC, tbc) into Factory ERPNext, recorded on Fabric ledger. Conveyor belt and TurtleBot were considered but rejected as over-engineered for adjacent lab islands. Open: QR vs. NFC reader choice.

- **Service Centre Island** is an optional, software-first extension with no permanent physical rack; its didactic purpose is to teach job-shop manufacturing (Werkstattfertigung) and the full MRP planning cycle in ERPNext. Each repair/maintenance job is a production order with a variable routing through shared work centres. The physical simulation method (role-play with job cards, digital mock-up, or lightweight props) is an open design question to be decided before first use. See `service-center-island/README.md`.
- **Island README canonical structure** (all islands follow this template): Title + one-liner → GitHub Pages link → `---` → `## Physical Structure` (optional, only for rack-based islands) + `---` → `## Hardware at a Glance` → `## Services` → `## Quick Start` (operational islands only) → `## Status`.

## What lives in Git

- `docker-compose.yml` and all config files
- Scripts (bootstrap, deploy, backup, restore)
- Documentation (all `.md` files, HTML overviews)

## What does NOT live in Git

- `.env` files (passwords)
- Docker volumes / database data
- Backup archives (`*.tar.gz`, `*.sql.gz`)
