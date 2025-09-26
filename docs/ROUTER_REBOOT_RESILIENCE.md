# Router Reboot Resilience Guide

This guide addresses the common issue where the Pi becomes unresponsive after
router reboots, typically occurring during overnight maintenance windows.

## Problem Description

**Symptoms:**

- Pi becomes unreachable via SSH after router reboots
- DNS queries timeout
- Docker containers may be running but not responding
- Network connectivity appears broken

**Root Causes:**

- DHCP lease renewal failures during router reboot
- Docker network state confusion
- DNS resolution failures
- Service dependencies not properly configured

## Quick Fixes

### 1. Improve Systemd Service Resilience

**Current service location:** `/etc/systemd/system/pihole-server.service`

**Add these settings to the `[Service]` section:**

```bash
sudo nano /etc/systemd/system/pihole-server.service

# Add these lines to [Service] section:
Restart=always
RestartSec=30
StartLimitBurst=5
StartLimitIntervalSec=300
```

**Reload and test:**

```bash
sudo systemctl daemon-reload
sudo systemctl restart pihole-server.service
sudo systemctl status pihole-server.service
```

### 2. Docker Container Auto-Recovery

**Ensure containers restart automatically:**

```bash
# Check current restart policies
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.RestartPolicy}}"

# All containers should show "unless-stopped"
# This is already configured in our docker-compose.yml
```

### 3. Network Health Monitoring

**Add network health check script:**

Create `/home/pi/pihole-server/scripts/network-health.sh`:

```bash
#!/bin/bash

# Network health monitoring and recovery script
source "$(dirname "$0")/utils.sh"

check_network_health() {
    local retries=3
    local delay=10

    for i in $(seq 1 $retries); do
        if ping -c 3 -W 5 8.8.8.8 >/dev/null 2>&1; then
            log "Network connectivity: OK"
            return 0
        fi
        warn "Network check failed (attempt $i/$retries)"
        sleep $delay
    done

    error "Network connectivity: FAILED after $retries attempts"
    return 1
}

check_dns_resolution() {
    local test_domains=("google.com" "cloudflare.com" "github.com")

    for domain in "${test_domains[@]}"; do
        if dig @127.0.0.1 "$domain" +short +timeout=5 >/dev/null 2>&1; then
            log "DNS resolution for $domain: OK"
        else
            warn "DNS resolution for $domain: FAILED"
            return 1
        fi
    done

    log "DNS resolution: All tests passed"
    return 0
}

restart_services_if_needed() {
    if ! check_network_health || ! check_dns_resolution; then
        log "Network issues detected, restarting services..."

        # Restart Docker daemon
        sudo systemctl restart docker
        sleep 10

        # Restart Pi-hole stack
        cd ~/pihole-server
        docker compose -f docker/docker-compose.core.yml restart

        # Wait and recheck
        sleep 30
        if check_network_health && check_dns_resolution; then
            log "Services restarted successfully"
        else
            error "Service restart failed, manual intervention required"
        fi
    fi
}

# Main execution
log "Starting network health check..."
restart_services_if_needed
log "Network health check completed"
```

**Make it executable:**

```bash
chmod +x ~/pihole-server/scripts/network-health.sh
```

### 4. Automated Recovery Cron Job

**Add cron job for periodic health checks:**

```bash
# Edit crontab
crontab -e

# Add this line (check every 5 minutes):
*/5 * * * * /home/pi/pihole-server/scripts/network-health.sh >> /home/pi/pihole-server/logs/health-check.log 2>&1
```

### 5. DHCP Client Configuration

**Improve DHCP lease resilience:**

```bash
sudo nano /etc/dhcpcd.conf

# Add or modify these settings:
timeout 60
retry 3
reboot 10
noipv6rs
noipv6
```

**Restart DHCP client:**

```bash
sudo systemctl restart dhcpcd
```

## Emergency Recovery Commands

### Manual Service Restart

```bash
# Full stack restart
cd ~/pihole-server
docker compose -f docker/docker-compose.core.yml down
docker compose -f docker/docker-compose.core.yml up -d

# Check status
docker ps
docker logs pihole --tail 10
docker logs unbound --tail 10
```

### Network Reset

```bash
# Reset network interfaces
sudo systemctl restart networking
sudo systemctl restart dhcpcd

# Restart Docker networking
sudo systemctl restart docker
```

### Complete System Recovery

```bash
# Nuclear option - full system restart
sudo reboot

# After reboot, check services
sudo systemctl status pihole-server.service
docker ps
```

## Monitoring and Logging

### Check Service Health

```bash
# System services
sudo systemctl status pihole-server.service
sudo systemctl status docker
sudo systemctl status dhcpcd

# Container health
docker ps
docker stats --no-stream

# Network connectivity
ping -c 3 8.8.8.8
dig @192.168.0.100 google.com +short
```

### Log Locations

- **System logs:** `journalctl -u pihole-server.service -f`
- **Docker logs:** `docker logs pihole` and `docker logs unbound`
- **Health check logs:** `~/pihole-server/logs/health-check.log`
- **Network logs:** `journalctl -u dhcpcd -f`

## Prevention Strategies

### 1. Static IP Configuration

Consider configuring a static IP instead of DHCP to avoid lease renewal issues.

### 2. Router Configuration

- **DHCP lease time:** Set to 24+ hours
- **DNS settings:** Configure router to use Pi as primary DNS
- **Port forwarding:** Ensure SSH port is consistently forwarded

### 3. Backup DNS

Configure a fallback DNS server in case Pi-hole becomes unreachable.

## Testing Recovery

**Simulate router reboot:**

```bash
# Test network recovery without actual router reboot
sudo systemctl stop dhcpcd
sleep 30
sudo systemctl start dhcpcd

# Check if services recover automatically
~/pihole-server/scripts/network-health.sh
```

## Troubleshooting

### Common Issues

1. **SSH timeout after router reboot**

   - Check DHCP lease: `ip addr show`
   - Verify router DHCP table
   - Try connecting via direct ethernet

2. **DNS queries timeout**

   - Check container status: `docker ps`
   - Restart containers: `docker compose restart`
   - Check logs: `docker logs pihole`

3. **Services won't start**
   - Check systemd status: `sudo systemctl status pihole-server.service`
   - Check Docker daemon: `sudo systemctl status docker`
   - Review logs: `journalctl -u pihole-server.service -n 50`

### Emergency Contacts

- **Router admin:** `http://192.168.0.1` (or your router's IP)
- **Pi direct access:** Connect monitor/keyboard if SSH fails
- **Network reset:** Unplug/replug ethernet cable

## Future Improvements

- [ ] Implement proper monitoring dashboard
- [ ] Add email/SMS alerts for service failures
- [ ] Create automated backup system
- [ ] Set up redundant Pi-hole instance
- [ ] Implement health check API endpoint

---

**Last Updated:** $(date) **Tested On:** Raspberry Pi 4, Debian 12 (Bookworm)
