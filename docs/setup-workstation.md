# Workstation Setup — Ubuntu 22.04 + Docker

Shared prerequisite for all lab islands that run Docker services on a local workstation (Farm Island, Factory Island, Distributor Island). Each island uses the same base OS and container runtime.

→ [Farm Island setup](islands/farm/setup.md) | [GitOps workflow](gitops.md)

---

## 1. Install Ubuntu 22.04 LTS

Download **Ubuntu 22.04 LTS Desktop** from [ubuntu.com](https://ubuntu.com/download/desktop) and create a bootable USB stick. During installation:

| Prompt | Recommended setting |
|---|---|
| Installation type | Minimal installation (saves resources) |
| Disk layout | Use entire SSD; enable LVM |
| Username | `farm` / `factory` / `distributor` (match island name) |
| Hostname | `farm-island` / `factory-island` / `distributor-island` |
| Automatic updates | Enable |

### 1.1 Post-install system update

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl wget htop net-tools openssh-server
```

> **Recommendation:** Enable the SSH server so the workstation can be administered remotely from within the lab network without requiring physical access.

### 1.2 Grafana kiosk mode (touch display)

For islands with a touch display showing Grafana, set up Chromium in kiosk mode as an autostart application:

```bash
sudo apt install -y chromium-browser unclutter
mkdir -p ~/.config/autostart
```

Create `~/.config/autostart/grafana-kiosk.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=Grafana Kiosk
Exec=chromium-browser --kiosk --noerrdialogs --disable-infobars \
  --no-first-run http://localhost:3000/d/farm/sensor-dashboard
X-GNOME-Autostart-enabled=true
```

Adjust the dashboard URL to match the island's Grafana home dashboard UID.

> Chromium opens automatically in full-screen kiosk mode when the desktop session starts. No manual browser launch is needed.

---

## 2. Install Docker Engine

Install from the official Docker repository (not the Ubuntu default repository, which ships older versions).

```bash
# Add Docker GPG key and repository
sudo apt install -y ca-certificates gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

# Allow running Docker without sudo
sudo usermod -aG docker $USER
newgrp docker

# Verify
docker --version
docker compose version
```

> After adding the user to the `docker` group, log out and back in (or run `newgrp docker`) for the group membership to take effect.

---

## 3. Clone the Repository

All island configurations are managed via Git. Clone the repository once on the workstation:

```bash
git clone https://github.com/digital-business-lab/digital-supply-chain.git /opt/digital-supply-chain
cd /opt/digital-supply-chain
```

> **Do not** copy files via USB stick. The GitOps workflow — automated `git pull` + `docker compose up -d` triggered every 15 minutes — only works when the workstation clones directly from GitHub. See [GitOps Workflow](gitops.md) for details.

---

## 4. Network: DHCP Reservation

Each island workstation must receive the **same IP address** on every boot. Island-internal services (e.g. the LoRaWAN packet forwarder on the Farm Island) target a fixed IP, and DNS is not used inside the island network.

Configure a MAC-based DHCP reservation on the MikroTik router:

```bash
# On the workstation — find the MAC address
ip link show
```

```routeros
# On the MikroTik router (Winbox or RouterOS terminal)
/ip dhcp-server lease
add address=192.168.10.10 mac-address=AA:BB:CC:DD:EE:FF comment=farm-island
```

> Replace `192.168.10.10` with the IP assigned in your lab network. Use the same IP in any island service that requires a static target address (e.g. ChirpStack Gateway Bridge UDP target on the Farm Island).

**NTP:** The MikroTik router provides NTP. Ubuntu and all Docker containers synchronise automatically — no additional NTP configuration is required.

---

## Next Steps

After completing the base setup, follow the island-specific setup guide:

- [Farm Island Setup](islands/farm/setup.md)
