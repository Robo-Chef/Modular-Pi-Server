#!/bin/bash

# Quick Deploy Script for Raspberry Pi Home Server
# This script provides a streamlined deployment process

set -euo pipefail

# Source utility functions
source "$(dirname "$0")"/utils.sh

# --- Initial Checks ---

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root. Please run as a regular user with sudo privileges."
fi

# Check if Docker is installed and running
if ! command -v docker &> /dev/null; then
    error "Docker is not installed. Please install Docker first (e.g., run scripts/setup.sh)."
fi
if ! docker info >/dev/null 2>&1; then
    error "Docker daemon is not running. Please start Docker first (e.g., sudo systemctl start docker)."
fi

# Check if Docker Compose is installed
if ! command -v docker compose &> /dev/null; then
    error "Docker Compose is not installed. Please install Docker Compose first (e.g., run scripts/setup.sh)."
fi

# Check if .env file exists
if [[ ! -f ".env" ]]; then
    error ".env file not found. Please copy env.example to .env and configure it."
fi

# shellcheck disable=SC1091
source .env

log "Starting Raspberry Pi Home Server Quick Deploy..."

# Project directory structure and initial file copying/permissions are handled by scripts/setup.sh
cd ~/pihole-server

# Set permissions
chmod 755 docker/pihole docker/unbound monitoring
chmod 700 docker/pihole/logs docker/unbound/logs

# Create Docker networks
log "Creating Docker networks..."
docker network create --subnet=172.20.0.0/24 pihole_net 2>/dev/null || true
docker network create --subnet=172.21.0.0/24 monitoring_net 2>/dev/null || true
docker network create --internal isolated_net 2>/dev/null || true

# Start core services
log "Starting core services (Pi-hole + Unbound)..."
cd docker
docker compose -f docker-compose.core.yml up -d

log "Waiting for core services to become healthy..."
wait_for_container_health pihole
wait_for_container_health unbound

# Start monitoring services if enabled
if [[ "${ENABLE_MONITORING:-true}" == "true" ]]; then
    log "Starting monitoring services..."
    docker compose -f monitoring/docker-compose.monitoring.yml up -d
    
    log "Waiting for monitoring services to become healthy..."
    wait_for_container_health prometheus
    wait_for_container_health grafana
    wait_for_container_health node-exporter
    wait_for_container_health uptime-kuma
    # Placeholder: if caddy-exporter is used, add its health check here
fi

# Display service status
log "Service status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Display access information
echo ""
log "🎉 Deployment completed successfully!"
echo ""
log "Access information:"
log "=================="
log "• Pi-hole Admin: http://${PI_STATIC_IP}/admin"
log "• Pi-hole Password: ${PIHOLE_PASSWORD}"
log "• DNS Server: ${PI_STATIC_IP}"
echo ""

if [[ "${ENABLE_UPTIME_KUMA:-true}" == "true" ]]; then
    log "• Grafana: http://${PI_STATIC_IP}:3000 (admin/${GRAFANA_ADMIN_PASSWORD})"
    log "• Uptime Kuma: http://${PI_STATIC_IP}:3001"
    echo ""
fi

log "Next steps:"
log "==========="
log "1. Configure your router to use ${PI_STATIC_IP} as the DNS server"
log "2. Test DNS resolution: dig @${PI_STATIC_IP} google.com"
log "3. Check Pi-hole logs: docker logs pihole"
log "4. Run maintenance: ~/pihole-server/scripts/maintenance.sh status"
echo ""

log "For troubleshooting, see: ~/pihole-server/docs/troubleshooting.md"
log "For security hardening, see: ~/pihole-server/docs/security-hardening.md"


