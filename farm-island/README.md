# Farm Island — Coffee Farm

Origin of the supply chain. LoRaWAN sensors measure field conditions; ERPNext manages harvest batches; a Fabric peer node writes batch events to the shared traceability ledger.

📖 **[Full documentation → GitHub Pages](https://digital-business-lab.github.io/digital-supply-chain/islands/farm/)**

---

## Hardware at a Glance

The island is built on an aluminium profile rack with multiple levels: coffee plant + LED grow light on top, water reservoir in the middle, compute and network hardware below, touch display mounted on the front.

| Component | Function |
|---|---|
| Linux workstation (Dell, Core i7, 16 GB) | All Docker services |
| MikroTik wAP LR8 kit | LoRaWAN gateway |
| LoRaWAN sensors (Dragino, Seeed) | Soil moisture, temperature, CO₂ |
| LED grow light | Controllable plant lighting (intensity + schedule) |
| Shelly relay + pump + water tank | Moisture-triggered automated irrigation |
| Touch display | Grafana dashboard (kiosk mode) |
| MikroTik router | DHCP / NTP / routing |

## Services

ChirpStack · Mosquitto · Node-RED · ERPNext · Grafana · Fabric Peer Node · PostgreSQL · MariaDB

## Quick Start

```bash
cp farm-island/.env.example farm-island/.env
# fill in passwords, then:
chmod +x farm-island/scripts/bootstrap.sh && ./farm-island/scripts/bootstrap.sh
```
