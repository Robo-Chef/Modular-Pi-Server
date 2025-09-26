#!/bin/bash

# Deploy Monitoring Stack Script
# This script deploys the optional monitoring services (Prometheus, Grafana, Uptime Kuma, Node Exporter)

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utility functions from utils.sh
# shellcheck source=./utils.sh
source "${SCRIPT_DIR}/utils.sh"

# Load environment variables from .env file if it exists
if [[ -f "${SCRIPT_DIR}/../.env" ]]; then
    # Export all environment variables from .env file
    set -a  # automatically export all variables
    # shellcheck source=/dev/null
    source "${SCRIPT_DIR}/../.env"
    set +a  # stop automatically exporting
    log "Environment variables loaded from .env file"
else
    error "No .env file found. Please create one from env.example"
fi

log "🚀 Starting monitoring stack deployment..."

log "Creating monitoring directories..."
mkdir -p monitoring/prometheus
mkdir -p monitoring/grafana/provisioning/datasources
mkdir -p monitoring/grafana/provisioning/dashboards
mkdir -p monitoring/grafana/provisioning/alerting
mkdir -p monitoring/prometheus/rules

log "Setting monitoring directory permissions..."
# Prometheus runs as nobody (65534)
sudo chown -R 65534:65534 monitoring/prometheus 2>/dev/null || warn "Could not set Prometheus directory ownership."
# Grafana runs as root (472)
sudo chown -R 472:472 monitoring/grafana 2>/dev/null || warn "Could not set Grafana directory ownership."

log "Checking core services status..."
if ! docker compose -f docker/docker-compose.core.yml ps pihole unbound | grep -q "Up"; then
    warn "Core Pi-hole/Unbound services are not running. Monitoring may not function correctly."
fi

log "Starting monitoring services..."
if ! docker compose -f docker/monitoring/docker-compose.monitoring.yml up -d; then
    error "Failed to start monitoring services"
fi

log "Monitoring services started successfully"

log "Waiting for monitoring services to become healthy..."
wait_for_container_health grafana || warn "Grafana container failed health check."
wait_for_container_health prometheus || warn "Prometheus container failed health check."
wait_for_container_health node-exporter || warn "Node Exporter container failed health check."
wait_for_container_health uptime-kuma || warn "Uptime Kuma container failed health check."

log "🎉 Monitoring stack deployment complete!"
log ""
log "📊 Access your monitoring services:"
log "   • Grafana: http://${PI_STATIC_IP}:${GRAFANA_PORT:-3000} (admin/admin)"
log "   • Uptime Kuma: http://${PI_STATIC_IP}:${UPTIME_KUMA_PORT:-3001}"
log "   • Prometheus: http://${PI_STATIC_IP}:${PROMETHEUS_PORT:-9090} (localhost only)"
log ""
log "📋 Next steps:"
log "   1. Configure Grafana dashboards"
log "   2. Set up Uptime Kuma monitoring targets"
log "   3. Review Prometheus metrics collection"