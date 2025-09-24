#!/bin/bash

# Raspberry Pi Home Server Maintenance Script
# This script provides various maintenance operations for the home server, 
# including status checks, system updates, container updates, backups, and backup verification.

set -euo pipefail # Exit immediately if a command exits with a non-zero status, exit if an undeclared variable is used, and propagate pipefail status.

# Source utility functions for consistent logging and error handling.
source "$(dirname "$0")"/utils.sh

# Verify the .env file exists, which contains essential environment variables.
if [[ ! -f ".env" ]]; then
    error ".env file not found. Please copy env.example to .env and configure it."
fi

# Source the .env file to load environment variables. SC1091 is disabled as .env is not a fixed path script.
# shellcheck disable=SC1091
source .env

# Function to display the current system and service status.
# Includes checks for systemd service, running Docker containers, disk usage, memory usage, and CPU usage.
status_check() {
    log "Checking system and service status..."
    # Check the status of the main Docker Compose systemd service.
    sudo systemctl status pihole-server.service || warn "pihole-server.service is not running or failed. Check `sudo systemctl status pihole-server.service` for details."
    # List all running Docker containers with their status and exposed ports.
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    log "Disk usage:"
    df -h / # Display human-readable disk usage for the root filesystem.
    echo ""
    log "Memory usage:"
    free -h # Display human-readable memory usage.
    echo ""
    log "CPU usage:"
    # Display current CPU usage percentage.
    top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%*id.*/\1/" | awk '{print 100 - $1"%"}'
}

# Function to perform a full system and container maintenance.
# This includes updating OS packages and pulling/recreating Docker containers.
full_maintenance() {
    log "Performing full system update and Docker container updates..."
    # Update and upgrade all system packages.
    sudo apt update && sudo apt upgrade -y || error "System package update/upgrade failed."
    # Pull the latest Docker images for all services defined in the compose files.
    docker compose -f docker/docker-compose.core.yml -f docker/monitoring/docker-compose.monitoring.yml -f docker/optional/docker-compose.optional.yml pull || warn "Failed to pull latest Docker images."
    # Recreate containers with new images (if pulled) and ensure they are running.
    docker compose -f docker/docker-compose.core.yml -f docker/monitoring/docker-compose.monitoring.yml -f docker/optional/docker-compose.optional.yml up -d || error "Failed to update/recreate Docker containers."
    log "Full maintenance completed."
    status_check # Display status after maintenance.
}

# Function to update only Docker containers.
# Pulls latest images and recreates containers without updating the host OS.
update_containers() {
    log "Updating Docker containers..."
    # Pull the latest Docker images.
    docker compose -f docker/docker-compose.core.yml -f docker/monitoring/docker-compose.monitoring.yml -f docker/optional/docker-compose.optional.yml pull || warn "Failed to pull latest Docker images."
    # Recreate containers with new images (if pulled) and ensure they are running.
    docker compose -f docker/docker-compose.core.yml -f docker/monitoring/docker-compose.monitoring.yml -f docker/optional/docker-compose.optional.yml up -d || error "Failed to update/recreate Docker containers."
    log "Container update completed."
    status_check # Display status after container update.
}

# Function to trigger the local backup script.
run_backup() {
    log "Running local backup script (scripts/backup.sh)..."
    # Execute the dedicated backup script.
    ./scripts/backup.sh || error "Backup script failed."
    log "Local backup completed."
}

# Main script logic: parse command-line arguments to perform specific maintenance tasks.
# Ensures at least one argument is provided.
if [[ $# -eq 0 ]]; then
    error "Usage: $0 {status|full|update|backup|verify|offsite}"
fi

case "$1" in
    status)
        status_check
        ;;
    full)
        full_maintenance
        ;;
    update)
        update_containers
        ;;
    backup)
        run_backup
        ;;
    verify)
        # Find the path to the latest daily backup directory.
        LATEST_BACKUP_DIR=$(find "${HOME}/pihole-server/backups/daily" -maxdepth 1 -type d -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)
        if [[ -n "$LATEST_BACKUP_DIR" ]]; then
            # Call the verify_backup function from utils.sh with the latest backup path.
            verify_backup "$LATEST_BACKUP_DIR"
        else
            warn "No daily backups found in '${HOME}/pihole-server/backups/daily' to verify. Please run './scripts/maintenance.sh backup' first."
        fi
        ;;
    offsite)
        # Call the offsite_backup function from utils.sh.
        offsite_backup
        ;;
    *)
        error "Invalid argument: $1. Usage: $0 {status|full|update|backup|verify|offsite}"
        ;;
esac
