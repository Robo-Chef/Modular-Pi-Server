# Security Hardening Guide

## Overview

This guide covers security hardening measures for the Raspberry Pi home server, including system-level security, Docker container security, and network security.

## System Security

### 1. SSH Hardening

```bash
# Edit SSH configuration
sudo nano /etc/ssh/sshd_config

# Key settings:
Port 2222
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AllowUsers pi
AllowTcpForwarding no
X11Forwarding no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
LoginGraceTime 60
Banner /etc/issue.net

# Restart SSH service
sudo systemctl restart ssh
```

### 2. Firewall Configuration

```bash
# Create comprehensive firewall rules
sudo tee /etc/nftables.conf > /dev/null <<'EOF'
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
        tcp dport {80, 443, 3000, 3001, 8123, 9000} accept

        # Allow ICMP (limited)
        icmp type echo-request limit rate 1/second accept
        icmp type echo-reply limit rate 1/second accept

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

# Enable firewall
sudo systemctl enable nftables
sudo systemctl start nftables
```

### 3. System Updates

```bash
# Configure automatic security updates
sudo tee /etc/apt/apt.conf.d/50unattended-upgrades > /dev/null <<'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESM:${distro_codename}";
    "${distro_id}:${distro_codename}-updates";
};

Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOF

# Enable automatic updates
sudo systemctl enable unattended-upgrades
sudo systemctl start unattended-upgrades
```

### 4. Kernel Security

```bash
# Add security parameters to kernel command line
sudo nano /boot/cmdline.txt

# Add these parameters:
# quiet loglevel=3 systemd.show_status=0 console=tty1 root=PARTUUID=... rw rootfstype=ext4 elevator=deadline fsck.repair=yes quiet splash plymouth.ignore-serial-consoles

# Configure kernel parameters
sudo tee /etc/sysctl.d/99-security.conf > /dev/null <<'EOF'
# Network security
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 1

# Memory protection
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1

# File system security
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
EOF

# Apply changes
sudo sysctl -p /etc/sysctl.d/99-security.conf
```

## Docker Security

### 1. Container Security

```bash
# Enable Docker Content Trust
export DOCKER_CONTENT_TRUST=1

# Scan images for vulnerabilities
docker scan pihole/pihole:latest
docker scan klutchell/unbound:latest

# Run containers as non-root user
# Add to docker-compose.yml:
# user: "1000:1000"
```

### 2. Network Isolation

```bash
# Create isolated networks
docker network create --internal isolated_net
docker network create --driver bridge --opt com.docker.network.bridge.enable_icc=false pihole_net

# Use read-only root filesystems where possible
# Add to docker-compose.yml:
# read_only: true
# tmpfs:
#   - /tmp
#   - /var/run
```

### 3. Resource Limits

```yaml
# Add to docker-compose.yml
deploy:
  resources:
    limits:
      cpus: "0.5"
      memory: 512M
    reservations:
      memory: 256M
  restart_policy:
    condition: on-failure
    delay: 5s
    max_attempts: 3
```

## Application Security

### 1. Pi-hole Security

```bash
# Set strong admin password
docker exec pihole pihole -a -p

# Enable DNSSEC
# Add to pihole configuration:
# DNSSEC=true

# Disable unnecessary features
# Add to pihole configuration:
# DNSMASQ_LISTENING=local
# PIHOLE_INTERFACE=eth0
```

### 2. Unbound Security

```bash
# Configure Unbound with security features
# Add to unbound.conf:
server:
    # Security settings
    hide-identity: yes
    hide-version: yes
    harden-glue: yes
    harden-dnssec-stripped: yes
    harden-below-nxdomain: yes
    harden-referral-path: yes
    use-caps-for-id: yes
    qname-minimisation: yes
    qname-minimisation-strict: yes

    # Access control
    access-control: 172.20.0.0/24 allow
    access-control: 192.168.0.0/24 allow
    access-control: 127.0.0.0/8 allow
```

