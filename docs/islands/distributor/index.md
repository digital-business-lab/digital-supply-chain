# Distributor Island — Coffee Trader

The Distributor Island coordinates warehousing, picking, and last-mile delivery — the only island with a physical mobile robot. Its TurtleBot4 Lite autonomously transports packages from the warehouse to the Coffee House, triggered by ERPNext delivery orders. VROOM optimises pick sequences; Hyperledger Fabric records shipment events.

→ [Architecture overview](../../architecture/index.md) | [Dependencies & integration contracts](../../architecture/dependencies.md) | [B2B communication](../../architecture/b2b-communication.md)

---

## Hardware

| Component | Model / Spec | Function |
|---|---|---|
| Linux workstation | — | WMS, logistics planning, ROS2 services |
| Touch display | — | Picking list and warehouse dashboard |
| USB barcode / RFID scanner | — | Goods receipt capture |
| TurtleBot4 Lite | iRobot Create3 + Raspberry Pi 4 | Autonomous last-mile delivery robot |
| TurtleBot4 docking station | iRobot Create3 dock | Charging and homing point for the robot |

---

## Services (Docker)

| Service | Function |
|---|---|
| ERPNext WMS | Warehouse FIFO bookings, stock management, delivery order lifecycle |
| VROOM | Delivery route and pick-sequence optimisation |
| Apache Kafka | Internal event processing (island-internal only) |
| Grafana | Warehouse and robot-status dashboard on the touch display |
| Fabric Peer Node | Writes shipment batch events to the shared ledger |
| rosbridge\_server | WebSocket-to-ROS2 bridge; exposes ROS2 topics/actions to Node-RED |
| robot\_manager | Custom ROS2 Python node; translates delivery orders into Nav2 goals |

> **Note on Docker networking:** ROS2 DDS multicast does not work reliably inside Docker bridge networks. Both `rosbridge_server` and `robot_manager` must run with `network_mode: host` so DDS traffic reaches the TurtleBot4 over the island LAN.

---

## External Dependencies

- **Upstream contract:** Factory shipment notice must provide the inbound batch reference and finished-goods metadata
- **Downstream contracts:** Coffee House purchase orders and delivery notices must remain aligned with the documented REST boundary
- **Shared service dependency:** Lab Cloud Fabric orderer and channel artefacts are required for ledger participation
- **Local-only dependencies:** ROS2, VROOM, and Node-RED can be developed and tested with synthetic orders before upstream and downstream systems exist

See [Dependencies and Integration Contracts](../../architecture/dependencies.md) for the canonical cross-component view.

---

## TurtleBot4 Lite — Robot Platform

**Assumption:** The TurtleBot4 Lite (ROS2 Humble on Ubuntu 22.04, RPi4) is sufficient for indoor flat-floor navigation within the lab. Maximum payload of the Create3 top plate is expected to exceed the weight of lab delivery packages (< 2 kg). Neither assumption has been validated under real lab conditions yet.

The robot operates on the same island WiFi as the workstation. ROS2 communication uses DDS over UDP multicast; a shared `ROS_DOMAIN_ID` ties the workstation and robot into a single ROS2 graph.

### Navigation Stack

| Layer | Technology | Notes |
|---|---|---|
| Mobile base | iRobot Create3 | Odometry, bump/cliff sensors, dock control |
| SLAM | `slam_toolbox` | Generates 2-D occupancy map of the lab — required before first delivery |
| Navigation | Nav2 (`nav2_bringup`) | Path planning, obstacle avoidance, goal execution |
| Docking | `irobot_create_msgs/action/DockServo` | Create3 built-in auto-dock action |

> **Open question:** A SLAM mapping session must be carried out before deployment. The map is considered stable for the lab environment; changes to furniture or obstacles may require remapping.

### Docking Station

The docking station is the robot's home position. The robot returns to it automatically after every completed or aborted delivery. The dock is placed within line-of-sight of the robot's cliff-sensor IR receivers, per the Create3 installation requirements.

---

## ERP Integration — Delivery Order to Robot Mission

**Design decision:** ERPNext is not ROS2-aware. The bridge is implemented via the existing Node-RED instance and `rosbridge_suite` — consistent with how Node-RED already integrates ERPNext with Fabric and Kafka on this island. A standalone Python service polling the ERPNext REST API was considered but rejected because it would duplicate the integration pattern already established in Node-RED.

```
ERPNext WMS
  Delivery Order created + stock reserved
    ↓ webhook (HTTP POST)
Node-RED
  validates payload, extracts batch_id + destination waypoint
    ↓ WebSocket message
rosbridge_server (ws://localhost:9090)
  translates message to ROS2 topic /robot/mission  (geometry_msgs/PoseStamped)
    ↓ ROS2 DDS (WiFi)
robot_manager node
  sends NavigateToPose action goal to Nav2
    ↓
TurtleBot4 Lite navigates to Coffee House waypoint
  [package picked up / RFID scanned]
    ↓ action result (success / failure)
robot_manager
  publishes /robot/status  →  rosbridge  →  Node-RED
    ├─→ ERPNext REST  (delivery confirmed, stock booking finalised)
    ├─→ Fabric Peer Node  (shipment event on ledger)
    └─→ REST API call to Coffee House  (delivery notice: batch_id + RFID tags)
robot_manager
  sends DockServo action → robot returns to docking station
```

