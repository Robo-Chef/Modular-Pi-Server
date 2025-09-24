# Raspberry Pi Home Server

A comprehensive, modular **LAN-only** home server setup using Raspberry Pi 3 B+ with Pi-hole, Unbound, monitoring, and optional services. Designed for easy deployment and personalization.

## Architecture

- **Base OS**: Raspberry Pi OS (64-bit)
- **Static IP**: Configured via `.env` (e.g., `192.168.1.XXX`)
- **Core Services**: Pi-hole + Unbound for DNS and ad blocking ![Screenshot: Pi-hole Admin Dashboard example]
- **Monitoring**: Prometheus, Grafana, Uptime Kuma
- **Optional**: Home Assistant, Gitea
- **Security**: `nftables` firewall, SSH hardening, container isolation
- **Resilience**: Configured for graceful recovery after network interruptions (e.g., router reboots)

## Getting Started

For detailed setup instructions, including initial OS flashing, configuration, and deployment, please refer to: [RASPBERRY_PI_SERVER_SETUP.md](RASPBERRY_PI_SERVER_SETUP.md)
Additionally, for a deeper understanding of the project's core philosophy, design choices, and constraints, consult the [LAN-Only Stack Plan](docs/LAN_ONLY_STACK_PLAN.md).

### 🚀 Quick Installation Steps

These steps assume you have already flashed Raspberry Pi OS and connected to your Pi via SSH.

1.  **Handle SSH Host Key Changes (if re-imaging Pi):**
    If you re-flashed your Raspberry Pi and receive a `REMOTE HOST IDENTIFICATION HAS CHANGED` warning when trying to SSH, remove the old host key from your computer's `known_hosts` file:

    ```bash
    ssh-keygen -R 192.168.1.XXX # Replace with your Pi's IP
    ```

2.  **Clone the repository:**

    ```bash
    git clone https://github.com/Robo-Chef/Modular-Pi-Server.git ~/pihole-server
    cd ~/pihole-server
    ```

    _(Note: If you forked the repository, use your fork's URL instead of the original.)_

3.  **Configure your `.env` file:**

    ```bash
    cp env.example .env
    nano .env
    ```

    - **Crucial:** Open `.env` and replace all placeholder values. The `UNIVERSAL_PASSWORD` should be your primary secure password, and it will be referenced by other services:

      ```ini
      # Universal password for all services
      UNIVERSAL_PASSWORD=YourStrongAndSecurePassword

      # Pi-hole specific (references UNIVERSAL_PASSWORD)
      PIHOLE_PASSWORD=${UNIVERSAL_PASSWORD}
      PIHOLE_ADMIN_EMAIL=admin@yourdomain.local
      PIHOLE_HOSTNAME=my-pihole.local

      # Timezone (e.g., Australia/Sydney, America/New_York, Europe/London)
      TZ=Australia/Sydney # Example: America/New_York

      # Network configuration (match your Pi's OS setup)
      PI_STATIC_IP=192.168.1.185 # Example: Your Pi's LAN IP
      PI_GATEWAY=192.168.1.1
      PI_DNS_SERVERS=8.8.8.8,8.8.4.4

      # Monitoring (references UNIVERSAL_PASSWORD)
      GRAFANA_ADMIN_PASSWORD=${UNIVERSAL_PASSWORD}

      # ... other variables ...
      ```

    - Ensure values like `TZ`, `PI_STATIC_IP`, `PIHOLE_HOSTNAME` match your initial Raspberry Pi OS setup.
    - Save and exit (`Ctrl+O`, `Enter`, `Ctrl+X` in `nano`).

4.  **Prepare and run setup scripts:**
    ```bash
    sudo apt update && sudo apt install -y dos2unix
    dos2unix .env scripts/*.sh
    chmod +x scripts/*.sh
    ./scripts/setup.sh
    ./scripts/quick-deploy.sh
    ```

## ⚙️ Personalization

**Before you begin**, it is crucial to personalize your server settings. All key configurations are managed through the `.env` file.

1.  **Copy `env.example` to `.env`:**

    ```bash
    cp env.example .env
    ```

2.  **Edit `.env`:** Open the newly created `.env` file and replace placeholders (e.g., `CHANGE_ME`, `your_timezone`, `192.168.1.XXX`). At minimum set:

    - `UNIVERSAL_PASSWORD` (your main secure password)
    - `TZ` (e.g., `Australia/Sydney`)
    - `PI_STATIC_IP` (your Pi's LAN IP)
    - `PIHOLE_PASSWORD` (will reference `UNIVERSAL_PASSWORD`)
    - `GRAFANA_ADMIN_PASSWORD` (will reference `UNIVERSAL_PASSWORD` if monitoring enabled)
    - Optional: Watchtower email vars if you want update notifications

    Save the file when done.

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

- All core services are easily configurable via the central `.env` file.
- SSH key-based authentication is highly recommended (after initial password setup).
- Firewall (`nftables`) is configured to block unnecessary incoming ports.
- Containers run in isolated Docker networks.
- Automated backups for critical configurations are set up.

## 🌐 Why a LAN-Only Server?

This project is designed for a **LAN-only home server** setup, a rational choice for several common scenarios:

- **ISP & Router Limitations:** Many Internet Service Providers (ISPs) use technologies like Carrier-Grade NAT (CGNAT), which prevent direct inbound connections from the internet to devices on your home network. Stock router firmware often has limited capabilities for advanced DNS redirection, NAT loopback, or complex firewall rules.
- **Hardware Constraints:** Raspberry Pi devices, especially older models like the Pi 3 B+ with 1GB RAM, have limited resources. Running demanding services (e.g., VPN servers, extensive remote access solutions) simultaneously with core functions like Pi-hole and Unbound can lead to performance issues and instability.

By focusing on a LAN-only approach, this project offers a **reliable, consistent, and lightweight solution** for enhancing your home network's privacy and control, without battling common external access limitations or overstraining the Pi's capabilities. Remote access solutions are often more complex and prone to issues in such environments.

---

## Next Steps
