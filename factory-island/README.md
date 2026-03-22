# Factory Island — Coffee Processing

The Factory Island is the didactic centrepiece: two Dobot robots demonstrate physical coffee processing steps (sorting green beans, roasting, quality control, packaging) that are directly reported back to the ERP system.

→ [Full architecture overview](../docs/architecture.md) | [B2B communication](../docs/b2b-communication.md)

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
