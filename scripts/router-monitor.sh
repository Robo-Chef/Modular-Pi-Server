#!/bin/bash

# Router Reboot Detection and Auto-Recovery Script
# This script runs every 2 minutes via cron to detect router reboots

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utility functions
# shellcheck source=./utils.sh
source "${SCRIPT_DIR}/utils.sh"

# Load environment variables from .env file if it exists
if [[ -f "${SCRIPT_DIR}/../.env" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "${SCRIPT_DIR}/../.env"
    set +a
else
    # Set defaults if no .env file
    PI_STATIC_IP="${PI_STATIC_IP:-192.168.1.XXX}"
    PI_GATEWAY="${PI_GATEWAY:-192.168.1.1}"
fi

# Log file for router monitoring
MONITOR_LOG="/var/log/router-monitor.log"
LOCK_FILE="/tmp/router-monitor.lock"
REBOOT_FLAG="/tmp/router_reboot_detected"

# Monitoring flags and status
MONITOR_DIR="/var/lib/pihole-server/monitoring"
FLAGS_DIR="$MONITOR_DIR/flags"
STATUS_FILE="$MONITOR_DIR/network-status.json"

# Create monitoring directories if they don't exist
sudo mkdir -p "$FLAGS_DIR" "$MONITOR_DIR/logs" 2>/dev/null || true
sudo chown -R pi:pi "$MONITOR_DIR" 2>/dev/null || true

# Prevent multiple instances
if [[ -f "$LOCK_FILE" ]]; then
    exit 0
fi
touch "$LOCK_FILE"

# Cleanup function
cleanup() {
    rm -f "$LOCK_FILE"
}
trap cleanup EXIT

# Simple logging function for this script
monitor_log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$MONITOR_LOG" >/dev/null
}

# Update status file with current state
update_status() {
    local router_status="$1"
    local pi_status="$2"
    local message="$3"
    
    # Read current recovery count before writing new file
    local current_recovery_count=0
    if [[ -f "$STATUS_FILE" ]]; then
        current_recovery_count=$(jq -r '.recovery_count // 0' "$STATUS_FILE" 2>/dev/null || echo "0")
    fi
    
    cat > "$STATUS_FILE" <<EOF
{
  "last_check": "$(date -Iseconds)",
  "router_status": "$router_status",
  "pi_status": "$pi_status",
  "services_status": "$(docker ps --format 'table {{.Names}}\t{{.Status}}' | grep -c "Up" || echo "0") containers running",
  "last_recovery": "$(date -Iseconds)",
  "recovery_count": $(( current_recovery_count + 1 )),
  "uptime_seconds": $(awk '{print int($1)}' /proc/uptime),
  "message": "$message"
}
EOF
}

# Create monitoring flags
create_flag() {
    local flag_name="$1"
    local message="$2"
    echo "$(date -Iseconds): $message" > "$FLAGS_DIR/$flag_name"
    monitor_log "FLAG CREATED: $flag_name - $message"
}

# Remove monitoring flags
remove_flag() {
    local flag_name="$1"
    rm -f "$FLAGS_DIR/$flag_name"
    monitor_log "FLAG REMOVED: $flag_name"
}

# Quick gateway check (lightweight)
check_gateway() {
    # Single ping with 3 second timeout for speed
    if ping -c 1 -W 3 "${PI_GATEWAY}" >/dev/null 2>&1; then
        return 0  # Gateway reachable
    else
        return 1  # Gateway unreachable
    fi
}

# Main monitoring logic
monitor_log "Router monitor check started"

if ! check_gateway; then
    monitor_log "🚨 ALERT: Gateway ${PI_GATEWAY} unreachable - ROUTER REBOOT DETECTED!"
    
    # Create monitoring flags
    create_flag "router_down" "Router unreachable - recovery in progress"
    create_flag "recovery_active" "Network recovery process started"
    update_status "down" "recovering" "Router reboot detected - starting recovery"
    
    # Check if we're already handling a reboot
    if [[ -f "$REBOOT_FLAG" ]]; then
        monitor_log "Router reboot already being handled by network-health.sh"
        update_status "down" "recovering" "Recovery already in progress"
        exit 0
    fi
    
    # Trigger comprehensive network health check
    monitor_log "🔄 Triggering comprehensive network recovery..."
    create_flag "network_health_running" "Comprehensive network recovery started"
    "${SCRIPT_DIR}/network-health.sh" >> "$MONITOR_LOG" 2>&1 &
    
    # Create flag to prevent duplicate triggers
    touch "$REBOOT_FLAG"
    
    monitor_log "✅ Network health check triggered in background"
else
    # Gateway is reachable - remove any stale flags
    if [[ -f "$REBOOT_FLAG" ]]; then
        monitor_log "🎉 Gateway restored - network recovery successful!"
        remove_flag "router_down"
        remove_flag "recovery_active" 
        remove_flag "network_health_running"
        update_status "up" "healthy" "Router and all services restored"
        rm -f "$REBOOT_FLAG"
    else
        # Normal operation
        update_status "up" "healthy" "All systems normal"
    fi
    
    # Log successful checks every 10 minutes (5 checks * 2 min intervals)
    if (( $(date +%M) % 10 == 0 )); then
        monitor_log "✅ Routine check: Gateway and services healthy"
    fi
fi

monitor_log "Router monitor check completed"
