# Factory Island — Coffee Processing

The Factory Island is the didactic centrepiece of the supply chain: two Dobot robots demonstrate physical processing steps — receiving, sorting, roasting (simulated), quality control, and packaging — while ERPNext MES connects every step to production orders, material tracking, and Hyperledger Fabric.

→ [Architecture overview](../../architecture/) | [B2B communication](../../architecture/b2b-communication.md) | [Decisions log](../../architecture/decisions.md)

---

## Physical Structure

Aluminium profile rack with three levels. **Only the top level carries a stainless-steel perforated plate (Lochblech)**; the mid and lower levels are solid multiplex shelves.

```
┌─────────────────────────────────────┐
│  TOP LEVEL — Robot Workspace        │
│  ┌───────────────────────────────┐  │
│  │  Stainless-steel Lochblech    │  │  ← standardised hole grid
│  │                               │  │
│  │  ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐   │  │  ← 3D-printed containers snap in
│  │  │  │ │  │ │  │ │  │ │  │   │  │     at fixed grid positions
│  │  └──┘ └──┘ └──┘ └──┘ └──┘   │  │
│  │  [IN] [SRT][RST][QC] [OUT]   │  │  ← named station zones
│  │                               │  │
│  │  Dobot #1 (linear axis)  ─── │──│  ← traverses all station zones
│  │  Dobot #2 (Vision Studio)    │  │  ← fixed at QC station
│  └───────────────────────────────┘  │
│                                     │
│  MID LEVEL — Storage (Multiplex)    │
│  ┌───────────────────────────────┐  │
│  │  Spare containers, tools,     │  │
│  │  Seeed Grove sensor modules   │  │
│  └───────────────────────────────┘  │
│                                     │
│  LOWER LEVEL — Compute (Multiplex)  │
│  ┌───────────────────────────────┐  │
│  │  Linux workstation            │  │
│  │  Network switch / router      │  │
│  └───────────────────────────────┘  │
│                                     │
│  FRONT — Touch display (mounted)    │
└─────────────────────────────────────┘
```

### Station Zones on the Lochblech

The Lochblech is divided into named zones. Each zone holds exactly one 6 × 6 cm container at a defined grid coordinate:

| Zone | Label | Description |
|---|---|---|
| IN | Goods receipt | Raw green beans arriving from Farm |
| SRT | Sort | Dobot #1 picks and places; defective beans removed |
| RST | Roast (simulated) | Container rests here during simulated roasting cycle |
| QC | Quality control | Dobot #2 (vision) inspects roast level and defects |
| OUT | Dispatch | Packaged, approved product ready for Distributor |
| REJ | Reject | Quarantine for non-conforming batches |

### Standardised Containers

All containers share a **~6 × 6 cm base footprint** and snap into the Lochblech grid — they cannot slip and always occupy reproducible positions. 3D-printed variants:

| Variant | Colour / marking | Content |
|---|---|---|
| Input container | green marking | Raw green beans (from Farm) |
| Sorted container | yellow marking | Pre-sorted beans, ready to roast |
| Roasted container | brown marking | Simulated roasted beans |
| Reject container | red marking | Defective / non-conforming beans |
| Output container | white/neutral | Packaged finished product |

---

## Dobot Hardware Capabilities

| # | Configuration | Capability | Assigned role |
|---|---|---|---|
| Dobot #1 | Mounted on **linear axis** | Traverses the full length of the Lochblech; can pick from any station zone and transport containers along the axis | Material transport: IN → SRT → RST → QC → OUT |
| Dobot #2 | Fixed position + **Vision Studio + camera** | Identifies objects by colour, shape, and position; no pre-programmed XYZ needed for detected objects | QC station: visual inspection, roast-level classification, defect detection |

*Assumption: the linear axis spans all station zones so Dobot #1 can reach every container without repositioning. If axis length is insufficient, a manual handoff between zones may be required for some steps — tbc once axis dimensions are confirmed.*

