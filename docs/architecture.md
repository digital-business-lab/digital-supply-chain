# Architecture

## The Four Lab Islands

```
Coffee Farm  →  Coffee Processing  →  Coffee Trader  →  Coffee House
   (Farm)          (Factory)           (Distributor)    (Consumer endpoint)
```

Each arrow represents a physical coffee batch moving through the chain and a set of REST API calls between independent companies. Each step is also recorded on the shared Hyperledger Fabric ledger.

| Island | Role | Coffee Context | Key Infrastructure |
|---|---|---|---|
| [Farm](../farm-island/README.md) | Origin of the supply chain | Coffee farm (e.g. Ethiopia / Colombia) | LoRaWAN sensors, ChirpStack, ERPNext, Fabric peer |
| [Factory](../factory-island/README.md) | Processing | Roasting & packaging | 2× Dobot robots, MES, OPC-UA, ERPNext, Fabric peer |
| [Distributor](../distributor-island/README.md) | Warehouse & Logistics | Coffee trader | ERPNext WMS, VROOM, Fabric peer |
| [Coffee House](../coffeehouse-island/README.md) | Consumer endpoint | Café / coffee bar | POS, Traceability Display, no ERP, no Fabric peer |

**B2B communication exclusively via REST APIs.** Kafka is island-internal only and never crosses company boundaries. See [b2b-communication.md](b2b-communication.md).

## Lab Cloud

A dedicated on-premise lab server (not Azure / AWS) providing managed services consumed by the islands — primarily the Coffee House, which has no local server infrastructure.

| Service | Technology | Purpose |
|---|---|---|
| Hyperledger Fabric Orderer | RAFT consensus | Coordinates consensus across all Fabric peer nodes |
| Fabric Gateway REST API | Fabric Gateway SDK | Read-only batch history endpoint for the Coffee House |
| Coffee House IoT Backend | Mosquitto + Node-RED + InfluxDB | Ingests coffee machine sensor data, serves REST to Traceability Display |
| Central Monitoring | Grafana + Hyperledger Explorer | Cross-island dashboard and blockchain browser for instructors |

Full details → [lab-cloud.md](lab-cloud.md)

## Hyperledger Fabric

Hyperledger Fabric provides a shared, tamper-proof ledger of supply chain events. Each B2B island writes one batch event per step; the Coffee House reads history via the Lab Cloud Fabric Gateway REST API.

| Node | Location |
|---|---|
| Fabric Peer Node | Farm island (Docker container) |
| Fabric Peer Node | Factory island (Docker container) |
| Fabric Peer Node | Distributor island (Docker container) |
| Fabric Orderer (RAFT) | Lab Cloud |
| Fabric Gateway REST API | Lab Cloud |

Full details → [hyperledger-fabric.md](hyperledger-fabric.md)

## Coffee House — Three Independent Modules

| Module | Hardware | Function |
|---|---|---|
| POS Module | Linux PC + RFID/barcode scanner | Sales, goods receipt (triggers Distributor REST call), reorders |
| Traceability Display | Customer-facing display | Batch history (Fabric Gateway) + brew parameters (Lab Cloud IoT) |
| IoT Connector | Coffee machine | Sends sensor data via MQTT/serial to Lab Cloud — no local processing |

The three modules communicate via local REST endpoints and can be deployed on one or several machines.

## Technology Stack

| Layer | Technology | Location | Purpose |
|---|---|---|---|
| Field layer | LoRaWAN sensors | Farm | Soil moisture, temperature, CO₂, light |
| IoT gateway | MikroTik + ChirpStack | Farm | LoRa to IP, sensor authentication |
| Integration | Node-RED | Farm, Factory, Distributor, Lab Cloud | MQTT bridge, ERPNext + Fabric integration |
| ERP / MES / WMS | ERPNext (Frappe) | Farm, Factory, Distributor | Stock, MES, WMS, accounting |
| Internal messaging | Apache Kafka | Per island | Internal events only — never crosses islands |
| Robot control | Dobot Python SDK / ROS2 | Factory | Pick & place, sorting, QC |
| Machine data | OPC-UA | Factory | Machine status to MES |
| Route planning | VROOM | Distributor | Delivery route optimisation |
| IoT backend | Mosquitto + Node-RED + InfluxDB | Lab Cloud | Coffee machine sensor ingestion and storage |
| Blockchain | Hyperledger Fabric | Lab Cloud (orderer) + per island (peer) | Tamper-proof batch ledger |
| Blockchain browser | Hyperledger Explorer | Lab Cloud | Visual transaction browser |
| Monitoring | Grafana + Prometheus | Per island + Lab Cloud | Real-time dashboards |
| Databases | PostgreSQL + MariaDB + Redis | Per island | ChirpStack, ERPNext, cache |
| POS | Custom web application | Coffee House | Sales, goods receipt, order management |
| Traceability UI | Web application | Coffee House | Customer-facing supply chain + brew display |
| Infrastructure | Docker + Docker Compose | All locations | Service isolation, reproducible deployment |
| Network | MikroTik RouterOS | Per island | DHCP, NTP, routing, LoRaWAN gateway |
