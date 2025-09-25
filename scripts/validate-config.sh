#!/bin/bash

# Configuration Validation Script for Raspberry Pi Home Server
# This script validates all configuration files before deployment

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utility functions
source "${SCRIPT_DIR}/utils.sh"

log "🔍 Validating Raspberry Pi Home Server Configuration..."

# Initialize validation counters
VALIDATION_PASSED=0
VALIDATION_FAILED=0
TOTAL_VALIDATIONS=0

# Function to run a validation check
run_validation() {
    local test_name="$1"
    local test_command="$2"
    
    TOTAL_VALIDATIONS=$((TOTAL_VALIDATIONS + 1))
    
    log "Checking: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        log " ✅ $test_name"
        VALIDATION_PASSED=$((VALIDATION_PASSED + 1))
        return 0
    else
        log_error " ❌ $test_name"
        VALIDATION_FAILED=$((VALIDATION_FAILED + 1))
        return 1
    fi
}

log "📋 Running configuration validations..."

# Check if .env file exists
run_validation ".env file exists" "test -f .env"

# Check if .env has required variables (if .env exists)
if [[ -f ".env" ]]; then
    # shellcheck source=/dev/null
    source .env
    run_validation "PI_STATIC_IP is set" "[[ -n \"\${PI_STATIC_IP:-}\" ]]"
    run_validation "UNIVERSAL_PASSWORD is set" "[[ -n \"\${UNIVERSAL_PASSWORD:-}\" ]]"
    run_validation "TZ is set" "[[ -n \"\${TZ:-}\" ]]"
    run_validation "PIHOLE_HOSTNAME is set" "[[ -n \"\${PIHOLE_HOSTNAME:-}\" ]]"
fi

# Check Docker Compose files exist
run_validation "Core Docker Compose file exists" "test -f docker/docker-compose.core.yml"
run_validation "Monitoring Docker Compose file exists" "test -f docker/monitoring/docker-compose.monitoring.yml"
run_validation "Optional Docker Compose file exists" "test -f docker/optional/docker-compose.optional.yml"

# Check monitoring configuration files
run_validation "Prometheus config exists" "test -f monitoring/prometheus/prometheus.yml"
run_validation "Grafana datasource config exists" "test -f monitoring/grafana/provisioning/datasources/datasources.yml"
run_validation "Grafana dashboard config exists" "test -f monitoring/grafana/provisioning/dashboards/dashboard.yml"

# Check Unbound configuration
run_validation "Unbound config exists" "test -f docker/unbound/config/unbound.conf"

# Check scripts are executable (on Linux)
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    run_validation "Setup script is executable" "test -x scripts/setup.sh"
    run_validation "Quick deploy script is executable" "test -x scripts/quick-deploy.sh"
    run_validation "Maintenance script is executable" "test -x scripts/maintenance.sh"
    run_validation "Test deployment script is executable" "test -x scripts/test-deployment.sh"
fi

# Check for required directories
run_validation "Docker directory exists" "test -d docker"
run_validation "Monitoring directory exists" "test -d monitoring"
run_validation "Scripts directory exists" "test -d scripts"

# Validate YAML syntax (if yq is available)
if command -v yq &> /dev/null; then
    run_validation "Core Docker Compose YAML syntax" "yq eval '.' docker/docker-compose.core.yml >/dev/null"
    run_validation "Monitoring Docker Compose YAML syntax" "yq eval '.' docker/monitoring/docker-compose.monitoring.yml >/dev/null"
    run_validation "Optional Docker Compose YAML syntax" "yq eval '.' docker/optional/docker-compose.optional.yml >/dev/null"
    run_validation "Prometheus config YAML syntax" "yq eval '.' monitoring/prometheus/prometheus.yml >/dev/null"
fi

# Summary
log ""
log "📊 Validation Summary:"
log " ✅ Passed: $VALIDATION_PASSED"
log " ❌ Failed: $VALIDATION_FAILED"
log " 📋 Total: $TOTAL_VALIDATIONS"

if [[ $VALIDATION_FAILED -eq 0 ]]; then
    log "🎉 All validations passed! Configuration is ready for deployment."
    exit 0
else
    log_error "⚠️  Some validations failed. Please fix the issues above before deploying."
    exit 1
fi
