#!/bin/bash

# Raspberry Pi Home Server Setup Script
# This script automates the initial setup process

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utility functions from utils.sh.
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
    log "No .env file found, using defaults"
fi

# Ensure the script is not run as root to prevent permission issues with user's home directory and Docker.
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root. Please run as a regular user with sudo privileges."
fi

# Verify the .env file exists, which contains essential environment variables for the setup.
if [[ ! -f "${SCRIPT_DIR}/../.env" ]]; then
    error ".env file not found. Please copy env.example to .env and configure it."
fi

# Environment variables are already loaded from .env file above (lines 16-25)

log "Starting Raspberry Pi Home Server setup..."

# Update and upgrade all installed packages to ensure the system is up-to-date and secure.
log "Updating system packages..."
if ! (sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt -o Dpkg::Options::="--force-confold" upgrade -y); then
    error "Failed to update or upgrade system packages."
fi

# Install essential system utilities and network tools.
log "Installing essential packages (curl, wget, git, vim, htop, nftables, jq, dnsutils)..."
if ! sudo apt install -y curl wget git vim htop nftables jq dnsutils; then
    error "Failed to install essential packages."
fi

# Install Docker if it's not already present.
log "Installing Docker (if not already installed)..."
if ! command -v docker &> /dev/null; then
    if ! curl -fsSL https://get.docker.com | sh; then
        error "Failed to install Docker."
    fi
    # Add the current user to the 'docker' group to allow running docker commands without sudo.
    if ! sudo usermod -aG docker "$USER"; then
        error "Failed to add user to docker group."
    fi
    log "Docker installed. Please log out and back in for group changes to take effect. Then re-run quick-deploy.sh."
fi

# Install Docker Compose plugin if it's not already present.
log "Installing Docker Compose plugin (if not already installed)..."
if ! command -v docker compose &> /dev/null; then
    if ! sudo apt install -y docker-compose-plugin; then
        error "Failed to install Docker Compose plugin."
    fi
fi

# Configure SSH daemon for password authentication (port configured via SSH_PORT in .env)
log "Configuring SSH daemon to allow password authentication for initial setup..."
log "SSH will use port ${SSH_PORT:-22} (configured in .env file)"
# Configure SSH port if different from default
if [[ "${SSH_PORT:-22}" != "22" ]]; then
    log "Configuring SSH to use port ${SSH_PORT}"
    sudo sed -i "s/^#Port 22/Port ${SSH_PORT}/" /etc/ssh/sshd_config || warn "Could not set SSH port to ${SSH_PORT}"
    sudo sed -i "s/^Port 22/Port ${SSH_PORT}/" /etc/ssh/sshd_config || warn "Could not change existing SSH port to ${SSH_PORT}"
fi

# Ensure password authentication is enabled (crucial for initial setup before key-based auth).
sudo sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config || warn "Could not uncomment PasswordAuthentication yes."
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config || warn "Could not set PasswordAuthentication to yes. Check sshd_config."
# Restart SSH service to apply changes
if systemctl list-units --type=service | grep -q "ssh.service"; then
  sudo systemctl restart ssh || warn "Could not restart SSH service. Changes will apply after reboot."
elif systemctl list-units --type=service | grep -q "sshd.service"; then
  sudo systemctl restart sshd || warn "Could not restart SSH service. Changes will apply after reboot."
else
  warn "Could not determine SSH service name. SSH changes will apply after reboot."
fi

# Create essential project directories if they don't exist.
log "Creating project directories for configs, docker, scripts, monitoring, backups, and docs..."
mkdir -p ~/pihole-server/{configs,docker,scripts,monitoring,backups,docs} || error "Failed to create base project directories."
mkdir -p ~/pihole-server/docker/{pihole,unbound,monitoring,optional} || error "Failed to create docker subdirectories."
mkdir -p ~/pihole-server/monitoring/{prometheus,grafana,uptime-kuma} || error "Failed to create monitoring subdirectories."
mkdir -p ~/pihole-server/backups/{daily,weekly,monthly} || error "Failed to create backup subdirectories."

# Set appropriate permissions for the project root and backup directory.
chmod 755 ~/pihole-server || warn "Failed to set permissions for ~/pihole-server."
chmod 700 ~/pihole-server/backups || warn "Failed to set permissions for ~/pihole-server/backups."

