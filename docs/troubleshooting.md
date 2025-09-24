# Troubleshooting Guide

This guide provides solutions to common issues encountered when setting up and maintaining your Raspberry Pi Home Server. Each section outlines a problem, explains potential causes, and offers step-by-step solutions with relevant commands.

## Common Issues and Solutions

### 1. DNS Resolution Issues

**Problem**: Devices connected to your network are unable to resolve domain names (e.g., websites don't load, ad-blocking doesn't work as expected) after configuring Pi-hole as the primary DNS server. This often manifests as slow browsing or complete failure to load web pages.

**Potential Causes**:

- Pi-hole or Unbound containers are not running or are unhealthy.
- Incorrect DNS settings on the router or client devices.
- Firewall blocking DNS traffic (port 53).
- Misconfigured Docker networks.

**Solutions** (run these commands on your Raspberry Pi via SSH):

```bash
# 1. Check Pi-hole container status and logs for errors.
log "Checking Pi-hole container status and recent logs..."
docker ps --filter "name=pihole"
docker logs pihole --tail 50

# 2. Test DNS resolution directly from the Pi-hole container.
# This verifies Pi-hole's ability to resolve domains through Unbound.
log "Testing DNS resolution from within the Pi-hole container for a known domain (e.g., google.com)..."
docker exec pihole dig @127.0.0.1 -p 5053 google.com

# 3. Test DNS resolution from the Raspberry Pi host, using Pi-hole as the DNS server.
# Replace ${PI_STATIC_IP} with your Pi's actual static IP address.
log "Testing DNS resolution from the Raspberry Pi host, using Pi-hole as DNS server..."
dig @${PI_STATIC_IP} google.com
nslookup google.com ${PI_STATIC_IP}

# 4. Check Unbound container status and logs if Pi-hole's internal resolution fails.
log "Checking Unbound container status and recent logs..."
docker ps --filter "name=unbound"
docker logs unbound --tail 50

# 5. Restart core services if issues persist.
log "Restarting core services (Pi-hole and Unbound) to apply any changes or clear transient issues..."
docker compose -f docker/docker-compose.core.yml restart
```

**Router Configuration Checks**:

- **Primary DNS Setting**: Ensure your router's primary DNS server is set to your Raspberry Pi's static IP address (e.g., `192.168.1.XXX`). Clear any secondary DNS entries.
- **DHCP Server**: Consider disabling your router's DHCP server and enabling Pi-hole's DHCP server for better client recognition and control. If you do this, ensure Pi-hole's DHCP range does not conflict with your router's IP range.
- **DNS Rebinding Protection**: Some routers have "DNS rebinding protection" which can interfere with local DNS services like Pi-hole. Look for settings like "DNS Rebinding Protection", "Hairpin NAT", or "WAN Loopback" and disable them if necessary, or add `pihole.local` and your Pi's hostname to an allowed list.
- **ISP DNS Override**: Certain ISPs might force their own DNS servers, bypassing your router's settings. You might need to check if your router has an option to prevent this or use a custom router firmware if available.

### 2. Pi-hole Web Interface Not Accessible

**Problem**: You cannot access the Pi-hole admin interface at `http://${PI_STATIC_IP}/admin`. This means you can't monitor your network, manage ad lists, or configure Pi-hole settings.

**Potential Causes**:

- Pi-hole container not running.
- Port 80 conflict on the host system.
- Firewall blocking port 80 or 443.
- Incorrect IP address or network configuration.

**Solutions** (run these commands on your Raspberry Pi via SSH):

```bash
# 1. Verify Pi-hole container is running.
log "Checking if the Pi-hole container is running..."
docker ps | grep pihole

# 2. Check if port 80 (HTTP) on the host is being used by another service.
# If another service is using port 80, Pi-hole won't be able to bind to it.
log "Checking if port 80 is in use on the host..."
sudo netstat -tlnp | grep :80

# 3. Check nftables firewall rules to ensure port 80 is allowed for incoming connections.
log "Listing nftables firewall rules to check for port 80 access..."
sudo nft list ruleset

# 4. Restart the Pi-hole container.
log "Restarting Pi-hole container..."
docker restart pihole

# 5. Check Pi-hole container logs for startup errors.
log "Checking Pi-hole container logs for errors during startup or web interface initialization..."
docker logs pihole --tail 50
```

### 3. High Memory Usage

