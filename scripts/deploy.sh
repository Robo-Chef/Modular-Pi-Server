#!/bin/bash

# One-Command Deployment Script for Raspberry Pi Home Server
# This script combines setup and deployment into a single command

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utility functions
source "${SCRIPT_DIR}/utils.sh"

# Source environment variables if .env exists
if [[ -f ".env" ]]; then
    source .env
fi

log "🚀 Starting One-Command Raspberry Pi Home Server Deployment..."

# Check if we're running as root
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root. Please run as a regular user with sudo privileges."
fi

# Check if .env file exists
if [[ ! -f ".env" ]]; then
    error ".env file not found. Please copy env.example to .env and configure it first."
fi

# Check if this is a fresh system (no Docker installed)
if ! command -v docker &> /dev/null; then
    log "📦 Fresh system detected - running full setup..."
    ./scripts/setup.sh
    log "⚠️  IMPORTANT: If Docker was installed, please log out and back in, then run this script again."
    log "   This ensures Docker group membership takes effect."
    exit 0
fi

# Check if Docker daemon is running
if ! docker info >/dev/null 2>&1; then
    error "Docker daemon is not running. Please start Docker first (sudo systemctl start docker)."
fi

# Check if Docker Compose is available
if ! command -v docker compose &> /dev/null; then
    error "Docker Compose is not installed. Please run ./scripts/setup.sh first."
fi

log "✅ Prerequisites check passed. Starting deployment..."

# Run the quick deployment
./scripts/quick-deploy.sh

log "🎉 Deployment completed successfully!"
log ""
log "📋 Next Steps:"
log "1. Configure your router to use ${PI_STATIC_IP} as Primary DNS"
log "2. Test DNS resolution: dig @${PI_STATIC_IP} google.com"
log "3. Test ad blocking: dig @${PI_STATIC_IP} doubleclick.net"
log "4. Access Pi-hole Admin: http://${PI_STATIC_IP}/admin"
log "5. Access Grafana: http://${PI_STATIC_IP}:3000"
log "6. Run comprehensive tests: ./scripts/test-deployment.sh"
log ""
log "🔧 For maintenance: ./scripts/maintenance.sh status"
log "📊 For monitoring: ./scripts/maintenance.sh full"
