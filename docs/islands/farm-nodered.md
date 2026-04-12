# Farm Island — Node-RED Setup and Flows

Node-RED (`farm-nodered`, port **1880**) is the integration hub of the Farm Island. It:

- receives decoded sensor telemetry from ChirpStack via MQTT,
- triggers irrigation automation (Shelly relay + pump) based on soil moisture,
- records manually triggered harvest events in ERPNext (Batch + Material Receipt), and
- writes outbound shipment events to the Hyperledger Fabric ledger.

→ [Farm Island overview](farm.md) | [ERPNext configuration](farm-erp.md) | [LoRaWAN details](../lorawan.md)

---

## 1. First-Time Setup

### 1.1 Access the Editor

After `docker compose up -d` the Node-RED editor is available at:

```
http://<HOST-IP>:1880
```

No login is required by default inside the lab network. To enable authentication, edit `settings.js` in the `nodered-data` Docker volume and set `adminAuth` (see [Node-RED security docs](https://nodered.org/docs/user-guide/runtime/securing-node-red)).

### 1.2 Install Required Palette Nodes

The standard **MQTT In/Out** and **HTTP Request** nodes are built into Node-RED and are already available in the editor. If you need the local operator panel and external credential storage described below, open **Menu → Manage Palette → Install** and install these community nodes:

| Node package | Purpose |
|---|---|
| `node-red-contrib-credentials` | Stores API keys outside the flow JSON |
| `node-red-dashboard` | Local operator panel for manual harvest recording |

Built-in nodes are available without any palette install. Install the community packages once; they persist in the `nodered-data` volume.

### 1.3 Configure ERPNext Credentials

ERPNext API credentials must not be embedded in the exported flow JSON. Expose them to the Node-RED container as environment variables and read them from Function nodes with `env.get(...)`:

1. In `farm-island/.env`, set `ERPNEXT_API_KEY` and `ERPNEXT_API_SECRET`.
2. In `farm-island/docker-compose.yml`, pass those variables into the `farm-nodered` container under `environment:`.
3. In every flow, add a **Function** node before each ERPNext HTTP Request node to set the `Authorization` header:

```javascript
// Prepend to every ERPNext HTTP Request node
const apiKey = env.get("ERPNEXT_API_KEY");
const apiSecret = env.get("ERPNEXT_API_SECRET");

msg.headers = {
    "Authorization": "token " + apiKey + ":" + apiSecret,
    "Content-Type": "application/json"
};
return msg;
```

### 1.4 Environment Variables in Node-RED

The `farm-island/docker-compose.yml` must expose the following variables into the Node-RED container (add under `environment:` if not present):

```yaml
ERPNEXT_BASE_URL:    "http://erpnext:8000"
ERPNEXT_API_KEY:     "${ERPNEXT_API_KEY}"
ERPNEXT_API_SECRET:  "${ERPNEXT_API_SECRET}"
SOIL_SENSOR_DEVEUI:  "${SOIL_SENSOR_DEVEUI}"
CO2_SENSOR_DEVEUI:   "${CO2_SENSOR_DEVEUI}"
MOISTURE_THRESHOLD_PCT: "50"
```

Inside a Function node, read them with:

```javascript
const base = env.get("ERPNEXT_BASE_URL");
const key  = env.get("ERPNEXT_API_KEY");
const sec  = env.get("ERPNEXT_API_SECRET");
```

---

## 2. MQTT Topic Structure

ChirpStack publishes decoded sensor payloads to the local Mosquitto broker using the topic pattern defined in `chirpstack.toml`:

```
application/<ApplicationID>/device/<DevEUI>/event/<EventType>
```

| Segment | Example | Notes |
|---|---|---|
| `<ApplicationID>` | `1` | Assigned by ChirpStack when the application is created |
| `<DevEUI>` | `a84041xxxxxx` | Unique per sensor, printed on the device |
| `<EventType>` | `up` | `up` = uplink (sensor reading); `join` = OTAA join |

**Wildcard subscription used by Node-RED MQTT-In nodes:**

```
application/+/device/+/event/up
```

**Example decoded payload** (Dragino LHT65 — temperature + humidity):

```json
{
  "deduplicationId": "...",
  "time": "2025-04-10T08:15:00Z",
  "deviceInfo": {
    "tenantId": "52f14cd4-c6f1-4fea-aed9-012eff0cd04a",
    "applicationId": "1",
    "deviceName": "LHT65-01",
    "devEui": "a84041xxxxxx",
    "deviceProfileName": "Dragino-LHT65"
  },
  "object": {
    "TempC_SHT": 22.1,
    "Hum_SHT": 64.3,
    "BatV": 3.2
  }
}
```

The `object` field contains decoded values produced by the ChirpStack device-profile JavaScript decoder.

---

## 3. Flow Overview

| Flow | Trigger | Purpose |
|---|---|---|
| **Flow 1** — Sensor Data Logger | MQTT uplink from any sensor | Stores latest sensor readings in global context for use by all other flows |
| **Flow 2** — Irrigation Automation | Every 5 min (Inject node) | Reads soil moisture from context; switches Shelly relay (pump) ON/OFF |
| **Flow 3** — Harvest Recording | **Manual** — Dashboard button pressed by operator | Attaches current sensor metadata to the batch; creates ERPNext Batch + Material Receipt |
| **Flow 4** — Grading Transfer | **Manual** — Dashboard button pressed by operator | Moves graded beans from Field Store to Graded Store in ERPNext |
| **Flow 5** — Outbound Shipment | **Manual** — Dashboard button pressed by operator | Creates Delivery Note in ERPNext; writes `HarvestShipped` event to Fabric ledger |

> **Harvest is always manually initiated.** Sensor data (soil moisture, temperature, CO₂) is collected continuously and is available as metadata, but the decision to harvest is made by the instructor or student — not by an automated threshold rule.

---

## 4. Flow 1 — Sensor Data Logger

**Purpose:** Subscribe to all sensor uplinks and store the latest reading of each sensor in a Node-RED global context variable. All other flows read sensor values from this shared context.

**Node diagram:**

```
[MQTT In]  →  [JSON]  →  [Function: extract & store]  →  [Debug]
```

**Node configuration:**

| Node | Configuration |
|---|---|
| **MQTT In** | Server: `mosquitto:1883`; Topic: `application/+/device/+/event/up`; QoS: 0; Output: parsed JSON object |
| **JSON** | Action: "Always convert to JavaScript Object" |
| **Function: extract & store** | See code below |
| **Debug** | Output: `msg.payload` — visible in the debug panel |

**Function node code:**

```javascript
// Extract key fields
const devEui   = msg.payload.deviceInfo.devEui;
const ts       = msg.payload.time;
const readings = msg.payload.object || {};

// Persist in global context (keyed by DevEUI)
const sensors = global.get("sensors") || {};
sensors[devEui] = { ts, ...readings };
global.set("sensors", sensors);

// Forward enriched message
msg.devEui   = devEui;
msg.readings = readings;
msg.ts       = ts;
return msg;
```

---

## 5. Flow 2 — Irrigation Automation

**Purpose:** Check soil moisture every 5 minutes and switch the irrigation pump (via Shelly relay) ON or OFF depending on a configurable threshold.

> **This flow is irrigation-only.** It does not trigger any ERPNext records and has no connection to the harvest process.

**Node diagram:**

```
[Inject: every 5 min]  →  [Function: read moisture]  →  [Switch]
                                                              ├─→  [HTTP Request: relay ON]
                                                              └─→  [HTTP Request: relay OFF]
```

**Node configuration:**

| Node | Configuration |
|---|---|
| **Inject** | Repeat: every 5 minutes |
| **Function: read moisture** | See code below |
| **Switch** | Property: `msg.pumpShouldRun`; Rule 1: `== true` → output 1; Rule 2: `== false` → output 2 |
| **HTTP Request: relay ON** | Method: GET; URL: `http://<SHELLY_IP>/relay/0?turn=on` |
| **HTTP Request: relay OFF** | Method: GET; URL: `http://<SHELLY_IP>/relay/0?turn=off` |

> Replace `<SHELLY_IP>` with the Shelly device's IP address. Set `MOISTURE_THRESHOLD_PCT` in `.env` (default: 50 %).

**Function node code:**

```javascript
const threshold  = parseFloat(env.get("MOISTURE_THRESHOLD_PCT") || "50");
const sensors    = global.get("sensors") || {};
const soilDevEui = env.get("SOIL_SENSOR_DEVEUI") || "";
const sensor     = sensors[soilDevEui] || {};

// LHT65 reports relative humidity as "Hum_SHT" in this deployment
const moisture = sensor.Hum_SHT ?? null;

msg.moisture      = moisture;
msg.pumpShouldRun = moisture !== null && moisture < threshold;
return msg;
```

---

## 6. Flow 3 — Harvest Recording (Manual)

**Purpose:** Operator presses a Dashboard button to record a completed harvest. Node-RED reads the latest sensor values from global context, attaches them as metadata to a new ERPNext Batch, then books the harvested quantity as a Material Receipt into Field Store.

**Trigger: manual.** No sensor threshold is involved. Harvesting is a deliberate decision made by the instructor or student.

**Node diagram:**

```
[Dashboard: "Record Harvest" button]
        ↓
[Dashboard: enter Item (Arabica/Robusta), Qty (kg), Harvest Date]
        ↓
[Function: read sensor context + build Batch payload]
        ↓
[Function: set auth headers]
        ↓
[HTTP Request: POST /api/resource/Batch]   ← ERPNext
        ↓
[Function: extract batchId + build Stock Entry payload]
        ↓
[Function: set auth headers]
        ↓
[HTTP Request: POST /api/resource/Stock Entry]   ← ERPNext
        ↓
[Debug / Dashboard: show success toast]
```

**Dashboard inputs** (configure via `node-red-dashboard` Text Input and Dropdown nodes):

| Input | Type | Notes |
|---|---|---|
| Item | Dropdown | Options: `CF-BEAN-ARABICA`, `CF-BEAN-ROBUSTA` |
| Qty (kg) | Number input | Harvested weight |
| Harvest Date | Date picker | Defaults to today |

**Step A — Build Batch payload (Function node):**

```javascript
// Read sensor snapshot from context (populated by Flow 1)
const sensors    = global.get("sensors") || {};
const soilSensor = sensors[env.get("SOIL_SENSOR_DEVEUI")] || {};
const co2Sensor  = sensors[env.get("CO2_SENSOR_DEVEUI")]  || {};

const date = msg.harvestDate || new Date().toISOString().split("T")[0];

// Prepare batch document — ERPNext assigns the HARVEST-... name via naming series
msg.payload = {
    item:                msg.itemCode,         // e.g. "CF-BEAN-ARABICA"
    manufacturing_date:  date,
    avg_soil_moisture:   soilSensor.Hum_SHT  ?? null,
    avg_temperature:     soilSensor.TempC_SHT ?? null,
    co2_level:           co2Sensor.CO2        ?? null,
    sensor_reading_date: soilSensor.ts ? soilSensor.ts.split("T")[0] : date
};
return msg;
```

**HTTP Request node (Create Batch):**

| Field | Value |
|---|---|
| Method | POST |
| URL | `{{env.ERPNEXT_BASE_URL}}/api/resource/Batch` |
| Return | Parsed JSON object |

**Step B — Build Stock Entry payload (Function node):**

ERPNext returns the new batch name in `msg.payload.data.name`. Use it to book the material receipt.

```javascript
const batchId = msg.payload.data.name;   // e.g. "HARVEST-2025-04-0001"

msg.batchId = batchId;
msg.payload = {
    stock_entry_type: "Material Receipt",
    company: "Coffee Farm GmbH",
    items: [
        {
            item_code:   msg.itemCode,
            qty:         msg.harvestQtyKg,
            uom:         "kg",
            t_warehouse: "Field Store - CF",
            batch_no:    batchId
        }
    ]
};
return msg;
```

**HTTP Request node (Book Material Receipt):**

| Field | Value |
|---|---|
| Method | POST |
| URL | `{{env.ERPNEXT_BASE_URL}}/api/resource/Stock Entry` |
| Return | Parsed JSON object |

---

## 7. Flow 4 — Grading: Transfer Field Store → Graded Store

**Purpose:** After the instructor has manually graded a batch, transfer the passed quantity from *Field Store* to *Graded Store* in ERPNext.

**Trigger: manual** — operator presses "Confirm Grading Passed" in the Dashboard and enters the batch ID and quantity.

**Node diagram:**

```
[Dashboard: "Confirm Grading" button]
        ↓
[Dashboard: enter Batch ID, Qty (kg)]
        ↓
[Function: build Stock Entry (Material Transfer)]
        ↓
[Function: set auth headers]
        ↓
[HTTP Request: POST /api/resource/Stock Entry]
        ↓
[Debug / Dashboard: show success toast]
```

**Function node code:**

```javascript
// msg.batchId and msg.gradedQtyKg come from Dashboard input nodes
msg.payload = {
    stock_entry_type: "Material Transfer",
    company: "Coffee Farm GmbH",
    items: [
        {
            item_code:   "CF-BEAN-ARABICA",
            qty:         msg.gradedQtyKg,
            uom:         "kg",
            s_warehouse: "Field Store - CF",
            t_warehouse: "Graded Store - CF",
            batch_no:    msg.batchId
        }
    ]
};
return msg;
```

---

## 8. Flow 5 — Outbound Shipment: Delivery Note + Fabric Ledger Event

**Purpose:** When the operator ships a batch to the Factory, Node-RED (1) creates a Delivery Note in ERPNext and (2) writes a `HarvestShipped` event to the Hyperledger Fabric ledger via the Farm Fabric peer node.

**Trigger: manual** — operator presses "Ship to Factory" in the Dashboard.

**Node diagram:**

```
[Dashboard: "Ship to Factory" button]
        ↓
[Dashboard: enter Batch ID, Qty (kg)]
        ↓
[Function: build Delivery Note payload]
        ↓
[Function: set auth headers]
        ↓
[HTTP Request: POST /api/resource/Delivery Note]   ← ERPNext
        ↓
[Function: build Fabric event payload]
        ↓
[HTTP Request: POST Fabric gateway]                ← Farm Fabric peer node
        ↓
[Debug / Dashboard: show success toast]
```

**Function — Build Delivery Note payload:**

```javascript
msg.payload = {
    customer:     "Coffee Roasting GmbH",
    company:      "Coffee Farm GmbH",
    posting_date: new Date().toISOString().split("T")[0],
    items: [
        {
            item_code:   "CF-BEAN-ARABICA",
            qty:         msg.shipQtyKg,
            uom:         "kg",
            warehouse:   "Graded Store - CF",
            batch_no:    msg.batchId
        }
    ]
};
return msg;
```

**HTTP Request node (Delivery Note):**

| Field | Value |
|---|---|
| Method | POST |
| URL | `{{env.ERPNEXT_BASE_URL}}/api/resource/Delivery Note` |
| Return | Parsed JSON object |

**Function — Build Fabric event payload:**

```javascript
const dn = msg.payload.data;              // Delivery Note response from ERPNext
msg.payload = {
    event:        "HarvestShipped",
    batchId:      msg.batchId,
    itemCode:     "CF-BEAN-ARABICA",
    quantityKg:   msg.shipQtyKg,
    fromCompany:  "Coffee Farm GmbH",
    toCompany:    "Coffee Roasting GmbH",
    deliveryNote: dn.name,
    shippedAt:    new Date().toISOString()
};
return msg;
```

**HTTP Request node (Fabric peer node):**

| Field | Value |
|---|---|
| Method | POST |
| URL | `http://farm-fabric-peer:7051/submit` *(adjust to the Fabric REST gateway endpoint)* |
| Content-Type | `application/json` |
| Return | Parsed JSON object |

---

## 9. Error Handling and Debugging

### Catching HTTP Errors

Connect a **Catch** node to each HTTP Request node and route errors to a **Debug** node and optionally a **Dashboard Notification** node:

```
[Catch]  →  [Function: format error]  →  [Debug]
                                               └─→  [Dashboard: show error toast]
```

**Function node code:**

```javascript
msg.errorMsg = `ERPNext error ${msg.statusCode}: ${JSON.stringify(msg.payload)}`;
node.error(msg.errorMsg, msg);
return msg;
```

### Reading ERPNext Error Responses

ERPNext returns application errors as:

```json
{ "exc_type": "ValidationError", "exc": "...", "message": "..." }
```

Always check `msg.payload.exc_type` in the node after an HTTP Request before proceeding to the next step.

### Debug Panel

The Node-RED **Debug** panel (right sidebar) shows all messages that pass through Debug nodes. During demos, enable the debug node on the MQTT-In node (Flow 1) to verify that sensor payloads arrive from ChirpStack.

### Test Without a Physical Sensor

Use an **Inject** node with a manually crafted JSON payload to simulate a sensor reading arriving from ChirpStack:

```json
{
  "deviceInfo": { "devEui": "a84041xxxxxx", "deviceName": "LHT65-01" },
  "time": "2025-04-10T08:15:00Z",
  "object": { "TempC_SHT": 22.1, "Hum_SHT": 48.5, "BatV": 3.2 }
}
```

Connect the Inject node to the JSON node at the start of Flow 1. Once the payload is injected, it will be stored in the global sensor context and will be available as metadata the next time the "Record Harvest" button is pressed.

---

## 10. Complete ERPNext API Call Reference

| Flow | ERPNext action | Method | Endpoint | Body type |
|---|---|---|---|---|
| 3 | Create Batch (with sensor metadata) | POST | `/api/resource/Batch` | Batch document |
| 3 | Book Material Receipt (harvest into Field Store) | POST | `/api/resource/Stock Entry` | Stock Entry (Material Receipt) |
| 4 | Transfer Field Store → Graded Store | POST | `/api/resource/Stock Entry` | Stock Entry (Material Transfer) |
| 5 | Create Delivery Note (outbound shipment) | POST | `/api/resource/Delivery Note` | Delivery Note document |
| Any | Read a batch record | GET | `/api/resource/Batch/<batch_id>` | — |
| Any | Submit a draft document | PUT | `/api/resource/<DocType>/<name>` | `{"docstatus": 1}` |
