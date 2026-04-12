# Digital Open-Source Supply Chain (Coffee)

A teaching and research project simulating a multi-tier B2B supply chain using **coffee as the example product**. Four independent lab islands communicate via REST APIs and a shared Hyperledger Fabric ledger — entirely open-source.

> **Central idea:** A customer in the Coffee House scans a QR code and traces their cup of coffee all the way back to the farm — origin, roasting profile, distributor route, and brewing parameters.

---

## Lab Islands

| Island | Role | Key Technology |
|---|---|---|
| [Farm](farm-island/README.md) | Coffee farm · origin of the chain | LoRaWAN, ChirpStack, ERPNext, Fabric peer |
| [Factory](factory-island/README.md) | Roasting & processing | Dobot robots, MES, OPC-UA, Fabric peer |
| [Distributor](distributor-island/README.md) | Coffee trader & warehouse | ERPNext WMS, VROOM, Fabric peer |
| [Coffee House](coffeehouse-island/README.md) | Consumer endpoint · no ERP | POS, Traceability Display, Lab Cloud IoT |
| [Service Centre](service-center-island/README.md) *(optional)* | Coffee equipment repair · job-shop MRP | ERPNext Manufacturing, Fabric Peer (optional) |

B2B communication exclusively via **REST APIs**. Each island is an independent company with its own ERPNext and Kafka. The Coffee House is intentionally lean — no ERP, no Kafka, no Fabric peer node.

---

## Documentation

| Topic | Description |
|---|---|
| [Architecture](docs/architecture/) | Four islands, Lab Cloud, Hyperledger Fabric overview |
| [Lab Cloud](lab-cloud/README.md) | On-premise shared services (Fabric orderer, IoT backend, monitoring) |
| [Hyperledger Fabric](docs/architecture/hyperledger-fabric.md) | End-to-end batch traceability across all tiers |
| [B2B Communication](docs/architecture/b2b-communication.md) | REST API messages between companies |
| [LoRaWAN Architecture](docs/islands/farm/lorawan.md) | Four-layer sensor stack on the Farm island |
| [Network Architecture](docs/architecture/network.md) | All services, ports, and access rules |
| [Didactic Scenarios](docs/teaching/didactic-scenarios.md) | Use cases for foundational, advanced, and research courses |
| [Operations & Backup](docs/operations/) | Backup strategy, VM templates for teaching |
| [Architecture Decisions](docs/architecture/decisions.md) | Why we chose what we chose |
| [GitOps Workflow](docs/operations/gitops.md) | How configuration changes reach the islands |

**Visual overview:** [docs/lab-islands_overview_2.html](docs/lab-islands_overview_2.html)

---

## Quick Start — Farm Island

```bash
git clone https://github.com/digital-business-lab/digital-supply-chain.git
cd digital-supply-chain
chmod +x farm-island/scripts/bootstrap.sh && ./farm-island/scripts/bootstrap.sh
```

See [Farm Island setup guide](farm-island/README.md) for full instructions.

---

## Technology Stack

LoRaWAN · ChirpStack · ERPNext · Apache Kafka · Dobot · OPC-UA · VROOM · Hyperledger Fabric · Mosquitto · Node-RED · InfluxDB · Grafana · Docker · MikroTik RouterOS

Full table → [docs/architecture/#technology-stack](docs/architecture/#technology-stack)
