# Digital Open-Source Supply Chain (Coffee)

A teaching and research project simulating a multi-tier B2B supply chain using **coffee as the example product**. Four independent lab islands communicate via REST APIs and a shared Hyperledger Fabric ledger — entirely open-source.

> **Central idea:** A customer in the Coffee House scans a QR code and traces their cup of coffee all the way back to the farm — origin, roasting profile, distributor route, and brewing parameters.

---

## Lab Islands

| Island | Role | Key Technology |
|---|---|---|
| [Farm](islands/farm/index.md) | Coffee farm · origin of the chain | LoRaWAN, ChirpStack, ERPNext, Fabric peer |
| [Factory](islands/factory/index.md) | Roasting & processing | Dobot robots, MES, OPC-UA, Fabric peer |
| [Distributor](islands/distributor/index.md) | Coffee trader & warehouse | ERPNext WMS, VROOM, Fabric peer |
| [Coffee House](islands/coffeehouse/index.md) | Consumer endpoint · no ERP | POS, Traceability Display, Lab Cloud IoT |

B2B communication exclusively via **REST APIs**. Each island is an independent company with its own ERPNext and Kafka. The Coffee House is intentionally lean — no ERP, no Kafka, no Fabric peer node.

---

## Architecture at a Glance

```
Coffee Farm  →  Coffee Processing  →  Coffee Trader  →  Coffee House
   (Farm)          (Factory)           (Distributor)    (Consumer endpoint)
        │                │                    │                  │
        └────────────────┴────────────────────┘                  │
                         │                                        │
              ┌──────────────────────┐                           │
              │       Lab Cloud       │◄──────────────────────────┘
              │  Fabric Orderer       │  IoT sensor data + Fabric client
              │  Coffee IoT Backend   │
              │  Central Monitoring   │
              └──────────────────────┘
```

→ [Full architecture documentation](architecture.md)

---

## Project Status

| Component | Status |
|---|---|
| Overall concept & documentation site | Completed |
| Visual architecture overview | Completed |
| Farm Island — stack & automation | Partially specified — setup docs exist, full validation pending |
| Lab Cloud — Fabric orderer + IoT backend | Planned — not yet set up |
| Factory Island | Partially specified — hardware defined, docker-compose pending |
| Distributor Island | Partially specified — architecture defined, docker-compose pending |
| Coffee House Island | Planned — modules not yet implemented |
| Hyperledger Fabric network (multi-island) | Planned |
| REST API endpoint definitions | Planned |
| Curriculum and seminar use cases | Planned |

---

## Build the Supply Chain

The [Supply Chain Setup Guide](setup-guide.md) walks through standing up all components in the correct order, with checkpoints and links to each island's detail documentation.

→ [Setup Guide](setup-guide.md)

---

## Technology Stack

LoRaWAN · ChirpStack · ERPNext · Apache Kafka · Dobot · OPC-UA · VROOM · Hyperledger Fabric · Mosquitto · Node-RED · InfluxDB · Grafana · Docker · MikroTik RouterOS

→ [Full technology stack](architecture.md#technology-stack)
