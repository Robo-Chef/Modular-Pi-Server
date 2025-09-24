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