# Configure kernel parameters for network and memory optimization.
log "Configuring kernel parameters for network and memory management..."
# Use tee to write the sysctl configuration to a file.
sudo tee /etc/sysctl.d/99-rpi.conf > /dev/null <<EOF
# Network optimizations: Increase receive and send buffer sizes.
net.core.rmem_max=${NETWORK_BUFFER_SIZE:-26214400}
net.core.wmem_max=${NETWORK_BUFFER_SIZE:-26214400}
net.ipv4.tcp_rmem=4096 65536 ${NETWORK_BUFFER_SIZE:-26214400}
net.ipv4.tcp_wmem=4096 65536 ${NETWORK_BUFFER_SIZE:-26214400}

# Memory management: Reduce swappiness to minimize SD card wear, tune dirty page ratios.
vm.swappiness=${VM_SWAPPINESS:-1}
vm.dirty_ratio=${VM_DIRTY_RATIO:-15}
vm.dirty_background_ratio=${VM_DIRTY_BACKGROUND_RATIO:-5}

# File system optimizations: Increase maximum number of open file descriptors.
fs.file-max=${FS_FILE_MAX:-65536}
EOF

# Apply the new kernel parameters.
sudo sysctl -p /etc/sysctl.d/99-rpi.conf || error "Failed to apply new kernel parameters."

# Configure nftables firewall rules.
log "Configuring nftables firewall rules..."
sudo tee /etc/nftables.conf > /dev/null <<EOF
#!/usr/bin/nft -f

# Flush any existing rules to start fresh.
flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        
        # Allow established and related connections for active sessions.
        ct state {established, related} accept
        
        # Allow all traffic on the loopback interface.
        iifname "lo" accept
        
        # Allow SSH connections on the configured port from any source on the LAN.
        tcp dport ${SSH_PORT:-22} accept
        
        # Allow DNS queries (TCP and UDP) for Pi-hole.
        tcp dport ${DNS_PORT:-53} accept
        udp dport ${DNS_PORT:-53} accept
        
        # Allow web interfaces (Pi-hole, Grafana, Uptime Kuma, HTTPS).
        tcp dport ${HTTP_PORT:-80} accept
        tcp dport ${HTTPS_PORT:-443} accept
        tcp dport ${GRAFANA_PORT:-3000} accept
        tcp dport ${UPTIME_KUMA_PORT:-3001} accept
        
        # Allow ICMP echo-requests (ping) for basic network diagnostics.
        icmp type echo-request accept
        
        # Explicitly drop all other incoming traffic.
        counter drop
    }
    
    chain forward {
        type filter hook forward priority 0; policy drop; # Block all forwarded traffic by default.
    }
    
    chain output {
        type filter hook output priority 0; policy accept; # Allow all outbound traffic from the Pi.
    }
}
EOF

# Enable and start the nftables service.
sudo systemctl enable nftables || error "Failed to enable nftables service."
sudo systemctl start nftables || error "Failed to start nftables service."

# Note: Docker network creation moved to deployment scripts where Docker daemon is guaranteed to be running
# and user has proper group permissions. Networks will be created during actual deployment.

# Note: The commented-out cp commands are for manual copying of files, 
# but with git clone, these files are already in place. 
# log "Copying configuration files..."
# cp -r docker/* ~/pihole-server/docker/
# cp -r monitoring/* ~/pihole-server/monitoring/
# cp -r configs/* ~/pihole-server/configs/
# cp scripts/* ~/pihole-server/scripts/

