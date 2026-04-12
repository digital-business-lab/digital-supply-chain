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

Each island uses a **MikroTik router** as the local network hub and a MikroTik access point / uplink device.

- All devices (workstation, sensors, display) are DHCP clients on the MikroTik router
- The router uses `.1` as its address in each island subnet
- The access point / uplink device uses `.2` in each island subnet
- The workstation receives a **fixed DHCP reservation** by MAC address
- This fixed IP is required so the MikroTik wAP LR8 kit can point the LoRa packet forwarder at a stable address
- Critical services should use static leases or static IP addresses within the island subnet

### Detailed Network Configuration

The lab uses one dedicated `/24` subnet per island and one for the Lab Cloud. The subnets start with Farm at `192.168.91.0/24` and increment by one for each island.

| Domain | Subnet | Router / Gateway | Key fixed addresses | Notes |
|---|---|---|---|---|
| Farm Island | `192.168.91.0/24` | `192.168.91.1` | Router `192.168.91.1`; AP / uplink `192.168.91.2`; workstation `192.168.91.10`; LoRaWAN gateway `192.168.91.20`; ChirpStack host `192.168.91.30` | Farm devices use this subnet and route to Lab Cloud for Fabric orderer and central services |
| Factory Island | `192.168.92.0/24` | `192.168.92.1` | Router `192.168.92.1`; AP / uplink `192.168.92.2`; workstation `192.168.92.10`; Dobot base controller `192.168.92.20`; Vision camera `192.168.92.21` | Dedicated subnet isolates production equipment |
| Distributor Island | `192.168.93.0/24` | `192.168.93.1` | Router `192.168.93.1`; AP / uplink `192.168.93.2`; workstation `192.168.93.10`; TurtleBot4 base station `192.168.93.20`; ROS2 bridge endpoint `192.168.93.21` | TurtleBot4 and ROS2 components remain on island network |
| Coffee House | `192.168.94.0/24` | `192.168.94.1` | Router `192.168.94.1`; AP / uplink `192.168.94.2`; PC `192.168.94.10`; Traceability display `192.168.94.11`; coffee machine `192.168.94.20` | Coffee House uses Lab Cloud and Distributor services only |
| Lab Cloud | `192.168.95.0/24` | `192.168.95.1` | Router `192.168.95.1`; AP / uplink `192.168.95.2`; server `192.168.95.10`; Grafana `192.168.95.11`; MQTT / Fabric Gateway `192.168.95.12` | Lab Cloud services are the central backbone for all islands |

## Inter-Island Connectivity

In the lab environment, all islands are on the same physical LAN. For a more realistic setup, each island is placed behind its own MikroTik router with a dedicated subnet, and REST API endpoints can be exposed via Traefik as virtual hostnames (e.g. `api.farm.lab.local`).
