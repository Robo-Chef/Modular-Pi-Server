#!/bin/bash

# Raspberry Pi Home Server Setup Script
# This script automates the initial setup process

set -euo pipefail

# Source utility functions
source "$(dirname "$0")"/utils.sh

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root. Please run as a regular user with sudo privileges."
fi

# Check if .env file exists
if [[ ! -f ".env" ]]; then
    error ".env file not found. Please copy env.example to .env and configure it."
fi

# shellcheck disable=SC1091
source .env

log "Starting Raspberry Pi Home Server setup..."

# Update system
log "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install essential packages
log "Installing essential packages..."
sudo apt install -y curl wget git vim htop nftables jq dnsutils

# Install Docker
log "Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$USER"
    log "Docker installed. Please log out and back in for group changes to take effect."
fi

# Install Docker Compose
log "Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    sudo apt install -y docker-compose-plugin
fi

# Configure SSH daemon to listen on custom port and allow password auth
log "Configuring SSH daemon..."
sudo sed -i 's/^#Port 22/Port 2222/' /etc/ssh/sshd_config
sudo sed -i 's/^Port 22/Port 2222/' /etc/ssh/sshd_config
sudo sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl restart sshd

# Create project directories
log "Creating project directories..."
mkdir -p ~/pihole-server/{configs,docker,scripts,monitoring,backups,docs}
mkdir -p ~/pihole-server/docker/{pihole,unbound,monitoring,optional}
mkdir -p ~/pihole-server/monitoring/{prometheus,grafana,uptime-kuma}
mkdir -p ~/pihole-server/backups/{daily,weekly,monthly}

# Set permissions
chmod 755 ~/pihole-server
chmod 700 ~/pihole-server/backups

# Configure kernel parameters
log "Configuring kernel parameters..."
sudo tee /etc/sysctl.d/99-rpi.conf > /dev/null <<EOF
# Network optimizations
net.core.rmem_max=26214400
net.core.wmem_max=26214400
net.ipv4.tcp_rmem=4096 65536 26214400
net.ipv4.tcp_wmem=4096 65536 26214400

# Memory management
vm.swappiness=1
vm.dirty_ratio=15
vm.dirty_background_ratio=5

# File system optimizations
fs.file-max=65536
EOF

sudo sysctl -p /etc/sysctl.d/99-rpi.conf

# Configure firewall
log "Configuring nftables firewall..."
sudo tee /etc/nftables.conf > /dev/null <<EOF
#!/usr/bin/nft -f

# Flush existing rules
flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        
        # Allow established and related connections
        ct state {established, related} accept
        
        # Allow loopback
        iifname "lo" accept
        
        # Allow SSH on custom port
        tcp dport 2222 accept
        
        # Allow DNS (Pi-hole)
        tcp dport 53 accept
        udp dport 53 accept
        
        # Allow HTTP/HTTPS for web interfaces
        tcp dport {80, 443, 3000, 3001} accept
        
        # Allow ICMP
        icmp type echo-request accept
        
        # Drop everything else
        counter drop
    }
    
    chain forward {
        type filter hook forward priority 0; policy drop;
    }
    
    chain output {
        type filter hook output priority 0; policy accept;
    }
}
EOF

sudo systemctl enable nftables
sudo systemctl start nftables

# Create Docker networks
log "Creating Docker networks..."
docker network create --subnet=172.20.0.0/24 pihole_net 2>/dev/null || true
docker network create --subnet=172.21.0.0/24 monitoring_net 2>/dev/null || true
docker network create --internal isolated_net 2>/dev/null || true

# Copy configuration files
log "Copying configuration files..."
# cp -r docker/* ~/pihole-server/docker/
# cp -r monitoring/* ~/pihole-server/monitoring/
# cp -r configs/* ~/pihole-server/configs/
# cp scripts/* ~/pihole-server/scripts/

# Set up log rotation
log "Configuring log rotation..."
sudo tee /etc/logrotate.d/pihole-server > /dev/null <<EOF
/var/lib/docker/containers/*/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 0644 root root
    postrotate
        docker kill --signal="USR1" \$(docker ps -q) 2>/dev/null || true
    endscript
}
EOF

# Create backup script
log "Creating backup script..."
sudo tee ~/pihole-server/scripts/backup.sh > /dev/null <<'EOF'
#!/bin/bash

# Source utility functions
source "$(dirname "$0")"/utils.sh

BACKUP_DIR="${BACKUP_DIR:-/home/${USER}/pihole-server/backups/daily}"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-30}

log "Starting backup to $BACKUP_DIR/$DATE..."

# Create backup directory
mkdir -p "$BACKUP_DIR/$DATE" || error "Failed to create backup directory: $BACKUP_DIR/$DATE"

# Backup Pi-hole configuration
if docker ps | grep -q pihole; then
    log "Backing up Pi-hole configuration..."
    docker exec pihole pihole -a -t || warn "Failed to run pihole -a -t command. Pi-hole backup may be incomplete."
    # Ensure backup path is dynamically derived from project structure
    cp "$(pwd)"/docker/pihole/etc-pihole/* "$BACKUP_DIR/$DATE/" 2>/dev/null || warn "Failed to copy Pi-hole configuration files."
else
    warn "Pi-hole container not running, skipping Pi-hole backup."
fi

# Backup Docker Compose files
log "Backing up Docker Compose files..."
cp "$(pwd)"/docker/*.yml "$BACKUP_DIR/$DATE/" || warn "Failed to copy Docker Compose files."

# Backup configuration files
log "Backing up other configuration files..."
cp -r "$(pwd)"/configs "$BACKUP_DIR/$DATE/" || warn "Failed to copy configuration files from 'configs' directory."

# Clean up old backups
log "Cleaning up old backups (retaining $RETENTION_DAYS days)..."
find "$BACKUP_DIR" -type d -mtime +$RETENTION_DAYS -exec rm -rf {} + 2>/dev/null || warn "Failed to clean up old backup directories."

log "Backup completed: $BACKUP_DIR/$DATE"
EOF

chmod +x ~/pihole-server/scripts/backup.sh

# Set up cron job for backups
log "Setting up automated backups..."
(crontab -l 2>/dev/null; echo "0 2 * * * /home/${USER}/pihole-server/scripts/backup.sh") | crontab -

# Create systemd service for Docker Compose
log "Creating systemd service..."
sudo tee /etc/systemd/system/pihole-server.service > /dev/null <<EOF
[Unit]
Description=Pi-hole Home Server
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/${USER}/pihole-server/docker # Use dynamic user home directory
ExecStart=/usr/bin/docker compose -f docker-compose.core.yml -f docker-compose.monitoring.yml -f docker-compose.optional.yml up -d
ExecStop=/usr/bin/docker compose -f docker-compose.core.yml -f docker-compose.monitoring.yml -f docker-compose.optional.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable pihole-server.service

log "Setup completed successfully!"
log "Next steps:"
log "1. Reboot the system: sudo reboot"
log "2. Start the services: sudo systemctl start pihole-server"
log "3. Check status: sudo systemctl status pihole-server"
log "4. Access Pi-hole web interface: http://${PI_STATIC_IP}/admin"
log "5. Configure your router to use ${PI_STATIC_IP} as DNS server"