**Problem**: Your Raspberry Pi is experiencing high memory usage, leading to slow performance, unresponsiveness, or even system crashes.

**Potential Causes**:

- Too many Docker containers or services running simultaneously.
- A container consuming excessive memory due to a memory leak or heavy workload.
- Insufficient RAM allocated to Docker containers (limits/reservations).
- Inefficient kernel swapiness settings.

**Solutions** (run these commands on your Raspberry Pi via SSH):

```bash
# 1. Check overall memory usage on the Raspberry Pi host.
log "Checking overall system memory usage..."
free -h

# 2. Check individual Docker container memory and CPU usage.
# This helps identify which container is consuming the most resources.
log "Checking Docker container resource usage in real-time..."
docker stats --no-stream

# 3. Restart individual services or the entire Docker Compose stack to free up memory.
# This can be a temporary fix for memory leaks.
log "Restarting core Docker Compose services to potentially free up memory..."
docker compose -f docker-compose.core.yml restart
# If monitoring is enabled:
# docker compose -f docker/monitoring/docker-compose.monitoring.yml restart
# If optional services are enabled:
# docker compose -f docker/optional/docker-compose.optional.yml restart

# 4. Check container logs for messages related to memory exhaustion.
log "Searching Pi-hole and Unbound logs for memory-related errors or warnings..."
docker logs pihole | grep -i memory
docker logs unbound | grep -i memory

# 5. Consider reducing container memory limits in their respective docker-compose.yml files.
# This is a more permanent solution if a specific container consistently uses too much memory.
# Example: Adjust 'limits' and 'reservations' under 'deploy' section for a service.
log "Review and adjust memory limits/reservations in docker-compose files (e.g., docker-compose.core.yml, docker-compose.monitoring.yml, docker-compose.optional.yml) if a specific container is consistently consuming too much memory. This requires editing the .yml file and then running 'docker compose up -d' for that stack."
```

### 4. Slow DNS Resolution

**Problem**: DNS queries are noticeably slow, or domains are taking a long time to resolve, even if they eventually succeed. This can lead to a sluggish internet experience.

**Potential Causes**:

- Unbound configuration issues.
- Network latency between Pi-hole and Unbound, or Unbound and root DNS servers.
- Overloaded Raspberry Pi resources.
- External ISP issues.

**Solutions** (run these commands on your Raspberry Pi via SSH):

```bash
# 1. Check Unbound's internal status and configuration.
log "Checking Unbound's internal status..."
docker exec unbound unbound-control status

# 2. Test upstream DNS servers directly (e.g., Google DNS, Cloudflare DNS) from the Pi.
# This helps rule out issues with Unbound or your network connection to the internet.
log "Testing direct DNS resolution to external DNS servers (e.g., 8.8.8.8, 1.1.1.1)..."
dig @8.8.8.8 google.com
dig @1.1.1.1 google.com

# 3. Monitor Pi-hole's real-time query log to see which queries are being processed and how quickly.
log "Monitoring Pi-hole's real-time query log for slow queries..."
docker exec pihole pihole -t

# 4. Restart Unbound service to clear any transient issues or reload configuration.
log "Restarting Unbound container..."
docker restart unbound

# 5. Check for high CPU or memory usage (refer to 'High Memory Usage' section).
log "If DNS remains slow, check overall system resource usage (CPU, Memory) as described in 'High Memory Usage' section."
```

### 5. Container Startup Issues

**Problem**: One or more Docker containers fail to start, exit unexpectedly, or enter a restart loop. This prevents the associated services from becoming available.

**Potential Causes**:

- Corrupted configuration files or volumes.
- Insufficient system resources (memory, disk space).
- Port conflicts.
- Incorrect environment variables.
- Damaged Docker image.

**Solutions** (run these commands on your Raspberry Pi via SSH):

