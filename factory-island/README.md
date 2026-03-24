# Factory Island — Coffee Processing

Coffee processing and roasting. Two Dobot robots handle sorting, QC, and packaging; ERPNext MES manages production orders; a Fabric peer node records roasting events on the shared ledger.

📖 **[Full documentation → GitHub Pages](https://digital-business-lab.github.io/digital-supply-chain/islands/factory/)**

---

## Physical Structure

Aluminium profile rack with three levels — identical construction principle to the Farm Island.

```
TOP LEVEL   — Stainless-steel perforated plate (Lochblech) + 3D-printed containers
              (Dobot #1 sorting / Dobot #2 QC + packaging)
MID LEVEL   — Second perforated plate as WIP buffer / staging area
LOWER LEVEL — Workstation, network hardware
FRONT       — Touch display (MES / Grafana dashboard)
```

Containers (~6 × 6 cm base) snap into the grid at defined positions, enabling repeatable Dobot pick-and-place without vision system.

**Material input:** raw green beans arrive in a container carried manually from the Farm Island; goods receipt is scanned into ERPNext and recorded on the Fabric ledger.

---

## Hardware at a Glance

| Component | Function |
|---|---|
| Linux workstation | Robot control and MES |
| 2× Dobot Magician | Sorting + QC / packaging |
| Touch display | MES operator interface |

## Services

ERPNext MES · Dobot Python SDK · OPC-UA · Kafka · Grafana · Fabric Peer Node

## Status

> **Planned** — will be set up analogously to `farm-island/`.
