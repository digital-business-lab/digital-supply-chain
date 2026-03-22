# Project Instructions for Claude

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
- `CLAUDE.md` — this file; always read first when working on this project

**Rule:** Never put detailed content directly into `README.md`. Always put it in the appropriate `docs/*.md` file and link from `README.md`.

## Architecture Decisions (summary)

- **Coffee** is the example product throughout — farm → factory → distributor → coffee house
- **Hyperledger Fabric** is a core component (not optional): Farm, Factory, Distributor each run a peer node; Lab Cloud runs the orderer
- **Lab Cloud** is on-premise (not Azure/AWS): hosts Fabric orderer, Coffee House IoT backend (Mosquitto + Node-RED + InfluxDB), central Grafana
- **Coffee House** is intentionally lean: no ERP, no Kafka, no Fabric peer node; three independent modules (POS, Traceability Display, IoT connector)
- **Brewing parameters** (grind, temp, water) are off-chain: stored in InfluxDB, not on Fabric
- **B2B communication** exclusively via REST APIs — Kafka is island-internal only

## What lives in Git

- `docker-compose.yml` and all config files
- Scripts (bootstrap, deploy, backup, restore)
- Documentation (all `.md` files, HTML overviews)

## What does NOT live in Git

- `.env` files (passwords)
- Docker volumes / database data
- Backup archives (`*.tar.gz`, `*.sql.gz`)