```bash
# 1. Immediately check the logs of the problematic container for specific error messages.
log "Checking logs for a problematic container (e.g., pihole, unbound, grafana)..."
docker logs <container_name> --tail 100 # Replace <container_name> with the actual container name

# 2. Check the status of the Docker daemon. If Docker itself is not running, no containers can start.
log "Checking Docker daemon status..."
sudo systemctl status docker

# 3. Verify available disk space on your Raspberry Pi. Full disk can prevent containers from starting.
log "Checking available disk space..."
df -h

# 4. Inspect Docker networks. Misconfigured networks can prevent containers from communicating or starting.
log "Listing Docker networks and inspecting 'pihole_net'..."
docker network ls
docker network inspect pihole_net

# 5. Recreate containers from scratch (this can often resolve issues with corrupted container layers or volumes).
# Make sure to back up any important data in volumes before running 'down -v'.
log "Attempting to recreate core containers. This will stop and remove existing containers, then recreate them."
log "WARNING: This command will remove anonymous volumes. Ensure your data volumes are named or backed up if critical."
docker compose -f docker-compose.core.yml down # Stops and removes containers and networks
docker compose -f docker-compose.core.yml up -d # Recreates and starts containers

# 6. If the issue persists, try removing volumes associated with the container (WARNING: DATA LOSS).
# Only do this if you're sure you want to discard container-specific data or have a backup.
# docker volume rm <volume_name>
log "If all else fails, consider removing associated Docker volumes (WARNING: This will lead to data loss if not backed up). E.g., docker volume rm pihole_data"
```

### 6. Firewall Issues

**Problem**: You cannot access services (web interfaces, SSH, DNS) even if containers appear to be running. This indicates that the `nftables` firewall might be blocking the necessary traffic.

**Potential Causes**:

- Incorrect `nftables` rules preventing inbound connections.
- Firewall not running or misconfigured.
- IP address changes not reflected in firewall rules.

**Solutions** (run these commands on your Raspberry Pi via SSH):

```bash
# 1. Check the status of the nftables service.
log "Checking nftables firewall service status..."
sudo systemctl status nftables

# 2. List all active nftables rules to review them.
log "Listing active nftables ruleset..."
sudo nft list ruleset

# 3. Test port connectivity from another device on the LAN using `telnet` or `nc`.
# Replace ${PI_STATIC_IP} with your Pi's actual static IP address.
log "Testing direct port connectivity from another device on your LAN (e.g., your computer)..."
# From your computer's terminal:
# telnet ${PI_STATIC_IP} 53    # Test DNS TCP
# telnet ${PI_STATIC_IP} 80    # Test Pi-hole web interface HTTP
# telnet ${PI_STATIC_IP} 2222  # Test SSH on custom port

# 4. Temporarily disable the firewall for testing purposes.
# IMPORTANT: Re-enable the firewall immediately after testing to maintain security.
log "Temporarily stopping nftables for testing (re-enable immediately after testing!)..."
sudo systemctl stop nftables
# After stopping, re-test services.
# If services become accessible, the firewall rules are the problem.
log "After testing, restart nftables: sudo systemctl start nftables"

# 5. Review and update /etc/nftables.conf to ensure correct ports are allowed.
# If you make changes, remember to reload the rules: `sudo nft -f /etc/nftables.conf`
log "Review the /etc/nftables.conf file for incorrect rules. After making changes, apply them with: sudo nft -f /etc/nftables.conf"
```

### 7. Backup and Recovery Issues

**Problem**: Your automated backups are failing, or you are unable to successfully recover data from a backup.

**Potential Causes**:

- Backup script errors or incorrect permissions.
- Cron job not running.
- Insufficient disk space in the backup directory.
- Corrupted backup files.
- Incorrect paths in recovery steps.
- `REMOTE_BACKUP_LOCATION` not configured for off-site backups.

**Solutions** (run these commands on your Raspberry Pi via SSH):

```bash
# 1. Manually run the backup script to check for immediate errors.
log "Manually running the local backup script to check for errors..."
~/pihole-server/scripts/backup.sh

# 2. Check the cron job configuration to ensure it's scheduled correctly.
log "Checking cron jobs for the automated backup entry..."
crontab -l | grep backup

# 3. Manually trigger a Pi-hole internal backup to verify its functionality.
log "Manually triggering an internal Pi-hole backup..."
docker exec pihole pihole -a -t

# 4. Check permissions and ownership of the backup directories.
log "Checking permissions for backup directories..."
ls -la ~/pihole-server/backups/
ls -la ~/pihole-server/backups/daily/

# 5. Test the backup verification process.
log "Verifying the latest backup using the maintenance script..."
~/pihole-server/scripts/maintenance.sh verify

# 6. For off-site backups, ensure REMOTE_BACKUP_LOCATION is set in .env and reachable.
log "Checking REMOTE_BACKUP_LOCATION for off-site backups..."
echo "REMOTE_BACKUP_LOCATION: ${REMOTE_BACKUP_LOCATION}"
# Manually run off-site backup to test connectivity and permissions.
log "Manually running off-site backup to test (ensure SSH keys are set up):"
~/pihole-server/scripts/maintenance.sh offsite

# 7. When restoring, ensure you are copying the correct files to the correct locations.
# Example for Pi-hole: Copy files from a specific backup snapshot to Pi-hole's configuration volume.
log "When restoring, ensure correct backup directory (YYYYMMDD_HHMMSS) and destination. Example for Pi-hole config:"
echo "cp -r ~/pihole-server/backups/daily/YYYYMMDD_HHMMSS/etc-pihole/* ~/pihole-server/docker/pihole/etc-pihole/"
```

