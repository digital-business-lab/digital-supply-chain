# Farm Island — Hardware & Build

Detailed hardware information for the Farm Island, including the physical rack layout, component list, and practical assembly notes for the coffee farm didactic setup.

→ [Farm Island overview](index.md) | [LoRaWAN details](lorawan.md) | [Setup guide](setup.md) | [ERP config & demo data](erp.md)

---

## Rack layout and build

The Farm Island is built on an **aluminium profile rack** with three clearly separated shelf levels:

- **Top level:** plant area with grow light and LoRaWAN sensors
- **Mid level:** water reservoir, pump, and smart relay for irrigation
- **Lower level:** compute and network equipment

This physical layout keeps the plant, automation, and compute components visible and accessible for teaching.

### Build steps

1. Assemble the aluminium rack on a stable floor location with enough clearance for the front-mounted touch display.
2. Mount the touch display on the front of the rack at a comfortable viewing height.
3. Place the coffee plant and pot on the top level and set the LED grow light above the plant.
4. Install the LoRaWAN sensors around the plant so they can measure soil moisture, temperature, and CO₂ without being obstructed.
5. Position the water reservoir and pump on the mid level, with tubing routed cleanly to the plant pot.
6. Install the smart relay near the pump so it can switch the irrigation circuit safely.
7. Place the workstation, MikroTik router, and MikroTik wAP LR8 gateway on the lower level, leaving enough space for airflow and cable management.
8. Connect the workstation to the router and route power and network cables so that the top-level plant area is tidy and the lower-level electronics are easy to access for maintenance.

> Tip: label cables and keep sensor power/data cabling separate from mains power to reduce noise and simplify troubleshooting.

---

## Hardware components

| Component | Model / Spec | Function |
|---|---|---|
| Linux workstation | Dell, Core i7, 16 GB RAM, 256 GB SSD | Main compute node for all Docker services |
| Touch display | — | Grafana sensor dashboard in kiosk mode (rack-mounted) |
| LED grow light | — | Controllable plant lighting (intensity + schedule via Node-RED) |
| Smart relay | Shelly (tbc) | Switches irrigation pump based on soil-moisture threshold |
| Water tank + pump | — | Automated moisture-controlled irrigation |
| LoRaWAN gateway | MikroTik wAP LR8 kit | Receives sensor radio packets, forwards to ChirpStack |
| Router | MikroTik | DHCP, NTP, routing for all island devices |
| Sensors | Dragino LHT65, LDDS75 / Seeed SenseCAP S2103 | Soil moisture, temperature, CO₂, fill level |

