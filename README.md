# ERPNext v15 on Docker (Compose) — with **webshop** + **payments**

Production-like ERPNext v15 stack using Docker Compose.  
Includes MariaDB, Redis (queue + cache), backend, nginx frontend, websocket, workers (short/long), scheduler, and bootstrap helpers.

> **What you get**
> - ERPNext/FRAPPE v15 images
> - Persistent volumes for DB, sites, logs
> - Scheduler runs reliably from the bench root
> - Optional apps: `payments` and `webshop` (branch **version-15**)
> - One-file Compose (`pwd.yml`) for quick spin-up

---

## Prerequisites

- Docker Engine
- **docker-compose v1.29+** (or Compose V2: use `docker compose` commands)
- Linux host (tested on Ubuntu Server)
- If UFW is enabled, open LAN access:
  ```bash
  sudo ufw allow OpenSSH
  sudo ufw allow 8080/tcp
  ```

---

## 1) Prepare `pwd.yml`

Make sure your `pwd.yml` resembles this (only the relevant bits shown).  
**Key points**:
- `frontend` has correct site headers.
- `scheduler` runs from bench root with `bench schedule`.

```yaml
version: "3"

services:
  backend:
    image: frappe/erpnext:v15.78.1
    networks: [frappe_network]
    deploy: { restart_policy: { condition: on-failure } }
    volumes:
      - sites:/home/frappe/frappe-bench/sites
      - logs:/home/frappe/frappe-bench/logs
    environment:
      DB_HOST: db
      DB_PORT: "3306"
      MYSQL_ROOT_PASSWORD: admin
      MARIADB_ROOT_PASSWORD: admin

  configurator:
    image: frappe/erpnext:v15.78.1
    networks: [frappe_network]
    deploy: { restart_policy: { condition: none } }
    entrypoint: ["bash","-c"]
    command: >
      ls -1 apps > sites/apps.txt;
      bench set-config -g db_host $DB_HOST;
      bench set-config -gp db_port $DB_PORT;
      bench set-config -g redis_cache "redis://$REDIS_CACHE";
      bench set-config -g redis_queue "redis://$REDIS_QUEUE";
      bench set-config -g redis_socketio "redis://$REDIS_QUEUE";
      bench set-config -gp socketio_port $SOCKETIO_PORT;
    environment:
      DB_HOST: db
      DB_PORT: "3306"
      REDIS_CACHE: redis-cache:6379
      REDIS_QUEUE: redis-queue:6379
      SOCKETIO_PORT: "9000"
    volumes:
      - sites:/home/frappe/frappe-bench/sites
      - logs:/home/frappe/frappe-bench/logs

  create-site:
    image: frappe/erpnext:v15.78.1
    networks: [frappe_network]
    deploy: { restart_policy: { condition: none } }
    volumes:
      - sites:/home/frappe/frappe-bench/sites
      - logs:/home/frappe/frappe-bench/logs
    entrypoint: ["bash","-c"]
    command: >
      wait-for-it -t 120 db:3306;
      wait-for-it -t 120 redis-cache:6379;
      wait-for-it -t 120 redis-queue:6379;
      export start=`date +%s`;
      until [[ -n `grep -hs ^ sites/common_site_config.json | jq -r ".db_host // empty"` ]] &&             [[ -n `grep -hs ^ sites/common_site_config.json | jq -r ".redis_cache // empty"` ]] &&             [[ -n `grep -hs ^ sites/common_site_config.json | jq -r ".redis_queue // empty"` ]];
      do
        echo "Waiting for sites/common_site_config.json to be created";
        sleep 5;
        if (( `date +%s`-start > 120 )); then
          echo "could not find sites/common_site_config.json with required keys";
          exit 1;
        fi
      done;
      echo "sites/common_site_config.json found";
      bench new-site --mariadb-user-host-login-scope='%'         --admin-password=admin         --db-root-username=root --db-root-password=admin         --install-app erpnext --set-default frontend;

  db:
    image: mariadb:10.6
    networks: [frappe_network]
    healthcheck: { test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "--password=admin"], interval: 1s, retries: 20 }
    deploy: { restart_policy: { condition: on-failure } }
    command:
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
      - --skip-character-set-client-handshake
      - --skip-innodb-read-only-compressed
    environment:
      MYSQL_ROOT_PASSWORD: admin
      MARIADB_ROOT_PASSWORD: admin
    volumes:
      - db-data:/var/lib/mysql

  redis-queue:
    image: redis:6.2-alpine
    networks: [frappe_network]
    deploy: { restart_policy: { condition: on-failure } }
    volumes: [redis-queue-data:/data]

  redis-cache:
    image: redis:6.2-alpine
    networks: [frappe_network]
    deploy: { restart_policy: { condition: on-failure } }

  websocket:
    image: frappe/erpnext:v15.78.1
    networks: [frappe_network]
    deploy: { restart_policy: { condition: on-failure } }
    command: ["node","/home/frappe/frappe-bench/apps/frappe/socketio.js"]
    volumes:
      - sites:/home/frappe/frappe-bench/sites
      - logs:/home/frappe/frappe-bench/logs

  queue-short:
    image: frappe/erpnext:v15.78.1
    networks: [frappe_network]
    deploy: { restart_policy: { condition: on-failure } }
    command: ["bench","worker","--queue","short,default"]
    volumes:
      - sites:/home/frappe/frappe-bench/sites
      - logs:/home/frappe/frappe-bench/logs

  queue-long:
    image: frappe/erpnext:v15.78.1
    networks: [frappe_network]
    deploy: { restart_policy: { condition: on-failure } }
    command: ["bench","worker","--queue","long,default,short"]
    volumes:
      - sites:/home/frappe/frappe-bench/sites
      - logs:/home/frappe/frappe-bench/logs

  scheduler:
    image: frappe/erpnext:v15.78.1
    networks: [frappe_network]
    deploy: { restart_policy: { condition: on-failure } }
    working_dir: /home/frappe/frappe-bench
    command: ["bench","schedule"]
    volumes:
      - sites:/home/frappe/frappe-bench/sites
      - logs:/home/frappe/frappe-bench/logs

  frontend:
    image: frappe/erpnext:v15.78.1
    networks: [frappe_network]
    depends_on: [websocket]
    deploy: { restart_policy: { condition: on-failure } }
    command: ["nginx-entrypoint.sh"]
    environment:
      BACKEND: backend:8000
      FRAPPE_SITE_NAME_HEADER: "X-Frappe-Site-Name"
      FRAPPE_SITE_NAME: "frontend"
      SOCKETIO: websocket:9000
      UPSTREAM_REAL_IP_ADDRESS: 127.0.0.1
      UPSTREAM_REAL_IP_HEADER: X-Forwarded-For
      UPSTREAM_REAL_IP_RECURSIVE: "off"
      PROXY_READ_TIMEOUT: 120
      CLIENT_MAX_BODY_SIZE: 50m
    volumes:
      - sites:/home/frappe/frappe-bench/sites
      - logs:/home/frappe/frappe-bench/logs
    ports:
      - "8080:8080"

volumes:
  db-data:
  redis-queue-data:
  sites:
  logs:

networks:
  frappe_network:
    driver: bridge
```



