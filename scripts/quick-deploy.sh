#!/bin/bash

# Quick Deploy Script for Raspberry Pi Home Server
# This script provides a streamlined deployment process

set -euo pipefail

# --- Functions ---

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Function to wait for a Docker container to become healthy
wait_for_container_health() {
    local container_name=$1
    local timeout=${2:-120} # Default timeout of 120 seconds
    local start_time=$(date +%s)
    log "Waiting for container '$container_name' to become healthy (timeout: ${timeout}s)"

    while true; do
        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))

        if [[ $elapsed_time -ge $timeout ]]; then
            error "Container '$container_name' did not become healthy within ${timeout} seconds."
        fi

        # Check if container exists and is running
        if ! docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
            warn "Container '$container_name' not found or not running. Retrying..."
            sleep 5
            continue
        fi

        # Check container health status
        health_status=$(docker inspect --format='{{json .State.Health}}' "$container_name" 2>/dev/null || true)
        if [[ -n "$health_status" ]]; then
            status=$(echo "$health_status" | jq -r '.Status')
            if [[ "$status" == "healthy" ]]; then
                log "✓ Container '$container_name' is healthy."
                return 0
            elif [[ "$status" == "unhealthy" ]]; then
                warn "Container '$container_name' is unhealthy. Checking logs..."
                docker logs "$container_name" | tail -10
                error "Container '$container_name' is unhealthy."
            fi
        else
            # No healthcheck defined, assume healthy if running
            if docker ps --filter "name=^${container_name}$" --format '{{.Status}}' | grep -q "Up"; then
                log "✓ Container '$container_name' is running and has no healthcheck defined (assuming healthy)."
                return 0
            fi
        fi
        log "Container '$container_name' not yet healthy. Retrying in 5 seconds..."
        sleep 5
    done
}

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

# Source environment variables
source .env

log "Starting Raspberry Pi Home Server Quick Deploy..."

# Project directory structure and initial file copying/permissions are handled by scripts/setup.sh
cd ~/pihole-server

# Create necessary directories for containers
log "Creating container directories..."
mkdir -p docker/pihole/{etc-pihole,etc-dnsmasq.d,logs}
mkdir -p docker/unbound/{config,logs}
mkdir -p monitoring/{prometheus,grafana,uptime-kuma}

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
if [[ "${ENABLE_UPTIME_KUMA:-true}" == "true" ]]; then
    log "Starting monitoring services..."
    docker compose -f monitoring/docker-compose.monitoring.yml up -d
    
    log "Waiting for monitoring services to become healthy..."
    wait_for_container_health grafana
    wait_for_container_health uptime-kuma
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
log "• Pi-hole Admin: http://192.168.1.XXX/admin"
log "• Pi-hole Password: ${PIHOLE_PASSWORD}"
log "• DNS Server: 192.168.1.XXX"
echo ""

if [[ "${ENABLE_UPTIME_KUMA:-true}" == "true" ]]; then
    log "• Grafana: http://192.168.1.XXX:3000 (admin/${GRAFANA_ADMIN_PASSWORD})"
    log "• Uptime Kuma: http://192.168.1.XXX:3001"
    echo ""
fi

log "Next steps:"
log "==========="
log "1. Configure your router to use 192.168.1.XXX as the DNS server"
log "2. Test DNS resolution: dig @192.168.1.XXX google.com"
log "3. Check Pi-hole logs: docker logs pihole"
log "4. Run maintenance: ~/pihole-server/scripts/maintenance.sh status"
echo ""

log "For troubleshooting, see: ~/pihole-server/docs/troubleshooting.md"
log "For security hardening, see: ~/pihole-server/docs/security-hardening.md"