### 3. Monitoring Security

```bash
# Secure Grafana
# Add to grafana configuration:
# [security]
# admin_user = admin
# admin_password = $__env{GF_SECURITY_ADMIN_PASSWORD}
# secret_key = $__env{GF_SECURITY_SECRET_KEY}
# disable_gravatar = true
# cookie_secure = true
# cookie_samesite = strict
# strict_transport_security = true
# strict_transport_security_max_age_seconds = 31536000
# strict_transport_security_preload = true
# strict_transport_security_subdomains = true

# Secure Prometheus
# Add to prometheus configuration:
# global:
#   external_labels:
#     cluster: 'pihole-server'
#     replica: 'A'
```

## Network Security

### 1. DNS Security

```bash
# Configure Pi-hole with security features
# Add to pihole configuration:
# DNSMASQ_LISTENING=local
# PIHOLE_INTERFACE=eth0
# DNS_FQDN_REQUIRED=true
# DNS_BOGUS_PRIV=true
# DNS_FILTER_AAAA=true
# DNSSEC=true
# REV_SERVER=true
# REV_SERVER_DOMAIN=local
# REV_SERVER_TARGET=192.168.0.1
# REV_SERVER_CIDR=192.168.0.0/24
```

### 2. SSL/TLS Configuration

```bash
# Install Certbot for SSL certificates
sudo apt install -y certbot

# Generate self-signed certificates for local services
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/C=AU/ST=NSW/L=Sydney/O=Home/OU=IT/CN=pihole.local"

# Configure reverse proxy with SSL
# Add to nginx configuration:
# server {
#     listen 443 ssl;
#     server_name pihole.local;
#     ssl_certificate /path/to/cert.pem;
#     ssl_certificate_key /path/to/key.pem;
#     location / {
#         proxy_pass http://pihole:80;
#     }
# }
```

## Logging and Monitoring

### 1. Security Logging

```bash
# Configure rsyslog for security events
sudo tee /etc/rsyslog.d/50-security.conf > /dev/null <<'EOF'
# Security events
auth,authpriv.* /var/log/auth.log
kern.* /var/log/kern.log
mail.* /var/log/mail.log
cron.* /var/log/cron.log
daemon.* /var/log/daemon.log
syslog.* /var/log/syslog
user.* /var/log/user.log
EOF

# Restart rsyslog
sudo systemctl restart rsyslog
```

### 2. Intrusion Detection

```bash
# Install fail2ban
sudo apt install -y fail2ban

# Configure fail2ban
sudo tee /etc/fail2ban/jail.local > /dev/null <<'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = 2222
logpath = /var/log/auth.log
maxretry = 3

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 3
EOF

# Start fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

## Backup Security

### 1. Encrypted Backups

```bash
# Create encrypted backup script
tee ~/pihole-server/scripts/secure-backup.sh > /dev/null <<'EOF'
#!/bin/bash

BACKUP_DIR="/home/pi/pihole-server/backups/secure"
DATE=$(date +%Y%m%d_%H%M%S)
ENCRYPTION_KEY="/home/pi/pihole-server/backups/backup.key"

# Create backup directory
mkdir -p "$BACKUP_DIR/$DATE"

# Generate encryption key if it doesn't exist
if [[ ! -f "$ENCRYPTION_KEY" ]]; then
    openssl rand -base64 32 > "$ENCRYPTION_KEY"
    chmod 600 "$ENCRYPTION_KEY"
fi

