# Distributor Island — Coffee Trader

The Distributor Island coordinates warehousing, picking, and last-mile delivery — the only island with a physical mobile robot. Its TurtleBot4 Lite autonomously transports packages from the warehouse to the Coffee House, triggered by ERPNext delivery orders. VROOM optimises pick sequences; Hyperledger Fabric records shipment events.

→ [Architecture overview](../../architecture.md) | [B2B communication](../../b2b-communication.md)

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
