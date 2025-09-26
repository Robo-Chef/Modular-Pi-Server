# 🚀 Quick Start Guide - Raspberry Pi Home Server

## **Pre-Deployment Checklist**

Before you start, ensure you have:

- [ ] Raspberry Pi 3 B+ with 32GB+ SD card
- [ ] Ethernet cable connected to your router
- [ ] Raspberry Pi OS flashed with static IP configured
- [ ] SSH access to your Pi

## **One-Command Deployment**

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

## **Manual Deployment (Alternative)**

If you prefer step-by-step control:

```bash
# 1. Configure environment
cp env.example .env
nano .env  # Update with your values

# 2. Validate configuration
./scripts/validate-config.sh

# 3. Run setup (if fresh system)
./scripts/setup.sh

# 4. Deploy services
./scripts/quick-deploy.sh

# 5. Test deployment
./scripts/test-deployment.sh
```

## **Essential Configuration**

Update these values in your `.env` file:

```bash
# Your Pi's static IP (set during OS flashing)
PI_STATIC_IP=192.168.1.100

# Strong password for all services (for ease of use)
UNIVERSAL_PASSWORD=YourSecurePassword123!

# Your timezone
TZ=America/New_York

# Your Pi's hostname
PIHOLE_HOSTNAME=my-pihole.local

# Network Configuration (use defaults unless you have conflicts)
PIHOLE_NETWORK=172.20.0.0/24      # Pi-hole/Unbound network
PIHOLE_NET_IP_PIHOLE=172.20.0.3    # Pi-hole container IP
PIHOLE_NET_IP_UNBOUND=172.20.0.2   # Unbound container IP
```

**Important**: The deployment script automatically configures Pi-hole to accept
queries from your LAN network. No manual network configuration is needed.

## **Post-Deployment Steps**

1. **Configure Router DNS**:

   - Set Primary DNS to your Pi's IP (`192.168.1.100`)
   - Optional: Disable router DHCP, enable Pi-hole DHCP

2. **Test Core Functionality**:

   ```bash
   # Test DNS resolution
   dig @192.168.1.100 google.com

   # Test ad blocking
   dig @192.168.1.100 doubleclick.net  # Should return 0.0.0.0
   ```

3. **Access Web Interfaces**:
   - **Pi-hole Admin**: `http://192.168.1.100/admin` (password from .env)
   - **Grafana**: `http://192.168.1.100:3000` (admin/raspberry -
     auto-configured!)
   - **Uptime Kuma**: `http://192.168.1.100:3001` (admin/raspberry -
     auto-configured!)
   - **Prometheus**: `http://192.168.1.100:9090` (advanced users)
   - **Portainer**: `http://192.168.1.100:9000` (Docker management)

## **Troubleshooting**

If something goes wrong:

```bash
# Check service status
./scripts/maintenance.sh status

# View logs
docker logs pihole
docker logs unbound
docker logs grafana        # If monitoring enabled
docker logs prometheus     # If monitoring enabled

# Check router resilience status
./scripts/check-router-status.sh

# Restart services
./scripts/maintenance.sh update

# Run validation
./scripts/validate-config.sh
```

## **Service Management**

```bash
# Check status
./scripts/maintenance.sh status

# Update containers
./scripts/maintenance.sh update

# Full maintenance (OS + containers)
./scripts/maintenance.sh full

# Run backups
./scripts/maintenance.sh backup
```

## **Optional Services**

Enable additional services by setting these in `.env`:

```bash
ENABLE_HOME_ASSISTANT=true   # Smart home automation
ENABLE_GITEA=true           # Self-hosted Git
ENABLE_PORTAINER=true       # Docker management UI
ENABLE_DOZZLE=true          # Live log viewer
ENABLE_SPEEDTEST_TRACKER=true # Internet speed monitoring
```

## **Performance Tips**

- **Pi 3 B+**: Enable only 2-3 optional services max
- **Memory**: Monitor with `htop` or Grafana
- **Storage**: Use high-endurance SD cards
- **Network**: Use wired Ethernet for stability

## **Security Notes**

- Change default passwords immediately
- Enable SSH key authentication
- Keep system updated: `sudo apt update && sudo apt upgrade`
- Monitor logs regularly

---

**Need Help?** Check the full documentation:

- [RASPBERRY_PI_SERVER_SETUP.md](RASPBERRY_PI_SERVER_SETUP.md) - Detailed setup
  guide
- [docs/troubleshooting.md](docs/troubleshooting.md) - Common issues
- [docs/security-hardening.md](docs/security-hardening.md) - Security guide