### 8. Monitoring Issues (Grafana, Prometheus, Uptime Kuma)

**Problem**: Grafana dashboards are not showing data, Prometheus is not scraping targets, or Uptime Kuma is not monitoring services correctly.

**Potential Causes**:

- Monitoring containers not running.
- Incorrect Prometheus configuration (scrape targets).
- Grafana not connected to Prometheus datasource.
- Firewall blocking internal Docker network communication.
- Uptime Kuma monitor configuration errors.

**Solutions** (run these commands on your Raspberry Pi via SSH):

```bash
# 1. Check if monitoring containers are running.
log "Checking status of monitoring containers (Grafana, Prometheus, Uptime Kuma, Node Exporter)..."
docker ps | grep -E "(grafana|prometheus|uptime-kuma|node-exporter)"

# 2. Check logs for individual monitoring containers for specific errors.
log "Checking logs for Grafana, Prometheus, and Uptime Kuma..."
docker logs grafana --tail 50
docker logs prometheus --tail 50
docker logs uptime-kuma --tail 50

# 3. Verify internal network connectivity between containers (e.g., Grafana to Prometheus).
log "Testing internal network connectivity between Grafana and Prometheus..."
docker exec grafana ping prometheus

# 4. Restart the entire monitoring stack.
log "Restarting monitoring services..."
docker compose -f docker/monitoring/docker-compose.monitoring.yml restart

# 5. Check Prometheus configuration syntax.
log "Validating Prometheus configuration syntax..."
docker exec prometheus promtool check config /etc/prometheus/prometheus.yml

# 6. Verify Grafana data source connection (often done via Grafana UI).
log "Ensure Grafana's Prometheus datasource is correctly configured via the Grafana web UI (http://${PI_STATIC_IP}:3000)."
# Also check Grafana's internal provisioning logs:
docker logs grafana | grep -i "datasource"

# 7. For Uptime Kuma, check its dashboard for monitor status and logs.
log "Review Uptime Kuma's dashboard (http://${PI_STATIC_IP}:3001) for specific monitor errors."
```

### 9. SSH Connection Issues

**Problem**: You cannot connect to your Raspberry Pi via SSH, or the connection is refused/timed out.

**Potential Causes**:

- SSH daemon not running on the Pi.
- Incorrect SSH port or firewall blocking it.
- Wrong IP address or hostname.
- SSH host key mismatch.
- Password authentication disabled (if not using SSH keys).

**Solutions** (run these commands on your Raspberry Pi _locally if possible, otherwise debug carefully_):

```bash
# 1. Check SSH daemon status on the Raspberry Pi.
log "Checking SSH daemon status..."
sudo systemctl status sshd

# 2. Verify SSH configuration (port and authentication).
log "Checking SSH daemon configuration for Port and PasswordAuthentication..."
sudo grep -E '^(Port|PasswordAuthentication)' /etc/ssh/sshd_config

# 3. Check nftables firewall rules to ensure the SSH port (default 2222) is allowed.
log "Listing nftables rules to verify SSH port (2222) is open..."
sudo nft list ruleset | grep 2222

# 4. If you recently re-imaged your Pi and are getting a host key warning on your client machine:
log "If getting a 'WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!' error, clear the old host key on your client machine:"
echo "ssh-keygen -R <your_pi_ip>" # Replace <your_pi_ip> with your Pi's static IP

# 5. If using SSH keys, ensure your public key is in ~/.ssh/authorized_keys on the Pi.
log "Verify your public SSH key is in ~/.ssh/authorized_keys on the Pi."
cat ~/.ssh/authorized_keys

# 6. Restart SSH daemon after any configuration changes.
log "Restarting SSH daemon after configuration changes..."
sudo systemctl restart sshd
```

