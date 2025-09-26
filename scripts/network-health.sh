#!/bin/bash

# Network Health Monitoring Script
# This script periodically checks network health and restarts services if issues are detected

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utility functions
# shellcheck source=./utils.sh
source "${SCRIPT_DIR}/utils.sh"

log "Starting network health check..."

# Check external connectivity
if ! ping -c 3 8.8.8.8 >/dev/null 2>&1; then
    warn "External network connectivity to 8.8.8.8 (Google DNS) failed."
    log "Attempting to restart networking services..."
    sudo systemctl restart networking.service 2>/dev/null || true
    sudo systemctl restart dhcpcd.service 2>/dev/null || true
    sleep 10 # Give network time to recover
    if ! ping -c 3 8.8.8.8 >/dev/null 2>&1; then
        error "Network still down after restart attempts. Rebooting system."
        sudo reboot
    fi
else
    log "External network connectivity: OK"
fi

# Check DNS resolution
if ! dig +short google.com @127.0.0.1 >/dev/null 2>&1; then
    warn "DNS resolution for google.com via localhost (Pi-hole) failed."
    log "Attempting to restart Pi-hole service..."
    docker compose -f docker/docker-compose.core.yml restart pihole 2>/dev/null || true
    sleep 5
    if ! dig +short google.com @127.0.0.1 >/dev/null 2>&1; then
        error "Pi-hole DNS still failing. Rebooting system."
        sudo reboot
    fi
else
    log "DNS resolution for google.com: OK"
fi

log "Network health check completed."