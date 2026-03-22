# Distributor Island — Coffee Trader

The Distributor Island coordinates warehousing, picking, and route planning — purely software-driven, making the contrast with the physical Factory Island didactically valuable. It is the direct supplier to the Coffee House.

→ [Architecture overview](../architecture.md) | [B2B communication](../b2b-communication.md)

---

## Hardware

| Component | Function |
|---|---|
| Linux workstation | WMS and logistics planning |
| Touch display | Picking list and stock overview |
| USB barcode / RFID scanner | Goods receipt capture |

---

## Services (Docker)

| Service | Function |
|---|---|
| ERPNext WMS | Warehouse FIFO bookings, stock management |
| VROOM | Delivery route optimisation (open source) |
| Apache Kafka | Internal event processing (island-internal only) |
| Grafana | Warehouse dashboard on the touch display |
| Fabric Peer Node | Writes shipment batch events to the shared ledger |

---

## Internal Data Flow

```
Customer order received (from Coffee House REST API)
    ↓
ERPNext WMS — stock reservation + picking list
    ↓
VROOM — delivery route calculation
    ↓
Goods dispatched
    ├─→ Fabric Peer Node (shipment event on ledger)
    └─→ REST API call to Coffee House (delivery notice: batch_id + RFID tags)
```

---

## Status

> **Planned** — configuration will be created analogously to the Farm island.