---

## Didactic Concept: Simulating Roasting and MES

### Core Learning Objectives

The Factory Island is designed so students can experience and experiment with the following MES functions in direct connection with physical robot actions:

1. **Production order lifecycle** — from demand signal to finished goods
2. **Bill of materials (BoM) and material requirements** — how much raw material is needed?
3. **Work order routing** — defining the sequence of operations and assigning work centres
4. **Real-time shop-floor feedback** — robot status and sensor readings visible in MES
5. **Quality management** — recording non-conformances, quarantining batches
6. **Traceability** — linking the finished product batch back to the specific Farm harvest
7. **Overall Equipment Effectiveness (OEE)** — tracking utilisation and downtime per robot

### Simulating the Roasting Process

Since actual coffee roasting is not feasible in the lab, roasting is represented through a **time-temperature profile simulation** in combination with physical container movement:

```
Student places "green bean" container in IN zone
    ↓
Dobot #1 picks container → moves to SRT zone
    ↓
Dobot #2 (vision) inspects: counts beans, detects foreign objects
    ↓
Dobot #1 moves approved container to RST (Roast) zone
    ↓
MES starts roasting timer (configurable, e.g. 60 s for demo)
Grove temperature sensor at RST zone logs a mock temperature ramp
Touch display shows live temperature curve (Grafana)
    ↓
MES signals roasting complete → Dobot #1 moves container to QC zone
    ↓
Dobot #2 (vision) inspects roast level:
    - "Correctly roasted" token/marking → container moves to OUT
    - "Over-roasted" or defect detected    → container moves to REJ
    ↓
MES books production completion, records quality result
Fabric Peer Node writes batch event to ledger
```

**Physical representation of roast level:** The containers or the tokens inside them carry a colour-coded marker (green = raw, brown = roasted, dark red = over-roasted). Dobot #2's Vision Studio detects the colour and classifies the roast level. Students can deliberately place "wrong" tokens to trigger the reject path and observe MES behaviour.

*Alternative considered: using actual heat-sensitive material to change colour during the roast phase — rejected as too fragile for repeated classroom use.*

### Seeed Grove Sensor Integration

*Full sensor inventory to be confirmed. The following integration points are planned once the list is available:*

| Sensor type | Station zone | MES / Grafana use |
|---|---|---|
| Temperature | RST (roast zone) | Displays simulated roasting temperature curve |
| Colour / light | QC zone | Redundant roast-level check (backup to Vision Studio) |
| Proximity / distance | IN zone | Detects container arrival → triggers goods-receipt dialogue |
| Weight | OUT zone | Verifies container fill level before dispatch booking |
| CO₂ (if available) | RST zone | Narrative enrichment: "roasting gas" detection |

---

## MES Didactic Scenarios

The following scenarios are designed as self-contained exercises. Each scenario starts from a clean MES state and has a defined trigger, expected MES behaviour, and learning outcome.

### Scenario A — Standard Production Run

**Trigger:** Distributor sends a B2B purchase order via REST API.

**Flow:** ERPNext receives order → checks raw material stock → releases production order → student scans incoming Farm container (QR/NFC) → MES books goods receipt → Dobot workflow executes → MES books production completion → Distributor notified via REST → Fabric records batch.

**Learning outcome:** Students follow the complete production order lifecycle and see how each physical action (scan, robot movement, sensor reading) generates a corresponding ERP event.

### Scenario B — Quality Reject and Non-Conformance

**Trigger:** Dobot #2 vision detects a defect marker (deliberately placed by instructor).

**Flow:** Vision Studio classifies bean as "defective" → MES creates non-conformance record → batch moved to REJ zone → supervisor role in ERPNext must approve quarantine or rework decision → Fabric records quality event.

**Learning outcome:** Quality management workflow; difference between a production booking and a quality booking; what a non-conformance record contains.

### Scenario C — Bottleneck and Scheduling

