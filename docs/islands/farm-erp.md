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

## 12. Node-RED Integration — ERPNext API Calls

Node-RED runs on the Farm Island and calls the ERPNext Frappe REST API for the following events:

| Trigger | ERPNext action | API endpoint |
|---|---|---|
| Soil moisture drops below threshold | Creates a *Stock Entry* (reason: "Harvest Ready" note) — instructor confirmation still required | `POST /api/resource/Stock Entry` |
| Instructor confirms harvest | Creates a new **Batch** record with sensor metadata fields | `POST /api/resource/Batch` |
| Harvest quantity entered | Creates a *Stock Entry* (Material Receipt) booking beans into Field Store | `POST /api/resource/Stock Entry` |
| Grading complete | Creates a *Stock Transfer* (Field Store → Graded Store) | `POST /api/resource/Stock Entry` |
| Outbound shipment created | Creates a *Delivery Note* against the Factory customer | `POST /api/resource/Delivery Note` |

### 12.1 Example: Create a Harvest Batch via REST

```http
POST /api/resource/Batch
Authorization: token <API_KEY>:<API_SECRET>
Content-Type: application/json

{
  "item": "CF-BEAN-ARABICA",
  "batch_id": "HARVEST-2025-04-0001",
  "manufacturing_date": "2025-04-10",
  "avg_soil_moisture": 68.4,
  "avg_temperature": 22.1,
  "co2_level": 412.0,
  "sensor_reading_date": "2025-04-10"
}
```

### 12.2 Example: Book a Material Receipt (Harvest)

```http
POST /api/resource/Stock Entry
Authorization: token <API_KEY>:<API_SECRET>
Content-Type: application/json

{
  "stock_entry_type": "Material Receipt",
  "company": "Coffee Farm GmbH",
  "items": [
    {
      "item_code": "CF-BEAN-ARABICA",
      "qty": 25.0,
      "uom": "kg",
      "t_warehouse": "Field Store - CF",
      "batch_no": "HARVEST-2025-04-0001"
    }
  ]
}
```

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

The Fabric event payload written by Node-RED contains:

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
