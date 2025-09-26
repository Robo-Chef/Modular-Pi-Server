#!/bin/bash

# Deploy Monitoring Stack for Raspberry Pi Home Server
# This script deploys Prometheus, Grafana, Uptime Kuma, and Node Exporter

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utility functions
# shellcheck source=./utils.sh
source "${SCRIPT_DIR}/utils.sh"

# Load environment variables from .env file if it exists
if [[ -f "${SCRIPT_DIR}/../.env" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "${SCRIPT_DIR}/../.env"
    set +a
    log "Environment variables loaded from .env file"
else
    warn "No .env file found, using defaults"
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

log "Configuring Uptime Kuma with default admin account..."
"${SCRIPT_DIR}/configure-uptime-kuma.sh" || warn "Failed to auto-configure Uptime Kuma"

log "🎉 Monitoring stack deployment complete!"
log ""
log "📊 Access your monitoring services:"
log "   • Grafana: http://${PI_STATIC_IP}:${GRAFANA_PORT:-3000} (admin/${GRAFANA_ADMIN_PASSWORD:-raspberry})"
log "   • Uptime Kuma: http://${PI_STATIC_IP}:${UPTIME_KUMA_PORT:-3001} (admin/${UNIVERSAL_PASSWORD:-raspberry})"
log "   • Prometheus: http://${PI_STATIC_IP}:${PROMETHEUS_PORT:-9090} (advanced users)"
log ""
log "📋 Next steps:"
log "   1. Configure Grafana dashboards"
log "   2. Set up Uptime Kuma monitoring targets"
log "   3. Review Prometheus metrics at /targets"
log ""
log "🔧 Troubleshooting:"
log "   • Check logs: docker logs grafana"
log "   • Check logs: docker logs prometheus"
log "   • Check logs: docker logs uptime-kuma"