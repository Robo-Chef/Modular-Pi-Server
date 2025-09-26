#!/bin/bash

# Network Health Monitoring Script for Raspberry Pi Home Server
# This script checks network connectivity and service health, automatically recovering from issues

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
    PI_STATIC_IP="${PI_STATIC_IP:-192.168.1.100}"
    PI_GATEWAY="${PI_GATEWAY:-192.168.1.1}"
fi

log "Starting network health check..."

# Check 1: External network connectivity
log "Checking external network connectivity..."
if ! ping -c 3 -W 5 8.8.8.8 >/dev/null 2>&1; then
    warn "External network connectivity to 8.8.8.8 (Google DNS) failed."
    log "Attempting to restart networking services..."
    
    # Try to restart networking services
    sudo systemctl restart networking.service 2>/dev/null || true
    sudo systemctl restart dhcpcd.service 2>/dev/null || true
    
    # Give network time to recover
    sleep 10
    
    # Test again
    if ! ping -c 3 -W 5 8.8.8.8 >/dev/null 2>&1; then
        error "Network still down after restart attempts. Rebooting system."
        sudo reboot
    else
        log "Network connectivity restored after service restart."
    fi
else
    log "External network connectivity: OK"
fi

# Check 2: Gateway connectivity
log "Checking gateway connectivity..."
if ! ping -c 2 -W 3 "${PI_GATEWAY}" >/dev/null 2>&1; then
    warn "Gateway connectivity to ${PI_GATEWAY} failed."
    # Gateway issues often resolve themselves, so we'll log but not reboot immediately
else
    log "Gateway connectivity: OK"
fi

# Check 3: DNS resolution via Pi-hole
log "Checking DNS resolution via Pi-hole..."
if ! dig +short +time=5 google.com @127.0.0.1 >/dev/null 2>&1; then
    warn "DNS resolution for google.com via localhost (Pi-hole) failed."
    log "Attempting to restart Pi-hole service..."
    
    # Try to restart Pi-hole
    if docker compose -f "${SCRIPT_DIR}/../docker/docker-compose.core.yml" restart pihole 2>/dev/null; then
        sleep 5
        # Test DNS again
        if ! dig +short +time=5 google.com @127.0.0.1 >/dev/null 2>&1; then
            warn "Pi-hole DNS still failing after restart."
            # Try full core services restart
            log "Restarting all core services..."
            docker compose -f "${SCRIPT_DIR}/../docker/docker-compose.core.yml" restart 2>/dev/null || true
            sleep 10
            
            # Final test
            if ! dig +short +time=5 google.com @127.0.0.1 >/dev/null 2>&1; then
                error "Pi-hole DNS still failing. Rebooting system."
                sudo reboot
            fi
        else
            log "DNS resolution restored after Pi-hole restart."
        fi
    else
        warn "Failed to restart Pi-hole. May need manual intervention."
    fi
else
    log "DNS resolution via Pi-hole: OK"
fi

# Check 4: Pi-hole web interface
log "Checking Pi-hole web interface..."
if ! curl -f -s --connect-timeout 5 "http://127.0.0.1/admin/api.php?summary" >/dev/null 2>&1; then
    warn "Pi-hole web interface not responding."
    # This is less critical, so we'll just log it
else
    log "Pi-hole web interface: OK"
fi

# Check 5: Docker daemon health
log "Checking Docker daemon health..."
if ! docker info >/dev/null 2>&1; then
    warn "Docker daemon not responding."
    log "Attempting to restart Docker..."
    sudo systemctl restart docker 2>/dev/null || true
    sleep 5
    
    if ! docker info >/dev/null 2>&1; then
        warn "Docker daemon still not responding after restart."
    else
        log "Docker daemon restored after restart."
    fi
else
    log "Docker daemon: OK"
fi

# Check 6: Container health (if monitoring is enabled)
if [[ "${ENABLE_MONITORING:-false}" == "true" ]]; then
    log "Checking monitoring services health..."
    
    # Check if containers are running
    for container in grafana prometheus uptime-kuma node-exporter; do
        if docker ps --format "table {{.Names}}" | grep -q "^${container}$"; then
            log "Container ${container}: Running"
        else
            warn "Container ${container}: Not running"
            # Try to restart monitoring stack
            if [[ ! -f "/tmp/monitoring_restart_attempted" ]]; then
                log "Attempting to restart monitoring stack..."
                docker compose -f "${SCRIPT_DIR}/../docker/monitoring/docker-compose.monitoring.yml" restart 2>/dev/null || true
                touch "/tmp/monitoring_restart_attempted"
            fi
        fi
    done
fi

# Check 7: Disk space
log "Checking disk space..."
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [[ ${DISK_USAGE} -gt 90 ]]; then
    warn "Disk usage is ${DISK_USAGE}% - critically high!"
    # Clean up Docker logs and unused images
    docker system prune -f >/dev/null 2>&1 || true
    log "Cleaned up Docker system to free disk space."
elif [[ ${DISK_USAGE} -gt 80 ]]; then
    warn "Disk usage is ${DISK_USAGE}% - getting high"
else
    log "Disk space: OK (${DISK_USAGE}% used)"
fi

# Clean up temporary files
rm -f "/tmp/monitoring_restart_attempted" 2>/dev/null || true

log "Network health check completed successfully."

# Optional: Log system stats
log "System status: Load: $(uptime | awk -F'load average:' '{print $2}'), Memory: $(free -h | awk 'NR==2{printf "%.1f%%", $3*100/$2 }')"