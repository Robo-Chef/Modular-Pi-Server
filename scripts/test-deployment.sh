#!/bin/bash

# Test Deployment Script for Raspberry Pi Home Server
# This script validates the deployment and runs comprehensive tests against the deployed services.

set -euo pipefail # Exit immediately if a command exits with a non-zero status, exit if an undeclared variable is used, and propagate pipefail status.

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utility functions for consistent logging and error handling.
# shellcheck source=./utils.sh
source "${SCRIPT_DIR}/utils.sh"

# Initialize counters for tracking test results.
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# Generic function to run a test command and compare its exit status with an expected result.
# Arguments:
#   $1: Name/description of the test.
#   $2: The command string to execute.
#   $3: The expected exit status (0 for success).
run_test() {
   local test_name="$1"
   local test_command="$2"
   local expected_result="$3"
   local status
   
   TOTAL_TESTS=$((TOTAL_TESTS + 1))
   
   log "Running test: $test_name"
   
   # Execute the command and suppress its output, capturing only the exit status.
   if eval "$test_command" >/dev/null 2>&1; then
       status=$?
       if [[ "$status" -eq "$expected_result" ]]; then
           log " PASS: $test_name"
           TESTS_PASSED=$((TESTS_PASSED + 1))
           return 0
       else
           error " FAIL: $test_name (unexpected exit code: got $status; expected $expected_result)"
           TESTS_FAILED=$((TESTS_FAILED + 1))
           return 1
       fi
   else
       status=$? # Capture exit status from eval in case the command itself failed.
       error " FAIL: $test_name (command failed with status $status)"
       TESTS_FAILED=$((TESTS_FAILED + 1))
       return 1
   fi
}

