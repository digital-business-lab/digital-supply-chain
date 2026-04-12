# Lab Cloud — Setup Guide

Step-by-step guide for provisioning the Lab Cloud from a fresh server.
The Lab Cloud **must be running before any island peer joins the Fabric channel**.

**Prerequisites:** Complete [Workstation Setup](../operations/setup-workstation.md) first (Ubuntu 22.04, Docker, repository cloned to `/opt/digital-supply-chain`).

→ [Lab Cloud architecture overview](README.md) | [Hyperledger Fabric concepts](../architecture/hyperledger-fabric.md) | [Supply Chain Setup Guide](../operations/setup-guide.md)

---

## Hardware

| Component | Spec |
|---|---|
| Server | Linux workstation — same class as island workstations (i7, 16 GB RAM, 256 GB SSD) |
| OS | Ubuntu 22.04 LTS |
| Network | Fixed IP on the lab LAN (recommended: `192.168.1.1` or via DHCP reservation by MAC) |

The server runs all Lab Cloud services in Docker. 16 GB RAM is the minimum; the combined footprint of the Fabric orderer, IoT backend, Grafana, and Hyperledger Explorer sits comfortably within this budget.

---

## Services

| Service | Port | Technology | Function |
|---|---|---|---|
| Fabric Orderer (RAFT) | 7050 | Hyperledger Fabric 2.5 LTS | Consensus ordering for all island peer nodes |
| Fabric Gateway API | 8080 | Node.js + `@hyperledger/fabric-gateway` | REST endpoint for traceability queries (Coffee House) |
| Mosquitto | 1883 | Eclipse Mosquitto | Receives coffee machine sensor data from Coffee House |
| Node-RED | 1880 | Node-RED | Normalises IoT data; writes to InfluxDB; serves brew parameter REST |
| InfluxDB | 8086 | InfluxDB v2 | Time-series storage for per-brew sensor readings |
| Grafana (central) | 3000 | Grafana | Cross-island supply chain dashboard for instructors |
| Hyperledger Explorer | 8081 | Hyperledger Explorer | Visual browser for all Fabric transactions |

All services except Mosquitto and the Fabric Gateway API are internal to the Lab Cloud. The Coffee House connects to ports **1883** (MQTT) and **8080** (REST). Island peer nodes connect to port **7050** (gRPC).

---

## Repository Structure

Once implemented, the `lab-cloud/` folder will mirror the island folder pattern:

```
lab-cloud/
  docker-compose.yml        ← all Lab Cloud services
  .env.example              ← template for secrets (committed)
  .env                      ← actual secrets (gitignored)
  config/
    fabric/
      crypto-config.yaml    ← cryptogen input: 4 orgs (Farm, Factory, Distributor, OrdererOrg)
      configtx.yaml         ← channel profile, orderer config, org MSPs
      organizations/        ← generated crypto material (gitignored)
      channel-artifacts/    ← genesis block, channel tx (gitignored)
    mosquitto/
      mosquitto.conf
    nodered/
      flows.json            ← IoT normalisation flows + brew parameter REST endpoint
    grafana/
      provisioning/
        datasources/        ← InfluxDB v2, Fabric data sources
        dashboards/         ← cross-island supply chain dashboard JSON
    influxdb/
      setup.sh              ← creates org, bucket, API token on first run
  scripts/
    bootstrap.sh            ← idempotent full setup (calls steps below)
    01-generate-crypto.sh   ← cryptogen generate
    02-create-channel.sh    ← osnadmin channel join (orderer self-joins)
    03-deploy-chaincode.sh  ← package, install, approve, commit (run per island once peers are up)
    backup.sh
    restore.sh
```

!!! note
    `config/fabric/organizations/` and `config/fabric/channel-artifacts/` are generated artefacts and must be **gitignored**. Crypto material contains private keys. Channel artefacts are deterministically reproducible from `configtx.yaml`.

---

## Step 1 — Provision the Server

```bash
# On the lab server — after completing Workstation Setup (Ubuntu 22.04 + Docker)
cd /opt/digital-supply-chain
cp lab-cloud/.env.example lab-cloud/.env
nano lab-cloud/.env   # fill in all placeholder values (see .env.example for required keys)
```

Required `.env` values:

