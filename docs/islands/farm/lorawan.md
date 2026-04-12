# LoRaWAN Architecture (Farm Island)

The LoRaWAN integration on the Farm Island follows a clearly separated four-layer architecture. Each layer has a single responsibility and can be replaced independently.

## Layer 1 — Sensors (Field Level)

Battery-powered LoRa sensors transmit encrypted packets in the **868 MHz band** (Europe). Typical measurement intervals: 5–15 minutes.

| Sensor | Model | Measurement |
|---|---|---|
| Temperature / humidity | Dragino LHT65 | Air temperature, relative humidity |
| Fill level / distance | Dragino LDDS75 | Storage fill level |
| CO₂ | Seeed SenseCAP S2103 | CO₂ concentration in storage / greenhouse |

All data is contextually meaningful for coffee farming: soil moisture tracks irrigation needs, microclimate temperature affects bean development, CO₂ levels matter in storage, canopy light affects ripening.

## Layer 2 — Gateway (MikroTik wAP LR8)

The MikroTik wAP LR8 kit receives radio signals from all sensors in the 868 MHz band and forwards them as UDP packets to ChirpStack. The device does **not** interpret packet content — it is pure packet forwarding. A single gateway can serve an unlimited number of sensors within radio range.

## Layer 3 — Network Server (ChirpStack, local)

ChirpStack runs locally via Docker on the Farm Island's Linux workstation.

| Function | Detail |
|---|---|
| Sensor authentication | AppKey / DevEUI per sensor |
| Deduplication | Drops duplicate packets from multiple gateways |
| Payload decoding | JavaScript decoder per device type |
| Output | Clean JSON messages via local Mosquitto MQTT broker |

Running ChirpStack locally (instead of The Things Network) ensures offline capability, full pipeline visibility for students, data sovereignty, and no dependency on an external service.

## Layer 4 — Integration (Node-RED)

Node-RED subscribes to the MQTT topic from ChirpStack and distributes data to:

- **ERPNext** — automatic inventory and quality bookings
- **Kafka** — internal further processing (island-internal only)
- **Fabric peer node** — harvest batch events written to the shared ledger

The visual programming interface is directly accessible to students without programming experience, making the data flow transparent and modifiable.

## Internal Data Flow

```
LoRaWAN sensors
    ↓ (868 MHz radio)
MikroTik wAP LR8
    ↓ (UDP:1700)
ChirpStack Gateway Bridge
    ↓ (MQTT)
ChirpStack Network Server
    ↓ (MQTT → Mosquitto)
Node-RED
    ├─→ ERPNext (REST API)
    ├─→ Kafka (internal)
    └─→ Fabric Peer Node (gRPC)
```
