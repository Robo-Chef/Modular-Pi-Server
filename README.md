# Raspberry Pi Home Server

A comprehensive, modular home server setup using Raspberry Pi 3 B+ with Pi-hole, Unbound, monitoring, and optional services. Designed for easy deployment and personalization.

## Architecture

- **Base OS**: Raspberry Pi OS (64-bit)
- **Static IP**: Configured via `.env` (e.g., `192.168.1.XXX`)
- **Core Services**: Pi-hole + Unbound for DNS and ad blocking
- **Monitoring**: Prometheus, Grafana, Uptime Kuma
- **Optional**: Home Assistant, Gitea
- **Security**: `nftables` firewall, SSH hardening, container isolation
- **Resilience**: Configured for graceful recovery after network interruptions (e.g., router reboots)

## Getting Started

For detailed setup instructions, including initial OS flashing, configuration, and deployment, please refer to: [RASPBERRY_PI_SERVER_SETUP.md](RASPBERRY_PI_SERVER_SETUP.md)

## ⚙️ Personalization

**Before you begin**, it is crucial to personalize your server settings. All key configurations are managed through the `.env` file.

1.  **Copy `env.example` to `.env`:**

    ```bash
    cp env.example .env
    ```

2.  **Edit `.env`:** Open the newly created `.env` file and replace all placeholder values (e.g., `CHANGE_ME`, `192.168.1.XXX`, `your_username`, `yourdomain.local`) with your desired, secure, and unique settings. This includes:

    - Passwords for various services
    - Your desired static IP address for the Raspberry Pi
    - Hostnames and email addresses
    - Timezone and other network settings

    _Ensure you save the changes to `.env` after editing._

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