### Delivery Confirmation

The primary confirmation signal is the Nav2 action result (goal reached). As an additional check, the Coffee House POS scans the RFID tag on the delivered package; a mismatch between the expected `batch_id` and the scanned tag would surface as an error in the Coffee House POS module.

> **Open question:** Whether physical RFID scan at the Coffee House is feasible during an automated delivery (no human present) depends on the placement of the scanner. This has not yet been finalised.

### Prompt Walkthrough Example — `FACTORY-ROAST-001` to Coffee House

For the end-to-end walkthrough prompt, the Distributor step is:

1. **Factory hand-off received**
   - ERPNext WMS creates a Purchase Receipt for `FACTORY-ROAST-001`, 4 kg of **Roasted Coffee — Medium**.
   - Node-RED submits:

   ```json
   {
     "batch_id": "FACTORY-ROAST-001",
     "island": "distributor",
     "event": "goods_receipt",
     "timestamp": "<ISO-8601>",
     "quantity_kg": 4
   }
   ```

2. **Coffee House order**
   - The Coffee House submits:

   ```http
   POST https://<distributor-ip>:8000/api/method/receive_coffee_house_order
   Content-Type: application/json

   { "item": "Roasted Coffee — Medium", "quantity_kg": 1, "destination": "Coffee House — Hauptstraße 1" }
   ```

   - `receive_coffee_house_order` is a custom ERPNext whitelisted method on the Distributor instance; it is not a standard ERPNext endpoint. In the current concept-only phase, its future contract is tracked in the API contract placeholder section below and will be documented there when the project transitions to production code.
   - ERPNext creates delivery order `DO-DIST-001` and reserves stock.

3. **Route planning + robot mission**
   - VROOM optimises the single-stop route with:

   ```json
   {
     "vehicles": [{"id": 1, "start": [48.208, 16.373], "end": [48.208, 16.373]}],
     "jobs": [{"id": 1, "location": [48.209, 16.374], "description": "Coffee House — Hauptstraße 1"}]
   }
   ```

   - On delivery-order confirmation, Node-RED sends:

   ```json
   {
     "op": "publish",
     "topic": "/robot/mission",
     "msg": { "batch_id": "FACTORY-ROAST-001", "waypoint": "coffeehouse_main" }
   }
   ```

4. **Delivery completion**
   - After Nav2 goal success, Node-RED finalises ERPNext booking, writes the Fabric event below, and notifies the Coffee House:

   ```json
   {
     "batch_id": "FACTORY-ROAST-001",
     "island": "distributor",
     "event": "delivery_completed",
     "destination": "Coffee House — Hauptstraße 1"
   }
   ```

   ```http
   POST https://<coffeehouse-ip>:5000/api/delivery_notice
   Content-Type: application/json

   { "batch_id": "FACTORY-ROAST-001", "rfid_tags": ["RFID-001"], "quantity_kg": 1 }
   ```

**Boundary output to Coffee House:**

- `batch_id = FACTORY-ROAST-001`
- RFID-tagged bag `RFID-001`
- confirmed Fabric events: `goods_receipt`, `delivery_completed`

**Assumption:** the waypoint `coffeehouse_main` already exists in the Nav2 map used by `robot_manager`. Waypoint creation is part of the TurtleBot4/Nav2 setup that must be completed before the first delivery run; it is not documented in detail in this repository yet.

### API Contract Placeholder (concept phase)

The walkthrough uses two custom ERPNext whitelisted methods that are **not implemented in this repository yet**:

- `receive_factory_shipment`
- `receive_coffee_house_order`

When the project moves from concept notes to production code, this page should document for both methods:

- authentication and authorisation expectations
- request validation and idempotency rules
- success and error response payloads
- how the methods map into ERPNext Purchase Receipt / Delivery Order creation

---

## Internal Data Flow

```
Customer order received (from Coffee House REST API)
    ↓
ERPNext WMS — stock reservation + pick list
    ↓
VROOM — pick sequence optimisation
    ↓
Picker assembles order → RFID tags scanned to delivery container
    ↓
ERPNext creates Delivery Order → webhook fired
    ↓
Node-RED → rosbridge → robot_manager → TurtleBot4 navigates to Coffee House
    ↓  (delivery confirmation: Nav2 goal result)
Node-RED
    ├─→ ERPNext        (delivery status update)
    ├─→ Fabric Peer Node (shipment event on ledger)
    └─→ REST API to Coffee House (delivery notice: batch_id + RFID tags)
    ↓
TurtleBot4 returns to docking station
```

---

## Open Questions and Risks

| Item | Status |
|---|---|
| Lab floor space sufficient for Nav2 navigation | Assumption — not yet validated |
| WiFi signal stable throughout robot travel path | Assumption — not yet measured |
| SLAM map creation before first deployment | Required; not yet done |
| RFID scan at Coffee House during autonomous delivery | Design open — depends on scanner placement |
| TurtleBot4 Lite payload sufficient (< 2 kg packages) | Expected — not yet weighed |
| Shelly relay model for Farm irrigation | Also open — mentioned here for completeness |

---

## Status

> **Planned** — configuration will be created analogously to the Farm island. The ROS2 integration (rosbridge, robot\_manager) is not yet implemented.
