# Farm Island — ERPNext Configuration & Demo Data

ERPNext v15 is the ERP system of the Farm Island. It manages **harvest batches**, **raw-material inventory**, and **outbound shipments** to the Factory Island. Node-RED feeds sensor-driven events into ERPNext via the Frappe REST API.

→ [Farm Island overview](farm.md) | [B2B communication](../b2b-communication.md) | [LoRaWAN details](../lorawan.md)

---

## 1. ERPNext Site Initialisation

After `docker compose up -d` on the Farm Island, the ERPNext container starts with an empty Frappe bench. Run the following once to create the site and install the ERPNext app:

```bash
# Enter the running ERPNext container
docker exec -it farm-erpnext bash

# Create the site (replace <SITE_NAME> with e.g. farm.localhost)
bench new-site farm.localhost \
  --mariadb-root-password "$MARIADB_ROOT_PASS" \
  --admin-password "$ERPNEXT_ADMIN_PASS" \
  --no-mariadb-socket

# Install ERPNext on the new site
bench --site farm.localhost install-app erpnext

# Enable scheduler and set the site as default
bench --site farm.localhost enable-scheduler
bench use farm.localhost
```

> **Assumption:** `$MARIADB_ROOT_PASS` and `$ERPNEXT_ADMIN_PASS` are the values set in `farm-island/.env`. Add `ERPNEXT_ADMIN_PASS` to `.env.example` if not already present.

After initialisation the ERPNext web UI is available at `http://<HOST-IP>:8000` — log in with user `Administrator` and the password set above.

---

## 2. Company Configuration

Navigate to **Setup → Company** and create (or edit the default company):

| Field | Value |
|---|---|
| Company Name | Coffee Farm GmbH |
| Abbreviation | CF |
| Default Currency | EUR |
| Country | Germany |
| Domain | Agriculture |
| Fiscal Year Start | 01 January |
| Fiscal Year End | 31 December |

> **Rationale:** "Agriculture" domain activates crop/harvest-oriented ERPNext features. Currency and country can be adjusted to match the actual lab setup without affecting the didactic scenarios.

### 2.1 System Settings

Navigate to **Setup → System Settings**:

| Field | Value |
|---|---|
| Language | English |
| Time Zone | Europe/Berlin |
| Date Format | DD-MM-YYYY |
| Float Precision | 3 |
| Currency Precision | 2 |

---

## 3. Chart of Accounts

ERPNext creates a standard chart of accounts automatically for Germany. The accounts most relevant to the Farm Island are listed below. No custom accounts are needed for the basic demo; the items in this section are for reference so instructors know where to look.

| Account | Type | Notes |
|---|---|---|
| **4000 – Revenue from Coffee Sales** | Income | Used on sales invoices to Factory Island |
| **5000 – Cost of Raw Materials** | Expense | COGS when coffee beans are dispatched |
| **1100 – Finished Goods (Inventory)** | Asset | Warehouse stock account for processed/packaged harvest batches |
| **1050 – Raw Material Store** | Asset | Warehouse stock account for green beans in the field store |
| **1200 – Accounts Receivable** | Asset | Open invoices against Factory Island |

---

## 4. Warehouses

Navigate to **Stock → Warehouse** and create the following warehouses under the company *Coffee Farm GmbH*:

| Warehouse Name | Abbreviation | Type | Purpose |
|---|---|---|---|
| Field Store – CF | FIELD-CF | Stores | Freshly harvested green beans, not yet graded |
| Graded Store – CF | GRADED-CF | Stores | Beans that have passed quality grading |
| Dispatch – CF | DISP-CF | Transit | Beans packed and ready for shipment to Factory |
| Reject / Quarantine – CF | REJ-CF | Stores | Batches that failed quality checks; await disposal or rework decision |

> **Naming convention:** ERPNext appends the company abbreviation automatically when using the warehouse creation wizard.

---

## 5. Units of Measure

Navigate to **Setup → UOM** and verify these units exist (ERPNext ships most of them; create any that are missing):

