# Coffee House Island — Consumer Endpoint

The Coffee House is the consumer endpoint of the supply chain. It is intentionally lean: no ERP, no Kafka, no Fabric peer node. A real coffee house has no IT department. Its three software modules can run on one machine or on separate hardware.

→ [Architecture overview](../../architecture/index.md) | [Dependencies & integration contracts](../../architecture/dependencies.md) | [Lab Cloud](../../lab-cloud/index.md) | [Hyperledger Fabric](../../architecture/hyperledger-fabric.md)

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

## External Dependencies

- **Distributor dependency:** POS needs the documented Distributor REST boundary for purchase orders and inbound delivery notices
- **Lab Cloud dependency:** Traceability Display needs the Fabric Gateway and brew REST endpoints; IoT Connector needs the Lab Cloud MQTT broker
- **Explicit non-dependency:** the Coffee House does not call Farm or Factory APIs directly
- **Independent local development remains possible:** all three modules can be built against mocks as long as they keep the documented external contracts

See [Dependencies and Integration Contracts](../../architecture/dependencies.md) for the canonical shared boundary definition.

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

## Prompt Walkthrough Example — Goods Receipt, Sale, Traceability

The supply-chain walkthrough prompt uses the following Coffee House sequence:

1. **Goods receipt**
   - Distributor calls:

   ```http
   POST https://<coffeehouse-ip>:5000/api/delivery_notice
   Content-Type: application/json

   { "batch_id": "FACTORY-ROAST-001", "rfid_tags": ["RFID-001"], "quantity_kg": 1 }
   ```

   - **Physical:** the delivered bag arrives from the TurtleBot4 and the barista scans `RFID-001`.
   - **Digital:** the POS stores `batch_id = FACTORY-ROAST-001` for later sale and traceability.

2. **Brewing telemetry**
   - The coffee machine sends:

   ```json
   {
     "batch_id": "FACTORY-ROAST-001",
     "grind_g": 18,
     "water_temp_c": 93,
     "water_ml": 200,
     "extraction_s": 28,
     "hardness_dh": 7
   }
   ```

   - The Lab Cloud IoT backend stores this in InfluxDB measurement `brew_events`.
   - This telemetry stays **off-chain**; it is not written to Hyperledger Fabric.

3. **Customer-facing traceability**
   - The Traceability Display queries:

   ```http
   GET https://<labcloud-ip>:8080/fabric/batch/FACTORY-ROAST-001/history
   ```

   - The display renders:

   ```text
   ✓ Farm:        Yirgacheffe, Ethiopia, 1850m — harvest_recorded
   ✓ Factory:     goods_receipt → roasting_complete → qc_pass
   ✓ Distributor: goods_receipt → delivery_completed
   ✓ This cup:    18g grind, 93°C, 28s extraction
   ```

**Assumption:** the Coffee House POS can resolve the scanned RFID tag to the stored `batch_id` without introducing a separate local ERP layer.

**Implementation note:** a lightweight local POS data store such as SQLite is sufficient for local POS state if it is populated from the incoming `delivery_notice`; this store is not intended to become a second ERP system.

---

## Status

> **Planned** — POS module, Traceability Display, and IoT connector are not yet implemented.
