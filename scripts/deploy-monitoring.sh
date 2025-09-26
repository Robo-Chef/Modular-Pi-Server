#!/bin/bash

# Monitoring Stack Deployment Script
# Deploys Grafana, Prometheus, and Uptime Kuma for comprehensive monitoring

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
    exit 1
fi

# Check if monitoring is enabled
if [[ "${ENABLE_MONITORING:-false}" != "true" ]]; then
    log "Monitoring is disabled in .env (ENABLE_MONITORING=false). Skipping monitoring deployment."
    exit 0
fi

# Ensure required directories exist
log "Creating monitoring directories..."
mkdir -p docker/monitoring/grafana/{dashboards,provisioning/{dashboards,datasources,alerting}}
mkdir -p docker/monitoring/prometheus/{data,rules}
mkdir -p docker/monitoring/uptime-kuma/data
mkdir -p logs/monitoring

# Set proper permissions for monitoring directories
log "Setting monitoring directory permissions..."
# Grafana runs as UID 472
sudo chown -R 472:472 docker/monitoring/grafana/ 2>/dev/null || warn "Could not set Grafana directory ownership"
# Prometheus runs as UID 65534 (nobody)
sudo chown -R 65534:65534 docker/monitoring/prometheus/data 2>/dev/null || warn "Could not set Prometheus data directory ownership"

# Check if core services are running
log "Checking core services status..."
if ! docker ps | grep -q "pihole"; then
    warn "Pi-hole is not running. Starting core services first..."
    "${SCRIPT_DIR}/quick-deploy.sh" || error "Failed to start core services"
fi

# Deploy monitoring stack
log "Starting monitoring services..."
if docker compose -f docker/monitoring/docker-compose.monitoring.yml up -d; then
    log "Monitoring services started successfully"
else
    error "Failed to start monitoring services"
    exit 1
fi

# Wait for services to become healthy
log "Waiting for monitoring services to become healthy..."
sleep 15

# Check monitoring service status
check_monitoring_health() {
    local services=("grafana" "prometheus" "uptime-kuma")
    local failed_services=()
    
    for service in "${services[@]}"; do
        if docker ps --filter "name=$service" --filter "status=running" --format "{{.Names}}" | grep -q "$service"; then
            log "✓ $service: Running"
        else
            warn "✗ $service: Not running"
            failed_services+=("$service")
        fi
    done
    
    if [[ ${#failed_services[@]} -eq 0 ]]; then
        log "All monitoring services are running successfully"
        return 0
    else
        error "Failed services: ${failed_services[*]}"
        return 1
    fi
}

# Test monitoring endpoints
test_monitoring_endpoints() {
    local pi_ip="${PI_STATIC_IP:-192.168.0.100}"
    local grafana_port="${GRAFANA_PORT:-3000}"
    local prometheus_port="${PROMETHEUS_PORT:-9090}"
    local uptime_kuma_port="${UPTIME_KUMA_PORT:-3001}"
    
    log "Testing monitoring endpoints..."
    
    # Test Grafana
    if curl -s --connect-timeout 5 "http://$pi_ip:$grafana_port/api/health" | grep -q "ok"; then
        log "✓ Grafana: Accessible at http://$pi_ip:$grafana_port"
    else
        warn "✗ Grafana: Not accessible at http://$pi_ip:$grafana_port"
    fi
    
    # Test Prometheus (localhost only)
    if curl -s --connect-timeout 5 "http://127.0.0.1:$prometheus_port/-/healthy" | grep -q "Prometheus is Healthy"; then
        log "✓ Prometheus: Healthy (localhost:$prometheus_port)"
    else
        warn "✗ Prometheus: Not healthy (localhost:$prometheus_port)"
    fi
    
    # Test Uptime Kuma
    if curl -s --connect-timeout 5 "http://$pi_ip:$uptime_kuma_port" >/dev/null 2>&1; then
        log "✓ Uptime Kuma: Accessible at http://$pi_ip:$uptime_kuma_port"
    else
        warn "✗ Uptime Kuma: Not accessible at http://$pi_ip:$uptime_kuma_port"
    fi
}

# Set up basic monitoring targets
setup_monitoring_targets() {
    log "Setting up monitoring targets..."
    
    # Add network health check to cron if not already present
    if ! crontab -l 2>/dev/null | grep -q "network-health.sh"; then
        log "Adding network health check to cron..."
        (crontab -l 2>/dev/null; echo "*/5 * * * * ${SCRIPT_DIR}/network-health.sh check >> ${SCRIPT_DIR}/../logs/health-check.log 2>&1") | crontab -
        log "Network health check cron job added (runs every 5 minutes)"
    else
        log "Network health check cron job already exists"
    fi
    
    # Add daily health report
    if ! crontab -l 2>/dev/null | grep -q "network-health.sh report"; then
        log "Adding daily health report to cron..."
        (crontab -l 2>/dev/null; echo "0 6 * * * ${SCRIPT_DIR}/network-health.sh report >> ${SCRIPT_DIR}/../logs/daily-report.log 2>&1") | crontab -
        log "Daily health report cron job added (runs at 6 AM)"
    else
        log "Daily health report cron job already exists"
    fi
}

# Display access information
display_access_info() {
    local pi_ip="${PI_STATIC_IP:-192.168.0.100}"
    local grafana_port="${GRAFANA_PORT:-3000}"
    local uptime_kuma_port="${UPTIME_KUMA_PORT:-3001}"
    
    echo ""
    echo "🎉 Monitoring Stack Deployment Complete!"
    echo ""
    echo "📊 Access your monitoring dashboards:"
    echo "  • Grafana:     http://$pi_ip:$grafana_port"
    echo "    - Username:  admin"
    echo "    - Password:  ${UNIVERSAL_PASSWORD:-raspberry}"
    echo ""
    echo "  • Uptime Kuma: http://$pi_ip:$uptime_kuma_port"
    echo "    - First-time setup required"
    echo ""
    echo "  • Pi-hole:     http://$pi_ip/admin"
    echo "    - Password:  ${PIHOLE_PASSWORD:-raspberry}"
    echo ""
    echo "🔧 Monitoring Features:"
    echo "  • Network health checks every 5 minutes"
    echo "  • Daily health reports at 6 AM"
    echo "  • Container health monitoring"
    echo "  • DNS query success tracking"
    echo "  • System resource monitoring"
    echo ""
    echo "📋 Log Files:"
    echo "  • Health checks: ~/pihole-server/logs/health-check.log"
    echo "  • Daily reports: ~/pihole-server/logs/daily-report.log"
    echo "  • Monitoring:    docker logs grafana / docker logs uptime-kuma"
    echo ""
}

# Main execution
main() {
    log "🚀 Starting monitoring stack deployment..."
    
    # Run health check first
    check_monitoring_health || {
        log "Attempting to start monitoring services..."
        docker compose -f docker/monitoring/docker-compose.monitoring.yml up -d
        sleep 15
        check_monitoring_health || error "Failed to start monitoring services"
    }
    
    # Test endpoints
    test_monitoring_endpoints
    
    # Set up automated monitoring
    setup_monitoring_targets
    
    # Display access information
    display_access_info
    
    log "✅ Monitoring stack deployment completed successfully!"
}

# Execute main function
main "$@"
