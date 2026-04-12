# Workstation Setup — Ubuntu 22.04 + Docker

Shared prerequisite for the Lab Cloud server and all lab island workstations that run Docker services. The Lab Cloud server plus the Farm, Factory, and Distributor island machines all use the same base OS and container runtime.

Complete this guide before starting the Lab Cloud deployment, and before deploying any island stack.

→ [Lab Cloud Setup](../lab-cloud/setup.md) | [GitOps workflow](gitops.md)

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

### 1.2 Touch display configuration

If a workstation has a touch display, its behavior should be configured per island and per use case. The workstation setup guide does not prescribe a dedicated kiosk mode.

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

After completing the base setup, proceed with the Lab Cloud setup first. Once the Lab Cloud is running, continue with island-specific setup in supply-chain order.

- [Lab Cloud Setup](../lab-cloud/setup.md)
- [Farm Island Setup](../islands/farm/setup.md)