**Trigger:** Two production orders arrive simultaneously (instructor triggers second order mid-run).

**Flow:** MES must queue the second order because Dobot #1 (linear axis) is busy → students observe the order queue on the MES dashboard → first order completes → second order released automatically.

**Learning outcome:** Work-centre capacity, queue management, the concept of a bottleneck resource.

### Scenario D — Material Shortage

**Trigger:** Production order is released but the IN zone container is empty or absent.

**Flow:** MES material availability check fails → production order placed on hold → MES creates a purchase requisition to Farm Island → students must trigger Farm shipment → goods receipt unblocks the production order.

**Learning outcome:** MRP logic (material requirements planning); how a missing component propagates through the system.

### Scenario E — End-to-End Traceability (Recall Simulation)

**Trigger:** Instructor announces a quality complaint from the Coffee House for a specific batch.

**Flow:** Students use ERPNext traceability report → trace batch number back through QC records → back to Farm harvest batch on Fabric ledger → identify which raw material lot was used → simulate recall decision.

**Learning outcome:** Hyperledger Fabric as the immutable inter-island audit trail; why on-chain batch IDs matter for real-world supply chains.

---

## Material Flow: Farm → Factory

**Decision:** manual transfer with ERP + Fabric tracking (see [decisions log](../../decisions.md)).

```
Farm ERPNext: create outbound shipment → print/attach QR or NFC label
    ↓  (student carries container to Factory Island)
Factory ERPNext: scan QR/NFC on container → goods receipt
    ↓
Fabric Peer Node: records inter-island handover event on ledger
    ↓
ERPNext: checks material availability → releases production order
    ↓
Dobot workflow starts (see roasting simulation above)
```

*Open question: QR code vs. NFC tag on container — not yet decided. Either requires a reader at the Factory workstation.*

---

## Hardware

| Component | Model / Spec | Function |
|---|---|---|
| Linux workstation | — | MES, robot control, Node-RED, all Docker services |
| Touch display | — | MES operator interface (ERPNext) + Grafana production dashboard |
| Dobot #1 | Dobot Magician + linear axis | Material transport along all station zones |
| Dobot #2 | Dobot Magician + Vision Studio + camera | Visual QC: roast-level classification, defect detection |
| Seeed Grove sensors | tbc (list pending) | Temperature, proximity, colour — integrated via Node-RED |
| Network switch / router | — | Island LAN, DHCP, routing |

---

## Services (Docker)

| Service | Function |
|---|---|
| ERPNext Manufacturing (MES) | Production orders, BoM, routing, QC records, traceability |
| Node-RED | Dobot SDK orchestration, sensor ingestion, MES REST integration |
| Dobot Python SDK | Direct robot control via USB/TCP (called from Node-RED) |
| OPC-UA Server | Exposes robot and sensor status to ERPNext |
| Apache Kafka | Island-internal event processing |
| Grafana | Production dashboard: roasting curve, OEE, order queue |
| Fabric Peer Node | Writes processing batch events to the shared ledger |
| MariaDB | ERPNext database |

---

## Internal Data Flow

```
B2B REST API (Distributor order)
    ↓
ERPNext: production order + material check
    ↓
Node-RED: orchestrates Dobot workflow step by step
    ├─→ Dobot #1 (linear axis)  — transport between zones
    ├─→ Dobot #2 (Vision Studio) — QC inspection
    └─→ Grove sensors            — temperature, proximity, colour
         ↓
    OPC-UA → ERPNext: books each operation
         ↓
    ERPNext: production completion + quality record
         └─→ Fabric Peer Node (batch event on ledger)
              └─→ B2B REST API (delivery notification to Distributor)
```

---

## Status

> **Planned** — configuration will be created analogously to the Farm island.

The `docker-compose.yml`, config files, and scripts for this island are not yet created. Seeed Grove sensor inventory is pending; MES scenario scripts will be developed once hardware is confirmed.
