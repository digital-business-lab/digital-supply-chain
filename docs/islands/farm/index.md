# Farm Island — Coffee Farm

The Farm Island represents the origin of the supply chain: a coffee farm. It is the only island with field-level sensor infrastructure, measuring growing conditions and logging harvest batches via ERPNext.

→ [Architecture overview](../../architecture/index.md) | [LoRaWAN details](lorawan.md) | [GitOps workflow](../../operations/gitops.md) | [Hardware & Build](hardware.md) | [Setup guide](setup.md) | [ERP config & demo data](erp.md)

---

## Physical Structure

The Farm Island is built on an **aluminium profile rack** with multiple shelf levels, making all components visible and accessible — a deliberate didactic choice.

```
┌─────────────────────────────────────┐
│  TOP LEVEL — Coffee Plant           │
│  ┌───────────────────────────────┐  │
│  │   LED grow light (above)      │  │  ← intensity + schedule controllable
│  │   🌱 Coffee plant in pot      │  │
│  │   LoRaWAN sensors around it   │  │  ← soil moisture, temp, CO₂
│  └───────────────────────────────┘  │
│                                     │
│  MID LEVEL — Water Reservoir        │
│  ┌───────────────────────────────┐  │
│  │   Water tank + pump           │  │
│  │   Shelly relay (irrigation)   │  │  ← moisture-triggered automation
│  └───────────────────────────────┘  │
│                                     │
│  LOWER LEVEL — Compute & Network    │
│  ┌───────────────────────────────┐  │
│  │   ERP workstation (Dell)      │  │
│  │   MikroTik router             │  │
│  │   MikroTik wAP LR8 gateway    │  │
│  └───────────────────────────────┘  │
│                                     │
│  FRONT — Touch display (mounted)    │
└─────────────────────────────────────┘
```

### Grow Light

An LED grow light is mounted above the coffee plant. Both **intensity** and **on/off schedule** are software-controlled (via Node-RED), allowing simulation of different photoperiods and light stress scenarios for didactic use.

### Automated Irrigation

A small water pump draws from a reservoir on the mid level. A **Shelly relay** (or equivalent smart relay) switches the pump based on soil-moisture readings from the LoRaWAN sensors. The control logic runs in Node-RED and triggers watering when moisture drops below a configurable threshold.

### Touch Display

A touch display is mounted on the front of the rack and shows the Grafana sensor dashboard in kiosk mode, giving a live view of plant conditions directly at the island.

---

For detailed hardware information and physical build instructions, see the dedicated [Hardware & Build](hardware.md) page.

---

## Services (Docker)

| Service | Port | Function |
|---|---|---|
| ChirpStack | 8080 | LoRaWAN Network Server — authentication, decoding, MQTT output |
| ChirpStack Gateway Bridge | 1700/udp | Translates UDP packets from wAP LR8 to MQTT |
| Mosquitto | 1883 | MQTT broker (island-internal) |
| Node-RED | 1880 | MQTT → ERPNext + Kafka + Fabric peer integration |
| Grafana | 3000 | Sensor dashboard on the touch display |
| ERPNext | 8000 | ERP: inventory, batch tracking, quality assurance |
| Fabric Peer Node | 7051 | Writes harvest batch events to the shared Fabric ledger |
| PostgreSQL | internal | Database for ChirpStack |
| MariaDB | internal | Database for ERPNext |

---

## Internal Data Flow

```
LoRaWAN sensors (868 MHz)
    ↓
MikroTik wAP LR8  →  UDP:1700
    ↓
ChirpStack Gateway Bridge  →  MQTT
    ↓
ChirpStack (auth, decode)  →  MQTT (Mosquitto)
    ↓
Node-RED
    ├─→ ERPNext          (REST — inventory & batch bookings)
    ├─→ Kafka            (internal event processing)
    ├─→ Fabric Peer Node (harvest batch event on ledger)
    ├─→ Shelly relay     (irrigation pump ON/OFF — moisture threshold)
    └─→ LED grow light   (intensity + schedule control)
```

---

## Getting Started

For initial setup, scripts, and folder structure, see the dedicated [Farm Island Setup Guide](setup.md).
