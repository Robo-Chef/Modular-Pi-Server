#!/bin/bash

# Utility functions for Raspberry Pi Home Server scripts

set -euo pipefail

# Colors for output for consistent logging.
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color escape code.

# shellcheck disable=SC2317  # Intentional use of return/exit in helper functions

# Logs a message to stdout in green. Used for general information.
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Logs a warning message to stdout in yellow. Used for non-critical issues.
warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# Logs an error message to stderr in red and exits the script with status 1. Used for critical failures.
error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
    exit 1
}

# Waits for a specified Docker container to report a 'healthy' status via its healthcheck.
# Arguments:
#   $1: The name of the Docker container to monitor.
#   $2 (optional): The maximum time (in seconds) to wait for the container to become healthy. Defaults to 120s.
wait_for_container_health() {
    local container_name="$1"
    local retries=20 # Number of times to check for health
    local delay=5    # Delay in seconds between checks
    local start_time
    start_time=$(date +%s)
    local i
    local elapsed_seconds

    log "Waiting for container '$container_name' to become healthy..."
    for ((i=1; i<=retries; i++)); do
        local health_status
        health_status=$(docker inspect --format '{{.State.Health.Status}}' "$container_name" 2>/dev/null || true)
        
        if [ "$health_status" = "healthy" ]; then
            elapsed_seconds=$(( $(date +%s) - start_time ))
            log "Container '$container_name' is healthy after ${elapsed_seconds} seconds"
            return 0
        fi
        
        if [ $i -lt $retries ]; then
            sleep $delay
        fi
    done
    
    elapsed_seconds=$(( $(date +%s) - start_time ))
    error "Timed out after ${elapsed_seconds} seconds waiting for container '$container_name' to become healthy. Current status: ${health_status:-unknown}"
}

# Verifies the integrity of a backup by attempting a partial restore to a temporary location.
# Arguments:
#   $1: The path to the backup directory to verify.
verify_backup() {
    local backup_path="$1"
    local temp_restore_dir
    # Create a unique temporary directory for the restore operation.
    temp_restore_dir=$(mktemp -d -t pihole-restore-XXXXXXXXXX) || error "Failed to create temporary restore directory."

    log "Verifying backup from '$backup_path' to temporary location '$temp_restore_dir'..."

    # Basic checks: ensure the provided backup directory exists.
    if [[ ! -d "$backup_path" ]]; then
        error "Backup directory '$backup_path' does not exist."
    fi

    # Check for the presence of essential Docker Compose files in the backup.
    if [[ ! -f "$backup_path/docker-compose.core.yml" ]]; then
        error "Core Docker Compose file not found in backup: $backup_path/docker-compose.core.yml"
    fi

    # Copy all backup contents to the temporary directory for verification.
    cp -r "$backup_path"/* "$temp_restore_dir/" || error "Failed to copy backup files to temporary restore directory."

    # Verify Docker Compose file syntax by running `docker compose config` in a dry-run mode.
    log "Verifying Docker Compose file syntax in temporary restore location..."
    # Pushd/popd manage directory stack to safely change and restore current directory.
    pushd "$temp_restore_dir" > /dev/null || error "Failed to change directory to $temp_restore_dir"
    if docker compose -f docker-compose.core.yml -f docker-compose.monitoring.yml -f docker-compose.optional.yml config > /dev/null; then
        log "Docker Compose configuration in backup is valid."
    else
        error "Docker Compose configuration in backup is INVALID. This backup might be corrupted."
    fi
    popd > /dev/null || error "Failed to return to original directory."

    # Clean up the temporary directory after verification.
    log "Cleaning up temporary restore directory '$temp_restore_dir'..."
    rm -rf "$temp_restore_dir" || warn "Failed to remove temporary restore directory: $temp_restore_dir (manual cleanup may be required)"

    log "Backup verification for '$backup_path' completed successfully."
    return 0
}

# Performs an off-site backup of the latest daily backup to a remote location.
# Requires the REMOTE_BACKUP_LOCATION environment variable to be set in .env.
# Assumes SSH key-based authentication is configured for remote locations for security.
offsite_backup() {
    local source_dir="${HOME}/pihole-server/backups/daily"
    local latest_backup_dir
    # Find the most recently created backup directory.
    latest_backup_dir=$(find "$source_dir" -maxdepth 1 -type d -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)

    if [[ -z "$latest_backup_dir" ]]; then
        error "No daily backups found to send off-site. Please run './scripts/maintenance.sh backup' first."
    fi

    # Validate that REMOTE_BACKUP_LOCATION is set.
    if [[ -z "${REMOTE_BACKUP_LOCATION}" ]]; then
        error "REMOTE_BACKUP_LOCATION is not set in your .env file. Cannot perform off-site backup."
    fi

    log "Starting off-site backup of '$latest_backup_dir' to '$REMOTE_BACKUP_LOCATION'..."

    # Use rsync for efficient and robust file transfer. -a (archive mode), -v (verbose), -z (compress).
    # Ensure SSH key-based authentication is set up on your system for passwordless access to the remote.
    if rsync -avzh "$latest_backup_dir" "${REMOTE_BACKUP_LOCATION}"; then
        log "Off-site backup of '$latest_backup_dir' completed successfully to '$REMOTE_BACKUP_LOCATION'."
    else
        error "Off-site backup failed! Check SSH connection, permissions, and ensure REMOTE_BACKUP_LOCATION is correctly configured and reachable."
    fi
    return 0
}
