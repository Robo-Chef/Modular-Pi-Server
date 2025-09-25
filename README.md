# Raspberry Pi Home Server

A comprehensive, modular **LAN-only** home server setup using Raspberry Pi 3 B+
with Pi-hole, Unbound, monitoring, and optional services. Designed for easy
deployment and personalization.

## Architecture

- **Decision Records**: Explore key architectural decisions in
  [docs/adr/](docs/adr/)
- **Base OS**: Raspberry Pi OS (64-bit)
- **Static IP**: Configured via `.env` (e.g., `192.168.1.XXX`)
- **Core Services**: Pi-hole + Unbound for DNS and ad blocking
  ![Screenshot: Pi-hole Admin Dashboard example]
- **Monitoring**: Prometheus, Grafana, Uptime Kuma
  ![Screenshot: Uptime Kuma status page]
- **Optional**: Home Assistant, Gitea
- **Security**: `nftables` firewall, SSH hardening, container isolation
- **Resilience**: Configured for graceful recovery after network interruptions
  (e.g., router reboots)

## Getting Started

### 🚀 **One-Command Deployment** (Recommended)

```bash
./scripts/deploy.sh
```

This single command handles everything: setup, deployment, and validation.

### 📋 **Quick Start Guide**

For a streamlined deployment experience, see:  
➡️ [QUICK_START.md](QUICK_START.md)

### 📖 **Detailed Setup Instructions**

For comprehensive setup instructions, including initial OS flashing,
configuration, and deployment, please refer to:  
➡️ [RASPBERRY_PI_SERVER_SETUP.md](RASPBERRY_PI_SERVER_SETUP.md)

Additionally, for a deeper understanding of the project's core philosophy,
design choices, and constraints, consult the
[LAN-Only Stack Plan](docs/LAN_ONLY_STACK_PLAN.md).

### 🛠️ Manual Installation Steps

Before proceeding, ensure your Raspberry Pi OS is **already installed and
configured** according to the detailed instructions in:  
➡️ [RASPBERRY_PI_SERVER_SETUP.md](RASPBERRY_PI_SERVER_SETUP.md)

These steps assume you have completed the initial OS setup via Raspberry Pi
Imager (hostname, username, password, timezone, static IP, SSH enabled) and are
currently connected to your Pi via SSH.

1.  **Handle SSH Host Key Changes (if re-imaging Pi):**

    ```bash
    ssh-keygen -R 192.168.1.XXX # Replace with your Pi's IP
    ```

2.  **Clone the repository (on your Pi):**

    ```bash
    git clone https://github.com/Robo-Chef/Modular-Pi-Server.git ~/pihole-server
    cd ~/pihole-server
    ```

3.  **Configure your `.env` file (on your Pi):**

    ```bash
    cp env.example .env
    nano .env
    ```

    - Replace placeholders with real values. `UNIVERSAL_PASSWORD` will be used
      by multiple services. Ensure `TZ`, `PI_STATIC_IP`, `PIHOLE_HOSTNAME` match
      your Pi OS setup.

4.  **Install dependencies and run setup script:**

    ```bash
    sudo apt update
    sudo apt install -y dos2unix dnsutils
    dos2unix .env scripts/*.sh
    chmod +x scripts/*.sh
    ./scripts/setup.sh
    ```

    - ⚠️ **Docker Group Change Requires Re-login!** After `setup.sh`, log out
      and back in to apply Docker group membership.

5.  **Deploy services:**

    ```bash
    ./scripts/quick-deploy.sh
    ```

6.  **Configure your Router:** Set the Pi static IP (e.g., `192.168.1.XXX`) as
    **Primary DNS Server** in router settings.

---

## 📦 Deployment, Verification & Troubleshooting

This section provides a full operational reference once your Pi is configured.

### 🐳 Deployment Options

**Option 1: Full Deployment (Recommended)**

```bash
./scripts/quick-deploy.sh
```

**Option 2: Staged Deployment**

```bash
docker-compose -f docker/docker-compose.core.yml up -d
docker-compose -f docker/monitoring/docker-compose.monitoring.yml up -d
docker-compose -f docker/optional/docker-compose.optional.yml up -d
```

