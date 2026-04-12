# Farm Island — Setup Guide

Step-by-step operational guide for bringing up the Farm Island from a fresh workstation. Covers LoRaWAN stack configuration, ChirpStack gateway and device registration, MikroTik wAP LR8 packet forwarder, and Grafana first-time setup.

**Prerequisites:** Complete [Workstation Setup](../setup-workstation.md) first (Ubuntu 22.04, Docker, repository cloned to `/opt/digital-supply-chain`).

→ [Farm Island overview](index.md) | [ERPNext configuration](erp.md) | [Node-RED flows](nodered.md) | [LoRaWAN details](../lorawan.md)

---

## 1. Start the Stack

```bash
cd /opt/digital-supply-chain

# Copy and fill in secrets
cp farm-island/.env.example farm-island/.env
nano farm-island/.env   # replace all placeholder passwords

# Run bootstrap (sets up systemd timers, starts Docker services)
chmod +x farm-island/scripts/bootstrap.sh
./farm-island/scripts/bootstrap.sh
```

The bootstrap script runs six steps: system check → Docker validation → Grafana kiosk autostart → password config → stack start → backup timer setup. Credentials and service URLs are printed at the end.

### Services after startup

| Service | URL / Port | Description |
|---|---|---|
| ChirpStack | `:8080` | LoRaWAN Network Server — gateway and device management |
| Node-RED | `:1880` | MQTT flow editor, ERPNext and Fabric integration |
| Grafana | `:3000` | Sensor dashboard (touch display) |
| ERPNext | `:8000` | ERP: inventory, batch tracking, quality assurance |
| Mosquitto MQTT | `:1883` | Island-internal broker (no external access needed) |
| ChirpStack Gateway Bridge | `:1700/udp` | Receives LoRa packets from MikroTik wAP LR8 |

---

## 2. Configure the MikroTik wAP LR8

The MikroTik wAP LR8 runs RouterOS with a built-in LoRa packet forwarder. Configure it to send packets to the workstation.

### 2.1 Set packet forwarder target

```routeros
# RouterOS terminal (or Winbox → LoRa → Gateways)
/lora gateway set 0 \
  servers=192.168.10.10:1700 \
  server-key=""
```

> Replace `192.168.10.10` with the DHCP-reserved IP of the workstation (set up in [Workstation Setup § Network](../setup-workstation.md#4-network-dhcp-reservation)). Port `1700/UDP` is received by the ChirpStack Gateway Bridge.

**Alternative via Winbox:** LoRa → Gateways → set Server Address to `192.168.10.10:1700`.

### 2.2 Verify the frequency plan

Confirm the frequency plan is set to **EU868** (standard in Europe):

```
Winbox: LoRa → Settings → Frequency Plan: EU_863_870_TTN
```

---

## 3. Configure ChirpStack

### 3.1 First login

Open ChirpStack at `http://192.168.10.10:8080`.

- Username: `admin`
- Password: `admin` — **change immediately after the first login**

### 3.2 Register the gateway

1. Navigate to **Gateways → Add gateway**
2. Enter the **Gateway EUI** (printed on the MikroTik device label, or visible under RouterOS → LoRa → Gateways)
3. Name: `Farm-Gateway` | Region: `EU868`
4. Save. The status should change to **Online** within a few seconds once the packet forwarder is running.

### 3.3 Create device profiles

Create one device profile per sensor type. Example for the **Dragino LHT65**:

1. Navigate to **Device Profiles → Add device profile**
2. Name: `Dragino-LHT65` | Region: `EU868` | MAC version: `1.0.3` | Regional parameters: `A`
3. Under **Codec**, paste the JavaScript payload decoder for the sensor
4. Save

> Payload decoders for common sensors (Dragino LHT65, SenseCAP S2103) are available on GitHub. Search: `chirpstack payload decoder [model name]`.

Repeat for each additional sensor model used on the island (e.g. Dragino LDDS75, Seeed SenseCAP S2103 CO₂).

### 3.4 Create an application and register devices

1. **Applications → Add application** → Name: `Farm-Sensors`
2. Inside the application: **Add device** → enter the **Device EUI** from the sensor label
3. After saving, enter the **Application Key (AppKey)** — also on the sensor label
4. Bring the sensor within radio range. After the first uplink, data appears under **Events**.

---

## 4. Basic Node-RED sensor flow

A minimal working flow to verify the sensor data pipeline end-to-end. For the full integration (ERPNext, irrigation, Fabric), see [Farm Island — Node-RED Flows](nodered.md).

### 4.1 Open the editor

```
http://192.168.10.10:1880
```

### 4.2 Create the test flow

Connect these nodes:

```
MQTT In → JSON Parse → Function (extract fields) → Debug
```

**MQTT In node settings:**
- Server: `mosquitto` | Port: `1883`
- Topic: `application/+/device/+/event/up`
- Output: parsed JSON object

**Function node** — extract sensor fields (example for Dragino LHT65):

```javascript
const data = msg.payload.object;
msg.payload = {
  deviceId: msg.payload.deviceInfo.devEui,
  temperature: data.TempC_SHT,
  humidity: data.Hum_SHT,
  timestamp: msg.payload.time,
};
return msg;
```

Deploy and watch the Debug panel for incoming sensor messages on each uplink.

---

## 5. Grafana first-time setup

### 5.1 First login

Open Grafana at `http://192.168.10.10:3000`. Use the credentials set in `farm-island/.env`.

The PostgreSQL data source is provisioned automatically on first start (via `config/grafana/provisioning/`).

### 5.2 Create the sensor dashboard

1. **Dashboards → New → New Dashboard → Add visualization**
2. Data source: `PostgreSQL`
3. Write a query to read sensor uplinks from the ChirpStack database
4. Add panels for temperature, humidity, and soil moisture
5. Save the dashboard and mark it as the **home dashboard** (star icon → set as home)

> Grafana opens automatically in kiosk mode on the touch display at boot (configured in [Workstation Setup § Grafana kiosk mode](../setup-workstation.md#12-grafana-kiosk-mode-touch-display)). No manual browser launch is needed.

---

## 6. Operations reference

Common Docker commands for day-to-day operation:

```bash
# Show status of all services
docker compose ps

# Follow logs for a specific service
docker compose logs -f chirpstack
docker compose logs -f nodered

# Restart a single service
docker compose restart chirpstack

# Stop all services (data preserved in volumes)
docker compose stop

# Stop and remove containers (data preserved in volumes)
docker compose down

# Pull updated images and restart
docker compose pull && docker compose up -d

# Resource usage overview
docker stats
```

---

## 7. Next steps after basic setup

| Step | Reference |
|---|---|
| ERPNext: create site, install app, configure warehouse and batch tracking | [Farm Island — ERPNext Configuration](erp.md) |
| Node-RED: add ERPNext REST API integration and irrigation automation | [Farm Island — Node-RED Flows](nodered.md) |
| ChirpStack: add remaining sensor types (Dragino LDDS75, SenseCAP CO₂) | § 3.3 above |
| Grafana: refine dashboards, configure alerting for threshold breaches | § 5 above |
| Automated GitOps deploy and backup timers | [GitOps Workflow](../gitops.md) |
