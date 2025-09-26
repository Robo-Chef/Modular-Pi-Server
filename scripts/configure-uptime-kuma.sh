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
else
    warn "No .env file found, using default passwords for Uptime Kuma."
    UNIVERSAL_PASSWORD="${UNIVERSAL_PASSWORD:-raspberry}"
fi

UPTIME_KUMA_URL="http://localhost:${UPTIME_KUMA_PORT:-3001}"
ADMIN_USERNAME="admin"
ADMIN_PASSWORD="${UNIVERSAL_PASSWORD}"

log "Attempting to configure Uptime Kuma admin account..."

# Wait for Uptime Kuma to be ready
wait_for_url "${UPTIME_KUMA_URL}" 60 || error "Uptime Kuma not ready after 60 seconds."

# Check if admin account already exists (by trying to log in)
if curl -s -X POST "${UPTIME_KUMA_URL}/api/user/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${ADMIN_USERNAME}\",\"password\":\"${ADMIN_PASSWORD}\"}" | grep -q "token"; then
    log "Uptime Kuma admin account already exists."
else
    log "Creating Uptime Kuma admin account..."
    # Create admin account
    if curl -s -X POST "${UPTIME_KUMA_URL}/api/user/add" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"${ADMIN_USERNAME}\",\"password\":\"${ADMIN_PASSWORD}\"}" | grep -q "ok\":true"; then
        log "Uptime Kuma admin account created successfully."
    else
        warn "Failed to create Uptime Kuma admin account. You may need to set it up manually."
    fi
fi

log "Uptime Kuma configuration complete."
log "Login at: ${UPTIME_KUMA_URL}"
log "Username: ${ADMIN_USERNAME}"
log "Password: ${ADMIN_PASSWORD}"