| UOM | Symbol | Notes |
|---|---|---|
| Kilogram | kg | Default weight unit for all coffee items |
| Gram | g | Used for sample/quality test quantities |
| Bag | bag | 1 bag = 60 kg (standard jute export bag); used for B2B orders |
| Nos | nos | Used for packaging materials (labels, bags) |

Add the **UOM Conversion Factor** for *Bag → kg*:

> **Stock → UOM Conversions:** Bag → Kilogram, Factor = 60

---

## 6. Item Groups

Navigate to **Stock → Item Group** and create the following hierarchy under *All Item Groups*:

```
All Item Groups
└── Coffee Farm Products
    ├── Green Coffee Beans
    └── Packaging Materials
```

---

## 7. Item Master (Demo Data)

Navigate to **Stock → Item** and create the following items.

### 7.1 Arabica Green Beans

| Field | Value |
|---|---|
| Item Code | CF-BEAN-ARABICA |
| Item Name | Green Coffee Beans – Arabica |
| Item Group | Green Coffee Beans |
| Default UOM | kg |
| Stock UOM | kg |
| Has Batch No | ✔ Yes |
| Batch Naming By | Naming Series |
| Batch Naming Series | HARVEST-.YYYY.-.MM.-.#### |
| Is Stock Item | ✔ Yes |
| Default Warehouse | Field Store – CF |
| Description | Unprocessed Arabica green beans harvested at the Coffee Farm lab island. Batch number encodes harvest year, month, and sequential index. |

### 7.2 Robusta Green Beans

| Field | Value |
|---|---|
| Item Code | CF-BEAN-ROBUSTA |
| Item Name | Green Coffee Beans – Robusta |
| Item Group | Green Coffee Beans |
| Default UOM | kg |
| Stock UOM | kg |
| Has Batch No | ✔ Yes |
| Batch Naming By | Naming Series |
| Batch Naming Series | HARVEST-.YYYY.-.MM.-.#### |
| Is Stock Item | ✔ Yes |
| Default Warehouse | Field Store – CF |
| Description | Unprocessed Robusta green beans harvested at the Coffee Farm lab island. |

### 7.3 Jute Export Bag (Packaging)

| Field | Value |
|---|---|
| Item Code | CF-PKG-JUTEBAG-60 |
| Item Name | Jute Bag 60 kg |
| Item Group | Packaging Materials |
| Default UOM | Nos |
| Stock UOM | Nos |
| Has Batch No | ✗ No |
| Is Stock Item | ✔ Yes |
| Default Warehouse | Graded Store – CF |
| Description | Standard 60 kg jute bag used for outbound coffee bean shipments to the Factory Island. |

---

## 8. Batch Tracking

Coffee bean items use **ERPNext Batch Numbers** to trace each harvest through the supply chain.

### 8.1 Batch Number Series

The naming series `HARVEST-.YYYY.-.MM.-.####` produces batch IDs such as `HARVEST-2025-04-0001`. This ID is:

- printed as a QR code on the jute bag label at the Farm
- scanned at the Factory goods-receipt station
- written to the Hyperledger Fabric ledger as the canonical batch identifier

### 8.2 Batch Custom Fields

Navigate to **Customize Form → Batch** and add the following custom fields to store IoT metadata with each harvest batch:

| Field Label | Field Name | Field Type | Notes |
|---|---|---|---|
| Avg. Soil Moisture (%) | avg_soil_moisture | Float | Average soil moisture reading over the last 7 days before harvest (from LoRaWAN sensors via Node-RED) |
| Avg. Temperature (°C) | avg_temperature | Float | Average ambient temperature over harvest period |
| CO₂ Level (ppm) | co2_level | Float | Last CO₂ reading before harvest |
| Sensor Reading Date | sensor_reading_date | Date | Date of the final sensor log that triggered the harvest event |
| Harvest GPS Lat | harvest_gps_lat | Float | Optional: GPS latitude of the plant position |
| Harvest GPS Lon | harvest_gps_lon | Float | Optional: GPS longitude of the plant position |

> **These fields are populated automatically by Node-RED** when a harvest event is booked. They can also be filled manually during the demo setup.

