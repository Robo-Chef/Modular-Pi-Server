#!/bin/bash

# Quick Deploy Script for Raspberry Pi Home Server
# This script provides a streamlined deployment process

set -euo pipefail

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

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root. Please run as a regular user with sudo privileges."
fi

# Check if .env file exists
if [[ ! -f ".env" ]]; then
    error ".env file not found. Please copy env.example to .env and configure it."
fi

# Source environment variables
source .env

log "Starting Raspberry Pi Home Server Quick Deploy..."

# Create project directory structure
log "Creating project directory structure..."
mkdir -p ~/pihole-server/{configs,docker,scripts,monitoring,backups,docs}
mkdir -p ~/pihole-server/docker/{pihole,unbound,monitoring,optional}
mkdir -p ~/pihole-server/monitoring/{prometheus,grafana,uptime-kuma}
mkdir -p ~/pihole-server/backups/{daily,weekly,monthly}

# Copy all files to project directory
log "Copying configuration files..."
cp -r docker/* ~/pihole-server/docker/ 2>/dev/null || true
cp -r monitoring/* ~/pihole-server/monitoring/ 2>/dev/null || true
cp -r configs/* ~/pihole-server/configs/ 2>/dev/null || true
cp scripts/* ~/pihole-server/scripts/ 2>/dev/null || true
cp docs/* ~/pihole-server/docs/ 2>/dev/null || true
cp .env ~/pihole-server/ 2>/dev/null || true

# Set permissions
chmod +x ~/pihole-server/scripts/*.sh
chmod 755 ~/pihole-server
chmod 700 ~/pihole-server/backups

# Change to project directory
cd ~/pihole-server

# Check Docker is running
if ! docker info >/dev/null 2>&1; then
    error "Docker is not running. Please start Docker first."
fi

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

# Wait for services to be healthy
log "Waiting for services to be healthy..."
sleep 30

# Check service health
log "Checking service health..."

# Check Pi-hole
if docker exec pihole curl -f http://localhost/admin/api.php?summary >/dev/null 2>&1; then
    log "✓ Pi-hole is healthy"
else
    warn "✗ Pi-hole is not responding. Checking logs..."
    docker logs pihole | tail -10
fi

# Check Unbound
if docker exec unbound unbound-control status >/dev/null 2>&1; then
    log "✓ Unbound is healthy"
else
    warn "✗ Unbound is not responding. Checking logs..."
    docker logs unbound | tail -10
fi

# Start monitoring services if enabled
if [[ "${ENABLE_UPTIME_KUMA:-true}" == "true" ]]; then
    log "Starting monitoring services..."
    docker compose -f monitoring/docker-compose.monitoring.yml up -d
    
    # Wait for monitoring services
    sleep 30
    
    # Check monitoring services
    if docker exec grafana wget --quiet --tries=1 --spider http://localhost:3000 >/dev/null 2>&1; then
        log "✓ Grafana is healthy"
    else
        warn "✗ Grafana is not responding"
    fi
    
    if docker exec uptime-kuma wget --quiet --tries=1 --spider http://localhost:3001 >/dev/null 2>&1; then
        log "✓ Uptime Kuma is healthy"
    else
        warn "✗ Uptime Kuma is not responding"
    fi
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
log "• Pi-hole Admin: http://192.168.0.185/admin"
log "• Pi-hole Password: ${PIHOLE_PASSWORD}"
log "• DNS Server: 192.168.0.185"
echo ""

if [[ "${ENABLE_UPTIME_KUMA:-true}" == "true" ]]; then
    log "• Grafana: http://192.168.0.185:3000 (admin/${GRAFANA_ADMIN_PASSWORD})"
    log "• Uptime Kuma: http://192.168.0.185:3001"
    echo ""
fi

log "Next steps:"
log "==========="
log "1. Configure your router to use 192.168.0.185 as the DNS server"
log "2. Test DNS resolution: dig @192.168.0.185 google.com"
log "3. Check Pi-hole logs: docker logs pihole"
log "4. Run maintenance: ~/pihole-server/scripts/maintenance.sh status"
echo ""

log "For troubleshooting, see: ~/pihole-server/docs/troubleshooting.md"
log "For security hardening, see: ~/pihole-server/docs/security-hardening.md"


