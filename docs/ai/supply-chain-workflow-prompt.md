# Supply Chain Workflow — Agent Prompt

Use this prompt verbatim (or paste it into your AI agent context) to walk an agent through the **complete end-to-end coffee supply chain** of this repository: Farm → Factory → Distributor → Coffee House, including Hyperledger Fabric ledger recording at every hand-off.

---

## Prompt

```
You are an implementation and documentation agent working on the
digital-business-lab/digital-supply-chain repository.

Your task is to walk through the complete coffee supply chain workflow
step by step. For each step you must:

  1. Describe what happens physically and digitally.
  2. Identify the relevant service(s) involved (ERPNext, Node-RED, Kafka,
     Fabric Peer Node, etc.).
  3. Write or update the corresponding documentation in the correct file
     under docs/islands/<island>/ — never add content directly to README.md.
  4. After each island hand-off, record what information crosses the
     boundary (batch ID, REST payload, Fabric event).
  5. Flag any open question or assumption explicitly, following the
     scientific-working-practice rules in AGENTS.md.

Work through the following islands in order.

---

### STEP 1 — Farm Island: Harvest and Dispatch

Context files:
- docs/islands/farm/index.md
- docs/islands/farm/erp.md
- docs/islands/farm/nodered.md
- docs/islands/farm/lorawan.md

Tasks:
1. A LoRaWAN soil-moisture sensor triggers an irrigation cycle via the
   Shelly relay. Show the Node-RED flow that reads the MQTT payload from
   ChirpStack, checks the moisture threshold, and switches the relay.
   Document this in docs/islands/farm/nodered.md.

2. An operator creates a Harvest Batch in ERPNext:
   - Item: "Green Coffee Beans — Yirgacheffe"
   - Batch ID: FARM-2024-001
   - Quantity: 5 kg
   - Quality grade: A
   Document the ERPNext field mapping in docs/islands/farm/erp.md.

3. Node-RED submits the harvest event to the Fabric Peer Node.
   Show the minimal JSON payload:
   {
     "batch_id": "FARM-2024-001",
     "island": "farm",
     "event": "harvest_recorded",
     "timestamp": "<ISO-8601>",
     "quantity_kg": 5,
     "quality_grade": "A",
     "location": "Yirgacheffe, Ethiopia, 1850 m"
   }

4. The operator attaches a QR code (or NFC tag — decision still open)
   to the physical container and creates a Stock Transfer in ERPNext
   to mark the batch as "ready for dispatch to Factory".

Boundary output to Factory:
- Container physically carried to Factory Island
- QR/NFC label encodes: batch_id = "FARM-2024-001"
- Fabric ledger now has one confirmed event: harvest_recorded

---

### STEP 2 — Factory Island: Goods Receipt, Roasting, QC

Context files:
- docs/islands/factory/index.md

Tasks:
1. An operator scans the QR/NFC label at the Factory workstation.
   ERPNext records a Goods Receipt:
   - Source: Farm Island
   - Item: "Green Coffee Beans — Yirgacheffe"
   - Batch: FARM-2024-001
   - Quantity received: 5 kg
   Node-RED triggers the Fabric Peer Node to record:
   {
     "batch_id": "FARM-2024-001",
     "island": "factory",
     "event": "goods_receipt",
     "timestamp": "<ISO-8601>",
     "quantity_kg": 5
   }

2. ERPNext checks material availability and releases Production Order
   PO-FACTORY-001 (Finished Item: "Roasted Coffee — Medium", 4 kg).
   Describe the BoM (Bill of Materials) with one raw-material line:
   Green Coffee Beans → Roasted Coffee, yield 80%.

3. Walk through the Dobot workflow (Scenario A — Standard Production Run):
   a. Dobot #1 picks the container from IN zone → moves to SRT zone.
      Dobot #2 vision inspection: bean count OK, no foreign objects.
   b. Dobot #1 moves container to RST zone.
      MES starts 60-second roasting timer; Grove temperature sensor logs
      a mock ramp from 20°C to 212°C.
   c. MES signals roasting complete. Dobot #1 moves to QC zone.
      Dobot #2 Vision Studio reads colour token: brown = correctly roasted.
   d. Dobot #1 moves container to OUT zone.
      ERPNext books production completion for PO-FACTORY-001.

4. Node-RED submits two Fabric events:
   - event: "roasting_complete", batch_id: "FACTORY-ROAST-001",
     source_batch: "FARM-2024-001", roast_profile: "medium, 212°C, 60s"
   - event: "qc_pass", batch_id: "FACTORY-ROAST-001",
     result: "correctly_roasted"

5. ERPNext creates a Sales Order / Delivery Note for the Distributor
   and calls the Distributor's REST API:
   POST https://<distributor-ip>:8000/api/method/receive_factory_shipment
   Body: { "batch_id": "FACTORY-ROAST-001", "quantity_kg": 4,
           "item": "Roasted Coffee — Medium" }

Boundary output to Distributor:
- batch_id = "FACTORY-ROAST-001"
- Fabric ledger now has three confirmed events:
  goods_receipt, roasting_complete, qc_pass

---

### STEP 3 — Distributor Island: Warehousing and Last-Mile Delivery

Context files:
- docs/islands/distributor/index.md

Tasks:
1. The Distributor's ERPNext WMS receives the factory REST call.
   Create a Purchase Receipt:
   - Supplier: Factory Island
   - Item: "Roasted Coffee — Medium"
   - Batch: FACTORY-ROAST-001
   - Quantity: 4 kg
   Node-RED triggers Fabric:
   {
     "batch_id": "FACTORY-ROAST-001",
     "island": "distributor",
     "event": "goods_receipt",
     "timestamp": "<ISO-8601>",
     "quantity_kg": 4
   }

2. The Coffee House sends a purchase order via REST:
   POST https://<distributor-ip>:8000/api/method/receive_coffee_house_order
   Body: { "item": "Roasted Coffee — Medium", "quantity_kg": 1,
           "destination": "Coffee House — Hauptstraße 1" }
   ERPNext WMS creates a Delivery Order (DO-DIST-001) and reserves stock.

3. VROOM optimises the pick sequence (single delivery for this scenario:
   warehouse → Coffee House waypoint).
   Show the minimal VROOM input JSON:
   {
     "vehicles": [{"id": 1, "start": [48.208, 16.373],
                   "end": [48.208, 16.373]}],
     "jobs": [{"id": 1, "location": [48.209, 16.374],
               "description": "Coffee House — Hauptstraße 1"}]
   }

4. ERPNext fires a webhook to Node-RED when DO-DIST-001 is confirmed.
   Node-RED sends a WebSocket message to rosbridge_server:
   { "op": "publish", "topic": "/robot/mission",
     "msg": { "batch_id": "FACTORY-ROAST-001",
              "waypoint": "coffeehouse_main" } }
   robot_manager sends a NavigateToPose goal to Nav2.
   TurtleBot4 Lite navigates to the Coffee House waypoint and delivers.

5. On Nav2 goal success, robot_manager publishes /robot/status → Node-RED:
   - ERPNext REST: delivery confirmed, stock booking finalised
   - Fabric Peer Node:
     { "batch_id": "FACTORY-ROAST-001",
       "island": "distributor",
       "event": "delivery_completed",
       "destination": "Coffee House — Hauptstraße 1" }
   - REST call to Coffee House:
     POST https://<coffeehouse-ip>:5000/api/delivery_notice
     Body: { "batch_id": "FACTORY-ROAST-001",
             "rfid_tags": ["RFID-001"],
             "quantity_kg": 1 }

6. TurtleBot4 returns to docking station (DockServo action).

Boundary output to Coffee House:
- batch_id = "FACTORY-ROAST-001"
- RFID tag on physical bag: RFID-001
- Fabric ledger now has four confirmed events:
  goods_receipt (distributor), delivery_completed

---

### STEP 4 — Coffee House Island: Goods Receipt, Sale, Traceability

Context files:
- docs/islands/coffeehouse/index.md

Tasks:
1. The POS Module receives the delivery_notice REST call from the
   Distributor and shows it in the goods-receipt UI.
   The barista (or scanner) reads RFID-001 on the bag.
   POS confirms receipt and stores: batch_id = "FACTORY-ROAST-001".

2. A customer orders a coffee. The barista grinds and brews.
   The smart coffee machine sends sensor data via MQTT to the
   Lab Cloud IoT connector:
   {
     "batch_id": "FACTORY-ROAST-001",
     "grind_g": 18,
     "water_temp_c": 93,
     "water_ml": 200,
     "extraction_s": 28,
     "hardness_dh": 7
   }
   Lab Cloud stores this in InfluxDB (measurement: "brew_events").
   This data is NOT written to the Fabric ledger (off-chain by design).

3. The customer scans the QR code on their receipt.
   The Traceability Display queries the Lab Cloud Fabric Gateway REST API:
   GET https://<labcloud-ip>:8080/fabric/batch/FACTORY-ROAST-001/history
   The API returns all on-chain events for this batch.
   Show what the display renders:
   ✓ Farm:        Yirgacheffe, Ethiopia, 1850m — harvest_recorded
   ✓ Factory:     goods_receipt → roasting_complete → qc_pass
   ✓ Distributor: goods_receipt → delivery_completed
   ✓ This cup:    18g grind, 93°C, 28s extraction (from InfluxDB)

---

### STEP 5 — Cross-Island Verification

After completing all four island steps, verify the full ledger trail:

1. On any island, run the Fabric CLI query:
   peer chaincode query -C supply-chain -n batch-tracker \
     -c '{"Args":["GetBatchHistory","FACTORY-ROAST-001"]}'
   The result must contain these events in order:
   - harvest_recorded      (farm)
   - goods_receipt         (factory)
   - roasting_complete     (factory)
   - qc_pass               (factory)
   - goods_receipt         (distributor)
   - delivery_completed    (distributor)

2. On the Lab Cloud, query InfluxDB for the brew event:
   influx query '
     from(bucket:"supply-chain")
     |> range(start: -1h)
     |> filter(fn: (r) => r._measurement == "brew_events"
               and r.batch_id == "FACTORY-ROAST-001")'

3. Report any missing events or mismatches as an open issue in the
   GitHub project board. Do not write TODO items into the .md files.

---

### OUTPUT REQUIREMENTS

After walking through all five steps:

1. Update or create the relevant docs section for each island if anything
   was missing or unclear. Follow the canonical structure in AGENTS.md.

2. Update AGENTS.md with any new architectural decisions agreed during
   this session (one to two sentences each, with rationale).

3. Summarise open questions found during the walkthrough in a short list
   at the end of your response, clearly marked as "Open Questions".

4. Do not put detailed content in README.md. Link only.

5. Commit message prefix: doc: or fix: as appropriate.
```