---

## 9. Customer Master

The **Factory Island** is the only direct B2B customer of the Farm. Navigate to **Selling → Customer**:

| Field | Value |
|---|---|
| Customer Name | Coffee Roasting GmbH |
| Customer Type | Company |
| Customer Group | Commercial |
| Territory | Germany |
| Default Currency | EUR |
| Payment Terms | Net 30 |
| Tax ID | (lab placeholder — leave blank) |

Add a **Contact** and **Address** so ERPNext can generate delivery notes correctly:

- Contact name: Factory Island Operator
- Email: factory@lab.local *(internal lab address — adjust as needed)*
- Address: Factory Island, Lab Building, Room XX

---

## 10. Supplier Master

The Farm does not purchase coffee beans from an external supplier — it grows them. The only purchased inputs for the demo are packaging materials. Navigate to **Buying → Supplier**:

| Field | Value |
|---|---|
| Supplier Name | Packaging Supplies GmbH |
| Supplier Type | Company |
| Supplier Group | Local |
| Default Currency | EUR |
| Payment Terms | Net 30 |

> **Note:** This supplier is demo-only. In lab exercises instructors can skip supplier purchasing entirely and instead use **Stock Reconciliation** to seed initial packaging stock.

---

## 11. Users and API Keys

### 11.1 Administrator (Instructor / Setup)

The default `Administrator` user is used for initial setup only. After setup, instructors log in with a named role account.

### 11.2 Farm Operator (Student Role)

Navigate to **Settings → User** and create:

| Field | Value |
|---|---|
| Email | operator@farm.local |
| First Name | Farm Operator |
| Role | Stock User, Stock Manager, Accounts User |
| Send Welcome Email | No |

This user represents the student working at the Farm Island. Roles grant access to inventory movements, batch creation, and delivery notes, but not to system configuration.

### 11.3 Node-RED API User

Navigate to **Settings → User** and create a dedicated API user:

| Field | Value |
|---|---|
| Email | nodered@farm.local |
| First Name | Node-RED Integration |
| Role | Stock User, Script Manager |
| Send Welcome Email | No |

After saving, generate an **API Key and API Secret**:

1. Open the user record → **API Access** section
2. Click **Generate Keys**
3. Copy both values into `farm-island/.env`:

```bash
ERPNEXT_API_KEY=<paste key here>
ERPNEXT_API_SECRET=<paste secret here>
```

Node-RED reads these environment variables at startup. All ERPNext REST calls from Node-RED use HTTP Basic Auth with this key pair.

---

## 12. Node-RED — Setup and Flows

Node-RED (`farm-nodered`, port 1880) is the integration hub of the Farm Island. It:

- receives decoded sensor telemetry from ChirpStack via MQTT,
- triggers automation (irrigation pump, grow light),
- creates and updates records in ERPNext via the Frappe REST API, and
- writes harvest batch events to the Hyperledger Fabric ledger.

The sections below describe how to set Node-RED up from a fresh container and what each flow does.

---

### 12.1 First-Time Setup

#### Access the UI

After `docker compose up -d` the Node-RED editor is available at:

```
http://<HOST-IP>:1880
```

No login is required by default inside the lab network. To enable authentication, edit `settings.js` in the `nodered-data` volume (see Node-RED docs).

#### Install Required Palette Nodes

Open **Menu → Manage Palette → Install** and install the following community nodes:

| Node package | Purpose |
|---|---|
| `node-red-contrib-mqtt-broker` | (built-in) MQTT subscribe/publish |
| `node-red-node-http-request` | (built-in) HTTP REST calls to ERPNext |
| `node-red-contrib-credentials` | Stores API keys outside the flow JSON |
| `node-red-dashboard` | (optional) Local status panel on the touchscreen |

All packages except `node-red-contrib-credentials` ship with the `nodered/node-red:3-minimal` image. Run the install once; packages persist in the `nodered-data` volume.

#### Configure ERPNext Credentials

ERPNext API credentials must be stored in Node-RED without being embedded in the flow JSON. Use the **Credentials** mechanism:

