# Coffee House Island — Consumer Endpoint

The Coffee House is the consumer endpoint of the supply chain. It is intentionally lean: no ERP, no Kafka, no Fabric peer node. A real coffee house has no IT department. Its three software modules can run on one machine or on separate hardware.

→ [Architecture overview](../../architecture/) | [Lab Cloud](../../../lab-cloud/README.md) | [Hyperledger Fabric](../../architecture/hyperledger-fabric.md)

---

## Hardware

| Component | Function |
|---|---|
| Linux PC | Runs POS module and optionally Traceability Display |
| RFID / barcode scanner | Goods receipt (incoming bags) and optionally customer receipts |
| Customer-facing display | Traceability Display web application |
| Smart coffee machine + sensors | Reports grind, temperature, bean type, water volume, hardness, extraction time |

---

## Three Independent Software Modules

| Module | Function | Connects to |
|---|---|---|
| **POS Module** | Sales, goods receipt (RFID scan → Distributor REST call), reorders | Distributor REST API |
| **Traceability Display** | Shows full batch history + brew parameters to the customer | Lab Cloud (Fabric Gateway + IoT REST) |
| **IoT Connector** | Coffee machine sends sensor data via MQTT/serial | Lab Cloud IoT backend |

The modules communicate with each other via local REST endpoints and are loosely coupled — each can be developed, deployed, and replaced independently.

---

## What the Coffee House Does NOT Have

| Not present | Reason |
|---|---|
| ERP system | A real coffee house doesn't have one |
| Kafka / internal message broker | No need for event streaming at this scale |
| Hyperledger Fabric peer node | Read-only access via Lab Cloud Fabric Gateway is sufficient |
| Local IoT processing | Delegated to Lab Cloud — analogous to a managed cloud service |

---

## Traceability Flow

```
Customer orders a coffee
    ↓
Barista scans bag RFID tag (or customer scans QR on receipt)
    ↓
POS Module retrieves batch_id
    ↓
Traceability Display queries Lab Cloud Fabric Gateway (REST)
    ↓
Display shows:
  ✓ Farm:        Yirgacheffe, Ethiopia, 1850m altitude
  ✓ Factory:     medium roast, 212°C, 11 min
  ✓ Distributor: shipped Vienna depot → this café
  ✓ This cup:    18g grind, 93°C, 28s extraction
```

---

## Status

> **Planned** — POS module, Traceability Display, and IoT connector are not yet implemented.