---

## 2) Boot the stack

```bash
docker-compose -f pwd.yml up -d
```

Open ERPNext on the LAN: `http://<server-ip>:8080/`  
(Default site: `frontend`. Admin password is what you set in `create-site`.)

If you ever hit the compose v1 **'ContainerConfig'** glitch:
```bash
docker-compose -f pwd.yml down && docker-compose -f pwd.yml up -d
```

---

## 3) Install **webshop** + **payments**

> You’ll install the apps into the bench, then ensure **every Python service** can import them.

### 3.1 Clone apps (once) in **backend**
```bash
docker-compose -f pwd.yml exec backend bash -lc '
set -e
cd /home/frappe/frappe-bench/apps
[ -d payments/.git ] || git clone -b version-15 --depth 1 https://github.com/frappe/payments payments
[ -d webshop/.git ]  || git clone -b version-15 --depth 1 https://github.com/frappe/webshop  webshop
cd /home/frappe/frappe-bench
ls -1 apps > sites/apps.txt
env/bin/python -m pip install -e apps/payments -e apps/webshop
'
```

### 3.2 Install wheels in **queue/scheduler/websocket**
```bash
for SVC in scheduler queue-short queue-long websocket; do
  docker-compose -f pwd.yml exec "$SVC" bash -lc '
    set -e
    cd /home/frappe/frappe-bench
    env/bin/python -m pip install -e apps/payments -e apps/webshop
  '
done
```

