# Raspberry Pi Home Server

A comprehensive, modular **LAN-only** home server setup using Raspberry Pi 3 B+
with Pi-hole, Unbound, monitoring, and optional services. Designed for easy
deployment and personalization.

## ✨ Key Features

- **🔧 Zero-Configuration Deployment**: Grafana auto-provisioned with Prometheus
  data source and Pi-hole dashboard
- **🎯 Auto-Setup**: Uptime Kuma automatically configured with admin account
- **🛡️ Router Reboot Resilience**: Automatic detection and recovery from router
  reboots with monitoring flags and status tracking
- **🚀 ARM64 Optimized**: All Docker images tested and working on Raspberry Pi
- **⚡ One-Command Deploy**: Single script handles everything from setup to
  validation
- **📊 Comprehensive Monitoring**: Prometheus, Grafana, Uptime Kuma, Node
  Exporter
- **🔒 Security Hardened**: nftables firewall, SSH hardening, container
  isolation

## Architecture

- **Decision Records**: Explore key architectural decisions in
  [docs/adr/](docs/adr/)
- **Base OS**: Raspberry Pi OS (64-bit)
- **Static IP**: Configured via `.env` (e.g., `192.168.1.XXX`)
- **Core Services**: Pi-hole + Unbound for DNS and ad blocking
- **Monitoring**: Prometheus, Grafana, Uptime Kuma (all auto-configured)
- **Optional**: Home Assistant, Gitea, Portainer, Speedtest Tracker
- **Security**: `nftables` firewall, SSH hardening, container isolation
- **Resilience**: Automated router reboot detection and recovery with monitoring
  flags

## Getting Started

### 🚀 Quick Start

For a streamlined deployment experience, see:  
➡️ [QUICK_START.md](QUICK_START.md)

### 📖 Detailed Setup Instructions

For comprehensive setup instructions, including initial OS flashing,
configuration, and deployment, please refer to:  
➡️ [RASPBERRY_PI_SERVER_SETUP.md](RASPBERRY_PI_SERVER_SETUP.md)

### 📋 Deployment Guide

For detailed deployment steps, troubleshooting, and configuration reference:  
➡️ [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)

Additionally, for a deeper understanding of the project's core philosophy,
design choices, and constraints, consult the
[LAN-Only Stack Plan](docs/LAN_ONLY_STACK_PLAN.md).

---

## 🌐 Access Your Services

- **Core**

  - Pi-hole: `http://192.168.1.XXX/admin`
  - Portainer: `http://192.168.1.XXX:9000`
  - Dozzle: `http://192.168.1.XXX:9999`

- **Monitoring**
  - Grafana: `http://192.168.1.XXX:3000`
  - Prometheus: `http://192.168.1.XXX:9090`
  - Uptime Kuma: `http://192.168.1.XXX:3001`

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
   `DEPLOYMENT_GUIDE.md`, `docs/security-hardening.md`,
   `docs/troubleshooting.md`).
2. Configure Pi-hole block/allow lists in Admin Panel.
3. Explore Grafana dashboards & Uptime Kuma alerts.
4. Enable optional services (Home Assistant, Gitea, Portainer, Dozzle, Speedtest
   Tracker).
5. Implement SSH key-based authentication for security.
6. Use `scripts/maintenance.sh` for updates/backups.
7. Explore advanced optimizations for performance and resilience.
