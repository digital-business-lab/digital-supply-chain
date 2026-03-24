# Service Centre Island

> **Optional island** — deployed on demand for didactic scenarios focused on job-shop manufacturing and MRP planning. No permanent physical rack is planned.

## Purpose

This island provides an authentic job-shop manufacturing (Werkstattfertigung) context as a didactic counterpart to the flow manufacturing (Fließfertigung) on the Factory Island. Repair and maintenance jobs for coffee equipment (espresso machines, grinders) are modelled as production orders in ERPNext, each with a variable routing through shared work centres.

Key learning objectives:

- Understand the structural difference between job-shop and flow manufacturing
- Execute the full MRP planning cycle in ERPNext: demand → BOM explosion → routing → capacity planning → order release → completion feedback
- Experience capacity conflicts when multiple repair orders compete for the same work centre
- Handle non-conformances (unexpected defects, missing spare parts) as production exceptions

## Process Model

Each repair job follows a variable routing. Example work centres and a selection of possible routings:

| Work Centre | Description |
|---|---|
| Diagnosis | Identify defect type and scope; create repair order in ERPNext |
| Disassembly | Partially or fully disassemble the equipment |
| Spare Parts | Check stock, create purchase requisition if needed |
| Repair | Execute the actual repair (mechanical, electrical, or cleaning) |
| Reassembly | Reassemble and perform functional test |
| Quality Check | Final inspection; record outcome in ERPNext |

Different defect types produce different routings through these work centres, creating the variable-sequence characteristic of job-shop manufacturing.

## Didactic Scenarios

### Standard Repair
A coffee grinder arrives with a blocked burr. Students process the order end-to-end: diagnosis → disassembly → spare parts check (burr in stock) → repair → reassembly → QC. Objective: practice the full production order lifecycle in ERPNext.

### Spare Parts Shortage
During a repair, a required spare part is not in stock. Students must create a purchase requisition, handle the waiting time in the schedule, and manage the order status in ERPNext. Objective: understand the interaction between MRP and procurement.

### Capacity Conflict
Two repair orders arrive simultaneously and compete for the same work centre (e.g. Repair). Students must prioritise and reschedule. Objective: understand finite capacity planning and its impact on delivery dates.

### Non-Conformance
During QC, a repaired machine fails the functional test. Students create a non-conformance report in ERPNext and route the job back to Repair. Objective: handle rework loops and their effect on work centre load.

## Open Design Questions

- **Physical simulation method** — how to represent the physical repair activity for students. Options under consideration:
    - Role-play with printed job cards (lowest effort, immediately deployable)
    - Digital mock-up on a tablet (students confirm steps by tapping through a repair workflow)
    - Lightweight physical props (a disassemblable coffee grinder or machine housing)
- **Fabric integration** — whether to record repair events on the shared Hyperledger Fabric ledger (e.g. for product-history traceability). Optional; depends on course scope.
- **Kafka** — internal event streaming is optional for this island; the island can run with ERPNext alone.

## Services

| Service | Role | Notes |
|---|---|---|
| ERPNext | Production orders, BOMs, routings, work centres, MRP | Core service; required |
| Fabric Peer Node | Record repair events on the traceability ledger | Optional |
| Kafka | Internal event streaming | Optional |

## Status

**Concept** — island approved as optional extension. ERPNext configuration (work centres, routings, spare-parts BOMs) not yet started. Physical simulation method open.
