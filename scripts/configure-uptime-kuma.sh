#!/bin/bash

# Configure Uptime Kuma with default admin account
# This script sets up the initial admin user automatically

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
fi

log "Configuring Uptime Kuma with default admin account..."

# Wait for Uptime Kuma to be ready
log "Waiting for Uptime Kuma to start..."
timeout=60
while ! curl -s http://localhost:3001 >/dev/null 2>&1; do
    sleep 2
    timeout=$((timeout - 2))
    if [ $timeout -le 0 ]; then
        error "Timeout waiting for Uptime Kuma to start"
    fi
done

# Check if setup is already done
if curl -s http://localhost:3001/api/status-page/config | grep -q "title"; then
    log "Uptime Kuma is already configured"
    exit 0
fi

# Set up initial admin account using API
log "Creating admin account..."
curl -X POST http://localhost:3001/setup \
    -H "Content-Type: application/json" \
    -d '{
        "username": "admin",
        "password": "'"${UNIVERSAL_PASSWORD:-raspberry}"'",
        "confirmPassword": "'"${UNIVERSAL_PASSWORD:-raspberry}"'",
        "autoLogin": true
    }' >/dev/null 2>&1 || warn "Failed to create admin account automatically"

log "✅ Uptime Kuma configuration complete!"
log "   Username: admin"
log "   Password: ${UNIVERSAL_PASSWORD:-raspberry}"
