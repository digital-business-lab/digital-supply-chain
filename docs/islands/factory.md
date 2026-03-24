# Factory Island — Coffee Processing

The Factory Island is the didactic centrepiece: two Dobot robots demonstrate physical coffee processing steps (sorting green beans, roasting, quality control, packaging) that are directly reported back to the ERP system.

→ [Architecture overview](../architecture.md) | [B2B communication](../b2b-communication.md)

---

## Physical Structure

The Factory Island is built on the same **aluminium profile rack** system as the Farm Island — multiple shelf levels, fully visible and accessible for didactic use.

```
┌─────────────────────────────────────┐
│  TOP LEVEL — Robot Workspace        │
│  ┌───────────────────────────────┐  │
│  │   Stainless-steel perforated  │  │  ← standardised grid (hole pattern)
│  │   plate (Lochblech)           │  │
│  │   ┌──────┐  ┌──────┐         │  │
│  │   │ 6×6  │  │ 6×6  │  ...    │  │  ← 3D-printed containers snap in
│  │   └──────┘  └──────┘         │  │     at defined grid positions
│  │                               │  │
│  │   Dobot #1 (sorting)          │  │  ← picks from input containers
│  │   Dobot #2 (QC + packaging)   │  │  ← fills output containers
│  └───────────────────────────────┘  │
│                                     │
│  MID LEVEL — Buffer / Staging       │
│  ┌───────────────────────────────┐  │
│  │   Perforated plate            │  │  ← staging containers for WIP
│  │   (work-in-progress buffer)   │  │     (sorted beans, rejects, etc.)
│  └───────────────────────────────┘  │
│                                     │
│  LOWER LEVEL — Compute & Network    │
│  ┌───────────────────────────────┐  │
│  │   ERP workstation             │  │
│  │   Network switch / router     │  │
│  └───────────────────────────────┘  │
│                                     │
│  FRONT — Touch display (mounted)    │
└─────────────────────────────────────┘
```

### Standardised Containers

All containers share a **~6 × 6 cm base footprint** and snap into the stainless-steel perforated grid so they cannot slip and always occupy a defined, reproducible position. Several container variants have been 3D-printed:

| Variant | Colour / marking | Content |
|---|---|---|
| Input container | — | Raw green beans (arriving from Farm) |
| Sorted container | — | Quality-sorted beans (after Dobot #1) |
| Reject container | — | Beans rejected by QC |
| Output container | — | Packaged / finished product (for Distributor) |

The perforated grid means Dobot pick-and-place operations can rely on **fixed, known XYZ coordinates** per grid slot — no vision system required for basic scenarios.

---

## Material Flow: Farm → Factory

**Decision:** manual transfer with ERP + Fabric tracking (see [decisions log](../decisions.md)).

```
Farm ERPNext: create outbound shipment
    ↓  (student carries container to Factory Island)
Factory ERPNext: scan QR/barcode on container → goods receipt
    ↓
Fabric Peer Node: records inter-island transfer event on ledger
    ↓
ERPNext: creates production order → triggers Dobot workflow
```

*Assumption: islands are positioned adjacent to each other in the same lab room, so manual carry is a realistic and deliberate simulation of a real-world goods handover (e.g. truck unloading). No automated conveyor is planned at this stage.*

*Open question: QR code vs. NFC tag on container — not yet decided. Either requires a reader at the Factory workstation.*

---

## Hardware

| Component | Model / Spec | Function |
|---|---|---|
| Linux workstation | — | Robot control and MES |
| Touch display | — | MES operator interface for production orders |
| Dobot Magician #1 | Dobot Magician | Pick & place — sorting green beans by quality |
| Dobot Magician #2 | Dobot Magician | Quality control + packaging |

---

## Services (Docker)

| Service | Function |
|---|---|
| ERPNext Manufacturing (MES) | Production orders, bills of materials, quality records |
| Dobot Python SDK | Direct robot control via USB/TCP |
| OPC-UA Server | Machine status exposure to ERPNext MES |
| Apache Kafka | Internal event processing (island-internal only) |
| Grafana | Production dashboard on the touch display |
| Fabric Peer Node | Writes roasting/processing batch events to the shared ledger |
| ROS2 (optional) | Advanced robot path programming for research contexts |

---

## Internal Data Flow

```
ERPNext production order
    ↓
Dobot Python SDK
    ↓
Dobot #1 (sorting green beans)
    ↓
Dobot #2 (QC + packaging)
    ↓
OPC-UA → ERPNext booking
    └─→ Fabric Peer Node (roasting batch event on ledger)
```

---

## Status

> **Planned** — configuration will be created analogously to the Farm island.

The `docker-compose.yml`, config files, and scripts for this island are not yet created. They will follow the same structure as `farm-island/`.
