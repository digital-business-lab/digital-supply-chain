# Lab Cloud

The Lab Cloud is a dedicated infrastructure layer running on a **lab server on-premise** — not in Azure, AWS, or any public cloud. It provides managed services consumed by individual islands, primarily the Coffee House, which has no local server infrastructure of its own.

This models a real-world pattern: small businesses subscribe to managed cloud services from a provider without understanding the underlying infrastructure. From the Coffee House's perspective, the Lab Cloud is a black box — the coffee machine sends data out, and a REST endpoint delivers processed results back.

## Services

### Hyperledger Fabric Orderer

Runs the RAFT ordering service for the shared Hyperledger Fabric blockchain network. Each of the three B2B islands (Farm, Factory, Distributor) operates its own Fabric peer node locally as a Docker container; the ordering service runs centrally on the Lab Cloud.

Additionally, the Lab Cloud runs a **Fabric Gateway SDK** endpoint that exposes batch history as a simple REST API. The Coffee House Traceability Display queries this endpoint using a batch ID obtained at goods receipt (from the RFID tag on the delivery bag).

### Coffee House IoT Backend

Since the Coffee House has no local server infrastructure, all IoT processing for the coffee machine is handled by the Lab Cloud:

| Component | Technology | Function |
|---|---|---|
| MQTT broker | Mosquitto | Receives sensor data from the coffee machine |
| Flow processor | Node-RED | Normalises readings, validates, routes to storage |
| Time-series storage | InfluxDB | Stores brew parameters per extraction event |
| Brew parameter API | REST endpoint | Serves latest data to the Traceability Display |

**Sensor data captured per brew:** grind level, temperature, bean type, water volume, water hardness, extraction time.

Note: brewing parameters are **not** written to the Hyperledger Fabric ledger. They are per-cup operational data, not supply chain events. See [hyperledger-fabric.md](hyperledger-fabric.md#what-is-not-on-chain).

### Central Monitoring

| Component | Purpose |
|---|---|
| Grafana (cross-island) | Dashboard showing the state of the entire supply chain for instructors |
| Hyperledger Explorer | Visual browser for all Fabric transactions; useful for teaching blockchain concepts |

## Didactic Significance

The Lab Cloud demonstrates three complementary deployment patterns within a single system:

1. **Fully local** — per-island ERPNext, Kafka, Grafana
2. **Distributed peer-to-peer consensus** — Fabric peer nodes on each B2B island
3. **Centralised managed services** — Lab Cloud (orderer, IoT backend, central monitoring)

Students encounter all three patterns in one coherent scenario and can directly compare their trade-offs.

## Planned Configuration

The Lab Cloud configuration will live in `lab-cloud/` in the repository, structured analogously to the island folders:

```
lab-cloud/
  docker-compose.yml    ← Fabric orderer, Mosquitto, Node-RED, InfluxDB, Grafana
  config/
    fabric/             ← channel config, crypto material
    mosquitto/          ← mosquitto.conf
    grafana/            ← provisioning, dashboards
  scripts/
    bootstrap.sh
    backup.sh
```
