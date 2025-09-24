#!/bin/bash

# Raspberry Pi Home Server Maintenance Script
# This script provides various maintenance operations for the home server

set -euo pipefail

# Source utility functions
source "$(dirname "$0")"/utils.sh

# Check if .env file exists
if [[ ! -f ".env" ]]; then
    error ".env file not found. Please copy env.example to .env and configure it."
fi

# shellcheck disable=SC1091
source .env

# Function to display service status
status_check() {
    log "Checking system and service status..."
    sudo systemctl status pihole-server.service || warn "pihole-server.service is not running or failed."
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    log "Disk usage:"
    df -h /
    echo ""
    log "Memory usage:"
    free -h
    echo ""
    log "CPU usage:"
    top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%*id.*/\1/" | awk '{print 100 - $1"%"}'
}

# Function to perform full maintenance
full_maintenance() {
    log "Performing full system update and container updates..."
    sudo apt update && sudo apt upgrade -y
    docker compose -f docker/docker-compose.core.yml -f docker/monitoring/docker-compose.monitoring.yml -f docker/optional/docker-compose.optional.yml pull
    docker compose -f docker/docker-compose.core.yml -f docker/monitoring/docker-compose.monitoring.yml -f docker/optional/docker-compose.optional.yml up -d
    log "Full maintenance completed."
    status_check
}

# Function to update containers
update_containers() {
    log "Updating Docker containers..."
    docker compose -f docker/docker-compose.core.yml -f docker/monitoring/docker-compose.monitoring.yml -f docker/optional/docker-compose.optional.yml pull
    docker compose -f docker/docker-compose.core.yml -f docker/monitoring/docker-compose.monitoring.yml -f docker/optional/docker-compose.optional.yml up -d
    log "Container update completed."
    status_check
}

# Function to run backup
run_backup() {
    log "Running backup script..."
    ./scripts/backup.sh
    log "Backup completed."
}

# Main script logic
if [[ $# -eq 0 ]]; then
    error "Usage: $0 {status|full|update|backup}"
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
        LATEST_BACKUP_DIR=$(find "${HOME}/pihole-server/backups/daily" -maxdepth 1 -type d -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)
        if [[ -n "$LATEST_BACKUP_DIR" ]]; then
            verify_backup "$LATEST_BACKUP_DIR"
        else
            warn "No daily backups found to verify. Please run './scripts/maintenance.sh backup' first."
        fi
        ;;
    offsite)
        offsite_backup
        ;;
    *)
        error "Invalid argument: $1. Usage: $0 {status|full|update|backup|verify|offsite}"
        ;;
esac
