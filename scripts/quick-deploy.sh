#!/bin/bash

# Quick Deploy Script for Raspberry Pi Home Server
# This script provides a streamlined deployment process for the server.

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=./utils.sh
source "${SCRIPT_DIR}/utils.sh"

# Source environment variables if .env exists
if [[ -f ".env" ]]; then
    # shellcheck source=/dev/null
    source .env
fi

# --- Initial Checks ---

# Ensure the script is not run as root to prevent permission issues.
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root. Please run as a regular user with sudo privileges."
fi

# Verify Docker is installed and its daemon is running.
if ! command -v docker &> /dev/null; then
    error "Docker is not installed. Please install Docker first (e.g., run scripts/setup.sh)."
fi
if ! docker info >/dev/null 2>&1; then
    error "Docker daemon is not running. Please start Docker first (e.g., sudo systemctl start docker)."
fi

# Verify Docker Compose is installed.
if ! command -v docker compose &> /dev/null; then
    error "Docker Compose is not installed. Please install Docker Compose first (e.g., run scripts/setup.sh)."
fi

# Verify the .env file exists, which contains essential environment variables.
if [[ ! -f ".env" ]]; then
    error ".env file not found. Please copy env.example to .env and configure it."
fi

log "Starting Raspberry Pi Home Server Quick Deploy..."

# Create required directory structure if missing
log "Ensuring required directory structure exists..."
mkdir -p docker/pihole/etc-pihole
mkdir -p docker/pihole/etc-dnsmasq.d
mkdir -p docker/pihole/logs
mkdir -p docker/unbound/logs

# Ensure we're in the project root directory
# The directory structure and initial setup are handled by `scripts/setup.sh`.
if [[ ! -f "docker/docker-compose.core.yml" ]]; then
    error "Docker Compose files not found. Ensure you're in the project root directory."
fi

# Set necessary permissions for Docker volumes and configurations.
chmod 755 docker/pihole docker/unbound monitoring || warn "Failed to set permissions on Docker configuration directories."
chmod 700 docker/pihole/logs docker/unbound/logs || warn "Failed to set permissions on Docker log directories."

# Create Docker custom bridge networks for service isolation.
log "Creating Docker networks (pihole_net, monitoring_net, isolated_net) if they don't exist..."
# '|| true' allows the script to continue if the network already exists.
docker network create --subnet=172.20.0.0/24 pihole_net 2>/dev/null || true
docker network create --subnet=172.21.0.0/24 monitoring_net 2>/dev/null || true
docker network create --internal isolated_net 2>/dev/null || true # `isolated_net` blocks outbound internet access for containers linked to it.

# Function to check and fix Docker network conflicts
check_docker_networks() {
  log "Checking for Docker network conflicts..."
  
  # Get configured network subnets from .env
  PIHOLE_NET_SUBNET="${PIHOLE_NETWORK:-172.22.0.0/24}"
  MONITORING_NET_SUBNET="${MONITORING_NETWORK:-172.23.0.0/24}"
  
  # Check if networks exist with mismatched subnet
  if docker network inspect pihole_net &>/dev/null; then
    CURRENT_SUBNET=$(docker network inspect pihole_net --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}')
    if [ "$CURRENT_SUBNET" != "$PIHOLE_NET_SUBNET" ]; then
      log "Network 'pihole_net' exists with subnet $CURRENT_SUBNET but config requires $PIHOLE_NET_SUBNET"
      log "Removing conflicting network and recreating..."
      docker network rm pihole_net || warn "Failed to remove network pihole_net"
    fi
  fi
  
  # Do the same check for monitoring network
  if docker network inspect monitoring_net &>/dev/null; then
    CURRENT_SUBNET=$(docker network inspect monitoring_net --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}')
    if [ "$CURRENT_SUBNET" != "$MONITORING_NET_SUBNET" ]; then
      log "Network 'monitoring_net' exists with subnet $CURRENT_SUBNET but config requires $MONITORING_NET_SUBNET"
      log "Removing conflicting network and recreating..."
      docker network rm monitoring_net || warn "Failed to remove network monitoring_net"
    fi
  fi
}

# --- Service Deployment ---

# Check for network conflicts before creating networks
check_docker_networks

# Start core services (Pi-hole and Unbound) as defined in docker-compose.core.yml.
log "Starting core services (Pi-hole + Unbound) from docker/docker-compose.core.yml..."
docker compose -f docker/docker-compose.core.yml up -d || error "Failed to start core Docker Compose services."

log "Waiting for core services to become healthy..."
wait_for_container_health pihole || error "Pi-hole container failed health check."
wait_for_container_health unbound || error "Unbound container failed health check."

