# Distributor Island — Coffee Trader

Warehouse management, route planning, and autonomous last-mile delivery. ERPNext WMS handles stock; VROOM optimises pick sequences; a TurtleBot4 Lite robot carries packages to the Coffee House; a Fabric peer node records shipment events on the shared ledger.

📖 **[Full documentation → GitHub Pages](https://digital-business-lab.github.io/digital-supply-chain/islands/distributor/)**

---

## Hardware at a Glance

| Component | Function |
|---|---|
| Linux workstation | WMS, logistics planning, ROS2 services |
| RFID / barcode scanner | Goods receipt capture |
| Touch display | Picking list and warehouse dashboard |
| TurtleBot4 Lite + docking station | Autonomous last-mile delivery to Coffee House |

## Services

ERPNext WMS · VROOM · Kafka · Grafana · Fabric Peer Node · rosbridge\_server · robot\_manager

## Status

> **Planned** — will be set up analogously to `farm-island/`.
