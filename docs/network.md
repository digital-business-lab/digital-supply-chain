# Network Architecture

All Linux workstations, the MikroTik LoRaWAN gateway, and the Lab Cloud server are connected via LAN. Each island's REST APIs are reachable over the LAN; in a production-realistic configuration they can be exposed via a reverse proxy (e.g. Traefik) to simulate internet-facing B2B APIs.

The Coffee House connects to the **Lab Cloud** for IoT data (MQTT) and blockchain queries (Fabric Gateway REST). It connects to the **Distributor** for goods receipt and purchase orders (REST). It has no direct network connection to the Farm or Factory.

## Service Map

| Component | Runs on | Protocol | Access |
|---|---|---|---|
| ChirpStack | Farm workstation | MQTT (local) | Farm-internal only |
| ERPNext Farm | Farm workstation | REST API | Farm-internal + Factory via API key |
| ERPNext Factory | Factory workstation | REST API | Factory-internal + Farm / Distributor via API key |
| ERPNext Distributor | Distributor workstation | REST API | Distributor-internal + Factory / Coffee House via API key |
| POS System | Coffee House PC | REST API (client) | Calls Distributor API for orders / goods receipt |
| Kafka (per island) | Each workstation | Kafka protocol | Island-internal only |
| Fabric Peer Node (×3) | Farm / Factory / Distributor | gRPC (Fabric) | Connects to Lab Cloud orderer |
| Fabric Orderer | Lab Cloud server | gRPC (Fabric) | Accepts endorsements from all three peer nodes |
| Fabric Gateway API | Lab Cloud server | REST API | Read-only; consumed by Coffee House Traceability Display |
| Coffee IoT Backend | Lab Cloud server | MQTT / REST | Receives sensor data from coffee machine; serves REST to Traceability Display |
| Grafana (per island) | Each workstation | HTTP | Touch display on each island |
| Grafana (central) | Lab Cloud server | HTTP | Cross-island dashboard for instructors |

## Island Network Setup

Each island uses a **MikroTik router** as the local network hub:

- All devices (workstation, sensors, display) are DHCP clients on the MikroTik router
- The workstation receives a **fixed DHCP reservation** by MAC address (e.g. `192.168.10.10`)
- This fixed IP is required so the MikroTik wAP LR8 kit can point the LoRa packet forwarder at a stable address

## Inter-Island Connectivity

In the lab environment, all islands are on the same physical LAN. For a more realistic setup, each island can be placed behind its own MikroTik router with a dedicated subnet, and REST API endpoints can be exposed via Traefik as virtual hostnames (e.g. `api.farm.scm-lab.local`).
