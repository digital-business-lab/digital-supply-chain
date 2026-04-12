# Didactic Scenarios

This lab is designed for three levels of engagement: foundational courses, advanced courses, and research. The coffee theme makes abstract supply chain concepts tangible for all levels.

## Foundational Courses

| Scenario | Learning Objective |
|---|---|
| Trace a coffee batch end-to-end | Follow a batch from harvest through roasting, distribution, to the customer's cup using the Traceability Display |
| Bullwhip effect | Observe how a small demand fluctuation at the Coffee House amplifies through Distributor → Factory → Farm |
| REST API analysis | Inspect which data one company shares with another via the ERPNext API logs |
| IoT pipeline | Follow a sensor measurement from LoRaWAN radio packet to ERPNext inventory booking |
| Customer traceability | Scan a QR code at the Coffee House and walk through the complete supply chain data |

## Advanced Courses

| Scenario | Learning Objective |
|---|---|
| Demand forecasting | Train ML algorithms on real sensor data (soil moisture, temperature) from the Farm island |
| Inventory optimisation | Implement EOQ models and dynamic ordering policies in ERPNext |
| Robot programming | Optimise Dobot pick-and-place paths with ROS2 on the Factory island |
| Blockchain configuration | Set up Hyperledger Fabric channels, define endorsement policies, query batch history via CLI |
| Coffee House IoT analysis | Query InfluxDB for brewing parameter trends, build custom Grafana dashboards |
| Modular Coffee House deployment | Deploy POS, Traceability Display, and IoT connector on separate hardware; understand REST interface contracts between them |

## Research Scenarios

| Scenario | Research Question |
|---|---|
| Disruption experiments | Simulate failure of one island (e.g. factory downtime) and measure supply chain resilience and recovery time |
| Routing optimisation | Compare VROOM's optimised delivery routes against greedy heuristics on real-world Vienna street data |
| Sensor data quality | Investigate the impact of LoRaWAN packet loss and sensor dropouts on ERP inventory accuracy |
| On-chain vs. off-chain | Analyse privacy, performance, and cost trade-offs between Fabric ledger data and InfluxDB time-series data |
| Lab Cloud vs. public cloud | Benchmark latency and throughput of on-premise Lab Cloud services against equivalent Azure IoT Hub / Azure Blockchain configurations |
| B2B API design | Evaluate different API authentication schemes (API key, OAuth2, mTLS) in a multi-company scenario |

## Teaching Setup

For practicals and seminars, each island can be provisioned from a **VM golden image** in minutes:

1. Start one VM copy per student group on the lab server (KVM/QEMU, min. 32 GB RAM for three simultaneous islands)
2. Each group gets a fully isolated environment — no interference between groups
3. Students can misconfigure or break their island freely; restore takes minutes
4. Instructor retains the production islands untouched

See [operations/](../operations/index.md) for VM template details.