# Set up log rotation for Docker container logs to prevent disk space exhaustion.
log "Configuring log rotation for Docker container logs..."
sudo tee /etc/logrotate.d/pihole-server > /dev/null <<EOF
/var/lib/docker/containers/*/*.log {
    daily             # Rotate logs daily.
    missingok         # Don't error if log file is missing.
    rotate 7          # Keep 7 rotated logs.
    compress          # Compress old logs.
    delaycompress     # Compress on the next rotation cycle.
    notifempty        # Don't rotate if the log file is empty.
    create 0644 root root # Create new log file with specific permissions.
    postrotate        # Commands to run after rotation.
        # Signal Docker to re-open logs without restarting containers.
        docker kill --signal="USR1" \$(docker ps -q) 2>/dev/null || true
    endscript
}
EOF

# Create the automated backup script dynamically.
log "Creating and setting permissions for the automated backup script (scripts/backup.sh)..."
sudo tee ~/pihole-server/scripts/backup.sh > /dev/null <<'EOF'
#!/bin/bash

# Source utility functions for logging and error handling.
source "$(dirname "$0")"/utils.sh

BACKUP_DIR="${BACKUP_DIR:-/home/${USER}/pihole-server/backups/daily}"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-30}

log "Starting backup to $BACKUP_DIR/$DATE..."

# Create backup directory, exit if creation fails.
mkdir -p "$BACKUP_DIR/$DATE" || error "Failed to create backup directory: $BACKUP_DIR/$DATE"

# Backup Pi-hole configuration if the container is running.
if docker ps | grep -q pihole; then
    log "Backing up Pi-hole configuration..."
    # Trigger Pi-hole's internal backup mechanism.
    docker exec pihole pihole -a -t || warn "Failed to run pihole -a -t command. Pi-hole backup may be incomplete."
    # Copy Pi-hole's configuration files to the backup directory.
    cp "$(pwd)"/docker/pihole/etc-pihole/* "$BACKUP_DIR/$DATE/" 2>/dev/null || warn "Failed to copy Pi-hole configuration files. Check source/destination."
else
    warn "Pi-hole container not running, skipping Pi-hole configuration backup."
fi

# Backup all Docker Compose files.
log "Backing up Docker Compose files..."
cp "$(pwd)"/docker/*.yml "$BACKUP_DIR/$DATE/" || warn "Failed to copy Docker Compose files. Check source/destination."

# Backup other configuration files from the 'configs' directory.
log "Backing up other configuration files from 'configs' directory..."
cp -r "$(pwd)"/configs "$BACKUP_DIR/$DATE/" || warn "Failed to copy configuration files from 'configs' directory. Check source/destination."

# Clean up old backups based on retention policy.
log "Cleaning up old backups (retaining $RETENTION_DAYS days)..."
find "$BACKUP_DIR" -type d -mtime +$RETENTION_DAYS -exec rm -rf {} + 2>/dev/null || warn "Failed to clean up old backup directories. Manual cleanup may be required."

log "Backup completed: $BACKUP_DIR/$DATE"
EOF

chmod +x ~/pihole-server/scripts/backup.sh || error "Failed to set execute permissions on backup.sh."

# Set up a cron job to run the backup script daily at 2 AM.
log "Setting up automated daily backups via cron..."
(crontab -l 2>/dev/null; echo "0 2 * * * /home/${USER}/pihole-server/scripts/backup.sh") | crontab - || error "Failed to set up cron job for backups."

# Set up router monitoring for automatic reboot detection and recovery
log "Setting up router reboot monitoring via cron..."
(crontab -l 2>/dev/null; echo "*/2 * * * * /home/${USER}/pihole-server/scripts/router-monitor.sh >/dev/null 2>&1") | crontab - || error "Failed to set up cron job for router monitoring."

# Create and configure the systemd service for Docker Compose.
log "Creating and enabling systemd service for Docker Compose..."
sudo tee /etc/systemd/system/pihole-server.service > /dev/null <<EOF
[Unit]
Description=Pi-hole Home Server with Router Reboot Resilience
# Ensure Docker service and network are online before starting.
Requires=docker.service network.target
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot          # Service runs once and stays active.
RemainAfterExit=yes   # Systemd considers the service active even after ExecStart finishes.
WorkingDirectory=/home/${USER}/pihole-server # Set working directory to project root.
# Start all Docker Compose services as a combined stack.
ExecStart=/usr/bin/docker compose -f docker/docker-compose.core.yml up -d
# Stop all Docker Compose services.
ExecStop=/usr/bin/docker compose -f docker/docker-compose.core.yml down
TimeoutStartSec=0     # Disable startup timeout.
# Auto-restart configuration for network resilience
Restart=always        # Always restart if the service stops
RestartSec=30         # Wait 30 seconds before restarting
StartLimitBurst=5     # Allow 5 restart attempts
StartLimitIntervalSec=300  # Within 5 minutes

[Install]
WantedBy=multi-user.target # Start service when the system reaches multi-user runlevel.
EOF

# Reload systemd to recognize the new service file and enable it to start on boot.
sudo systemctl daemon-reload || error "Failed to reload systemd daemon."
sudo systemctl enable pihole-server.service || error "Failed to enable pihole-server.service."

log "Setup completed successfully!"
log "Next steps:"
log "1. Reboot the system for all changes to take full effect: sudo reboot"
log "2. Start the services (if not already started after reboot): sudo systemctl start pihole-server.service"
log "3. Check service status: sudo systemctl status pihole-server.service"
log "4. Access Pi-hole web interface: http://${PI_STATIC_IP}/admin (replace with your Pi's IP)"
log "5. Configure your router to use ${PI_STATIC_IP} as the primary DNS server"
log "For detailed post-setup information, refer to RASPBERRY_PI_SERVER_SETUP.md and other documentation."
