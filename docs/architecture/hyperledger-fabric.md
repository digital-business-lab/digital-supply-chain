# Hyperledger Fabric: End-to-End Traceability

Hyperledger Fabric is the backbone of the traceability system. It provides a shared, immutable ledger of supply chain events that any party can query — without requiring direct API calls between non-adjacent companies. The Coffee House does not need to know the Farm's API address, and the Farm does not need to know the Coffee House exists.

## Why Blockchain for This Use Case

The alternative — having the Coffee House call the Distributor, which calls the Factory, which calls the Farm, in sequence at query time — has two problems:

1. It creates runtime dependencies between all parties simultaneously
2. It provides no cryptographic guarantee that the data has not been modified

For traceability claims (origin, processing conditions, chain of custody), tamper-evidence matters both technically and commercially. Hyperledger Fabric addresses both problems: the ledger is append-only and replicated across multiple independent peer nodes, and each transaction is endorsed by multiple organisations before being committed.

## Network Topology

| Node | Location | Role |
|---|---|---|
| Fabric Peer Node | Farm island (Docker) | Endorses and commits harvest events |
| Fabric Peer Node | Factory island (Docker) | Endorses and commits roasting events |
| Fabric Peer Node | Distributor island (Docker) | Endorses and commits shipment events |
| Fabric Orderer (RAFT) | Lab Cloud | Coordinates consensus across all peer nodes |
| Fabric Gateway REST API | Lab Cloud | Read-only endpoint for the Coffee House Traceability Display |
| Fabric Client | Coffee House | Queries via Lab Cloud Gateway — no local peer node |

## Events Written to the Ledger

Each island writes one batch event per supply chain step:

| Island | Event type | Key fields |
|---|---|---|
| Farm | `harvest` | batch_id, origin, altitude_m, cooperative, picker_count, harvest_date, sensor_summary |
| Factory | `roast` | batch_id, roast_profile, peak_temp_c, duration_min, output_kg, roast_date |
| Distributor | `ship` | batch_id, destination, dispatch_date, estimated_delivery, transport_mode |
| Coffee House | `receive` | batch_id, received_date, bag_count, rfid_ids[] |

## What Is Not On-Chain

Coffee machine brewing parameters (grind level, temperature, water volume, water hardness, extraction time) are **not** written to the Fabric ledger. They are:

- Per-cup operational data, not supply chain events
- Too granular and high-frequency for a blockchain
- Potentially commercially sensitive (proprietary roasting/brewing recipes)

They are stored in **InfluxDB** on the Lab Cloud and served directly to the Traceability Display via REST. See [Lab Cloud](../lab-cloud/README.md).

## Integration with Node-RED

On Farm, Factory, and Distributor islands, Node-RED flows that write data to ERPNext are extended to additionally submit a transaction to the local Fabric peer node. This is a **parallel write**, not a replacement:

- ERPNext remains the system of record for each island's internal data
- Fabric holds only the inter-party batch events that need to be visible to other companies

## Traceability Flow (Customer Perspective)

```
Customer scans QR code / RFID at Coffee House
          ↓
Traceability Display sends batch_id to Lab Cloud Fabric Gateway
          ↓
Fabric Gateway queries ledger for all events with that batch_id
          ↓
Display shows:
  ✓ Farm: harvested 2026-01-15, Yirgacheffe, Ethiopia, 1850m altitude
  ✓ Factory: roasted 2026-01-28, medium profile, 212°C, 11 min
  ✓ Distributor: shipped 2026-02-03, Vienna depot → Café Central
  ✓ Coffee House: received 2026-02-05
  ✓ This cup: grind 18g, 93°C, 28s extraction (from Lab Cloud IoT)
```