1. In the editor, open **Menu → Manage Palette → Settings → Credentials store** — or add a `credentials` node to the canvas.
2. Create a credential named `erpnext-farm` with two keys:
   - `apiKey` — value of `ERPNEXT_API_KEY` from `.env`
   - `apiSecret` — value of `ERPNEXT_API_SECRET` from `.env`
3. Every HTTP-request node that calls ERPNext reads these from `msg.headers` set by a preceding **Function** node:

```javascript
// Set in a Function node before every ERPNext HTTP Request node
msg.headers = {
    "Authorization": "token " + credentials.apiKey + ":" + credentials.apiSecret,
    "Content-Type": "application/json"
};
return msg;
```

#### Environment Variables in Node-RED

The `docker-compose.yml` exposes these environment variables into the Node-RED container (add them under `environment:` in `farm-island/docker-compose.yml` if not already present):

```yaml
ERPNEXT_BASE_URL: "http://erpnext:8000"
ERPNEXT_API_KEY:  "${ERPNEXT_API_KEY}"
ERPNEXT_API_SECRET: "${ERPNEXT_API_SECRET}"
```

Inside a Function node, read them with:

```javascript
const base = env.get("ERPNEXT_BASE_URL");
const key  = env.get("ERPNEXT_API_KEY");
const sec  = env.get("ERPNEXT_API_SECRET");
```

---

### 12.2 MQTT Topic Structure

ChirpStack publishes decoded sensor payloads to Mosquitto on this topic pattern (from `chirpstack.toml`):

```
application/<ApplicationID>/device/<DevEUI>/event/<EventType>
```

| Segment | Example value | Notes |
|---|---|---|
| `<ApplicationID>` | `1` | Assigned by ChirpStack when the application is created |
| `<DevEUI>` | `a84041xxxxxx` | Unique per sensor, printed on the device |
| `<EventType>` | `up` | `up` = uplink (sensor reading); `join` = OTAA join |

**Wildcard subscription for all sensor readings:**

```
application/+/device/+/event/up
```

This is the topic used by the Node-RED MQTT-In node in every flow that processes sensor data.

**Example decoded payload** from a Dragino LHT65 (temperature + humidity):

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

The `object` field contains decoded values from the ChirpStack device-profile JavaScript decoder.

---

### 12.3 Flow 1 — Sensor Data Logger

**Purpose:** Subscribe to all sensor uplinks; store the last reading of each sensor in a Node-RED global context variable for use by other flows.

**Nodes:**

```
[MQTT In]  →  [JSON]  →  [Function: extract & store]  →  [Debug]
```

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

### 12.4 Flow 2 — Irrigation Automation

**Purpose:** Read the soil-moisture value from the global context; switch the Shelly relay (pump) ON when moisture drops below a configurable threshold.

**Nodes:**

```
[Inject: every 5 min]  →  [Function: read moisture]  →  [Switch]
                                                            ├─ [HTTP Request: relay ON]
                                                            └─ [HTTP Request: relay OFF]
```

| Node | Configuration |
|---|---|
| **Inject** | Repeat: every 5 minutes |
| **Function: read moisture** | See code below |
| **Switch** | Property: `msg.pumpShouldRun`; Rule 1: `== true` → output 1; Rule 2: `== false` → output 2 |
| **HTTP Request: relay ON** | Method: GET; URL: `http://shelly-relay/relay/0?turn=on` |
| **HTTP Request: relay OFF** | Method: GET; URL: `http://shelly-relay/relay/0?turn=off` |

> **Note:** Replace `shelly-relay` with the Shelly device's IP address or hostname. Configure the threshold value as an environment variable `MOISTURE_THRESHOLD_PCT` (default: 50).

**Function node code:**

```javascript
const threshold = parseFloat(env.get("MOISTURE_THRESHOLD_PCT") || "50");
const sensors   = global.get("sensors") || {};

// Pick the soil moisture sensor by DevEUI (configure as env variable)
const soilDevEui = env.get("SOIL_SENSOR_DEVEUI") || "";
const sensor     = sensors[soilDevEui] || {};

// LHT65 reports soil moisture as "Hum_SHT" in this deployment
const moisture = sensor.Hum_SHT ?? null;

msg.moisture        = moisture;
msg.pumpShouldRun   = moisture !== null && moisture < threshold;
return msg;
```