## Performance Optimization

### 1. SD Card Optimization

Optimizing SD card usage can prolong its life and improve system responsiveness.

```bash
# 1. Mount filesystem with noatime and nodiratime options to reduce write operations.
# Edit /etc/fstab and add these options for your root filesystem (usually /dev/mmcblk0p2 for Raspberry Pi OS).
# Example line in /etc/fstab:
# /dev/mmcblk0p2 / ext4 defaults,noatime,nodiratime 0 1
log "Edit /etc/fstab to add 'noatime,nodiratime' options for your root filesystem to reduce SD card writes."

# 2. Disable swap file to reduce writes to the SD card.
# This should only be done if you have sufficient RAM (e.g., 2GB or more) and monitor memory usage.
log "Disabling swap file to reduce SD card wear. Only do this if you have sufficient RAM and monitor memory usage."
sudo dphys-swapfile swapoff || warn "Failed to stop swapfile."
sudo systemctl disable dphys-swapfile || warn "Failed to disable swapfile service."
```

### 2. Docker Optimization

Optimizing Docker can help manage resources and improve container performance.

```bash
# 1. Limit Docker container log size to prevent disk space exhaustion.
# This creates/modifies /etc/docker/daemon.json.
log "Configuring Docker to limit log file size and rotation."
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m", # Max size of a log file before it's rotated (10 Megabytes).
    "max-file": "3"    # Maximum number of log files to retain.
  }
}
EOF

# Restart Docker daemon for changes to take effect.
sudo systemctl restart docker || error "Failed to restart Docker daemon after log configuration."
```

### 3. Memory Optimization

Fine-tuning kernel memory parameters can help reduce unnecessary writes and improve memory management.

```bash
# 1. Configure kernel parameters for memory management in /etc/sysctl.d/99-rpi.conf.
# These settings reduce swappiness (minimizing SD card writes) and tune dirty page ratios.
# Ensure these lines are present in /etc/sysctl.d/99-rpi.conf (created by setup.sh).
log "Ensure kernel memory optimization parameters are set in /etc/sysctl.d/99-rpi.conf (vm.swappiness, vm.dirty_ratio, vm.dirty_background_ratio)."
# Example content (already in setup.sh):
# vm.swappiness=1
# vm.dirty_ratio=15
# vm.dirty_background_ratio=5

# 2. Apply the new kernel parameters without rebooting.
log "Applying kernel parameter changes without rebooting..."
sudo sysctl -p /etc/sysctl.d/99-rpi.conf || error "Failed to apply new kernel parameters."
```

## Log Analysis

Understanding how to effectively analyze logs is crucial for troubleshooting.

### 1. Pi-hole Logs

Pi-hole generates detailed logs that are essential for diagnosing DNS and ad-blocking issues.

```bash
# 1. View Pi-hole's real-time query log. This shows DNS queries as they happen.
log "Viewing Pi-hole's real-time query log for live DNS activity..."
docker exec pihole pihole -t

# 2. Check blocked domains directly from Pi-hole's FTL database.
# This confirms if gravity lists are working and which domains are being blocked.
log "Querying Pi-hole's FTL database for blocked domains (type 1)..."
docker exec pihole sqlite3 /etc/pihole/pihole-FTL.db "SELECT domain FROM gravity WHERE type = 1;"

# 3. Fetch Pi-hole's summary statistics via its API. Useful for quick overview of status.
# Replace ${PI_STATIC_IP} with your Pi's actual static IP address.
log "Fetching Pi-hole's summary statistics via API..."
curl -s http://${PI_STATIC_IP}/admin/api.php?summary | jq
```

### 2. System Logs

General system logs provide insights into the operating system and Docker daemon's health.

```bash
# 1. Check systemd journal logs for the pihole-server service.
# This shows logs related to the Docker Compose stack startup/shutdown.
log "Checking systemd journal logs for the 'pihole-server.service'..."
sudo journalctl -u pihole-server.service

# 2. Check systemd journal logs for the Docker service.
# This provides information about the Docker daemon's operations.
log "Checking systemd journal logs for the 'docker.service'..."
sudo journalctl -u docker.service

# 3. View kernel messages, especially for hardware-related issues or boot problems.
log "Viewing recent kernel messages (dmesg)..."
dmesg | tail -20

# 4. Inspect network interfaces and routing table on the host.
# Useful for diagnosing host-level network connectivity issues.
log "Inspecting network interfaces and routing table on the host..."
ip addr show
ip route show
```

