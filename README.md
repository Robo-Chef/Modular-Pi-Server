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

## ⚙️ Personalization

**Before you begin**, it is crucial to personalize your server settings. All key configurations are managed through the `.env` file.

1.  **Copy `env.example` to `.env`:**

    ```bash
    cp env.example .env
    ```

2.  **Edit `.env`:** Open the newly created `.env` file and replace placeholders (e.g., `CHANGE_ME`, `your_timezone`, `192.168.1.XXX`). At minimum set:

    - `TZ` (e.g., `Australia/Sydney`)
    - `PI_STATIC_IP` (your Pi's LAN IP)
    - `PIHOLE_PASSWORD` (admin password)
    - `GRAFANA_ADMIN_PASSWORD` (if monitoring enabled)
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