---

### 12.5 Flow 3 — Harvest Event: Create Batch + Book Material Receipt

**Purpose:** When a soil-moisture sensor reading drops below the harvest threshold, generate a new ERPNext Batch record with sensor metadata and book the harvested quantity into the Field Store.

This flow is **instructor-confirmed**: Node-RED detects the threshold breach and raises a notification; the instructor enters the harvest weight via the Node-RED Dashboard UI or via the ERPNext `Farm Operator` user. Node-RED then calls ERPNext in two sequential steps.

**Nodes:**

```
[MQTT In: sensor up]  →  [Function: check threshold]  →  [Switch]
                                                             └─ threshold breached
                                                                  ↓
                                                    [Dashboard: enter qty]
                                                          ↓
                                   [Function: build Batch payload]
                                          ↓
                               [HTTP Request: POST /api/resource/Batch]
                                          ↓
                              [Function: build Stock Entry payload]
                                          ↓
                         [HTTP Request: POST /api/resource/Stock Entry]
                                          ↓
                                   [Debug / notification]
```

**Step A — Detect threshold (Function node):**

```javascript
const threshold = parseFloat(env.get("HARVEST_MOISTURE_THRESHOLD_PCT") || "65");
const moisture  = msg.readings.Hum_SHT ?? 100;

if (moisture < threshold) {
    msg.triggerHarvest = true;
    msg.moisture       = moisture;
    msg.ts             = msg.ts;
    return msg;
}
return null;   // discard message — no action needed
```

**Step B — Build Batch payload (Function node):**

```javascript
const sensors = global.get("sensors") || {};
const date    = new Date(msg.ts).toISOString().split("T")[0];

// Aggregate readings from the last 7 days (simplified: last known values)
const soilSensor = sensors[env.get("SOIL_SENSOR_DEVEUI")] || {};
const co2Sensor  = sensors[env.get("CO2_SENSOR_DEVEUI")]  || {};

// Auto-generate batch ID using date (ERPNext will apply naming series)
msg.batchPayload = {
    item:                "CF-BEAN-ARABICA",
    manufacturing_date:  date,
    avg_soil_moisture:   soilSensor.Hum_SHT  ?? null,
    avg_temperature:     soilSensor.TempC_SHT ?? null,
    co2_level:           co2Sensor.CO2        ?? null,
    sensor_reading_date: date
};
return msg;
```

**Step B — HTTP Request node (Create Batch):**

| Field | Value |
|---|---|
| Method | POST |
| URL | `{{env.ERPNEXT_BASE_URL}}/api/resource/Batch` |
| Body | `msg.batchPayload` (set `msg.payload = msg.batchPayload` in preceding Function node) |
| Headers | `Authorization: token <key>:<secret>`, `Content-Type: application/json` |
| Return | Parsed JSON object |

**Step C — Build Stock Entry payload (Function node):**

ERPNext returns the new batch ID in the response. Use it to book the material receipt:

```javascript
const batchId = msg.payload.data.name;    // e.g. "HARVEST-2025-04-0001"
const qty     = msg.harvestQtyKg;          // entered via Dashboard UI

msg.stockPayload = {
    stock_entry_type: "Material Receipt",
    company: "Coffee Farm GmbH",
    items: [
        {
            item_code:   "CF-BEAN-ARABICA",
            qty:         qty,
            uom:         "kg",
            t_warehouse: "Field Store - CF",
            batch_no:    batchId
        }
    ]
};
msg.batchId = batchId;
return msg;
```

**Step C — HTTP Request node (Book Material Receipt):**

| Field | Value |
|---|---|
| Method | POST |
| URL | `{{env.ERPNEXT_BASE_URL}}/api/resource/Stock Entry` |
| Body | `msg.stockPayload` |
| Return | Parsed JSON object |

