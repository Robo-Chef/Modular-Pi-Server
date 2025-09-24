# Troubleshooting Guide

## Common Issues and Solutions

### 1. DNS Resolution Issues

**Problem**: Devices can't resolve domain names after setting Pi-hole as DNS server.

**Solutions**:

```bash
# Check Pi-hole status
docker logs pihole

# Test DNS resolution
dig @192.168.0.185 google.com
nslookup google.com 192.168.0.185

# Check Unbound status
docker logs unbound

# Restart services
docker compose -f docker-compose.core.yml restart
```

**Router Configuration**:

- Ensure router DNS is set to `192.168.0.185`
- Some routers require DHCP to be disabled when using static DNS
- Check for DNS rebinding protection settings

### 2. Pi-hole Web Interface Not Accessible

**Problem**: Can't access Pi-hole admin interface at `http://192.168.0.185/admin`.

**Solutions**:

```bash
# Check if Pi-hole is running
docker ps | grep pihole

# Check port binding
netstat -tlnp | grep :80

# Check firewall
sudo nft list ruleset

# Restart Pi-hole
docker restart pihole

# Check logs
docker logs pihole
```

### 3. High Memory Usage

**Problem**: Raspberry Pi running out of memory.

**Solutions**:

```bash
# Check memory usage
free -h
docker stats

# Restart services to free memory
docker compose -f docker-compose.core.yml restart

# Check for memory leaks
docker logs pihole | grep -i memory
docker logs unbound | grep -i memory

# Reduce container memory limits in docker-compose.yml
```

### 4. Slow DNS Resolution

**Problem**: DNS queries are slow or timing out.

**Solutions**:

```bash
# Check Unbound configuration
docker exec unbound unbound-control status

# Test upstream DNS servers
dig @8.8.8.8 google.com
dig @1.1.1.1 google.com

# Check Pi-hole query log
docker exec pihole pihole -t

# Restart Unbound
docker restart unbound
```

### 5. Container Startup Issues

**Problem**: Containers fail to start or keep restarting.

**Solutions**:

```bash
# Check container logs
docker logs pihole
docker logs unbound

# Check Docker daemon
sudo systemctl status docker

# Check disk space
df -h

# Check Docker networks
docker network ls
docker network inspect pihole_net

# Recreate containers
docker compose -f docker-compose.core.yml down
docker compose -f docker-compose.core.yml up -d
```

### 6. Firewall Issues

**Problem**: Services not accessible due to firewall rules.

**Solutions**:

```bash
# Check firewall status
sudo systemctl status nftables

# List current rules
sudo nft list ruleset

# Test connectivity
telnet 192.168.0.185 53
telnet 192.168.0.185 80

# Temporarily disable firewall for testing
sudo systemctl stop nftables
# Test services
sudo systemctl start nftables
```

### 7. Backup and Recovery Issues

**Problem**: Backups failing or corrupted.

**Solutions**:

```bash
# Check backup script
~/pihole-server/scripts/backup.sh

# Check cron job
crontab -l

# Manual backup
docker exec pihole pihole -a -t

# Check backup directory permissions
ls -la ~/pihole-server/backups/

# Test restore process
cp ~/pihole-server/backups/daily/YYYYMMDD_HHMMSS/* ~/pihole-server/docker/pihole/etc-pihole/
```

### 8. Monitoring Issues

**Problem**: Grafana or Prometheus not working.

**Solutions**:

```bash
# Check monitoring containers
docker ps | grep -E "(grafana|prometheus|uptime)"

# Check logs
docker logs grafana
docker logs prometheus

# Check network connectivity
docker exec grafana ping prometheus

# Restart monitoring stack
docker compose -f monitoring/docker-compose.monitoring.yml restart
```

## Performance Optimization

### 1. SD Card Optimization

```bash
# Add to /etc/fstab
/dev/mmcblk0p2 / ext4 defaults,noatime,nodiratime 0 1

# Disable swap
sudo dphys-swapfile swapoff
sudo systemctl disable dphys-swapfile
```

### 2. Docker Optimization

```bash
# Limit Docker log size
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

sudo systemctl restart docker
```

### 3. Memory Optimization

```bash
# Add to /etc/sysctl.d/99-rpi.conf
vm.swappiness=1
vm.dirty_ratio=15
vm.dirty_background_ratio=5

# Apply changes
sudo sysctl -p /etc/sysctl.d/99-rpi.conf
```

## Log Analysis

### 1. Pi-hole Logs

```bash
# Real-time query log
docker exec pihole pihole -t

# Check blocked domains
docker exec pihole sqlite3 /etc/pihole/pihole-FTL.db "SELECT domain FROM gravity WHERE type = 1;"

# Check statistics
curl -s http://192.168.0.185/admin/api.php?summary | jq
```

### 2. System Logs

```bash
# Check system logs
sudo journalctl -u pihole-server.service
sudo journalctl -u docker.service

# Check kernel messages
dmesg | tail -20

# Check network interfaces
ip addr show
ip route show
```

## Emergency Recovery

### 1. Complete System Recovery

```bash
# Stop all services
sudo systemctl stop pihole-server
docker compose -f ~/pihole-server/docker/docker-compose.core.yml down

# Restore from backup
cp -r ~/pihole-server/backups/daily/YYYYMMDD_HHMMSS/* ~/pihole-server/docker/pihole/etc-pihole/

# Restart services
sudo systemctl start pihole-server
```

### 2. Factory Reset

```bash
# Remove all containers and volumes
docker system prune -a --volumes

# Remove project files
rm -rf ~/pihole-server

# Re-run setup script
~/pihole-server/scripts/setup.sh
```

## Getting Help

1. Check the logs first: `docker logs <container_name>`
2. Verify network connectivity: `ping 8.8.8.8`
3. Test DNS resolution: `dig @192.168.0.185 google.com`
4. Check system resources: `htop`, `df -h`, `free -h`
5. Review firewall rules: `sudo nft list ruleset`

For additional support, check the official documentation:

- [Pi-hole Documentation](https://docs.pi-hole.net/)
- [Unbound Documentation](https://nlnetlabs.nl/documentation/unbound/)
- [Docker Documentation](https://docs.docker.com/)