# Start monitoring services if ENABLE_MONITORING is set to 'true' in .env.
if [[ "${ENABLE_MONITORING:-true}" == "true" ]]; then
    log "Starting monitoring services from docker/monitoring/docker-compose.monitoring.yml..."
    docker compose -f docker/monitoring/docker-compose.monitoring.yml up -d || error "Failed to start monitoring Docker Compose services."
    
    log "Waiting for monitoring services to become healthy..."
    # Perform health checks for each monitoring service.
    wait_for_container_health prometheus || error "Prometheus container failed health check."
    wait_for_container_health grafana || error "Grafana container failed health check."
    wait_for_container_health node-exporter || error "Node Exporter container failed health check."
    wait_for_container_health uptime-kuma || error "Uptime Kuma container failed health check."
    # Placeholder for caddy-exporter health check if Caddy is integrated in the future.
    # wait_for_container_health caddy-exporter
fi

# Start optional services if their respective ENABLE flags are set to 'true' in .env.
# Note: This logic assumes that individual ENABLE_SERVICE flags are checked here or within optional/docker-compose.optional.yml.
log "Starting optional services from docker/optional/docker-compose.optional.yml (if enabled in .env)..."
docker compose -f docker/optional/docker-compose.optional.yml up -d || warn "Optional services deployment failed or encountered issues. Check logs."

# Wait for optional services to become healthy (add individual health checks as needed)
if [[ "${ENABLE_HOME_ASSISTANT:-false}" == "true" ]]; then
    wait_for_container_health homeassistant || error "Home Assistant container failed health check."
fi
if [[ "${ENABLE_GITEA:-false}" == "true" ]]; then
    wait_for_container_health gitea || error "Gitea container failed health check."
fi
if [[ "${ENABLE_PORTAINER:-true}" == "true" ]]; then
    wait_for_container_health portainer || error "Portainer container failed health check."
fi
if [[ "${ENABLE_DOZZLE:-true}" == "true" ]]; then
    wait_for_container_health dozzle || error "Dozzle container failed health check."
fi
if [[ "${ENABLE_SPEEDTEST_TRACKER:-true}" == "true" ]]; then
    wait_for_container_health speedtest-tracker || error "Speedtest Tracker container failed health check."
fi
if [[ "${ENABLE_WATCHTOWER:-true}" == "true" ]]; then
    # Watchtower typically doesn't have a health check, assume healthy if running.
    if ! docker ps --filter "name=^watchtower$" --format '{{.Status}}' | grep -q "Up"; then
        warn "Watchtower container is not running. Automated updates will not occur."
    else
        log "Watchtower container is running."
    fi
fi

# All services should now be running from the project root directory.

# Display a summary of all running Docker services.
log "Service status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# --- Post-Deployment Information ---

echo ""
log "🎉 Deployment completed successfully!"
echo ""
log "Access information:"
log "=================="
log "• Pi-hole Admin: http://${PI_STATIC_IP}/admin (replace with your Pi's actual static IP)"
log "• Pi-hole Password: ${PIHOLE_PASSWORD} (from your .env file)"
log "• DNS Server: ${PI_STATIC_IP} (your Raspberry Pi's static IP)"
echo ""

# Provide access details for monitoring services if enabled.
if [[ "${ENABLE_MONITORING:-true}" == "true" ]]; then
    log "• Grafana: http://${PI_STATIC_IP}:3000 (admin/${GRAFANA_ADMIN_PASSWORD})"
    log "• Uptime Kuma: http://${PI_STATIC_IP}:3001"
    echo ""
fi

# Provide access details for other optional services if enabled.
if [[ "${ENABLE_PORTAINER:-true}" == "true" ]]; then
    log "• Portainer: http://${PI_STATIC_IP}:9000"
fi
if [[ "${ENABLE_DOZZLE:-true}" == "true" ]]; then
    log "• Dozzle: http://${PI_STATIC_IP}:8080"
fi
if [[ "${ENABLE_SPEEDTEST_TRACKER:-true}" == "true" ]]; then
    log "• Speedtest Tracker: http://${PI_STATIC_IP}:8787"
fi
if [[ "${ENABLE_GITEA:-false}" == "true" ]]; then
    log "• Gitea: http://${PI_STATIC_IP}:3002"
fi
if [[ "${ENABLE_HOME_ASSISTANT:-false}" == "true" ]]; then
    log "• Home Assistant: http://${PI_STATIC_IP}:8123 (via host network)"
fi

log "Next steps:"
log "==========="
log "1. Configure your router to use ${PI_STATIC_IP} as the primary DNS server for your LAN."
log "2. Test DNS resolution and ad-blocking from a client device: dig @${PI_STATIC_IP} google.com and dig @${PI_STATIC_IP} doubleclick.net"
log "3. Check Pi-hole logs for activity: docker logs pihole"
log "4. Perform system maintenance: ~/pihole-server/scripts/maintenance.sh status"
echo ""

log "For detailed troubleshooting steps, refer to: ~/pihole-server/docs/troubleshooting.md"
log "For enhancing server security, refer to: ~/pihole-server/docs/security-hardening.md"
log "For the architectural design and rationale, refer to: ~/pihole-server/docs/LAN_ONLY_STACK_PLAN.md and ~/pihole-server/docs/adr/0001-lan-only-design.md"