---

### 12.6 Flow 4 — Grading: Transfer Field Store → Graded Store

**Purpose:** After manual quality grading, transfer beans from *Field Store* to *Graded Store* in ERPNext. Triggered from the Node-RED Dashboard UI (instructor/operator presses "Confirm Grading Passed").

**Nodes:**

```
[Dashboard Button: "Confirm Grading"]  →  [Function: build Stock Entry]
                                                   ↓
                                    [HTTP Request: POST /api/resource/Stock Entry]
                                                   ↓
                                             [Debug / notify]
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

### 12.7 Flow 5 — Outbound Shipment: Delivery Note + Fabric Ledger Event

**Purpose:** When the instructor submits the outbound shipment, Node-RED (1) creates a Delivery Note in ERPNext against the Factory customer and (2) writes a `HarvestShipped` event to the Hyperledger Fabric ledger via the Fabric Peer Node REST gateway.

**Nodes:**

```
[Dashboard Button: "Ship to Factory"]
        ↓
[Function: build Delivery Note payload]
        ↓
[HTTP Request: POST /api/resource/Delivery Note]   ← ERPNext
        ↓
[Function: build Fabric event payload]
        ↓
[HTTP Request: POST Fabric gateway]                ← Fabric Peer Node
        ↓
[Debug / success notification]
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
const dn = msg.payload.data;              // Delivery Note response
msg.fabricPayload = {
    event:        "HarvestShipped",
    batchId:      msg.batchId,
    itemCode:     "CF-BEAN-ARABICA",
    quantityKg:   msg.shipQtyKg,
    fromCompany:  "Coffee Farm GmbH",
    toCompany:    "Coffee Roasting GmbH",
    deliveryNote: dn.name,
    shippedAt:    new Date().toISOString()
};
msg.payload = msg.fabricPayload;
return msg;
```

**HTTP Request node (Fabric Peer Node):**

| Field | Value |
|---|---|
| Method | POST |
| URL | `http://farm-fabric-peer:7051/submit` *(adjust to the Fabric REST gateway endpoint)* |
| Content-Type | `application/json` |
| Return | Parsed JSON object |

---

### 12.8 Error Handling and Debugging

#### Catching HTTP Errors

Connect a **Catch** node to each HTTP Request node and route errors to a **Debug** node and optionally a **Dashboard Notification** node:

```
[Catch]  →  [Function: format error]  →  [Debug]
                                              └─→  [Dashboard: show error toast]
```

The Function node extracts the HTTP status code:

```javascript
msg.errorMsg = `ERPNext error ${msg.statusCode}: ${JSON.stringify(msg.payload)}`;
node.error(msg.errorMsg, msg);
return msg;
```

#### Checking ERPNext Responses

ERPNext returns errors as:

```json
{ "exc_type": "ValidationError", "exc": "...", "message": "..." }
```

Always check `msg.payload.exc_type` after an HTTP Request node before proceeding to the next step.

#### Debug Panel

The Node-RED **Debug** panel (right sidebar) shows all messages passing through debug nodes. During demos, enable the debug node on the MQTT-In node to verify that sensor payloads arrive from ChirpStack.

#### Test Without a Physical Sensor

Use an **Inject** node with a manually crafted JSON payload to simulate a sensor reading:

```json
{
  "deviceInfo": { "devEui": "a84041xxxxxx", "deviceName": "LHT65-01" },
  "time": "2025-04-10T08:15:00Z",
  "object": { "TempC_SHT": 22.1, "Hum_SHT": 48.5, "BatV": 3.2 }
}
```

Set `Hum_SHT` below `HARVEST_MOISTURE_THRESHOLD_PCT` (default 65) to trigger the harvest flow.

---

### 12.9 Complete ERPNext API Call Reference

