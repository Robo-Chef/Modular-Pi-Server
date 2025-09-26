# Router Reboot Resilience System

This document describes the comprehensive router reboot detection and automatic
recovery system implemented in the Raspberry Pi Home Server.

## Overview

The system automatically detects when your router reboots and performs
comprehensive network recovery without requiring manual intervention or Pi
reboot.

## How It Works

### 1. Monitoring Schedule

- **`router-monitor.sh`**: Runs every 2 minutes via cron (lightweight gateway
  ping)
- **`network-health.sh`**: Triggered only when router issues are detected
  (comprehensive recovery)

### 2. Detection Process

1. **Gateway Monitoring**: Pings your router every 2 minutes
2. **Failure Detection**: If 3 consecutive pings fail, router reboot is assumed
3. **Flag Creation**: Creates monitoring flags for external systems to track
4. **Recovery Trigger**: Launches comprehensive network recovery process

### 3. Recovery Process

When router reboot is detected, the system automatically:

1. **DHCP Lease Renewal**: Releases and requests new IP lease
2. **Network Service Restart**: Restarts networking and dhcpcd services
3. **Docker Daemon Restart**: Refreshes Docker networks
4. **Container Restart**: Restarts Pi-hole and monitoring services
5. **Permission Reset**: Reconfigures Pi-hole network permissions
6. **Status Updates**: Updates monitoring flags and status files

## Monitoring & Status

### Status Files

- **Status JSON**: `/var/lib/pihole-server/monitoring/network-status.json`
- **Flags Directory**: `/var/lib/pihole-server/monitoring/flags/`
- **Logs**: `/var/log/router-monitor.log`

### Monitoring Flags

During router reboot recovery, these flags are created:

- 🚩 **`router_down`**: Router unreachable - recovery in progress
- 🚩 **`recovery_active`**: Network recovery process started
- 🚩 **`network_health_running`**: Comprehensive recovery in progress

Flags are automatically removed when recovery completes successfully.

### Status Checking

**View Current Status:**

```bash
./scripts/check-router-status.sh
```

**Watch Real-Time:**

```bash
./scripts/check-router-status.sh --watch
```

**View Logs:**

```bash
./scripts/check-router-status.sh --logs
```

### Example Status Output

```json
{
  "last_check": "2025-09-27T02:15:30+10:00",
  "router_status": "up",
  "pi_status": "healthy",
  "services_status": "7 containers running",
  "last_recovery": "2025-09-27T02:10:15+10:00",
  "recovery_count": 3,
  "uptime_seconds": 86400,
  "message": "All systems normal"
}
```

## Integration Options

### Uptime Kuma Integration

Monitor the status file or flag files:

```bash
# Monitor status file exists and is recent
test -f /var/lib/pihole-server/monitoring/network-status.json

# Check for active recovery flags
test ! -f /var/lib/pihole-server/monitoring/flags/router_down
```

### Grafana Dashboard

Create alerts based on:

- Recovery count increases
- Router down flags exist
- Status changes to "recovering"

### External Monitoring

Parse the JSON status file:

```bash
# Get router status
jq -r '.router_status' /var/lib/pihole-server/monitoring/network-status.json

# Get recovery count
jq -r '.recovery_count' /var/lib/pihole-server/monitoring/network-status.json

# Check if recovery is active
ls /var/lib/pihole-server/monitoring/flags/ 2>/dev/null | wc -l
```

## Configuration

### Environment Variables

The system uses these variables from your `.env` file:

```bash
PI_GATEWAY=192.168.1.1        # Your router's IP address
PI_STATIC_IP=192.168.1.XXX    # Your Pi's static IP (replace XXX)
ENABLE_MONITORING=true        # Enable monitoring service restarts
```

### Cron Schedule

Router monitoring is automatically configured during setup:

```bash
# Check every 2 minutes
*/2 * * * * /home/pi/pihole-server/scripts/router-monitor.sh >/dev/null 2>&1
```

### Systemd Service Resilience

The `pihole-server.service` is configured for automatic restart:

```ini
[Service]
Restart=always
RestartSec=30
StartLimitBurst=5
StartLimitIntervalSec=300
```

## Troubleshooting

### Manual Recovery

If automatic recovery fails, you can manually trigger it:

```bash
# Run comprehensive network health check
./scripts/network-health.sh

# Check router connectivity
ping -c 3 192.168.1.1

# Restart all services
sudo systemctl restart pihole-server.service
```

### Log Analysis

Check what happened during recovery:

```bash
# View router monitor logs
tail -50 /var/log/router-monitor.log

# Check systemd service logs
sudo journalctl -u pihole-server.service --since "1 hour ago"

# View Docker container logs
docker logs pihole --since 1h
```

### Common Issues

**Recovery Takes Too Long:**

- Router may take longer than 5 minutes to fully restart
- Increase `MAX_WAIT` in `network-health.sh` if needed

**False Positives:**

- Temporary network glitches may trigger recovery
- Check router stability and network cables

**Services Don't Restart:**

- Check Docker daemon status: `sudo systemctl status docker`
- Verify disk space: `df -h`
- Check container health: `docker ps`

## Benefits

✅ **Zero Manual Intervention**: Pi automatically recovers from router reboots  
✅ **Full Visibility**: Monitor recovery process via flags and status files  
✅ **External Integration**: Status available for Grafana, Uptime Kuma, etc.  
✅ **Comprehensive Recovery**: DHCP, networking, Docker, and services all
restarted  
✅ **Failure Protection**: Automatic Pi reboot if router down for >5 minutes

This system ensures your Pi-hole server remains highly available even with
unreliable router hardware or frequent power outages.
