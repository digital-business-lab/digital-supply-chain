# Supply Chain Setup Guide

This guide walks through standing up the complete Digital Open-Source Supply Chain from scratch, island by island. Each section gives the **sequence of steps** and links to the authoritative detail documentation — it does not duplicate it.

> **Why this order matters:** The Lab Cloud must be running first because it hosts the Hyperledger Fabric orderer. No island peer can join the channel until the orderer is reachable. After that, islands can be brought up in supply-chain order (Farm → Factory → Distributor → Coffee House), which also maps to the teaching narrative.

---

## Setup Sequence

- [ ] Configure lab network and DHCP reservations
- [ ] Complete workstation baseline setup on the Lab Cloud server and all island machines
- [ ] Deploy the Lab Cloud and verify the Fabric orderer is reachable
- [ ] Start islands in supply-chain order: Farm → Factory → Distributor → Coffee House

## Prerequisites

Before starting any island deployment, complete the shared prerequisites and make the Lab Cloud available first.

The shared prerequisites include network configuration and DHCP reservations first, then workstation baseline setup on each island machine and the Lab Cloud server, plus repository checkout. The Lab Cloud must be deployed before any island peer can join the Fabric channel.

### Network

All islands must be reachable from the Lab Cloud and from each other over the lab LAN. See [Network](../architecture/network.md) for VLAN layout, DHCP reservations, and firewall rules.

### Software — All Workstations

Follow [Workstation Setup](setup-workstation.md) on every island machine and on the Lab Cloud server after lab network configuration and before deploying any island stack. This covers Ubuntu 22.04, Docker Engine, Docker Compose, and cloning the repository to `/opt/digital-supply-chain`.

### Hardware

Confirm the following hardware is available and physically set up:

| Island | Minimum compute | Additional hardware |
|---|---|---|
| Lab Cloud | Lab server (on-premise) | — |
| Farm | Linux workstation (Dell, i7, 16 GB RAM) | MikroTik router, MikroTik wAP LR8 gateway, LoRaWAN sensors, Shelly relay, pump, LED grow light, touch display |
| Factory | Linux workstation | Dobot #1 + linear axis, Dobot #2 + Vision Studio camera, aluminium rack, Lochblech, containers, touch display |
| Distributor | Linux workstation | TurtleBot4 Lite + docking station, USB barcode/RFID scanner, touch display |
| Coffee House | Linux PC | Customer-facing display, RFID/barcode scanner, smart coffee machine |

### Repository

```bash
git clone https://github.com/digital-business-lab/digital-supply-chain.git /opt/digital-supply-chain
```

---

## Step 1 — Lab Cloud

**Must be completed before any island peer can join the Fabric channel.**

The Lab Cloud runs the Hyperledger Fabric ordering service, the Coffee House IoT backend, and the central cross-island Grafana instance.

