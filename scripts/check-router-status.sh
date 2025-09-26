#!/bin/bash

# Router Status Checker - View current monitoring status and flags
# Usage: ./check-router-status.sh [--watch] [--logs]

set -euo pipefail

MONITOR_DIR="/var/lib/pihole-server/monitoring"
FLAGS_DIR="$MONITOR_DIR/flags"
STATUS_FILE="$MONITOR_DIR/network-status.json"
MONITOR_LOG="/var/log/router-monitor.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_status() {
    echo -e "${BLUE}=== Pi-hole Server Router Monitoring Status ===${NC}"
    echo ""
    
    # Check if monitoring is set up
    if [[ ! -f "$STATUS_FILE" ]]; then
        echo -e "${RED}❌ Monitoring not initialized${NC}"
        echo "Run: sudo ./scripts/create-monitoring-flags.sh"
        exit 1
    fi
    
    # Show current status
    echo -e "${GREEN}📊 Current Status:${NC}"
    if command -v jq >/dev/null 2>&1; then
        cat "$STATUS_FILE" | jq -r '
        "  Last Check: " + .last_check +
        "\n  Router: " + .router_status + 
        "\n  Pi Status: " + .pi_status +
        "\n  Services: " + .services_status +
        "\n  Recovery Count: " + (.recovery_count | tostring) +
        "\n  Uptime: " + (.uptime_seconds | tostring) + " seconds" +
        "\n  Message: " + .message'
    else
        cat "$STATUS_FILE"
    fi
    echo ""
    
    # Show active flags
    echo -e "${YELLOW}🚩 Active Flags:${NC}"
    if [[ -d "$FLAGS_DIR" ]] && [[ -n "$(ls -A "$FLAGS_DIR" 2>/dev/null)" ]]; then
        for flag in "$FLAGS_DIR"/*; do
            if [[ -f "$flag" ]]; then
                flag_name=$(basename "$flag")
                flag_content=$(cat "$flag")
                echo -e "  ${RED}⚠️  $flag_name${NC}: $flag_content"
            fi
        done
    else
        echo -e "  ${GREEN}✅ No active flags (system healthy)${NC}"
    fi
    echo ""
    
    # Show recent log entries
    echo -e "${BLUE}📝 Recent Activity (last 10 entries):${NC}"
    if [[ -f "$MONITOR_LOG" ]]; then
        tail -10 "$MONITOR_LOG" | while read -r line; do
            if [[ "$line" == *"ALERT"* ]] || [[ "$line" == *"🚨"* ]]; then
                echo -e "  ${RED}$line${NC}"
            elif [[ "$line" == *"Gateway restored"* ]] || [[ "$line" == *"🎉"* ]]; then
                echo -e "  ${GREEN}$line${NC}"
            elif [[ "$line" == *"FLAG"* ]]; then
                echo -e "  ${YELLOW}$line${NC}"
            else
                echo "  $line"
            fi
        done
    else
        echo "  No log file found"
    fi
    echo ""
}

# Handle command line arguments
case "${1:-}" in
    --watch)
        echo "Watching router status (Ctrl+C to exit)..."
        while true; do
            clear
            show_status
            sleep 5
        done
        ;;
    --logs)
        echo -e "${BLUE}=== Full Router Monitor Logs ===${NC}"
        if [[ -f "$MONITOR_LOG" ]]; then
            tail -50 "$MONITOR_LOG"
        else
            echo "No log file found at $MONITOR_LOG"
        fi
        ;;
    *)
        show_status
        echo -e "${BLUE}Usage:${NC}"
        echo "  $0           - Show current status"
        echo "  $0 --watch   - Watch status in real-time"
        echo "  $0 --logs    - Show recent log entries"
        ;;
esac
