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

For **detailed setup instructions**, including initial OS flashing, configuration, and deployment, please refer to:
➡️ [RASPBERRY_PI_SERVER_SETUP.md](RASPBERRY_PI_SERVER_SETUP.md)

Additionally, for a deeper understanding of the project's core philosophy, design choices, and constraints, consult the [LAN-Only Stack Plan](docs/LAN_ONLY_STACK_PLAN.md).

### 🚀 Quick Installation Steps

Before proceeding, ensure your Raspberry Pi OS is **already installed and configured** according to the detailed instructions in:
➡️ [RASPBERRY_PI_SERVER_SETUP.md](RASPBERRY_PI_SERVER_SETUP.md)

These steps assume you have completed the initial OS setup via Raspberry Pi Imager (hostname, username, password, timezone, static IP, SSH enabled) and are currently connected to your Pi via SSH.

1.  **Handle SSH Host Key Changes (if re-imaging Pi):**
    If you re-flashed your Raspberry Pi and receive a `REMOTE HOST IDENTIFICATION HAS CHANGED` warning, remove the old host key from your computer's `~/.ssh/known_hosts` file (on your computer):

    ```bash
    ssh-keygen -R 192.168.1.XXX # Replace with your Pi's IP
    ```

2.  **Clone the repository (on your Pi):**

    ```bash
    git clone https://github.com/Robo-Chef/Modular-Pi-Server.git ~/pihole-server
    cd ~/pihole-server
    ```

    _(Note: If you forked the repository, use your fork's URL instead of the original.)_

3.  **Configure your `.env` file (on your Pi):**

    ```bash
    cp env.example .env
    nano .env
    ```

    - **Crucial:** Open `.env` and replace all placeholder values. The `UNIVERSAL_PASSWORD` should be your primary secure password, and it will be referenced by other services. Ensure `TZ`, `PI_STATIC_IP`, `PIHOLE_HOSTNAME` match your initial Raspberry Pi OS setup. _Refer to `env.example` for detailed inline comments and examples._

    - Save and exit (`Ctrl+O`, `Enter`, `Ctrl+X` in `nano`).

4.  **Install dependencies and run setup script (on your Pi):**

    ```bash
    sudo apt update                 # Refresh package lists
    sudo apt install -y dos2unix dnsutils # Install essential utilities
    dos2unix .env scripts/*.sh      # Ensure correct line endings
    chmod +x scripts/*.sh           # Make scripts executable
    ./scripts/setup.sh              # Run the initial system setup
    ```

    - **⚠️ IMPORTANT: Docker Group Change Requires Re-login! ⚠️**
      If `setup.sh` installs Docker, it adds your user to the `docker` group. **This change only takes effect after a new SSH login session.** If prompted by the script to log out and back in:
      1.  Type `exit` to close your current SSH session.
      2.  Reconnect: `ssh your_username@192.168.1.XXX`
      3.  After logging back in, navigate back to your project: `cd ~/pihole-server`
          Then proceed to the next step.

5.  **Deploy services (on your Pi):**

    ```bash
    ./scripts/quick-deploy.sh
    ```

6.  **Configure your Router:** Set your Raspberry Pi's static IP address (e.g., `192.168.1.XXX`) as the **Primary DNS Server** in your router's settings. (Refer to `RASPBERRY_PI_SERVER_SETUP.md` for more details).

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
