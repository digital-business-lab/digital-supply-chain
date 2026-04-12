# Architecture Decisions

This document records the key design decisions made for this project, including the rationale. These are intended to help future contributors understand *why* the system is built the way it is.

---

## Coffee as the example product

**Decision:** All four islands are framed around coffee — the farm grows it, the factory roasts it, the distributor trades it, the coffee house serves it.

**Rationale:** Coffee is a globally understood product with a genuinely complex, multi-continent supply chain. It makes abstract concepts (batch traceability, LoRaWAN sensor data, route optimisation) immediately tangible. The traceability story — from farm altitude and cooperative to brewing temperature — is compelling for students and visitors alike.

---

## Fourth island: Coffee House as lean consumer endpoint

**Decision:** The Coffee House has no ERP, no Kafka, no Fabric peer node, and no local middleware.

**Rationale:** A real coffee house has no IT department. The asymmetry between the three B2B islands and the Coffee House is didactically valuable: students see that the digital supply chain reaches the end consumer without requiring them to operate complex infrastructure. The Coffee House delegates IoT processing to the Lab Cloud (analogous to a managed cloud service subscription).

---

## Lab Cloud instead of public cloud

**Decision:** The Hyperledger Fabric orderer and Coffee House IoT backend run on an on-premise lab server, not on Azure or AWS.

**Rationale:** An on-premise Lab Cloud gives students full visibility into all layers (no black box), keeps the setup offline-capable, avoids cloud costs, and preserves data sovereignty. Architecturally it models the same pattern as a managed cloud service — the Coffee House consumes services without knowing how they work — while keeping everything inspectable for teaching purposes.

---

## Hyperledger Fabric as integral component (not optional)

**Decision:** Fabric is core infrastructure. Each B2B island runs a peer node; the Lab Cloud runs the orderer; the Coffee House reads via the Fabric Gateway REST API.

**Rationale:** The alternative — cascading REST calls (Coffee House → Distributor → Factory → Farm) at query time — creates runtime dependencies between all parties and provides no tamper-evidence. Fabric solves both: any party can query the ledger independently, and the append-only structure makes tampering detectable. The scenario also demonstrates concretely *why* blockchain is useful in supply chains, not just as a buzzword.

---

## Brewing parameters off-chain

**Decision:** Coffee machine sensor data (grind, temperature, water volume, hardness, extraction time) is stored in InfluxDB on the Lab Cloud, not on the Hyperledger Fabric ledger.

**Rationale:** Brewing parameters are per-cup operational data, not inter-company supply chain events. Writing them to the chain would be too granular, high-frequency, and would mix operational telemetry with the batch provenance record. They may also be commercially sensitive (proprietary recipes). InfluxDB is the appropriate store for time-series sensor data.

---

## Three independent modules in the Coffee House

**Decision:** POS, Traceability Display, and IoT connector are loosely coupled modules with defined REST interfaces. They can run on one machine or on several.

**Rationale:** Flexibility for different hardware configurations in the lab. Also didactically valuable: instructors can demonstrate the same logical architecture on one laptop or on three separate Raspberry Pis, showing that software architecture and deployment topology are independent concerns.

---

## ChirpStack instead of TTN (The Things Network)

**Decision:** LoRaWAN network server runs locally as ChirpStack, not via The Things Network cloud service.

**Rationale:** Offline capability in lab operation; full pipeline visibility for students (every layer is locally inspectable); data sovereignty for research; no dependency on an external service. The didactic value of seeing ChirpStack receive, authenticate, and decode LoRa packets locally outweighs the convenience of a cloud-hosted network server.

---

## No VM operation on the workstation

**Decision:** Each island runs natively on Ubuntu + Docker, without a hypervisor on the island workstation.

**Rationale:** 16 GB RAM is insufficient for a hypervisor + ERPNext running simultaneously. The touchscreen kiosk (Grafana in kiosk mode) works more reliably natively. VMs are used on a *separate dedicated lab server* for teaching — not on the island workstations themselves.

---

## Backup strategy: script-based instead of VM snapshots

**Decision:** SQL dumps + Docker volume archives via systemd timer, 7-day retention.

**Rationale:** Block-level VM snapshots of a running database are unreliable (risk of inconsistent state). `pg_dump` and `mysqldump` produce consistent, portable, human-readable backups. The script-based approach is also transparent and auditable — students can read and understand the backup process.

---

## GitOps for deployment

**Decision:** All configuration lives in Git; each island runs a systemd timer that polls for changes every 15 minutes and applies them via `docker compose up -d`.

**Rationale:** Rollback via `git revert`; audit trail of all configuration changes; consistent rollout across all islands; didactic value (students see the full change history and understand that infrastructure is code).
