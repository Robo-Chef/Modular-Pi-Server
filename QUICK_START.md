# 🚀 Quick Start Guide - Raspberry Pi Home Server

## Prerequisites

- Raspberry Pi 3 B+ with 32GB+ SD card
- Raspberry Pi OS flashed with static IP configured
- SSH access to your Pi
- Basic Linux command line knowledge

## One-Command Deployment

Once your Pi is ready, run this single command:

```bash
./scripts/deploy.sh
```

This script will:

1. ✅ Check prerequisites
2. 📦 Install dependencies (if needed)
3. 🐳 Deploy all services
4. 🔍 Run health checks
5. 📋 Provide next steps

## Manual Deployment (Alternative)

If you prefer step-by-step control:

```bash
# 1. Clone repository
git clone https://github.com/Robo-Chef/Modular-Pi-Server.git ~/pihole-server
cd ~/pihole-server

# 2. Configure environment
cp env.example .env
nano .env  # Update with your values

# 3. Validate configuration
./scripts/validate-config.sh

# 4. Deploy services
./scripts/deploy.sh

# 5. Test deployment
./scripts/test-deployment.sh
```

## Essential Configuration

Update these values in your `.env` file:

```bash
# Your Pi's static IP (set during OS flashing)
PI_STATIC_IP=192.168.1.XXX

# Strong password for all services (for ease of use)
UNIVERSAL_PASSWORD=YourSecurePassword123!

# Your timezone
TZ=America/New_York

# Your Pi's hostname
PIHOLE_HOSTNAME=my-pihole.local
```

**Important**: Replace `XXX` with your actual Pi's IP address (e.g., `100`, `150`, `200`). This IP must match what you configured during OS flashing.

## Post-Deployment Verification

```bash
# Test DNS resolution
dig @192.168.1.XXX google.com

# Test ad blocking
dig @192.168.1.XXX doubleclick.net  # Should return 0.0.0.0

# Run comprehensive tests
./scripts/test-deployment.sh
```

## Access Web Interfaces

- **Pi-hole Admin**: `http://192.168.1.XXX/admin`
- **Grafana**: `http://192.168.1.XXX:3000` (if monitoring enabled)
- **Uptime Kuma**: `http://192.168.1.XXX:3001` (if monitoring enabled)

## Router Configuration

1. Access your router's admin interface
2. Set Primary DNS to your Pi's IP (`192.168.1.XXX`)
3. Save and apply settings

## Service Management

```bash
# Check status
./scripts/maintenance.sh status

# Restart services
./scripts/maintenance.sh restart

# Run backups
./scripts/maintenance.sh backup
```

## Troubleshooting

If something goes wrong:

```bash
# Check service status
./scripts/maintenance.sh status

# View logs
docker logs pihole
docker logs unbound

# Restart services
./scripts/maintenance.sh restart

# Run validation
./scripts/validate-config.sh
```

## Optional Services

Enable additional services by setting these in `.env`:

```bash
ENABLE_HOME_ASSISTANT=true   # Smart home automation
ENABLE_PORTAINER=true       # Docker management UI
ENABLE_DOZZLE=true          # Live log viewer
ENABLE_SPEEDTEST_TRACKER=true # Internet speed monitoring
```

## Performance Tips

- **Pi 3 B+**: Enable only 2-3 optional services max
- **Memory**: Monitor with `htop` or Grafana
- **Storage**: Use high-endurance SD cards
- **Network**: Use wired Ethernet for stability

## Security Notes

- Change default passwords immediately
- Enable SSH key authentication
- Keep system updated: `sudo apt update && sudo apt upgrade`
- Monitor logs regularly

---

**📚 For detailed information, see:**

- **[Deployment Guide](DEPLOYMENT_GUIDE.md)** - Comprehensive setup, troubleshooting, and configuration
- **[Raspberry Pi Setup](RASPBERRY_PI_SERVER_SETUP.md)** - OS flashing and initial configuration
- **[Troubleshooting](docs/troubleshooting.md)** - Common issues and solutions
- **[Security Hardening](docs/security-hardening.md)** - Security best practices

**🎉 Congratulations!** Your Raspberry Pi Home Server is now running successfully!