| Variable | Description |
|---|---|
| `ORDERER_GENERAL_LOGLEVEL` | `INFO` recommended; `DEBUG` for troubleshooting |
| `INFLUXDB_ADMIN_TOKEN` | Initial admin token — set once, keep secret |
| `INFLUXDB_ORG` | InfluxDB organisation name (e.g. `digital-supply-chain`) |
| `INFLUXDB_BUCKET` | Bucket for coffee machine data (e.g. `coffeehouse-iot`) |
| `INFLUXDB_RETENTION` | Retention duration (e.g. `30d`) |
| `GRAFANA_ADMIN_PASSWORD` | Initial Grafana admin password |
| `FABRIC_GATEWAY_PORT` | Port for the Fabric Gateway REST service (default `8080`) |
| `MOSQUITTO_ALLOW_ANONYMOUS` | `false` — configure password auth (see Mosquitto section) |

---

## Step 2 — Generate Fabric Crypto Material

Fabric identities are managed with **cryptogen** — appropriate for a teaching lab.

> **Decision rationale:** Fabric CA provides dynamic enrolment and is more realistic, but adds two CA servers plus enrolment procedures per organisation. cryptogen generates static key material from a YAML spec, which is reproducible and easier to understand in a teaching context. Revocation and dynamic enrolment are not required here.

### 2.1 Install Fabric Binaries

```bash
# Install Fabric 2.5 LTS binaries + Docker images
cd /opt/digital-supply-chain/lab-cloud
curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.5.0 1.5.7
# Binaries land in lab-cloud/bin/; add to PATH for this session:
export PATH=$PWD/bin:$PATH
```

### 2.2 Write crypto-config.yaml

`lab-cloud/config/fabric/crypto-config.yaml` defines four organisations:

```yaml
OrdererOrgs:
  - Name: OrdererOrg
    Domain: orderer.lab.local
    Specs:
      - Hostname: orderer

PeerOrgs:
  - Name: FarmOrg
    Domain: farm.lab.local
    Template:
      Count: 1
    Users:
      Count: 1

  - Name: FactoryOrg
    Domain: factory.lab.local
    Template:
      Count: 1
    Users:
      Count: 1

  - Name: DistributorOrg
    Domain: distributor.lab.local
    Template:
      Count: 1
    Users:
      Count: 1
```

### 2.3 Generate Crypto Material

```bash
cd /opt/digital-supply-chain/lab-cloud/config/fabric
cryptogen generate --config=crypto-config.yaml --output=organizations
```

Output: `organizations/` tree containing MSP directories, TLS certs, and private keys for all four orgs.

---

## Step 3 — Create the Fabric Channel

### 3.1 Write configtx.yaml

`lab-cloud/config/fabric/configtx.yaml` defines:

- MSP directories for each org (pointing into `organizations/`)
- Orderer configuration: RAFT, `BatchTimeout: 2s`, `MaxMessageCount: 10`
- An application channel profile `SupplyChainChannel` with all four orgs