### 3.3 Migrate & clear caches
```bash
docker-compose -f pwd.yml exec backend bash -lc '
  bench --site frontend migrate
  bench --site frontend clear-cache
  bench --site frontend clear-website-cache
'
docker-compose -f pwd.yml restart queue-short queue-long scheduler
```

### 3.4 Verify
```bash
docker-compose -f pwd.yml exec backend bench --site frontend list-apps
# Expect to see: frappe, erpnext, payments, webshop
```

---

## 4) Enable **Webshop** and **Payments** in ERPNext (UI)

1. **Webshop**
   - Log in as Administrator → **Website > Settings**
   - Ensure Website is enabled; publish at least one **Item** with website visibility.
   - **E Commerce Settings**: enable Shopping Cart, set Price List, Currencies, UOMs, etc.
   - Build website (happens automatically via scheduler). If needed, **Clear Website Cache**.

2. **Payments (via `payments` app)**
   - Go to **Integrations > Payment Gateways** and configure your provider(s):
     - **Stripe**: add **Stripe Settings** (API keys), set as enabled.
     - **Razorpay**: add **Razorpay Settings** (key id/secret), enable.
     - **Braintree**, **GoCardless**, etc. as required.
   - In **Accounts > Payment Gateway Account**, link the gateway to your Company, Default Receivable, and Currency.
   - Test a checkout from the Webshop page/cart.



---

## Day-2 Ops (handy commands)

```bash
# Status
docker-compose -f pwd.yml ps

# Logs
docker-compose -f pwd.yml logs --tail=120 backend frontend scheduler
docker-compose -f pwd.yml logs --tail=80 queue-short queue-long

# Health (quiet output is good)
docker-compose -f pwd.yml logs --tail=120 scheduler | egrep -i 'traceback|module|error' || echo "scheduler clean ✅"

# Housekeeping
docker-compose -f pwd.yml exec backend bench --site frontend migrate
docker-compose -f pwd.yml exec backend bench --site frontend clear-cache
docker-compose -f pwd.yml exec backend bench --site frontend clear-website-cache

# Restart specific services
docker-compose -f pwd.yml restart backend frontend websocket scheduler
```

---

## Troubleshooting

### 500 “Internal Server Error” on `:8080`
- From **frontend** container, check backend:
  ```bash
  docker-compose -f pwd.yml exec frontend bash -lc 'curl -sS http://backend:8000/api/method/ping || true'
  ```
  If you see “backend does not exist”, do a full cycle:
  ```bash
  docker-compose -f pwd.yml down && docker-compose -f pwd.yml up -d
  ```
- Confirm frontend env:
  ```yaml
  FRAPPE_SITE_NAME_HEADER: "X-Frappe-Site-Name"
  FRAPPE_SITE_NAME: "frontend"
  ```
- Check backend errors:
  ```bash
  docker-compose -f pwd.yml exec backend bash -lc 'tail -n 120 logs/web.error.log || true'
  ```

### `ModuleNotFoundError: No module named 'payments'/'webshop'`
- Ensure apps are present under `apps/` and listed in `sites/apps.txt`.
- Run `pip install` in **backend, scheduler, queue-short, queue-long, websocket**:
  ```bash
  docker-compose -f pwd.yml exec <service> bash -lc 'cd /home/frappe/frappe-bench && env/bin/python -m pip install -e apps/payments -e apps/webshop'
  ```
- Restart workers & scheduler:
  ```bash
  docker-compose -f pwd.yml restart queue-short queue-long scheduler
  ```

### Scheduler says “No such command 'schedule'”
- Ensure in `pwd.yml`:
  ```yaml
  scheduler:
    working_dir: /home/frappe/frappe-bench
    command: ["bench","schedule"]
  ```

### Compose v1 **KeyError: 'ContainerConfig'**
- Clear stale metadata:
  ```bash
  docker-compose -f pwd.yml down
  docker-compose -f pwd.yml up -d
  ```

### Configurator didn’t write `common_site_config.json`
- Set the keys manually:
  ```bash
  docker-compose -f pwd.yml exec backend bash -lc '
  bench set-config -g db_host db
  bench set-config -g db_port 3306
  bench set-config -g redis_cache redis://redis-cache:6379
  bench set-config -g redis_queue redis://redis-queue:6379
  bench set-config -g redis_socketio redis://redis-queue:6379
  bench set-config -g socketio_port 9000
  jq . sites/common_site_config.json || cat sites/common_site_config.json
  '
  ```

---


