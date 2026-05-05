# Dependencies and Integration Contracts

This page is the **canonical reference** for cross-island and shared-service dependencies. Its purpose is to let each island be designed and implemented independently first, while still preserving the contracts required for later end-to-end integration.

## Dependency Rules

The supply chain uses a small set of explicit integration patterns:

- **Adjacent companies communicate via REST only**:
  - Farm ↔ Factory
  - Factory ↔ Distributor
  - Distributor ↔ Coffee House
- **Non-adjacent traceability uses Hyperledger Fabric**, queried through the **Lab Cloud Fabric Gateway REST API**
- **Coffee House brewing telemetry goes only to the Lab Cloud IoT backend** and remains off-chain
- **Kafka is island-internal only** and is never a dependency between islands
- **Node-RED is an integration tool, not a cross-company contract**; its flows may change as long as the documented inputs and outputs stay stable

## Cross-Cutting Contracts That Must Stay Stable

The following interfaces must be treated as shared contracts even while components are implemented independently.

| Contract | Producer | Consumer | Minimum stable fields / behaviour |
|---|---|---|---|
| `batch_id` identity | Farm creates; later islands propagate | All islands + Lab Cloud + Coffee House | A supply-chain batch keeps a traceable parent/child relationship across all stages; downstream systems must retain the upstream reference |
| Physical tag payload | Farm / Factory / Distributor attach QR, NFC, or RFID identifiers | Next island in the chain | The physical carrier must resolve to the same `batch_id` used in REST and Fabric records |
| Farm delivery notice | Farm | Factory | `batch_id`, source item, quantity, quality status, shipment timestamp |
| Factory shipment notice | Factory | Distributor | `batch_id`, source `farm_batch_id`, finished item, quantity, QC result, shipment timestamp |
| Coffee House purchase order | Coffee House | Distributor | item, quantity, destination / waypoint reference, requester identity |
| Distributor delivery notice | Distributor | Coffee House | `batch_id`, `rfid_tags[]` or equivalent identifiers, quantity, delivery timestamp |
| Fabric `BatchEvent` write | Farm / Factory / Distributor | Shared ledger, later Coffee House | Every inter-island traceability step must write a timestamped event with island identity and event-specific payload |
| Fabric batch history read | Lab Cloud Fabric Gateway | Coffee House Traceability Display | Query by `batch_id`; return the ordered event history for that batch |
| Brew telemetry event | Coffee House IoT Connector | Lab Cloud IoT backend | `batch_id`, grind, water temperature, water volume, extraction time, water hardness, timestamp |
| Latest brew lookup | Lab Cloud IoT backend | Coffee House Traceability Display | Query by `batch_id`; return the latest brew event used for the current cup display |

## Hard Shared Prerequisites

These prerequisites span multiple components and therefore must be aligned early:

| Shared prerequisite | Needed by | Why it matters |
|---|---|---|
| Fixed network addressing / DNS / routing | All islands + Lab Cloud | REST, MQTT, and Fabric endpoints must remain reachable at stable addresses |
| Time synchronisation (NTP) | All islands + Lab Cloud | Event ordering and auditability depend on coherent timestamps |
| API authentication model | Adjacent REST participants | All custom REST calls assume API-key-based authentication in the lab setup |
| Fabric crypto material and channel artefacts | Lab Cloud + Farm + Factory + Distributor | Peer join and ledger writes require consistent MSPs, TLS material, and channel configuration |
| Shared naming of destination waypoints | Distributor + Coffee House | Delivery orders must reference a waypoint known to the TurtleBot4/Nav2 setup |

## Component Dependency Matrix

| Component | Can be implemented locally first? | Hard external dependencies for full integration | Outputs that other components rely on |
|---|---|---|---|
| **Lab Cloud** | Yes | None to start; Farm/Factory/Distributor required later for meaningful Fabric data; Coffee House required later for live IoT data | Fabric orderer, Fabric Gateway REST, IoT backend REST/MQTT, central monitoring |
| **Farm Island** | Yes | Lab Cloud orderer + channel artefacts for Fabric participation; Factory contract for real B2B hand-off | Harvest batch records, Farm delivery notice, Fabric harvest / handover events, physical tag carrying `batch_id` |
| **Factory Island** | Yes | Farm hand-off contract for raw material receipt; Distributor REST contract for finished-goods hand-off; Lab Cloud orderer + channel artefacts for Fabric | Goods receipt against Farm batch, production / QC records, Factory shipment notice, Fabric processing events |
| **Distributor Island** | Yes | Factory shipment contract for inbound goods; Coffee House order + delivery-notice contract; Lab Cloud orderer + channel artefacts for Fabric | Warehouse receipt, delivery order execution, Coffee House delivery notice, Fabric shipment events |
| **Coffee House Island** | Yes | Distributor REST contract, Lab Cloud Fabric Gateway, Lab Cloud IoT backend | Purchase orders to Distributor, goods-receipt scan state, brew telemetry, customer-facing traceability queries |
| **Service Centre (optional)** | Yes | None for the main coffee chain; optional Fabric integration if repair history should appear in traceability views | Optional ERP/MRP learning flows, optional Fabric repair events |