| Flow | ERPNext action | Method | Endpoint | Body type |
|---|---|---|---|---|
| 3 | Create Batch | POST | `/api/resource/Batch` | Batch document |
| 3 | Book Material Receipt (harvest) | POST | `/api/resource/Stock Entry` | Stock Entry (Material Receipt) |
| 4 | Transfer Field Store → Graded Store | POST | `/api/resource/Stock Entry` | Stock Entry (Material Transfer) |
| 5 | Create Delivery Note (outbound shipment) | POST | `/api/resource/Delivery Note` | Delivery Note document |
| Any | Read current batch stock | GET | `/api/resource/Batch/<batch_id>` | — |
| Any | Submit a draft document | PUT | `/api/resource/<DocType>/<name>` | `{"docstatus": 1}` |

---

## 13. Initial Demo Data — Seed Script

The following steps seed a complete, consistent demo state that instructors can use for the first lab session. Execute them manually via the ERPNext UI **or** run the bench console commands shown.

### Step 1 — Opening Stock (Field Store)

Create a **Stock Reconciliation** to set opening inventory:

| Item | Batch | Warehouse | Qty (kg) |
|---|---|---|---|
| CF-BEAN-ARABICA | HARVEST-2025-03-0001 | Field Store – CF | 50 |
| CF-BEAN-ARABICA | HARVEST-2025-04-0001 | Field Store – CF | 25 |
| CF-BEAN-ROBUSTA | HARVEST-2025-03-0002 | Field Store – CF | 30 |
| CF-PKG-JUTEBAG-60 | — | Graded Store – CF | 10 (Nos) |

### Step 2 — Populate Batch Metadata

Open each batch record created in Step 1 and fill the custom sensor fields with representative demo values:

| Batch | Soil Moisture | Temp (°C) | CO₂ (ppm) | Reading Date |
|---|---|---|---|---|
| HARVEST-2025-03-0001 | 72.3 | 21.8 | 408 | 2025-03-15 |
| HARVEST-2025-04-0001 | 68.4 | 22.1 | 412 | 2025-04-10 |
| HARVEST-2025-03-0002 | 70.1 | 21.5 | 405 | 2025-03-20 |

### Step 3 — Create a Draft Delivery Note (Factory Purchase Order Scenario)

To demonstrate the B2B flow, create one **Delivery Note** in *Draft* state that students will submit during the lab exercise:

| Field | Value |
|---|---|
| Customer | Coffee Roasting GmbH |
| Posting Date | today |
| Item | CF-BEAN-ARABICA |
| Batch | HARVEST-2025-04-0001 |
| Qty | 25 kg |
| Warehouse | Graded Store – CF |

Leaving it in Draft lets students experience the submit workflow and observe the resulting stock deduction and Fabric ledger write.

---

## 14. Outbound B2B Flow (Farm → Factory)

```
Farm ERPNext: stock graded beans (Graded Store – CF)
    ↓
Farm: create Delivery Note → submit → print QR label (batch ID)
    ↓
Student carries jute bag physically to Factory Island
    ↓
Factory ERPNext: scan QR code → auto-create Purchase Receipt
    ↓
Fabric Peer Node (Farm Island): writes inter-island handover event
```

The Fabric event is written by **Node-RED Flow 5** (see [section 12.7](#127-flow-5--outbound-shipment-delivery-note--fabric-ledger-event)) immediately after the Delivery Note is submitted in ERPNext. The event payload is:

```json
{
  "event": "HarvestShipped",
  "batchId": "HARVEST-2025-04-0001",
  "itemCode": "CF-BEAN-ARABICA",
  "quantityKg": 25.0,
  "fromCompany": "Coffee Farm GmbH",
  "toCompany": "Coffee Roasting GmbH",
  "shippedAt": "2025-04-12T08:00:00Z"
}
```

---

## 15. Reference: Relevant ERPNext Modules

| Module | Used for |
|---|---|
| **Stock** | Warehouse management, material receipts, transfers, stock reconciliation |
| **Selling** | Delivery notes to the Factory Island |
| **Batch** | Harvest batch creation and traceability |
| **Quality** | (Optional) quality inspections on graded beans before shipment |
| **Reports → Batch-Wise Balance History** | End-to-end batch traceability across stock movements |
| **Reports → Stock Ledger** | Per-warehouse, per-item movement history |
