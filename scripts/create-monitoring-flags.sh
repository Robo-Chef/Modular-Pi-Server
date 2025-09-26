#!/bin/bash

# Create monitoring flag system for router reboot detection
# This script sets up status files that can be monitored by external systems

MONITOR_DIR="/var/lib/pihole-server/monitoring"
FLAGS_DIR="$MONITOR_DIR/flags"
STATUS_FILE="$MONITOR_DIR/network-status.json"

# Create monitoring directories
sudo mkdir -p "$FLAGS_DIR"
sudo mkdir -p "$MONITOR_DIR/logs"

# Set permissions
sudo chown -R pi:pi "$MONITOR_DIR" 2>/dev/null || true

# Create initial status file
cat > "$STATUS_FILE" <<EOF
{
  "last_check": "$(date -Iseconds)",
  "router_status": "unknown",
  "pi_status": "starting",
  "services_status": "unknown",
  "last_recovery": "never",
  "recovery_count": 0,
  "uptime_seconds": $(awk '{print int($1)}' /proc/uptime)
}
EOF

echo "Monitoring flags system created at: $MONITOR_DIR"
echo "Status file: $STATUS_FILE"
echo "Flags directory: $FLAGS_DIR"