## Emergency Recovery

These steps describe how to recover from severe issues or completely reset your server.

### 1. Complete System Recovery

Restoring your entire Docker Compose stack from a backup.

```bash
# 1. Stop all Docker Compose services controlled by systemd.
log "Stopping all Docker Compose services managed by systemd..."
sudo systemctl stop pihole-server.service || warn "pihole-server.service was not running or failed to stop gracefully."

# 2. Manually bring down any remaining Docker Compose services and remove their containers.
# Use the combined docker-compose files to ensure all services are covered.
log "Bringing down and removing all Docker Compose containers (excluding volumes)..."
docker compose -f docker/docker-compose.core.yml -f docker/monitoring/docker-compose.monitoring.yml -f docker/optional/docker-compose.optional.yml down || warn "Failed to bring down all Docker Compose services. Some may already be stopped."

# 3. Restore configuration files from your chosen backup.
# Replace YYYYMMDD_HHMMSS with the actual timestamp of the backup you wish to restore.
log "Restoring configuration files from backup (replace YYYYMMDD_HHMMSS with your backup timestamp)..."
# Restore Pi-hole configurations
cp -r ~/pihole-server/backups/daily/YYYYMMDD_HHMMSS/etc-pihole/* ~/pihole-server/docker/pihole/etc-pihole/ || error "Failed to restore Pi-hole configuration."
# Restore other configurations like unbound, prometheus, grafana, etc. as needed from the backup directory.
log "Remember to restore other relevant configuration files (e.g., Unbound, Prometheus, Grafana) from your chosen backup directory."

# 4. Start all Docker Compose services via systemd.
log "Starting all Docker Compose services via systemd..."
sudo systemctl start pihole-server.service || error "Failed to start pihole-server.service after restore."

# 5. Verify service status after recovery.
log "Verifying service status after recovery. Run 'sudo systemctl status pihole-server.service' and 'docker ps'."
```

### 2. Factory Reset

Performing a complete factory reset, removing all Docker data and project files. This is a drastic measure and should only be used as a last resort.

```bash
# 1. Remove all Docker containers, networks, images, and volumes.
# The `-a` flag removes all stopped containers, all networks not used by at least one container,
# all dangling images, and optionally all volumes not used by at least one container.
log "Removing all Docker containers, networks, images, and volumes (DANGER: DATA LOSS)..."
docker system prune -a --volumes || warn "Docker system prune encountered issues."

# 2. Remove the entire project directory.
log "Removing the entire project directory (~/pihole-server/)..."
rm -rf ~/pihole-server || warn "Failed to remove project directory."

# 3. Re-run the setup script from scratch to reinitialize the server.
log "Now, re-clone the repository and re-run the setup and quick-deploy scripts to rebuild your server."
echo "git clone https://github.com/Robo-Chef/Modular-Pi-Server.git ~/pihole-server"
echo "cd ~/pihole-server"
echo "cp env.example .env && nano .env"
echo "./scripts/setup.sh"
echo "./scripts/quick-deploy.sh"
```

## Getting Help

When seeking help for issues, providing comprehensive information is key.

1.  **Check the logs first**: Always start by checking the logs of the affected container (`docker logs <container_name>`) or system service (`sudo journalctl -u <service_name>`).
2.  **Verify network connectivity**: Ensure your Raspberry Pi has internet access (`ping 8.8.8.8`) and that clients can reach your Pi's static IP.
3.  **Test DNS resolution**: Directly query Pi-hole for known domains (`dig @${PI_STATIC_IP} google.com` and for an ad domain `dig @${PI_STATIC_IP} doubleclick.net`).
4.  **Check system resources**: Use `htop`, `df -h`, and `free -h` to check for high CPU, disk, or memory usage.
5.  **Review firewall rules**: Use `sudo nft list ruleset` to ensure necessary ports are open.
6.  **Provide context**: When asking for help, describe what you were doing when the issue occurred, any recent changes, and the exact error messages you received.

For additional support, consult the official documentation for the respective tools:

- [Pi-hole Documentation](https://docs.pi-hole.net/)
- [Unbound Documentation](https://nlnetlabs.nl/documentation/unbound/)
- [Docker Documentation](https://docs.docker.com/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Uptime Kuma Documentation](https://github.com/louislam/uptime-kuma/wiki)
