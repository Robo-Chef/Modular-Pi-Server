# Router Reboot Resilience for Raspberry Pi Home Server

This guide outlines steps to make your Raspberry Pi Home Server resilient to router reboots and temporary network outages. Router reboots can disrupt DHCP leases, DNS resolution, and Docker networking, leading to services becoming unresponsive.

## 1. Systemd Service Resilience (Auto-Restart)

Ensure your `pihole-server.service` (and other critical services) are configured to automatically restart on failure.

**Action:** Edit `/etc/systemd/system/pihole-server.service` on your Pi.

```bash
sudo nano /etc/systemd/system/pihole-server.service
```

**Add/Modify these lines in the `[Service]` section:**

```ini
[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/${USER}/pihole-server
ExecStart=/usr/bin/docker compose -f docker/docker-compose.core.yml up -d
ExecStop=/usr/bin/docker compose -f docker/docker-compose.core.yml down
TimeoutStartSec=0
Restart=always      # <--- ADD THIS LINE
RestartSec=30       # <--- ADD THIS LINE (wait 30 seconds before restarting)
```

**Reload systemd to apply changes:**

```bash
sudo systemctl daemon-reload
sudo systemctl enable pihole-server.service
sudo systemctl restart pihole-server.service
```

**Explanation:**
- `Restart=always`: Ensures the service is always restarted if it stops for any reason.
- `RestartSec=30`: Waits 30 seconds before attempting a restart, giving the network time to stabilize after a reboot.

## 2. Network Health Monitoring Script (Automated Recovery)

A script to periodically check network health and restart services if issues are detected.

**Action:** The project includes `scripts/network-health.sh` for this purpose.

**To enable automatic health monitoring:**

```bash
# Make the script executable
chmod +x scripts/network-health.sh

# Test the script manually
./scripts/network-health.sh
```

**Content of `scripts/network-health.sh`:**

The script performs these checks:
1. **External Connectivity**: Pings 8.8.8.8 to verify internet access
2. **DNS Resolution**: Tests Pi-hole DNS functionality
3. **Automatic Recovery**: Restarts networking services or reboots if issues persist

## 3. Automated Recovery Cron Job

Schedule the `network-health.sh` script to run periodically.

**Action:** Add a cron job.

```bash
crontab -e
```

**Add this line to run every 5 minutes:**

```cron
*/5 * * * * /home/pi/pihole-server/scripts/network-health.sh >> /home/pi/pihole-server/logs/health-check.log 2>&1
```

**Create the logs directory first:**

```bash
mkdir -p ~/pihole-server/logs
```

**Explanation:**
- This runs the script every 5 minutes.
- Output is logged to `~/pihole-server/logs/health-check.log`.

## 4. DHCP Client Hardening

Make the DHCP client more resilient to router reboots.

**Action:** Edit `/etc/dhcpcd.conf`.

```bash
sudo nano /etc/dhcpcd.conf
```

**Add these lines at the end:**

```ini
# Custom settings for network resilience
timeout 60  # Wait up to 60 seconds for a DHCP lease
retry 3     # Retry 3 times before giving up
```

**Restart `dhcpcd` service:**

```bash
sudo systemctl restart dhcpcd.service
```

## 5. Emergency Recovery Commands

If all else fails, these commands can help.

**Check Docker services:**

```bash
docker ps -a
docker logs pihole
docker logs unbound
```

**Restart Docker daemon:**

```bash
sudo systemctl restart docker
```

**Restart Pi-hole server stack:**

```bash
sudo systemctl restart pihole-server.service
```

**Full system reboot (last resort):**

```bash
sudo reboot
```

## 6. Monitoring Integration

If you have the monitoring stack deployed, you can set up alerts for network issues:

1. **Grafana Alerts**: Configure alerts for DNS query failures or network connectivity issues
2. **Uptime Kuma**: Monitor Pi-hole web interface and external connectivity
3. **Prometheus Metrics**: Track network and DNS resolution metrics

## Implementation Summary

By implementing these steps, your Raspberry Pi Home Server will be significantly more robust against router reboots and temporary network disruptions:

✅ **Auto-restart services** on failure  
✅ **Automated health monitoring** every 5 minutes  
✅ **DHCP resilience** with longer timeouts  
✅ **Emergency recovery** commands ready  
✅ **Monitoring integration** for proactive alerts  

Your Pi will now automatically recover from most network-related issues without manual intervention!