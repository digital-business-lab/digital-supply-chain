# Service Centre Island — Coffee Equipment Repair & Maintenance

> **Optional island** — deployed on demand for didactic scenarios focused on job-shop manufacturing (Werkstattfertigung) and MRP planning. No permanent physical rack; physical simulation method is to be defined.

Aftersales service for coffee equipment across the supply chain. Each repair or maintenance job is modelled as a production order in ERPNext with its own routing through shared work centres, providing an authentic job-shop context distinct from the automated flow manufacturing on the Factory Island.

📖 **[Full documentation → GitHub Pages](https://digital-business-lab.github.io/digital-supply-chain/islands/service-centre/)**

---

## Didactic Purpose

This island teaches job-shop manufacturing and the full MRP planning cycle in ERPNext:

- Each repair order is a production order with a variable routing (Diagnosis → Disassembly → Spare Parts Procurement → Repair → Test → Cleaning)
- Different defect types produce different routings through the same work centres, creating capacity conflicts students must resolve
- Students act as service technicians: booking time against work orders, reporting completions, and handling non-conformances directly in ERPNext
- Open question: how to simulate the physical repair activity (role-play with printed job cards, a digital mock-up, or lightweight props — to be decided)

---

## Hardware at a Glance

> Hardware not yet defined. The island is intentionally software-first; no permanent aluminium profile rack is planned.

| Component | Function |
|---|---|
| Laptop or lab PC | ERPNext and optional Fabric peer node |
| Printed job cards / props | Physical simulation of repair tasks (method tbc) |

## Services

ERPNext (Manufacturing module) · Fabric Peer Node (optional)

## Status

> **Concept** — island approved as optional extension for Werkstattfertigung / MRP scenarios. Physical simulation method open. ERPNext configuration (work centres, routings, BOMs for spare parts) not yet started.
