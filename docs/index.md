# Digital Open-Source Supply Chain (Coffee)

A teaching and research project simulating a multi-tier B2B supply chain using **coffee as the example product**. Four independent lab islands communicate via REST APIs and a shared Hyperledger Fabric ledger — entirely open-source.

> **Central idea:** A customer in the Coffee House scans a QR code and traces their cup of coffee all the way back to the farm — origin, roasting profile, distributor route, and brewing parameters.

---

## Lab Islands

| Island | Role | Key Technology |
|---|---|---|
| [Farm](islands/farm.md) | Coffee farm · origin of the chain | LoRaWAN, ChirpStack, ERPNext, Fabric peer |
| [Factory](islands/factory.md) | Roasting & processing | Dobot robots, MES, OPC-UA, Fabric peer |
| [Distributor](islands/distributor.md) | Coffee trader & warehouse | ERPNext WMS, VROOM, Fabric peer |
| [Coffee House](islands/coffeehouse.md) | Consumer endpoint · no ERP | POS, Traceability Display, Lab Cloud IoT |

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

### Completed
- Overall concept documented (this site)
- Visual architecture overview ([lab-islands_overview_2.html](lab-islands_overview_2.html))
- Farm island fully specified and operational

### Open
- Factory, Distributor, Coffee House islands
- Lab Cloud setup
- Hyperledger Fabric network
- REST API endpoint definitions
- Curriculum and seminar use cases

---

## Quick Start — Farm Island

```bash
git clone https://github.com/digital-business-lab/digital-supply-chain.git
cd digital-supply-chain
chmod +x farm-island/scripts/bootstrap.sh && ./farm-island/scripts/bootstrap.sh
```

→ [Farm Island setup guide](islands/farm.md)

---

## Technology Stack

LoRaWAN · ChirpStack · ERPNext · Apache Kafka · Dobot · OPC-UA · VROOM · Hyperledger Fabric · Mosquitto · Node-RED · InfluxDB · Grafana · Docker · MikroTik RouterOS

→ [Full technology stack](architecture.md#technology-stack)
