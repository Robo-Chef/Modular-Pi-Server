#!/bin/bash

# Utility functions for Raspberry Pi Home Server scripts

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() { # shellcheck disable=SC2317
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() { # shellcheck disable=SC2317
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Function to wait for a Docker container to become healthy
wait_for_container_health() {
    local container_name="$1"
    local retries=20
    local delay=5
    local start_time; start_time=$(date +%s)

    log "Waiting for container '$container_name' to become healthy..."
    for i in $(seq 1 $retries); do
        if docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null | grep -q "healthy"; then
            log "Container '$container_name' is healthy."
            return 0
        fi
        printf "Container '%s' not yet healthy (attempt %d/%d). Waiting %d seconds...\n" "$container_name" "$i" "$retries" "$delay"
        sleep "$delay"
    done

    error "Container '$container_name' did not become healthy within the allotted time."
}
