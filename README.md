# SCM Labor — Digitale Open-Source-Lieferkette

Lehr- und Forschungsprojekt zur Simulation einer mehrstufigen B2B-Lieferkette.
Drei unabhängige Laborinseln — **Farm · Factory · Distributor** — kommunizieren ausschließlich über REST-APIs, vollständig auf Open-Source-Basis.

---

## Projektstand (März 2026)

### Erledigt
- Gesamtkonzept ausgearbeitet (`docs/Lieferkette_Konzept.docx`)
- SVG-Übersicht der drei Laborinseln (`docs/laborinseln_uebersicht_1.html`)
- Farm-Insel vollständig spezifiziert:
  - `docker-compose.yml` mit allen Diensten
  - Konfigurationsdateien (ChirpStack, Mosquitto, Grafana, PostgreSQL)
  - Bootstrap-Skript für Schnelleinrichtung (`scripts/bootstrap.sh`)
  - Backup- und Restore-Skripte inkl. systemd-Timer
  - MikroTik RouterOS Backup-Skript
  - Setup-Anleitung als DOCX (`farm-insel/docs/`)

### Offen
- Factory-Insel und Distributor-Insel analog aufbauen
- REST-API-Endpunkte zwischen den drei Inseln definieren
- Node-RED-Flows für ERPNext-Integration entwickeln
- Lehrplan und Use-Case-Sammlung für Seminare ausarbeiten
- VM-Golden-Image nach erstem produktivem Aufbau erstellen

---

## Ordnerstruktur

```
SCM Labor/
  README.md                        ← diese Datei
  docs/
    Lieferkette_Konzept.docx       ← Gesamtkonzept (9 Kapitel)
    laborinseln_uebersicht_1.html  ← Architekturübersicht (SVG)
  farm-insel/
    docker-compose.yml             ← vollständiger Dienste-Stack
    .env.example                   ← Vorlage für Passwörter
    docs/
      Farm-Insel_Setup-Anleitung.docx
    config/
      chirpstack/                  ← chirpstack.toml
      chirpstack-gateway-bridge/   ← chirpstack-gateway-bridge.toml
      grafana/provisioning/        ← Datasource-Provisioning
      mosquitto/                   ← mosquitto.conf
      postgres/                    ← init.sql
    scripts/
      bootstrap.sh                 ← Einmaliger Schnellstart (läuft auf der Workstation)
      backup.sh                    ← Datensicherung (Datenbanken + Volumes)
      restore.sh                   ← Wiederherstellung aus Backup
      install-backup-timer.sh      ← Richtet systemd-Timer ein
      farm-backup.service/.timer   ← systemd-Units (täglich 02:00)
      mikrotik-backup.rsc          ← RouterOS-Backup-Befehle
```

Factory- und Distributor-Insel entstehen analog als `factory-insel/` und `distributor-insel/`.

---

## Architektur

### Die drei Laborinseln

| Insel | Rolle | Besonderheit |
|---|---|---|
| Farm | Ursprung der Lieferkette | LoRaWAN-Sensorik, IoT-Stack |
| Factory | Verarbeitung | 2× Dobot-Roboter, MES |
| Distributor | Lager & Logistik | WMS, VROOM-Routenplanung |

Jede Insel = ein eigenständiges Unternehmen mit eigenem ERPNext, eigenem Kafka und eigenem MikroTik-Router. **B2B-Kommunikation ausschließlich über REST-APIs.**

### Farm-Insel im Detail

**Hardware:** Dell Workstation (Core i7, 16 GB RAM, 265 GB SSD), Touchscreen, MikroTik wAP LR8 kit als LoRaWAN-Gateway, MikroTik Router (DHCP/NTP/Routing für alle Insel-Geräte).

**Netzwerk:** Alle Geräte sind DHCP-Clients am MikroTik-Router. Die Workstation bekommt eine feste DHCP-Reservierung nach MAC-Adresse (z.B. `192.168.10.10`), damit der wAP LR8 den Paketforwarder auf eine feste IP zeigen kann.

**Dienste (Docker):**

| Dienst | Port | Funktion |
|---|---|---|
| ChirpStack | 8080 | LoRaWAN Network Server |
| ChirpStack Gateway Bridge | 1700/udp | Übersetzt UDP→MQTT (MikroTik wAP LR8) |
| Mosquitto | 1883 | MQTT-Broker (intern) |
| Node-RED | 1880 | MQTT→ERPNext Integration |
| Grafana | 3000 | Sensor-Dashboard (Touchscreen, Kiosk-Modus) |
| ERPNext | 8000 | ERP: Lager, Chargen, QS |
| PostgreSQL | intern | Datenbank für ChirpStack |
| MariaDB | intern | Datenbank für ERPNext |

**Datenfluss:**
LoRaWAN-Sensoren → MikroTik wAP LR8 (UDP:1700) → ChirpStack Gateway Bridge → Mosquitto (MQTT) → ChirpStack → Node-RED → ERPNext + Kafka

---

## Getroffene Entscheidungen

**ChirpStack statt TTN (The Things Network)**
TTN wurde initial als Cloud-Lösung geplant, dann durch lokales ChirpStack ersetzt. Begründung: Offline-Fähigkeit im Laborbetrieb, vollständige Einsehbarkeit der Pipeline für Studierende (didaktischer Wert), Datensouveränität für Forschung, keine Abhängigkeit von externem Dienst.

**Kein VM-Betrieb auf der Workstation**
Die Farm-Insel läuft nativ auf Ubuntu + Docker, ohne Hypervisor. Begründung: 16 GB RAM sind für VM + ERPNext zu eng, Touchscreen-Kiosk funktioniert einfacher nativ. VMs sind jedoch für den **Lehrbetrieb** auf einem separaten Labor-Server sinnvoll: Ein Golden Image nach erster Einrichtung ermöglicht es, für jede Studierendengruppe eine isolierte Umgebung in Minuten bereitzustellen.

**Kein SSH-Fernzugriff durch Claude**
Ausgehende TCP-Verbindungen sind in der Claude-Sandbox blockiert. Einrichtung erfolgt stattdessen über das Bootstrap-Skript (`scripts/bootstrap.sh`), das auf der Workstation ausgeführt wird.

**Backup-Strategie: Skriptbasiert statt VM-Snapshots**
SQL-Dumps (pg_dump, mysqldump) + Docker Volume-Archive, automatisiert via systemd-Timer, Aufbewahrung 7 Tage. Zuverlässiger als Block-Level-Snapshots einer laufenden Datenbank.

---

## Schnellstart Farm-Insel

```bash
# 1. Ordner auf die Workstation kopieren (USB oder scp)
scp -r farm-insel/ farm@192.168.10.10:~/

# 2. Bootstrap-Skript starten (richtet alles ein)
cd ~/farm-insel
chmod +x scripts/bootstrap.sh && ./scripts/bootstrap.sh
```

---

## Technologiestack (vollständig Open Source)

LoRaWAN: MikroTik wAP LR8 · ChirpStack · Mosquitto
Integration: Node-RED · Apache Kafka
ERP: ERPNext (Frappe)
Datenbanken: PostgreSQL · MariaDB · Redis
Dashboard: Grafana
Robotik: Dobot Python SDK · ROS2 (optional)
Logistik: VROOM (Routenoptimierung)
Netzwerk: MikroTik RouterOS