# Function to run a test with custom comparison logic.
# Arguments:
#   $1: Name/description of the test.
#   $2: Command to execute (output will be captured).
#   $3: Comparison command to evaluate the output.
#   $4: Expected exit status (0 for success).
run_test_custom() {
    local test_name="$1"
    local test_command="$2"
    local comparison_command="$3"
    local expected_result="$4"
    local output
    local status
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    log "Running test: $test_name"
    
    # Execute the command and capture its output and status
    output=$(eval "$test_command" 2>&1)
    status=$?
    
    # Evaluate the comparison command
    if eval "$comparison_command" <<<"$output" 2>/dev/null; then
        if [[ "$status" -eq "$expected_result" ]]; then
            log " PASS: $test_name"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        else
            error " FAIL: $test_name (unexpected exit code: got $status; expected $expected_result)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    else
        error " FAIL: $test_name (output comparison failed)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

log "Starting Raspberry Pi Home Server deployment tests..."

# --- System & Setup Checks ---

# Test 1: Verify the .env file exists in the current directory.
run_test "Environment file (.env) exists" "test -f .env" 0

# Test 2: Verify Docker daemon is running and accessible.
run_test "Docker daemon is running" "docker info" 0

# Test 3: Verify essential project directories are present.
run_test "Project directories (docker, monitoring, scripts) exist" "test -d docker && test -d monitoring && test -d scripts" 0

# Test 4: Verify Docker custom networks for Pi-hole and monitoring are created.
run_test "Pi-hole Docker network exists" "docker network ls | grep -q pihole_net" 0

# --- Core Service Checks (Pi-hole & Unbound) ---

# Test 5: Verify core Docker containers (Pi-hole and Unbound) are running.
run_test "Pi-hole container is running" "docker ps | grep -q pihole" 0
run_test "Unbound container is running" "docker ps | grep -q unbound" 0

# Test 6: Check Pi-hole's internal health endpoint.
run_test "Pi-hole is healthy" "docker exec pihole curl -f http://localhost/admin/api.php?summary" 0

# Test 7: Check Unbound's internal status using unbound-control.
run_test "Unbound is healthy" "docker exec unbound unbound-control status" 0

# Test 8: Verify DNS resolution works via Pi-hole for a known domain (e.g., google.com).
run_test_custom "DNS resolution via Pi-hole works" "dig @${PI_STATIC_IP} +short google.com" "[[ -n \"$result\" ]]" 0

# Test 9: Verify ad blocking is active by querying a known ad domain (e.g., doubleclick.net).
run_test_custom "Ad blocking via Pi-hole works" "dig @${PI_STATIC_IP} +short doubleclick.net" "[[ -z \"$result\" ]]" 0

# Test 10: Check if the Pi-hole web interface is accessible from the host.
run_test "Pi-hole web interface is accessible" "curl -f http://${PI_STATIC_IP}/admin/api.php?summary" 0

# --- Monitoring Service Checks (if enabled) ---

# Test 11: Check if monitoring services (Grafana, Uptime Kuma, Prometheus) are running if enabled.
if [[ "${ENABLE_MONITORING:-true}" == "true" ]]; then
    run_test "Grafana container is running" "docker ps | grep -q grafana" 0
    run_test "Uptime Kuma container is running" "docker ps | grep -q uptime-kuma" 0
    run_test "Prometheus container is running" "docker ps | grep -q prometheus" 0
    
    # Test accessibility of monitoring web interfaces.
    run_test "Grafana web interface is accessible" "curl -f http://${PI_STATIC_IP}:3000/api/health" 0
    run_test "Uptime Kuma web interface is accessible" "curl -f http://${PI_STATIC_IP}:3001" 0
fi

# --- System & Security Checks ---

# Test 12: Verify nftables firewall service is active.
run_test "nftables firewall is active" "sudo systemctl is-active nftables" 0

# Test 13: Check system resource usage (memory and disk) against reasonable thresholds.
run_test_custom "Memory usage is reasonable (below 90%)" "free | awk 'NR==2{printf \"%.0f\", \$3*100/\$2}'" "[[ \"$result\" -lt 90 ]]" 0
run_test_custom "Disk usage is reasonable (below 80% on root)" "df / | awk 'NR==2 {print \$5}' | sed 's/%//'" "[[ \"$result\" -lt 80 ]]" 0

# Test 14: Verify existence of log files for core services.
run_test "Pi-hole logs exist" "test -f docker/pihole/logs/pihole.log" 0
run_test "Unbound logs exist" "test -f docker/unbound/logs/unbound.log" 0

# Test 15: Check if the backup script is executable.
run_test "Backup script (scripts/backup.sh) is executable" "test -x scripts/backup.sh" 0

# Test 16: Check if the maintenance script is executable.
run_test "Maintenance script (scripts/maintenance.sh) is executable" "test -x scripts/maintenance.sh" 0

# Test 17: Verify the automated backup cron job is configured.
run_test "Automated backup cron job exists" "crontab -l | grep -q backup" 0

# Test 18: Check if the systemd service for Docker Compose exists.
run_test "Systemd service (pihole-server.service) exists" "test -f /etc/systemd/system/pihole-server.service" 0

# Test 19: Verify kernel parameters configuration file exists.
run_test "Kernel parameters configuration exists" "test -f /etc/sysctl.d/99-rpi.conf" 0

# Test 20: Check SSH configuration to ensure password authentication is still enabled (for initial setup).
run_test "SSH is configured to allow password authentication" "grep -q 'PasswordAuthentication yes' /etc/ssh/sshd_config" 0

# --- Performance Tests ---

log "Running performance tests..."

# Test 21: Measure DNS response time for a public domain.
run_test_custom "DNS response time is acceptable (below 100ms)" "time dig @${PI_STATIC_IP} google.com | grep 'Query time' | awk '{print $4}'" "[[ \"$result\" -lt 100 ]]" 0

# Test 22: Verify Docker container restart functionality and time.
run_test_custom "Pi-hole container restarts successfully" "time docker restart pihole" "[[ \"$? \" -eq 0 ]]" 0

# Test 23: Check Pi-hole's memory usage.
run_test_custom "Pi-hole memory usage is reasonable (below 512 MiB)" "docker stats pihole --no-stream --format '{{.MemUsage}}' | awk -F'/' '{print $1}' | sed 's/MiB//'" "[[ \"$result\" -lt 512 ]]" 0

# Test 24: Check overall CPU usage of the system.
run_test_custom "CPU usage is reasonable (below 80%)" "top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | sed 's/%us,//'" "[[ \"$result\" -lt 80 ]]" 0

# Test 25: Verify external network connectivity.
run_test "Internet connectivity is working (ping 8.8.8.8)" "ping -c 1 8.8.8.8" 0

# Test 26: Check accessibility of core service ports.
run_test "Port 53 (DNS) is accessible" "nc -z ${PI_STATIC_IP} 53" 0
run_test "Port 80 (HTTP for Pi-hole) is accessible" "nc -z ${PI_STATIC_IP} 80" 0

# Check accessibility of monitoring service ports if enabled.
if [[ "${ENABLE_MONITORING:-true}" == "true" ]]; then
    run_test "Port 3000 (Grafana) is accessible" "nc -z ${PI_STATIC_IP} 3000" 0
    run_test "Port 3001 (Uptime Kuma) is accessible" "nc -z ${PI_STATIC_IP} 3001" 0
fi

# Test 27 (Optional): Placeholder for SSL/TLS certificate validity check.
# This test is commented out as SSL/TLS is not part of the default LAN-only setup.
# run_test "SSL certificate is valid" "openssl s_client -connect ${PI_STATIC_IP}:443 -servername pihole.local < /dev/null"

# Test 28: Verify Pi-hole's FTL database is accessible and functional.
run_test "Pi-hole FTL database is accessible" "docker exec pihole sqlite3 /etc/pihole/pihole-FTL.db 'SELECT COUNT(*) FROM gravity;'" 0

# Test 29: Validate the syntax of the combined Docker Compose configuration.
run_test "Docker Compose syntax is valid" "docker compose -f docker-compose.core.yml -f monitoring/docker-compose.monitoring.yml -f optional/docker-compose.optional.yml config" 0

# Test 30: Verify all expected services are running in Docker Compose.
run_test_custom "All expected Docker Compose services are running" "docker compose ps --services --filter 'status=running' | wc -l" "[[ \"$result\" -ge 2 ]]" 0 # At least Pi-hole and Unbound should be running.

# --- Summary of Test Results ---

echo ""
log "Test Results Summary:"
log "===================="
log "Total Tests: $TOTAL_TESTS"
log "Passed: $TESTS_PASSED"
log "Failed: $TESTS_FAILED"

# Final status based on test outcomes.
if [[ $TESTS_FAILED -eq 0 ]]; then
    log " All tests passed! Deployment is successful and stable."
    exit 0
else
    error " $TESTS_FAILED tests failed. Please review the failures above and troubleshoot the issues."
fi