The `lab-cloud/` folder and its `docker-compose.yml` are still under development. Implementation progress is tracked in the repository's GitHub project board, while the full setup procedure is documented in `.md` files. See the [Lab Cloud Setup Guide](../lab-cloud/setup.md). Summary:

    1. Provision the server with Ubuntu 22.04 + Docker (see [Workstation Setup](setup-workstation.md)).
    2. Clone the repository to `/opt/digital-supply-chain`.
    3. Generate Fabric crypto material with `cryptogen` (see [Lab Cloud Setup — Step 2](../lab-cloud/setup.md#step-2-generate-fabric-crypto-material)).
    4. Create the channel genesis block and orderer self-join (see [Lab Cloud Setup — Step 3](../lab-cloud/setup.md#step-3-create-the-fabric-channel)).
    5. Start the Lab Cloud stack:
       ```bash
       cd /opt/digital-supply-chain
       cp lab-cloud/.env.example lab-cloud/.env
       # fill in secrets
       ./lab-cloud/scripts/bootstrap.sh
       ```
    6. Verify the orderer is reachable on port `7050` from all island workstations.
    7. Distribute the channel genesis block (`lab-channel.block`) and each org's MSP material to the respective island administrators.

    → [Lab Cloud Setup Guide](../lab-cloud/setup.md) | [Lab Cloud overview](../lab-cloud/index.md) | [Hyperledger Fabric](../architecture/hyperledger-fabric.md)

### Checkpoint

- [ ] Fabric orderer running and reachable from lab network
- [ ] Channel genesis block generated and orderer joined
- [ ] Coffee House IoT backend running (Mosquitto, Node-RED, InfluxDB)
- [ ] Central Grafana accessible

---

## Step 2 — Farm Island

The Farm Island is the **origin of the supply chain**: it produces coffee, logs harvest batches in ERPNext, and writes batch events to the Fabric ledger.

### 2.1 Deploy the Stack

Follow the [Farm Island Setup Guide](../islands/farm/setup.md):

1. Complete workstation setup.
2. Configure secrets: `cp farm-island/.env.example farm-island/.env` and fill in passwords.
3. Run `./farm-island/scripts/bootstrap.sh` — starts ChirpStack, Mosquitto, Node-RED, Grafana, ERPNext, and the Fabric peer.

### 2.2 LoRaWAN — Gateway and Sensors

1. Configure the MikroTik wAP LR8 packet forwarder to point to `192.168.10.10:1700` (or the workstation's DHCP reservation) — see [LoRaWAN](../islands/farm/lorawan.md).
2. Register the gateway in ChirpStack.
3. Register each sensor device (Dragino LHT65, LDDS75, or Seeed SenseCAP S2103) in ChirpStack with the correct AppEUI / DevEUI / AppKey.
4. Verify decoded uplink payloads appear in ChirpStack's live frame log.

### 2.3 ERPNext Configuration

Follow [Farm Island — ERP Config & Demo Data](../islands/farm/erp.md):

1. Create warehouses, item definitions (green coffee bean batches), and stock locations.
2. Add demo harvest batches for initial testing.
3. Configure quality inspection templates.

### 2.4 Node-RED Flows

Follow [Farm Island — Node-RED Flows](../islands/farm/nodered.md):

1. Import the Node-RED flow package from `farm-island/config/nodered/`.
2. Verify the MQTT → ERPNext → Kafka → Fabric peer pipeline.
3. Test the irrigation automation: trigger a low-moisture event and confirm the Shelly relay switches the pump.

### 2.5 Join Fabric Channel

Once the Lab Cloud is running, each island peer must be joined to the shared channel. Implementation details and the exact peer join procedure are tracked in the repository's GitHub project board, while the final procedure will be documented in `.md` files. Expected steps:

    1. Obtain the channel genesis block from the Lab Cloud administrator.
    2. Run the peer join command (see [Hyperledger Fabric](../architecture/hyperledger-fabric.md) for the exact command once the channel config is finalised).
    3. Install and commit the supply chain chaincode on the peer.

### Checkpoint

- [ ] All Docker services healthy (`docker compose ps`)
- [ ] At least one sensor uplink visible in ChirpStack
- [ ] Grafana sensor dashboard live on the touch display
- [ ] Irrigation automation triggered by a test low-moisture event
- [ ] First harvest batch created in ERPNext
- [ ] Batch event written to Fabric ledger (verify via Hyperledger Explorer on Lab Cloud)

---

## Step 3 — Factory Island

The Factory Island receives raw coffee from the Farm, runs it through a simulated roasting and quality control process using two Dobot robots, and ships approved product to the Distributor.

The `factory-island/` folder and its deployment artifacts are under active development. Implementation progress is tracked in the repository's GitHub project board, while the operational details are documented in `.md` files. The steps below describe the intended setup sequence; details will be added to [Factory Island](../islands/factory/index.md) as work progresses.

### 3.1 Deploy the Stack

Expected services: ERPNext MES, Apache Kafka, Fabric peer node, OPC-UA server, Node-RED, Grafana.

```bash
# Intended deployment command once the Factory Island docker-compose file exists
cd /opt/digital-supply-chain
cp factory-island/.env.example factory-island/.env
./factory-island/scripts/bootstrap.sh
```

### 3.2 Physical Setup — Robots and Rack

1. Mount the aluminium rack and install the **stainless-steel Lochblech** on the top level.
2. Attach **Dobot #1** to the linear axis so it spans all station zones (IN → SRT → RST → QC → OUT).
3. Mount **Dobot #2** with Vision Studio camera at the QC zone.
4. Verify axis length covers all zones — if not, a mid-zone handoff point must be defined (open question, tbc).
5. Snap 3D-printed containers (green, yellow, brown, red, white variants) into grid positions on the Lochblech.

### 3.3 Dobot Programming

Dobot programming details will be documented in `.md` files as part of the Factory Island implementation, while execution progress is tracked in the repository's GitHub project board. Expected: station-zone XYZ coordinates for Dobot #1, pick-place routines for each process step, Vision Studio training set for roast-level and defect classification on Dobot #2.

### 3.4 ERPNext MES Configuration

MES configuration guidance will be documented in `.md` files as part of the Factory Island implementation, while execution progress is tracked in the repository's GitHub project board. Expected: Bill of Materials for each product variant, routings (IN → SRT → RST → QC → OUT), work centre definitions, OEE tracking, non-conformance handling, five didactic scenarios (see [Didactic Scenarios](../teaching/didactic-scenarios.md)).

### 3.5 Join Fabric Channel

Same procedure as Step 2.5 — obtain channel genesis block from Lab Cloud, join factory peer, install chaincode.

### 3.6 B2B Goods Receipt from Farm

When the Farm physically delivers beans, the Factory operator scans a QR code or NFC tag to trigger a goods receipt in Factory ERPNext (linked to the Farm batch ID on the Fabric ledger). The reader type (QR scanner vs. NFC) is an open decision and is being tracked in the repository's GitHub project board.

### Checkpoint

- [ ] All Docker services healthy
- [ ] Dobot #1 completes a test pick-place cycle across all station zones
- [ ] Dobot #2 classifies a test container by colour in Vision Studio
- [ ] Simulated production order runs end-to-end in ERPNext MES
- [ ] Shipment event written to Fabric ledger
- [ ] Factory peer synced with Farm peer (verify shared batch history)

---

## Step 4 — Distributor Island

The Distributor receives roasted coffee from the Factory, manages warehouse stock, and dispatches last-mile delivery via TurtleBot4 Lite to the Coffee House.

The `distributor-island/` folder and its deployment artifacts are under active development. Implementation progress is tracked in the repository's GitHub project board, while deployment guidance will remain in `.md` files.

### 4.1 Deploy the Stack

Expected services: ERPNext WMS, Apache Kafka, Fabric peer node, VROOM, rosbridge_server, robot_manager (ROS2 node), Grafana.

```bash
# Intended deployment command once the Distributor Island docker-compose file exists
cd /opt/digital-supply-chain
cp distributor-island/.env.example distributor-island/.env
./distributor-island/scripts/bootstrap.sh
```

!!! note "Docker networking for ROS2"
    Both `rosbridge_server` and `robot_manager` must run with `network_mode: host` to allow ROS2 DDS multicast traffic to reach the TurtleBot4 over the island LAN. See [Distributor Island](../islands/distributor/index.md) for details.

### 4.2 TurtleBot4 Lite Setup

1. Flash TurtleBot4 with Ubuntu 22.04 + ROS2 Humble (follow official TurtleBot4 documentation).
2. Set matching `ROS_DOMAIN_ID` on both workstation and robot so they share a single ROS2 DDS graph.
3. Place the docking station in line-of-sight of the robot's cliff-sensor IR receivers.

### 4.3 SLAM Map Generation

Before the first delivery, a floor map of the lab must be created:

SLAM mapping procedure details are tracked in the repository's GitHub project board, while the final procedure notes will be documented in `.md` files. Expected: launch `slam_toolbox` in mapping mode, manually drive the robot around all relevant areas, save the map, configure the map path in `nav2_params.yaml`. Waypoints for each delivery target (e.g. `coffee_house_counter`) must be defined as named poses in the map frame.

### 4.4 ERPNext WMS Configuration

ERPNext WMS configuration guidance is being developed in `.md` files, while the implementation work is tracked in the repository's GitHub project board. Expected: warehouse structure, FIFO stock management rules, delivery order lifecycle, integration with VROOM for pick-sequence optimisation.

### 4.5 Node-RED — ERP to Robot Bridge

Deploy the Node-RED flow that converts an ERPNext delivery order webhook into a `robot_manager` mission via `rosbridge_server` WebSocket. See [Distributor Island](../islands/distributor/index.md#erp-integration-delivery-order-to-robot-mission) for the flow diagram.

### 4.6 Join Fabric Channel

Same procedure as Step 2.5.

### Checkpoint

- [ ] All Docker services healthy
- [ ] TurtleBot4 navigates to a test waypoint and returns to dock autonomously
- [ ] A delivery order in ERPNext triggers a robot mission end-to-end
- [ ] Shipment event written to Fabric ledger
- [ ] All three B2B island peers (Farm, Factory, Distributor) in sync

---

## Step 5 — Coffee House Island

The Coffee House is the consumer endpoint. It has no ERP, no Kafka, and no Fabric peer — all heavyweight processing is delegated to the Lab Cloud.

The three Coffee House modules (POS, Traceability Display, IoT Connector) are planned and their implementation status is tracked in the repository's GitHub project board, while the setup sequence is documented in `.md` files. The steps below describe the intended setup sequence.

### 5.1 Deploy the Modules

Expected: POS module, Traceability Display web app, IoT Connector (MQTT/serial agent).

```bash
# Intended deployment command once the Coffee House island source and docker-compose file exist
cd /opt/digital-supply-chain
cp coffeehouse-island/.env.example coffeehouse-island/.env
./coffeehouse-island/scripts/bootstrap.sh
```

### 5.2 Configure Connections

| Module | Connects to | Config item |
|---|---|---|
| POS | Distributor REST API | `DISTRIBUTOR_API_URL` in `.env` |
| Traceability Display | Lab Cloud Fabric Gateway REST + IoT REST | `LAB_CLOUD_URL` in `.env` |
| IoT Connector | Lab Cloud Mosquitto broker | MQTT broker host/port in `.env` |

### 5.3 RFID / QR Tag Registration

When a delivery bag arrives from the Distributor, its RFID tag or QR code carries the Fabric `batch_id`. Scan it at goods receipt in the POS module to link the bag to the local inventory and enable traceability lookup.

### 5.4 Coffee Machine Integration

Smart coffee machine integration details are being defined in the repository's GitHub project board. Expected: the coffee machine (model tbc) publishes grind level, temperature, bean type, water volume, water hardness, and extraction time per brew either via MQTT or serial. The IoT Connector captures this and forwards it to the Lab Cloud Mosquitto broker.

### Checkpoint

- [ ] POS module running; goods receipt via RFID/QR scan works
- [ ] Traceability Display shows full batch history for a scanned batch_id
- [ ] Coffee machine sensor data visible in Lab Cloud InfluxDB

---

## Step 6 — End-to-End Smoke Test

Once all five components are running, verify the complete supply chain with a single coffee batch.

### Scenario: Trace a Cup Back to the Farm

1. **Farm:** Create a harvest batch in ERPNext (`batch_id: DEMO-001`). Confirm the batch event appears on the Fabric ledger via Hyperledger Explorer.
2. **Farm → Factory transfer:** Physically carry (or simulate) a bag to the Factory. Scan the QR/NFC tag at Factory goods receipt. Confirm `DEMO-001` appears as a purchase receipt in Factory ERPNext.
3. **Factory:** Create and run a production order for `DEMO-001` through the MES (IN → SRT → RST → QC → OUT). Confirm the roast event is written to Fabric.
4. **Factory → Distributor transfer:** Create a delivery note in Factory ERPNext and ship to Distributor. Confirm goods receipt at Distributor WMS.
5. **Distributor:** Create a delivery order to the Coffee House. Confirm the TurtleBot4 executes the mission and docks on return. Confirm shipment event on Fabric.
6. **Coffee House:** Scan the RFID tag at goods receipt. Open the Traceability Display and scan the QR code:

    ```
    Expected output on Traceability Display:
    ✓ Farm:        [origin, altitude, harvest date]
    ✓ Factory:     [roast level, temperature, duration]
    ✓ Distributor: [warehouse, ship date, route]
    ✓ This cup:    [grind, temperature, extraction time]
    ```

The B2B REST API endpoint definitions (Farm → Factory, Factory → Distributor, Distributor → Coffee House, Lab Cloud Fabric Gateway) are documented and coordinated through the repository's GitHub project board. See [B2B Communication](../architecture/b2b-communication.md) for the framework; endpoint schemas will be added as islands are implemented.

---

## Summary Table

| Step | Component | Status |
|---|---|---|
| Prerequisites | Ubuntu 22.04, Docker, network | Documented — [Workstation Setup](setup-workstation.md), [Network](../architecture/network.md) |
| 1 | Lab Cloud (orderer + IoT backend) | Planned — `lab-cloud/` folder not yet created |
| 2 | Farm Island | Partially specified — stack exists, Fabric join + full validation pending |
| 3 | Factory Island | Partially specified — hardware defined, docker-compose and detailed docs pending |
| 4 | Distributor Island | Partially specified — architecture defined, docker-compose and detailed docs pending |
| 5 | Coffee House Island | Planned — modules not yet implemented |
| 6 | End-to-end smoke test | Planned — requires all islands complete |
