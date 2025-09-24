# Raspberry Pi Home Server - Complete Deployment Guide

## Quick Start

This guide will help you deploy a complete home server on your Raspberry Pi 3 B+ with Pi-hole, Unbound, monitoring, and optional services.

### Prerequisites

- Raspberry Pi 3 B+ with 32GB+ SD card
- Ethernet connection to your router
- SSH access to the Pi (after initial OS setup)
- Basic Linux command line knowledge

### Step 1: Initial Raspberry Pi OS Setup (Refer to `RASPBERRY_PI_SERVER_SETUP.md` for details)

This project assumes you have already:

1.  Flashed Raspberry Pi OS (64-bit Full recommended) onto your SD card using the [Raspberry Pi Imager](https://www.raspberrypi.com/software/).
2.  Configured advanced options during flashing:

    - Set hostname (e.g., `my-pihole.local`)
    - Set username (e.g., `your_username`) and password
    - Set static IP (e.g., `192.168.1.XXX/24`), Gateway, and DNS servers.
    - Set Time Zone (e.g., `Australia/Sydney`)
    - Enabled SSH with password authentication.

3.  Connected to your Pi via SSH from your computer:
    ```bash
    # If re-imaging your Pi and seeing a host key warning:
    # ssh-keygen -R 192.168.1.XXX # Replace with your Pi's IP on your computer
    ssh your_username@192.168.1.XXX # Connect to your Pi
    ```

### Step 2: Deploy the Home Server (on your Raspberry Pi)

1.  **Clone the repository:**

    ```bash
    git clone https://github.com/Robo-Chef/Modular-Pi-Server.git ~/pihole-server
    cd ~/pihole-server
    ```

    _(Note: If you forked the repository, use your fork's URL instead of the original.)_

2.  **Configure your `.env` file:**

    ```bash
    cp env.example .env
    nano .env
    ```

    - **Crucial:** Open the newly created `.env` file and replace all placeholder values. The `UNIVERSAL_PASSWORD` should be your primary secure password, and it will be referenced by other services. Ensure `TZ`, `PI_STATIC_IP`, `PIHOLE_HOSTNAME` match your initial Raspberry Pi OS setup. _Refer to `env.example` for detailed inline comments and examples._

    - Save and exit (`Ctrl+O`, `Enter`, `Ctrl+X` in `nano`).

3.  **Prepare and run setup scripts:**

    ```bash
    sudo apt update && sudo apt install -y dos2unix dnsutils
    dos2unix .env scripts/*.sh
    chmod +x scripts/*.sh
    ./scripts/setup.sh
    ```

    - **Important:** If `setup.sh` installs Docker, it will prompt you to **log out and log back in** for group changes to take effect. If this happens, log out of SSH, then reconnect. After reconnecting, `cd ~/pihole-server` again before running the next script.

4.  **Deploy services:**

    ```bash
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
