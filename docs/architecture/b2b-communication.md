# B2B Communication Between Companies

Each lab island represents an independent company. Inter-company communication uses **REST APIs exclusively** — not shared middleware such as Kafka. This design is intentional: students learn explicitly which data one company shares with another, and which data remains internal. Kafka remains a company-internal tool on each island.

## Message Overview

| Sender | Receiver | Message | Trigger |
|---|---|---|---|
| Farm | Factory | Delivery notice (batch, quantity, quality) | Harvest completed |
| Factory | Farm | Purchase order (green beans, quantity) | Production order created |
| Factory | Distributor | Delivery notice (roasted coffee, batch) | Roasting completed |
| Distributor | Factory | Purchase order (roasted coffee, quantity) | Customer order received |
| Distributor | Coffee House | Delivery notice (coffee bags, batch ID, RFID tags) | Delivery dispatched |
| Coffee House | Distributor | Purchase order (coffee bags, quantity) | Stock running low |

## Authentication

- **Lab context:** API key per company, configured in ERPNext
- **Research / production context:** OAuth2 can be added for stronger access control

ERPNext provides a REST API out of the box. No additional API gateway is required for the lab setup.

## Design Rationale

The exclusive use of REST APIs between islands — rather than a shared message broker — reflects real B2B practice. It also has strong didactic value:

- Students must define explicit API contracts between companies
- Each company decides what data it exposes and what it keeps internal
- API failures are visible and debuggable (HTTP status codes, logs)
- The Hyperledger Fabric ledger handles the cross-company data sharing that doesn't require real-time API calls (batch history, traceability)

## Coffee House Special Case

The Coffee House POS module calls the Distributor's ERPNext REST API to:

1. **Confirm goods receipt** — when an RFID tag on an incoming coffee bag is scanned
2. **Place purchase orders** — when stock falls below a threshold

The Coffee House has no direct API connection to the Farm or Factory. It accesses their data only via the Hyperledger Fabric ledger (through the Lab Cloud Fabric Gateway).
