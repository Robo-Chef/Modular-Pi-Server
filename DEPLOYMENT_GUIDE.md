# Raspberry Pi Home Server - Complete Deployment Guide

## Quick Start

This guide will help you deploy a complete home server on your Raspberry Pi 3 B+ with Pi-hole, Unbound, monitoring, and optional services.

### Prerequisites

- Raspberry Pi 3 B+ with 32GB+ SD card
- Ethernet connection to your router
- SSH access to the Pi
- Basic Linux command line knowledge

### Step 1: Initial Setup

1. **Flash Raspberry Pi OS**

   - Download [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
   - Select "Raspberry Pi OS (64-bit)" - Full version
   - Configure advanced options:
     - Enable SSH with key authentication
     - Set hostname: `my-pihole.local` (_Choose a hostname, to be matched with `PIHOLE_HOSTNAME` in `.env` later_)
     - Set username: `your_username` (_Choose a username, to be matched with your `UNIVERSAL_PASSWORD` in `.env` later_)
     - Set static IP: `192.168.1.XXX/24` (_Choose a static IP, to be matched with `PI_STATIC_IP` in `.env` later_)
     - Gateway: `192.168.1.1` (_Choose your network gateway, to be matched with `PI_GATEWAY` in `.env` later_)
     - DNS: `8.8.8.8,8.8.4.4` (_Choose primary and secondary DNS servers, to be matched with `PI_DNS_SERVERS` in `.env` later_)

2. **First Boot**

   ```bash
   # Connect via SSH
   ssh your_username@192.168.1.XXX

   # Update system
   sudo apt update && sudo apt upgrade -y

   # Install essential packages
   sudo apt install -y curl wget git vim htop nftables jq
   ```

### Step 2: Deploy the Home Server

1. **Clone the repository**

   ```bash
   git clone https://github.com/Robo-Chef/Modular-Pi-Server.git ~/pihole-server
   cd ~/pihole-server
   ```

   _**Note:** Replace `https://github.com/Robo-Chef/Modular-Pi-Server.git` with the URL of your forked repository, or if you haven't forked, you can use the original._

2. **Configure environment**

   ```bash
   # Copy and edit environment file
   cp env.example .env
   nano .env
   ```

   **Crucial:** Open the newly created `.env` file and replace all placeholder values. The `UNIVERSAL_PASSWORD` should be your primary secure password, and it will be referenced by other services:

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

3. **Run the setup script**

   ```bash
   # Fix line endings for scripts (install `dos2unix` first)
   sudo apt update && sudo apt install -y dos2unix
   dos2unix .env scripts/*.sh

   # Make scripts executable
   chmod +x scripts/*.sh

   # Now run the setup script
   ./scripts/setup.sh
   ```

4. **Deploy services**
   ```bash
   chmod +x scripts/quick-deploy.sh
   ./scripts/quick-deploy.sh
   ```

### Step 3: Configure Your Router

1. **Set DNS Server**

   - Access your router's admin interface (usually `192.168.0.1` or `192.168.1.1`)
   - Navigate to DNS settings
   - Set primary DNS to `192.168.1.XXX`
   - Set secondary DNS to `8.8.8.8` (fallback)

2. **Optional: Disable Router DHCP**
   - If you want Pi-hole to handle DHCP, disable it on your router
   - This allows Pi-hole to assign IP addresses and set itself as DNS

### Step 4: Verify Installation

1. **Test DNS Resolution**

   ```bash
   # Test from the Pi
   dig @192.168.1.XXX google.com
   nslookup google.com 192.168.1.XXX

   # Test from another device
   nslookup google.com 192.168.1.XXX
   ```

2. **Check Web Interfaces**

   - Pi-hole Admin: http://192.168.1.XXX/admin
   - Grafana: http://192.168.1.XXX:3000
   - Uptime Kuma: http://192.168.1.XXX:3001

3. **Verify Ad Blocking**
   - Visit a site with ads
   - Check Pi-hole admin for blocked queries
   - Test with known ad domains

## Service Management

### Starting/Stopping Services

```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# Restart specific service
docker restart pihole

# View service status
docker ps
```

### Monitoring and Maintenance

```bash
# Check system status
./scripts/maintenance.sh status

# Run full maintenance
./scripts/maintenance.sh full

# Update services
./scripts/maintenance.sh update

# Create backup
./scripts/maintenance.sh backup
```

### Logs and Debugging

```bash
# View Pi-hole logs
docker logs pihole

# View Unbound logs
docker logs unbound

# View all container logs
docker logs $(docker ps -q)

# Follow logs in real-time
docker logs -f pihole
```

## Configuration Files

### Pi-hole Configuration

- **Location**: `docker/pihole/etc-pihole/`
- **Key files**: `pihole-FTL.conf`, `custom.list`
- **Web interface**: http://192.168.1.XXX/admin

### Unbound Configuration

- **Location**: `docker/unbound/config/unbound.conf`
- **Features**: DNSSEC validation, query minimization
- **Port**: 5053 (internal)

### Monitoring Configuration

- **Prometheus**: `monitoring/prometheus/prometheus.yml`
- **Grafana**: `monitoring/grafana/provisioning/`
- **Dashboards**: `monitoring/grafana/dashboards/`

## Security Features

### Firewall

- **Tool**: nftables
- **Configuration**: `/etc/nftables.conf`
- **Status**: `sudo systemctl status nftables`

### SSH Hardening

- **Port**: 2222 (custom)
- **Authentication**: Key-based only
- **Configuration**: `/etc/ssh/sshd_config`

### Container Security

- **Isolated networks**: Each service in its own network
- **Resource limits**: CPU and memory constraints
- **Health checks**: Automatic restart on failure

## Backup and Recovery

### Automated Backups

- **Schedule**: Daily at 2 AM
- **Location**: `backups/daily/`
- **Retention**: 30 days (configurable)

### Manual Backup

```bash
# Create backup
./scripts/maintenance.sh backup

# Restore from backup
cp -r backups/daily/YYYYMMDD_HHMMSS/* docker/pihole/etc-pihole/
docker restart pihole
```

### Full System Backup

```bash
# Create system image
sudo dd if=/dev/mmcblk0 | gzip > backups/pi3b-full-$(date +%Y%m%d).img.gz

# Restore system image
# gunzip -c backup.img.gz | sudo dd of=/dev/mmcblk0
```

## Troubleshooting

### Common Issues

1. **DNS not working**

   - Check Pi-hole status: `docker logs pihole`
   - Verify router DNS settings
   - Test with: `dig @192.168.1.XXX google.com`

2. **Web interface not accessible**

   - Check firewall: `sudo nft list ruleset`
   - Verify port binding: `netstat -tlnp | grep :80`
   - Restart service: `docker restart pihole`

3. **High memory usage**

   - Check resource usage: `docker stats`
   - Restart services: `docker compose restart`
   - Check logs for memory leaks

4. **Slow performance**
   - Check disk space: `df -h`
   - Monitor CPU usage: `htop`
   - Review container resource limits

### Getting Help

1. **Check logs first**: `docker logs <container_name>`
2. **Verify network**: `ping 8.8.8.8`
3. **Test DNS**: `dig @192.168.1.XXX google.com`
4. **Review documentation**: `docs/troubleshooting.md`

## Optional Services

### Home Assistant

```bash
# Enable in docker-compose.yml
# Uncomment homeassistant service
docker compose up -d homeassistant
```

### Gitea (Git Server)

```bash
# Enable in docker-compose.yml
# Uncomment gitea service
docker compose up -d gitea
```

### Portainer (Docker Management)

```bash
# Add to docker-compose.yml
# Deploy with: docker compose up -d portainer
```

## Performance Optimization

### SD Card Optimization

```bash
# Add to /etc/fstab
/dev/mmcblk0p2 / ext4 defaults,noatime,nodiratime 0 1
```

### Memory Optimization

```bash
# Add to /etc/sysctl.d/99-rpi.conf
vm.swappiness=1
vm.dirty_ratio=15
vm.dirty_background_ratio=5
```

### Docker Optimization

```bash
# Limit log size in /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

## Maintenance Schedule

### Daily

- Automated backups
- Log rotation
- Health checks

### Weekly

- System updates
- Container updates
- Security scans

### Monthly

- Full system backup
- Performance review
- Security audit

## Support and Resources

- **Documentation**: `docs/` directory
- **Troubleshooting**: `docs/troubleshooting.md`
- **Security**: `docs/security-hardening.md`
- **Scripts**: `scripts/` directory

## Next Steps

1. **Configure Pi-hole**: Add custom blocklists, whitelist domains
2. **Set up monitoring**: Configure Grafana dashboards
3. **Enable optional services**: Home Assistant, Gitea, etc.
4. **Implement security**: Review security hardening guide
5. **Regular maintenance**: Set up monitoring alerts

---

**Congratulations!** You now have a fully functional home server with DNS filtering, monitoring, and optional services. The system is designed to be self-healing with automated backups and health checks.
