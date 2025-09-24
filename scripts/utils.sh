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

# Function to verify a backup by attempting a partial restore to a temporary location
verify_backup() {
    local backup_path="$1"
    local temp_restore_dir
    temp_restore_dir=$(mktemp -d -t pihole-restore-XXXXXXXXXX) || error "Failed to create temporary restore directory."

    log "Verifying backup from '$backup_path' to temporary location '$temp_restore_dir'..."

    # Basic checks: ensure backup directory exists and contains expected files
    if [[ ! -d "$backup_path" ]]; then
        error "Backup directory '$backup_path' does not exist."
    fi

    # Check for core docker-compose file
    if [[ ! -f "$backup_path/docker-compose.core.yml" ]]; then
        error "Core Docker Compose file not found in backup: $backup_path/docker-compose.core.yml"
    fi

    # Copy essential backup files for verification
    cp -r "$backup_path"/* "$temp_restore_dir/" || error "Failed to copy backup files to temporary restore directory."

    # Verify Docker Compose file syntax (dry run config)
    log "Verifying Docker Compose file syntax in temporary restore location..."
    pushd "$temp_restore_dir" > /dev/null || error "Failed to change directory to $temp_restore_dir"
    if docker compose -f docker-compose.core.yml -f docker-compose.monitoring.yml -f docker-compose.optional.yml config > /dev/null; then
        log "Docker Compose configuration in backup is valid."
    else
        error "Docker Compose configuration in backup is INVALID."
    fi
    popd > /dev/null || error "Failed to return to original directory."

    # Clean up temporary directory
    log "Cleaning up temporary restore directory '$temp_restore_dir'..."
    rm -rf "$temp_restore_dir" || warn "Failed to remove temporary restore directory: $temp_restore_dir"

    log "Backup verification for '$backup_path' completed successfully."
    return 0
}

# Function to perform off-site backup
offsite_backup() {
    local source_dir="${HOME}/pihole-server/backups/daily"
    local latest_backup_dir
    latest_backup_dir=$(find "$source_dir" -maxdepth 1 -type d -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)

    if [[ -z "$latest_backup_dir" ]]; then
        error "No daily backups found to send off-site. Please run './scripts/maintenance.sh backup' first."
    fi

    if [[ -z "${REMOTE_BACKUP_LOCATION}" ]]; then
        error "REMOTE_BACKUP_LOCATION is not set in your .env file. Cannot perform off-site backup."
    fi

    log "Starting off-site backup of '$latest_backup_dir' to '$REMOTE_BACKUP_LOCATION'..."

    # Use rsync for efficiency and robustness. Assumes SSH key-based authentication is set up for remote locations.
    if rsync -avzh "$latest_backup_dir" "${REMOTE_BACKUP_LOCATION}"; then
        log "Off-site backup of '$latest_backup_dir' completed successfully to '$REMOTE_BACKUP_LOCATION'."
    else
        error "Off-site backup failed! Check SSH connection, permissions, and REMOTE_BACKUP_LOCATION."
    fi
    return 0
}
