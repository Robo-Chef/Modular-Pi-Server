#!/usr/bin/env bash
# shellcheck source=./utils.sh
# shellcheck disable=SC1091  # Not following: source was not specified as input

# Test Deployment Script for Raspberry Pi Home Server
# This script validates the deployment and runs comprehensive tests against the deployed services.

set -Eeuo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utility functions for consistent logging and error handling.
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
    local expected_result="${3:-0}"  # Default to 0 if not provided
    local status output
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    log "Running test: $test_name"
    
    # Execute the command and capture output and status
    output="$(eval "$test_command" 2>&1)" || true
    status=$?
    
    # Check if the actual status matches the expected result
    if [ "$status" -eq "$expected_result" ]; then
        log " [PASS] $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error " [FAIL] $test_name"
        log_error "   Command: $test_command"
        log_error "   Output: $output"
        log_error "   Expected status: $expected_result"
        log_error "   Actual status: $status"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Function to run a test with custom comparison logic.
# Arguments:
#   $1: Name/description of the test.
#   $2: Command to execute (output will be captured).
#   $3: Command to evaluate the result (use $result to reference the output).
#   $4: Expected result (0 for success, 1 for failure).
run_test_custom() {
    local test_name="$1"
    local test_command="$2"
    local comparison_command="$3"
    local expected_result="${4:-0}"  # Default to 0 if not provided
    local output result status
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    log "Running test: $test_name"
    
    # Execute the test command and capture output and status
    output="$(eval "$test_command" 2>&1)" || true
    status=$?
    
    # Store the output in result for use in the comparison command
    result="$output"
    
    # Evaluate the comparison command
    if eval "$comparison_command" 2>/dev/null; then
        log " [PASS] $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error " [FAIL] $test_name"
        log_error "   Command: $test_command"
        log_error "   Output: $output"
        log_error "   Expected result: $expected_result"
        log_error "   Actual result: $result"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Main function to run all tests
main() {
    log "Starting Raspberry Pi Home Server deployment tests..."

    # --- System & Setup Checks ---

    # Test 1: Verify the .env file exists in the current directory.
    run_test ".env file exists" "test -f .env" 0

    # Test 2: Verify Docker is installed and running.
    run_test "Docker is installed" "command -v docker" 0
    run_test "Docker daemon is running" "docker info >/dev/null 2>&1" 0

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
    run_test_custom "DNS resolution via Pi-hole works" "dig @${PI_STATIC_IP} +short google.com | head -n 1" "[[ -n \"$result\" ]]"

    # Test 9: Verify ad blocking is active by querying a known ad domain (e.g., doubleclick.net).
    run_test_custom "Ad blocking via Pi-hole works" "dig @${PI_STATIC_IP} +short doubleclick.net" "[[ -z \"$result\" ]]"

    # Test 10: Check if the Pi-hole web interface is accessible from the host.
    run_test "Pi-hole web interface is accessible" "curl -f http://${PI_STATIC_IP}/admin/api.php?summary" 0

    # --- Monitoring Service Checks (if enabled) ---

    # Test 11: Check if monitoring services (Grafana, Uptime Kuma, Prometheus) are running if enabled.
    if [[ "${ENABLE_MONITORING:-true}" == "true" ]]; then
        run_test "Prometheus is running" "docker ps | grep -q prometheus" 0
        run_test "Grafana is running" "docker ps | grep -q grafana" 0
        run_test "Node Exporter is running" "docker ps | grep -q node-exporter" 0
        run_test "Alertmanager is running" "docker ps | grep -q alertmanager" 0

        # Test 12: Check if monitoring services are healthy.
        run_test "Prometheus is healthy" "curl -f http://localhost:9090/-/healthy" 0
        run_test "Grafana is healthy" "curl -f http://localhost:3000/api/health" 0
    fi

    # --- Security & Firewall Checks ---

    # Test 13: Check if nftables firewall is active.
    run_test "nftables firewall is active" "sudo systemctl is-active nftables" 0

    # Test 14: Check system resource usage (memory and disk) against reasonable thresholds.
    run_test_custom "Memory usage is reasonable (below 90%)" "free | awk 'NR==2{printf \"%.0f\", \$3*100/\$2}'" "[[ \"$result\" -lt 90 ]]"
    run_test_custom "Disk usage is reasonable (below 80% on root)" "df / | awk 'NR==2 {print \$5}' | sed 's/%//'" "[[ \"$result\" -lt 80 ]]"

    # Test 15: Verify existence of log files for core services.
    run_test "Pi-hole log file exists" "test -f /var/log/pihole.log" 0
    run_test "Unbound log file exists" "test -f /var/log/unbound.log" 0

    # --- Optional Service Checks ---

    # Test 16: Check if optional services (Portainer, Watchtower, Dozzle) are running if enabled.
    if [[ "${ENABLE_OPTIONAL_SERVICES:-true}" == "true" ]]; then
        run_test "Portainer is running" "docker ps | grep -q portainer" 0
        run_test "Watchtower is running" "docker ps | grep -q watchtower" 0
        run_test "Dozzle is running" "docker ps | grep -q dozzle" 0
    fi

    # Test 17: Check if backup directories exist and have content.
    run_test "Backup directory exists" "test -d /backups" 0
    run_test "Daily backup exists" "test -f /backups/daily-backup-*.tar.gz" 0

    # --- Performance Checks ---

    # Test 18: Check Pi-hole query performance.
    run_test_custom "Pi-hole query performance is good (below 100ms)" "docker exec pihole pihole -t | head -n 1 | awk '{print \$1}' | sed 's/ms//'" "[[ \"$result\" -lt 100 ]]"

    # Test 19: Check system load average.
    run_test_custom "System load average is reasonable (below 2.0)" "uptime | awk -F'load average:' '{ print \$2 }' | cut -d, -f1 | sed 's/ //g'" "[[ \"$(echo \"$result > 2.0\" | bc -l)\" -eq 0 ]]"

    # Test 20: Check available disk space on backup drive.
    run_test_custom "Backup disk has sufficient space (above 10GB)" "df /backups | awk 'NR==2 {print \$4}'" "[[ \"$result\" -gt 10485760 ]]"

    # --- Network & Connectivity Checks ---

    # Test 21: Verify internet connectivity.
    run_test "Internet connectivity works" "ping -c 1 8.8.8.8" 0

    # Test 22: Verify DNS resolution works externally.
    run_test "External DNS resolution works" "nslookup google.com" 0

    # Test 23: Check if all required ports are accessible.
    run_test "Pi-hole DNS port (53) is accessible" "nc -z ${PI_STATIC_IP} 53" 0
    run_test "Pi-hole web port (80) is accessible" "nc -z ${PI_STATIC_IP} 80" 0

    # Test 24: Check overall CPU usage of the system.
    run_test_custom "CPU usage is reasonable (below 80%)" "top -bn1 | grep 'Cpu(s)' | awk '{print \$2}' | sed 's/%us,//'" "[[ \"$result\" -lt 80 ]]"

    # Test 25: Check Pi-hole memory usage.
    run_test_custom "Pi-hole memory usage is reasonable (below 512 MiB)" "docker stats pihole --no-stream --format '{{.MemUsage}}' | awk -F'/' '{print \$1}' | sed 's/MiB//'" "[[ \"$result\" -lt 512 ]]"

    # Test 26: Check Unbound memory usage.
    run_test_custom "Unbound memory usage is reasonable (below 256 MiB)" "docker stats unbound --no-stream --format '{{.MemUsage}}' | awk -F'/' '{print \$1}' | sed 's/MiB//'" "[[ \"$result\" -lt 256 ]]"

    # --- Final Summary ---

    log "Test Results Summary:"
    log " Tests Passed: $TESTS_PASSED"
    log " Tests Failed: $TESTS_FAILED"
    log " Total Tests: $TOTAL_TESTS"

    if [ "$TESTS_FAILED" -gt 0 ]; then
        log_error "Some tests failed. Please review the output above."
        exit 1
    else
        log "All tests passed successfully! "
        exit 0
    fi
}

# Run the main function with all arguments
main "$@"
