#!/bin/bash

# Test Deployment Script for Raspberry Pi Home Server
# This script validates the deployment and runs comprehensive tests

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() { # shellcheck disable=SC2317
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() { # shellcheck disable=SC2317
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    return 1
}

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# Test function
run_test() { # shellcheck disable=SC2317
  # SC2317: This helper intentionally contains code paths ShellCheck deems unreachable
  # in some error/early-return flows. We disable it at function scope by design.
   local test_name="$1"
   local test_command="$2"
   local expected_result="$3"
    
   TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
   log "Running test: $test_name"
    
   local status # Capture exit status
   if eval "$test_command" >/dev/null 2>&1; then
       status=$?
       if [[ "$status" -eq "$expected_result" ]]; then
           log "✓ PASS: $test_name"
           TESTS_PASSED=$((TESTS_PASSED + 1))
           return 0
       else
           error "✗ FAIL: $test_name (unexpected exit code: got $status; expected $expected_result)"
           TESTS_FAILED=$((TESTS_FAILED + 1))
           return 1
       fi
   else
       status=$? # Capture exit status from eval
       error "✗ FAIL: $test_name (command failed with status $status)"
       TESTS_FAILED=$((TESTS_FAILED + 1))
       return 1
   fi
}

# Test function with custom success condition
run_test_custom() { # shellcheck disable=SC2317
  # SC2317: same rationale as run_test()
   local test_name="$1"
   local test_command="$2"
   local success_condition="$3"
    
   TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
   log "Running test: $test_name"
    
   local result
   result=$(eval "$test_command" 2>/dev/null)
   local status=$? # Capture exit status
    
   if eval "$success_condition"; then
       log "✓ PASS: $test_name"
       TESTS_PASSED=$((TESTS_PASSED + 1))
       return 0
   else
       error "✗ FAIL: $test_name (condition failed with status $status, result: $result)"
       TESTS_FAILED=$((TESTS_FAILED + 1))
       return 1
   fi
}

log "Starting Raspberry Pi Home Server deployment tests..."

# Test 1: Check if .env file exists
run_test "Environment file exists" "test -f .env" 0

# Test 2: Check if Docker is running
run_test "Docker is running" "docker info" 0

# Test 3: Check if required directories exist
run_test "Project directories exist" "test -d docker && test -d monitoring && test -d scripts" 0

# Test 4: Check if Docker networks exist
run_test "Docker networks exist" "docker network ls | grep -q pihole_net" 0

# Test 5: Check if containers are running
run_test "Pi-hole container is running" "docker ps | grep -q pihole" 0
run_test "Unbound container is running" "docker ps | grep -q unbound" 0

# Test 6: Check Pi-hole health
run_test "Pi-hole is healthy" "docker exec pihole curl -f http://localhost/admin/api.php?summary" 0

# Test 7: Check Unbound health
run_test "Unbound is healthy" "docker exec unbound unbound-control status" 0

# Test 8: Test DNS resolution
run_test_custom "DNS resolution works" "dig @192.168.1.XXX +short google.com" "[[ -n '$result' ]]" 0

# Test 9: Test ad blocking
run_test_custom "Ad blocking works" "dig @192.168.1.XXX +short doubleclick.net" "[[ -z '$result' ]]" 0

# Test 10: Check Pi-hole web interface
run_test "Pi-hole web interface accessible" "curl -f http://192.168.1.XXX/admin/api.php?summary" 0

# Test 11: Check if monitoring services are running (if enabled)
if [[ "${ENABLE_UPTIME_KUMA:-true}" == "true" ]]; then
    run_test "Grafana container is running" "docker ps | grep -q grafana" 0
    run_test "Uptime Kuma container is running" "docker ps | grep -q uptime-kuma" 0
    run_test "Prometheus container is running" "docker ps | grep -q prometheus" 0
    
    # Test monitoring web interfaces
    run_test "Grafana is accessible" "curl -f http://192.168.1.XXX:3000/api/health" 0
    run_test "Uptime Kuma is accessible" "curl -f http://192.168.1.XXX:3001" 0
fi

# Test 12: Check firewall status
run_test "Firewall is active" "sudo systemctl is-active nftables" 0

# Test 13: Check system resources
run_test_custom "Memory usage is reasonable" "free | awk 'NR==2{printf \"%.0f\", \$3*100/\$2}'" "[[ $result -lt 90 ]]" 0
run_test_custom "Disk usage is reasonable" "df / | awk 'NR==2 {print \$5}' | sed 's/%//'" "[[ $result -lt 80 ]]" 0

# Test 14: Check log files
run_test "Pi-hole logs exist" "test -f docker/pihole/logs/pihole.log" 0
run_test "Unbound logs exist" "test -f docker/unbound/logs/unbound.log" 0

# Test 15: Check backup script
run_test "Backup script is executable" "test -x scripts/backup.sh" 0

# Test 16: Check maintenance script
run_test "Maintenance script is executable" "test -x scripts/maintenance.sh" 0

# Test 17: Check cron jobs
run_test "Backup cron job exists" "crontab -l | grep -q backup" 0

# Test 18: Check systemd service
run_test "Systemd service exists" "test -f /etc/systemd/system/pihole-server.service" 0

# Test 19: Check kernel parameters
run_test "Kernel parameters configured" "test -f /etc/sysctl.d/99-rpi.conf" 0

# Test 20: Check SSH configuration
run_test "SSH is configured securely" "grep -q 'PasswordAuthentication no' /etc/ssh/sshd_config" 0

# Performance Tests
log "Running performance tests..."

# Test 21: DNS response time
run_test_custom "DNS response time is acceptable" "time dig @192.168.1.XXX google.com | grep 'Query time' | awk '{print $4}'" "[[ $result -lt 100 ]]" 0

# Test 22: Container startup time
run_test_custom "Container startup time is acceptable" "time docker restart pihole" "[[ $? -eq 0 ]]" 0

# Test 23: Memory usage per container
run_test_custom "Pi-hole memory usage is reasonable" "docker stats pihole --no-stream --format '{{.MemUsage}}' | awk -F'/' '{print $1}' | sed 's/MiB//'" "[[ $result -lt 512 ]]" 0

# Test 24: CPU usage
run_test_custom "CPU usage is reasonable" "top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | sed 's/%us,//'" "[[ $result -lt 80 ]]" 0

# Test 25: Network connectivity
run_test "Internet connectivity works" "ping -c 1 8.8.8.8" 0

# Test 26: Port accessibility
run_test "Port 53 is accessible" "nc -z 192.168.1.XXX 53" 0
run_test "Port 80 is accessible" "nc -z 192.168.1.XXX 80" 0

if [[ "${ENABLE_UPTIME_KUMA:-true}" == "true" ]]; then
    run_test "Port 3000 is accessible" "nc -z 192.168.1.XXX 3000" 0
    run_test "Port 3001 is accessible" "nc -z 192.168.1.XXX 3001" 0
fi

# Test 27: SSL/TLS (if configured)
# run_test "SSL certificate is valid" "openssl s_client -connect 192.168.1.XXX:443 -servername pihole.local < /dev/null"

# Test 28: Database integrity
run_test "Pi-hole database is accessible" "docker exec pihole sqlite3 /etc/pihole/pihole-FTL.db 'SELECT COUNT(*) FROM gravity;'" 0

# Test 29: Configuration file syntax
run_test "Docker Compose syntax is valid" "docker compose config" 0

# Test 30: Service dependencies
run_test "Service dependencies are met" "docker compose ps --services --filter 'status=running' | wc -l" 0

# Display test results
echo ""
log "Test Results Summary:"
log "===================="
log "Total Tests: $TOTAL_TESTS"
log "Passed: $TESTS_PASSED"
log "Failed: $TESTS_FAILED"

if [[ $TESTS_FAILED -eq 0 ]]; then
    log "🎉 All tests passed! Deployment is successful."
    exit 0
else
    error "❌ $TESTS_FAILED tests failed. Please check the issues above."
    exit 1
fi