---

### 🔍 Verification Steps

**Check Services:**

```bash
docker ps
docker-compose logs
docker-compose logs pihole
```

**Test Core Services:**

```bash
./scripts/test-deployment.sh
ping 192.168.1.100
curl http://192.168.1.100/admin/
dig @192.168.1.100 google.com
```

**Test Monitoring Stack:**

```bash
curl http://localhost:9090/-/healthy   # Prometheus
curl http://localhost:3000/api/health # Grafana
curl http://localhost:9100/metrics    # Node Exporter
```

---

### 🌐 Access Your Services

- **Core**

  - Pi-hole: `http://192.168.1.100/admin`
    ![Screenshot: Pi-hole Admin Dashboard example]
  - Portainer: `http://192.168.1.100:9000`
    ![Screenshot: Portainer dashboard view]
  - Dozzle: `http://192.168.1.100:9999`
    ![Screenshot: Dozzle live logs interface]

- **Monitoring**
  - Grafana: `http://192.168.1.100:3000`
  - Prometheus: `http://192.168.1.100:9090`
  - Alertmanager: `http://192.168.1.100:9093`
  - Uptime Kuma: `http://192.168.1.100:3001`
    ![Screenshot: Uptime Kuma status page]

---

### ⚠️ Troubleshooting

**DNS Problems:**

```bash
docker-compose restart pihole unbound
docker-compose exec pihole pihole -t
```

**Container Startup Issues:**

```bash
docker-compose logs <service>
docker-compose restart <service>
docker-compose up -d --force-recreate <service>
```

**Network Connectivity:**

```bash
ufw status
ip addr show
ping 8.8.8.8
```

---

### 🔒 Security Hardening

```bash
sudo ufw enable
sudo ufw allow ssh http https
```

- Change default passwords (Grafana, Pi-hole).
- Enable fail2ban if configured:
  ```bash
  sudo systemctl enable fail2ban
  sudo systemctl start fail2ban
  ```

---

### 📊 Monitoring Setup

- Grafana: `http://192.168.1.100:3000` (default login: `admin/admin` → change
  password)
- Add Prometheus datasource: `http://prometheus:9090`
- Import dashboards for system metrics, Pi-hole queries, Docker stats.

---

### 🎯 Final Verification

```bash
./scripts/test-deployment.sh
htop
docker stats
curl http://localhost:9090/api/v1/query?query=up
```

Expected results:  
✅ All containers running  
✅ DNS resolution works  
✅ Monitoring accessible  
✅ Security active

---

## Directory Structure

```
├── configs/           # Configuration files
├── docker/            # Docker Compose files (core, monitoring, optional)
├── scripts/           # Setup and maintenance scripts
├── monitoring/        # Monitoring configurations (Prometheus, Grafana, Uptime Kuma)
├── backups/           # Backup storage location
└── docs/              # Documentation (security hardening, troubleshooting)
```

## Key Features & Security Notes

- All core services configurable via `.env`
- SSH key-based authentication recommended
- Firewall (`nftables`) configured to block unnecessary ports
- Containers run in isolated Docker networks
- Automated backups for critical configs

## 🌐 Why a LAN-Only Server?

This project is designed for a **LAN-only home server**, a rational choice for
common scenarios:

- **ISP & Router Limitations:** CGNAT and stock routers often block inbound
  access.
- **Hardware Constraints:** Pi 3 B+ has limited resources, so remote access
  solutions can destabilize performance.

By focusing on LAN-only, this project provides a **reliable, lightweight,
consistent solution** without external access complexity.

---

## Next Steps

1. Review full documentation (`RASPBERRY_PI_SERVER_SETUP.md`,
   `docs/security-hardening.md`, `docs/troubleshooting.md`).
2. Configure Pi-hole block/allow lists in Admin Panel.
3. Explore Grafana dashboards & Uptime Kuma alerts.
4. Enable optional services (Home Assistant, Gitea, Portainer, Dozzle, Speedtest
   Tracker).
5. Implement SSH key-based authentication for security.
6. Use `scripts/maintenance.sh` for updates/backups.
7. Explore advanced optimizations for performance and resilience.