# Backup Pi-hole configuration
docker exec pihole pihole -a -t
cp -r ~/pihole-server/docker/pihole/etc-pihole/* "$BACKUP_DIR/$DATE/"

# Create encrypted archive
tar -czf - "$BACKUP_DIR/$DATE" | openssl enc -aes-256-cbc -salt -in - -out "$BACKUP_DIR/pihole-backup-$DATE.tar.gz.enc" -pass file:"$ENCRYPTION_KEY"

# Remove unencrypted backup
rm -rf "$BACKUP_DIR/$DATE"

echo "Encrypted backup created: $BACKUP_DIR/pihole-backup-$DATE.tar.gz.enc"
EOF

chmod +x ~/pihole-server/scripts/secure-backup.sh
```

### 2. Backup Verification

```bash
# Create backup verification script
tee ~/pihole-server/scripts/verify-backup.sh > /dev/null <<'EOF'
#!/bin/bash

BACKUP_FILE="$1"
ENCRYPTION_KEY="/home/pi/pihole-server/backups/backup.key"

if [[ -z "$BACKUP_FILE" ]]; then
    echo "Usage: $0 <backup_file>"
    exit 1
fi

# Verify encrypted backup
if openssl enc -aes-256-cbc -d -in "$BACKUP_FILE" -pass file:"$ENCRYPTION_KEY" | tar -tzf - > /dev/null 2>&1; then
    echo "Backup verification successful"
    exit 0
else
    echo "Backup verification failed"
    exit 1
fi
EOF

chmod +x ~/pihole-server/scripts/verify-backup.sh
```

## Security Monitoring

### 1. Security Alerts

```bash
# Create security monitoring script
tee ~/pihole-server/scripts/security-monitor.sh > /dev/null <<'EOF'
#!/bin/bash

# Check for failed SSH attempts
FAILED_SSH=$(grep "Failed password" /var/log/auth.log | wc -l)
if [[ $FAILED_SSH -gt 10 ]]; then
    echo "WARNING: $FAILED_SSH failed SSH attempts detected"
fi

# Check for suspicious network activity
SUSPICIOUS_CONNECTIONS=$(netstat -an | grep :22 | grep ESTABLISHED | wc -l)
if [[ $SUSPICIOUS_CONNECTIONS -gt 5 ]]; then
    echo "WARNING: $SUSPICIOUS_CONNECTIONS active SSH connections"
fi

# Check disk space
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [[ $DISK_USAGE -gt 80 ]]; then
    echo "WARNING: Disk usage is at ${DISK_USAGE}%"
fi

# Check memory usage
MEMORY_USAGE=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
if [[ $MEMORY_USAGE -gt 90 ]]; then
    echo "WARNING: Memory usage is at ${MEMORY_USAGE}%"
fi
EOF

chmod +x ~/pihole-server/scripts/security-monitor.sh

# Add to crontab
(crontab -l 2>/dev/null; echo "*/15 * * * * /home/pi/pihole-server/scripts/security-monitor.sh") | crontab -
```

## Regular Security Maintenance

### 1. Weekly Security Tasks

```bash
# Create weekly security maintenance script
tee ~/pihole-server/scripts/weekly-security.sh > /dev/null <<'EOF'
#!/bin/bash

# Update system packages
sudo apt update && sudo apt upgrade -y

# Update Docker images
docker compose -f ~/pihole-server/docker/docker-compose.core.yml pull
docker compose -f ~/pihole-server/docker/docker-compose.core.yml up -d

# Scan for vulnerabilities
docker scan pihole/pihole:latest
docker scan klutchell/unbound:latest

# Check for security updates
sudo unattended-upgrade --dry-run

# Clean up old logs
sudo journalctl --vacuum-time=7d

# Check firewall status
sudo nft list ruleset | grep -c "policy drop"

# Verify backups
find ~/pihole-server/backups -name "*.enc" -mtime -7 -exec ~/pihole-server/scripts/verify-backup.sh {} \;
EOF

chmod +x ~/pihole-server/scripts/weekly-security.sh

# Add to crontab
(crontab -l 2>/dev/null; echo "0 2 * * 0 /home/pi/pihole-server/scripts/weekly-security.sh") | crontab -
```

This security hardening guide provides comprehensive protection for your Raspberry Pi home server. Regular maintenance and monitoring are essential to maintain security over time.