---

## How to Use This Prompt

1. Copy the text inside the fenced block above.
2. Paste it as the first message in a new AI agent session (GitHub Copilot, ChatGPT, Claude, etc.).
3. Attach the following files as context if the agent supports file uploads:
   - `AGENTS.md`
   - `docs/islands/farm/index.md`
   - `docs/islands/factory/index.md`
   - `docs/islands/distributor/index.md`
   - `docs/islands/coffeehouse/index.md`
   - `docs/architecture/decisions.md`
4. Let the agent execute each step in order. Review its output against the actual repo files.
5. Accept changes that are consistent with the architecture decisions in `AGENTS.md`; reject anything that contradicts them.

---

## What the Prompt Covers

| Area | Covered |
|---|---|
| LoRaWAN sensor pipeline (Farm) | ✓ |
| ERPNext Harvest Batch + Goods Receipt (all islands) | ✓ |
| Node-RED integration at every hand-off | ✓ |
| Hyperledger Fabric on-chain events | ✓ |
| Dobot robot workflow (Factory MES Scenario A) | ✓ |
| VROOM route optimisation | ✓ |
| TurtleBot4 autonomous delivery | ✓ |
| Coffee House traceability display | ✓ |
| InfluxDB off-chain brewing parameters | ✓ |
| Cross-island Fabric ledger verification | ✓ |
| Open-question surfacing | ✓ |