!!! warning "Placeholder — configtx.yaml template not yet written"
    A working template will be committed to `lab-cloud/config/fabric/configtx.yaml` when the `lab-cloud/` folder is created. Refer to the [Hyperledger Fabric 2.5 sample configtx.yaml](https://github.com/hyperledger/fabric-samples/blob/main/config/configtx.yaml) as a starting point.

### 3.2 Generate the Genesis Block

```bash
configtxgen \
  -profile SupplyChainChannel \
  -outputBlock channel-artifacts/lab-channel.block \
  -channelID lab-channel \
  -configPath config/fabric
```

### 3.3 Orderer Self-Joins the Channel

With Fabric 2.5 (`osnadmin`), the orderer joins a channel by receiving its genesis block directly — no separate system channel needed:

```bash
# The orderer container must be running (started in Step 4)
osnadmin channel join \
  --channelID lab-channel \
  --config-block channel-artifacts/lab-channel.block \
  -o localhost:7053 \
  --ca-file  organizations/ordererOrganizations/orderer.lab.local/tlsca/tlsca.orderer.lab.local-cert.pem \
  --client-cert organizations/ordererOrganizations/orderer.lab.local/orderers/orderer.orderer.lab.local/tls/server.crt \
  --client-key  organizations/ordererOrganizations/orderer.lab.local/orderers/orderer.orderer.lab.local/tls/server.key
```

---

## Step 4 — Start the Lab Cloud Stack

```bash
cd /opt/digital-supply-chain/lab-cloud
docker compose up -d
docker compose ps     # all services should show "running"
```

### Services after startup

| Service | URL | Notes |
|---|---|---|
| Fabric Orderer | `grpcs://localhost:7050` | TLS — island peers connect here |
| Fabric Gateway API | `http://localhost:8080` | REST — Coffee House connects here |
| Mosquitto | `mqtt://localhost:1883` | MQTT — Coffee House connects here |
| Node-RED | `http://localhost:1880` | Flow editor |
| InfluxDB | `http://localhost:8086` | Admin UI |
| Grafana | `http://localhost:3000` | Central dashboard |
| Hyperledger Explorer | `http://localhost:8081` | Fabric transaction browser |

### InfluxDB First-Time Setup

On first start, InfluxDB v2 requires an initialisation step:

```bash
docker compose exec influxdb influx setup \
  --org "$INFLUXDB_ORG" \
  --bucket "$INFLUXDB_BUCKET" \
  --username admin \
  --password "$INFLUXDB_ADMIN_PASSWORD" \
  --token "$INFLUXDB_ADMIN_TOKEN" \
  --retention "$INFLUXDB_RETENTION" \
  --force
```

This is idempotent — safe to run multiple times. The bootstrap script calls it automatically.

---

## Step 5 — Deploy the Supply Chain Chaincode

The chaincode is written in **Go** and lives at `lab-cloud/chaincode/supplychain/`.

> **Decision rationale:** Go is idiomatic for Hyperledger Fabric and has the most complete documentation and examples. TypeScript/Node.js was considered (lower barrier for students unfamiliar with Go) but rejected because Go chaincode has significantly better performance and the examples in the official Fabric samples are Go-first.

### Chaincode Data Model

The chaincode manages one asset type: `BatchEvent`. Multiple events per `batch_id` are stored; a query by `batch_id` returns the full chain of events across all islands.

```go
type BatchEvent struct {
    BatchID   string `json:"batch_id"`
    EventType string `json:"event_type"` // "harvest" | "roast" | "ship" | "receive"
    Island    string `json:"island"`
    Timestamp string `json:"timestamp"`
    Data      string `json:"data"`        // JSON-encoded event-specific fields
}
```

Key chaincode functions:

| Function | Caller | Description |
|---|---|---|
| `RecordEvent(batchID, eventType, island, data)` | Island Node-RED | Appends a new BatchEvent to the ledger |
| `GetBatchHistory(batchID)` | Fabric Gateway API | Returns all events for a batch_id, ordered by timestamp |
| `GetAllBatches()` | Grafana / Explorer | Returns all known batch_ids (for instructor overview) |

### 5.1 Chaincode Lifecycle

!!! warning "Placeholder — chaincode source not yet written"
    The chaincode source will be at `lab-cloud/chaincode/supplychain/`. Steps below show the commands; they require all three island peers to be running and channel-joined.

```bash
cd /opt/digital-supply-chain/lab-cloud

# 1. Package
peer lifecycle chaincode package supplychain.tar.gz \
  --path ./chaincode/supplychain \
  --lang golang \
  --label supplychain_1.0

# 2. Install on each peer (run once per island peer — see ../operations/setup-guide.md)
#    Each island admin runs this on their own peer node.

# 3. Approve for each org (org admin runs this from each island)
peer lifecycle chaincode approveformyorg ...

# 4. Commit (run once, by any org, after all orgs approved)
peer lifecycle chaincode commit ...
```

Full parameter examples will be added to the chaincode README once the source is written. Endorsement policy: **majority of orgs** (2 out of 3 peer orgs must endorse each transaction).

---

## Step 6 — Fabric Gateway REST Service

The Fabric Gateway REST service is a lightweight **Node.js/Express** application using the `@hyperledger/fabric-gateway` package. It connects to the orderer and queries the ledger on behalf of the Coffee House.

```
coffeehouse-app  ──GET /batch/:id──►  Fabric Gateway REST (Lab Cloud :8080)
                                              │
                                              │ gRPC (Fabric Gateway SDK)
                                              ▼
                                    Lab Cloud orderer → peer nodes
```

!!! warning "Placeholder — Fabric Gateway REST service not yet implemented"
    The service will live at `lab-cloud/services/fabric-gateway-api/`. Expected endpoints:

    | Method | Path | Response |
    |---|---|---|
    | `GET` | `/batch/:batch_id` | All `BatchEvent` records for the given batch_id |
    | `GET` | `/batches` | List of all known batch_ids |
    | `GET` | `/health` | Service health check |

    Authentication: API key in `Authorization: Bearer <token>` header. The token is configured in `.env` and shared with the Coffee House. No user-level auth is needed for this teaching use case.

---

## Step 7 — Mosquitto (Coffee House IoT)

The Coffee House coffee machine sends sensor data to the Lab Cloud Mosquitto broker over MQTT.

### mosquitto.conf

```
listener 1883
allow_anonymous false
password_file /mosquitto/config/passwd

# Topic structure: coffeehouse/brew/<machine_id>
```

Create the password file (do this before starting the stack):

```bash
docker run --rm -v $(pwd)/config/mosquitto:/mosquitto/config \
  eclipse-mosquitto \
  mosquitto_passwd -c /mosquitto/config/passwd coffeehouse
# Enter and confirm the password when prompted
```

The Coffee House IoT Connector is configured with the same username/password in its `.env`.

---

## Step 8 — Node-RED IoT Flows

Two flows run in the Lab Cloud Node-RED instance:

### Flow 1 — Brew Data Ingestion

```
MQTT In (coffeehouse/brew/+)
  → JSON parse
  → validate required fields (grind_g, temp_c, water_ml, extraction_s, bean_type)
  → InfluxDB v2 write (bucket: coffeehouse-iot, measurement: brew)
```

### Flow 2 — Brew Parameter REST Endpoint

```
HTTP In (GET /brew/:batch_id/latest)
  → InfluxDB v2 query (Flux: last brew event for batch_id)
  → format JSON response
  → HTTP Response
```

This REST endpoint is called by the Coffee House Traceability Display to retrieve brewing parameters alongside the Fabric batch history.

!!! warning "Placeholder — Node-RED flow JSON not yet written"
    Flows will be committed to `lab-cloud/config/nodered/flows.json`. The InfluxDB v2 node (`node-red-contrib-influxdb`) must be installed in the Node-RED container.

---

## Step 9 — Grafana Central Dashboard

The central Grafana instance visualises the overall supply chain state for instructors.

!!! warning "Placeholder — Grafana dashboard not yet designed"
    Planned panels:

    - **Fabric ledger activity** — transaction count per org, last event timestamps, batch event timeline
    - **Farm sensors** — forwarded via InfluxDB on the Farm island (cross-island Grafana data source)
    - **Coffee House IoT** — latest brew parameters from the Lab Cloud InfluxDB
    - **Island service health** — up/down status per island (Prometheus blackbox exporter or simple HTTP probe)

    Provisioning files will live in `lab-cloud/config/grafana/provisioning/`.

---

## Step 10 — Hyperledger Explorer

Hyperledger Explorer provides a web-based view of all Fabric blocks and transactions. It is primarily a **teaching tool** — useful for showing students the ledger structure in class.

!!! warning "Placeholder — Explorer configuration not yet written"
    Explorer requires a `connection-profile.json` that points to the orderer and all peer nodes via their TLS certs and enrolled identities. This will be generated as part of the bootstrap process once the `lab-cloud/` folder is implemented.

---

## Checkpoint

After completing all steps:

- [ ] `docker compose ps` — all 7 services running
- [ ] Fabric orderer reachable on port `7050` from all island workstations: `curl -k https://<lab-cloud-ip>:7050`
- [ ] Channel `lab-channel` exists: `osnadmin channel list -o localhost:7053 ...`
- [ ] InfluxDB admin UI accessible at `http://<lab-cloud-ip>:8086`
- [ ] Mosquitto accepts MQTT connections from Coffee House subnet
- [ ] Node-RED flows loaded and deployed (no red error nodes)
- [ ] Grafana central dashboard loads at `http://<lab-cloud-ip>:3000`
- [ ] Hyperledger Explorer shows the channel at `http://<lab-cloud-ip>:8081`
- [ ] Fabric Gateway REST: `curl http://<lab-cloud-ip>:8080/health` returns `{"status":"ok"}`

---

## Design Decisions

| Decision | Choice | Alternative considered | Rationale |
|---|---|---|---|
| Certificate management | `cryptogen` | Fabric CA | cryptogen is reproducible from a YAML spec; Fabric CA adds two CA servers + enrolment scripts per org — unnecessary complexity for a teaching lab that has no dynamic enrolment requirement |
| Orderer count | 1 RAFT node | 3-node RAFT | Single node removes quorum complexity; fault tolerance is not a priority in a lab setting; 3 nodes would require a more powerful server or separate machines |
| Chaincode language | Go | TypeScript/Node.js | Go is idiomatic for Fabric; has the most reference material; outperforms Node.js chaincode at equivalent complexity |
| InfluxDB version | v2 | v1 | v2 is the current supported release; bucket/token model maps better to multi-tenant use; InfluxQL (v1) is still available via compatibility layer if needed |
| Server hardware | i7 / 16 GB (same class as islands) | Dedicated server | Reduces hardware procurement complexity; tested to be sufficient for the combined service footprint |
