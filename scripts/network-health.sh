#!/bin/bash

# Network health monitoring and recovery script
# Part of the Raspberry Pi Home Server stack

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
fi

# Configuration
NETWORK_CHECK_RETRIES=${NETWORK_CHECK_RETRIES:-3}
NETWORK_CHECK_DELAY=${NETWORK_CHECK_DELAY:-10}
DNS_TEST_DOMAINS=("google.com" "cloudflare.com" "github.com")
LOG_FILE="${SCRIPT_DIR}/../logs/health-check.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

check_network_health() {
    local retries=$NETWORK_CHECK_RETRIES
    local delay=$NETWORK_CHECK_DELAY
    
    for i in $(seq 1 $retries); do
        if ping -c 3 -W 5 8.8.8.8 >/dev/null 2>&1; then
            log "Network connectivity: OK"
            return 0
        fi
        warn "Network check failed (attempt $i/$retries)"
        sleep $delay
    done
    
    error "Network connectivity: FAILED after $retries attempts"
    return 1
}

check_dns_resolution() {
    local failed_domains=()
    
    for domain in "${DNS_TEST_DOMAINS[@]}"; do
        if dig @127.0.0.1 "$domain" +short +timeout=5 >/dev/null 2>&1; then
            log "DNS resolution for $domain: OK"
        else
            warn "DNS resolution for $domain: FAILED"
            failed_domains+=("$domain")
        fi
    done
    
    if [[ ${#failed_domains[@]} -eq 0 ]]; then
        log "DNS resolution: All tests passed"
        return 0
    else
        error "DNS resolution failed for: ${failed_domains[*]}"
        return 1
    fi
}

check_container_health() {
    local containers=("pihole" "unbound")
    local unhealthy_containers=()
    
    for container in "${containers[@]}"; do
        if docker ps --filter "name=$container" --filter "status=running" --format "{{.Names}}" | grep -q "$container"; then
            # Check if container has health check
            local health_status
            health_status=$(docker inspect "$container" --format='{{.State.Health.Status}}' 2>/dev/null || echo "no-healthcheck")
            
            if [[ "$health_status" == "healthy" ]] || [[ "$health_status" == "no-healthcheck" ]]; then
                log "Container $container: OK ($health_status)"
            else
                warn "Container $container: UNHEALTHY ($health_status)"
                unhealthy_containers+=("$container")
            fi
        else
            error "Container $container: NOT RUNNING"
            unhealthy_containers+=("$container")
        fi
    done
    
    if [[ ${#unhealthy_containers[@]} -eq 0 ]]; then
        log "Container health: All containers healthy"
        return 0
    else
        error "Unhealthy containers: ${unhealthy_containers[*]}"
        return 1
    fi
}

check_pihole_functionality() {
    local pi_ip="${PI_STATIC_IP:-192.168.0.100}"
    
    # Test DNS query
    if dig "@$pi_ip" google.com +short +timeout=5 >/dev/null 2>&1; then
        log "Pi-hole DNS query: OK"
    else
        warn "Pi-hole DNS query: FAILED"
        return 1
    fi
    
    # Test ad blocking
    if dig "@$pi_ip" doubleclick.net +short +timeout=5 | grep -q "0.0.0.0"; then
        log "Pi-hole ad blocking: OK"
    else
        warn "Pi-hole ad blocking: FAILED or not configured"
        return 1
    fi
    
    # Test web interface
    if curl -s --connect-timeout 5 "http://$pi_ip/admin/api.php?summary" | grep -q "queries_blocked_today"; then
        log "Pi-hole web interface: OK"
    else
        warn "Pi-hole web interface: FAILED"
        return 1
    fi
    
    return 0
}

restart_services_if_needed() {
    local network_ok=false
    local dns_ok=false
    local containers_ok=false
    local pihole_ok=false
    
    # Run all health checks
    check_network_health && network_ok=true
    check_dns_resolution && dns_ok=true
    check_container_health && containers_ok=true
    check_pihole_functionality && pihole_ok=true
    
    # Determine if restart is needed
    if [[ "$network_ok" == true && "$dns_ok" == true && "$containers_ok" == true && "$pihole_ok" == true ]]; then
        log "All health checks passed - no restart needed"
        return 0
    fi
    
    log "Health check failures detected, attempting service restart..."
    
    # Navigate to project directory
    cd "${SCRIPT_DIR}/.." || {
        error "Could not navigate to project directory"
        return 1
    }
    
    # Restart Docker daemon if network issues
    if [[ "$network_ok" == false ]]; then
        log "Restarting Docker daemon due to network issues..."
        sudo systemctl restart docker
        sleep 15
    fi
    
    # Restart Pi-hole stack
    log "Restarting Pi-hole stack..."
    if docker compose -f docker/docker-compose.core.yml restart; then
        log "Docker containers restarted successfully"
    else
        error "Failed to restart Docker containers"
        return 1
    fi
    
    # Wait for services to stabilize
    log "Waiting for services to stabilize..."
    sleep 30
    
    # Recheck health
    if check_network_health && check_dns_resolution && check_container_health && check_pihole_functionality; then
        log "Service restart successful - all health checks now pass"
        return 0
    else
        error "Service restart failed - manual intervention required"
        return 1
    fi
}

generate_health_report() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "=== HEALTH REPORT - $timestamp ===" | tee -a "$LOG_FILE"
    
    # System info
    echo "System Uptime: $(uptime -p)" | tee -a "$LOG_FILE"
    echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')" | tee -a "$LOG_FILE"
    echo "Memory Usage: $(free -h | grep '^Mem:' | awk '{print $3 "/" $2}')" | tee -a "$LOG_FILE"
    echo "Disk Usage: $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}')" | tee -a "$LOG_FILE"
    
    # Network info
    echo "IP Address: $(hostname -I | awk '{print $1}')" | tee -a "$LOG_FILE"
    
    # Container status
    echo "Container Status:" | tee -a "$LOG_FILE"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | tee -a "$LOG_FILE"
    
    echo "=================================" | tee -a "$LOG_FILE"
}

# Main execution
main() {
    local action="${1:-check}"
    
    case "$action" in
        "check")
            log "Starting network health check..."
            restart_services_if_needed
            log "Network health check completed"
            ;;
        "report")
            generate_health_report
            ;;
        "force-restart")
            log "Forcing service restart..."
            cd "${SCRIPT_DIR}/.." || exit 1
            docker compose -f docker/docker-compose.core.yml restart
            sleep 30
            restart_services_if_needed
            ;;
        *)
            echo "Usage: $0 [check|report|force-restart]"
            echo "  check        - Run health checks and restart services if needed (default)"
            echo "  report       - Generate detailed health report"
            echo "  force-restart - Force restart services and then check health"
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