## Per-Component Dependency Boundaries

### Lab Cloud

- Must be available before any B2B island can join the Fabric channel
- Exposes only three cross-component interfaces:
  - Fabric orderer (`7050`) for peer nodes
  - Fabric Gateway REST for Coffee House traceability
  - MQTT + brew REST for Coffee House telemetry
- Does **not** need Farm, Factory, Distributor, or Coffee House to be fully implemented before its own stack can be developed

### Farm Island

- Can develop LoRaWAN, ChirpStack, ERPNext, irrigation automation, and local dashboards without any other island
- Needs the **Lab Cloud** only when enabling Fabric join and end-to-end traceability
- Needs the **Factory contract** only for the later outbound hand-off:
  - what metadata accompanies the physical batch
  - how the next island resolves the tag to `batch_id`

### Factory Island

- Can develop MES, robot flows, simulated roasting, and QC locally with demo batches
- Needs the **Farm contract** for real inbound goods receipt against an upstream batch
- Needs the **Distributor contract** for outbound shipment notification and downstream warehouse receipt
- Needs the **Lab Cloud** for Fabric participation

### Distributor Island

- Can develop WMS, VROOM, ROS2, and robot orchestration locally with synthetic delivery orders
- Needs the **Factory contract** for inbound shipment data
- Needs the **Coffee House contract** for outbound delivery notice and purchase-order intake
- Needs the **Lab Cloud** for Fabric participation

### Coffee House Island

- Can develop POS, Traceability Display, and IoT Connector independently with mocked REST/MQTT endpoints
- Depends on the **Distributor** for stock replenishment workflows and inbound delivery notices
- Depends on the **Lab Cloud** for:
  - Fabric batch history queries
  - brew telemetry ingestion
  - latest brew lookup for the Traceability Display
- Has **no direct dependency** on Farm or Factory APIs

### Service Centre

- Is intentionally outside the mandatory coffee-chain runtime path
- Must not introduce a required dependency for Farm, Factory, Distributor, Coffee House, or Lab Cloud
- If Fabric integration is added later, it should be treated as an optional extension contract

## Contracts That Are Intentionally Not Yet Frozen

Some decisions remain open, but they must not block independent implementation because the boundary is already fixed at a higher level:

| Open decision | Fixed boundary despite the open point |
|---|---|
| QR code vs. NFC for Farm → Factory hand-off | The receiving system still needs to resolve the tag to the same `batch_id` |
| RFID scanner placement for autonomous delivery at the Coffee House | The delivery notice still needs to carry `batch_id` plus bag identifiers |
| Final custom ERPNext endpoint implementation details | The participating components already know which business events must cross the boundary |
| Exact coffee machine model and transport (MQTT vs. serial adapter) | The IoT Connector still has to forward the documented brew telemetry fields to the Lab Cloud |

## Integration Readiness Checklist

Before separate component implementations are connected into one supply chain, verify that:

- [ ] each component exposes only the documented cross-boundary interfaces
- [ ] every REST call has an identified caller, callee, authentication method, and minimum payload
- [ ] every physical bag/container can be resolved to the corresponding `batch_id`
- [ ] Fabric event names and payload ownership are aligned across Farm, Factory, and Distributor
- [ ] Coffee House traceability reads only from the Lab Cloud, never directly from Farm or Factory
- [ ] open hardware choices do not alter the documented interface contracts

## Related Documentation

- [Architecture overview](index.md)
- [B2B communication](b2b-communication.md)
- [Hyperledger Fabric](hyperledger-fabric.md)
- [Network architecture](network.md)
- [Supply Chain Setup Guide](../operations/setup-guide.md)
