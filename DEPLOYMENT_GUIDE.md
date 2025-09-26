# Raspberry Pi Home Server - Deployment Checklist & Quick Reference

## Quick Start

This guide serves as a quick checklist and reference for deploying your
Raspberry Pi home server. For **detailed, step-by-step instructions**, always
refer to the
[Raspberry Pi Home Server Setup Guide](RASPBERRY_PI_SERVER_SETUP.md).

### Prerequisites

- Raspberry Pi 3 B+ with 32GB+ SD card
- Raspberry Pi OS (64-bit) freshly installed
- Ethernet connection to your router
- Internet connection for downloading packages
- SSH access to the Pi (after initial OS setup)
- Basic Linux command line knowledge

### Step 1: Initial Raspberry Pi OS Setup

Follow the **detailed instructions for OS flashing and initial configuration**
in: ➡️ [RASPBERRY_PI_SERVER_SETUP.md](RASPBERRY_PI_SERVER_SETUP.md)

Ensure you have configured:

1.  Hostname (e.g., `my-pihole.local`)
2.  Username (e.g., `your_username`) and password
3.  Static IP (e.g., `192.168.1.XXX/24`), Gateway, and DNS servers.
4.  Time Zone (e.g., `Australia/Sydney`)
5.  SSH with password authentication.

After completing the OS setup, connect to your Pi via SSH:

```bash
# If re-imaging your Pi and seeing a host key warning (run on your computer):
# ssh-keygen -R 192.168.1.XXX # Replace with your Pi's IP
ssh your_username@192.168.1.XXX # Connect to your Pi (replace with your username and Pi's static IP)
```

### Step 2: Deploy the Home Server (on your Raspberry Pi)

These steps are performed on your Raspberry Pi via SSH. Refer to
[RASPBERRY_PI_SERVER_SETUP.md](RASPBERRY_PI_SERVER_SETUP.md) for detailed
explanations.

#### Option A: One-Command Deployment (Recommended)

1.  **Clone the repository:**

    ```bash
    # HTTPS (recommended for most users)
    git clone https://github.com/Robo-Chef/Modular-Pi-Server.git ~/pihole-server
    # OR SSH (if you have SSH keys configured)
    # git clone git@github.com:Robo-Chef/Modular-Pi-Server.git ~/pihole-server
    cd ~/pihole-server
    ```

2.  **Configure your `.env` file:**

    ```bash
    cp env.example .env
    nano .env
    ```

    **Required Settings:**

    - `UNIVERSAL_PASSWORD` - Change from default
    - `TZ` - Your timezone (e.g., `America/New_York`, `Europe/London`)
    - `PI_STATIC_IP` - Your Pi's IP address (e.g., `192.168.0.100`)
    - `PI_GATEWAY` - **Your router's IP** (find with
      `ipconfig | findstr "Default Gateway"` on Windows)
    - `PIHOLE_HOSTNAME` - Friendly name for your Pi-hole

    **Optional Settings:**

    - `ENABLE_MONITORING=true` - Enable Grafana/Uptime Kuma dashboards
    - Network settings - Use defaults unless you have conflicts

    **How to find your router's IP (PI_GATEWAY):**

    ```powershell
    # On Windows:
    ipconfig | findstr "Default Gateway"

    # On Linux/Mac:
    ip route | grep default
    ```

    Common values: `192.168.0.1`, `192.168.1.1`, or `10.0.0.1`

3.  **Deploy everything:**

    ```bash
    ./scripts/deploy.sh
    ```

    **Important - Two-Stage Process:** On fresh systems, this script will:

    **Stage 1 (First Run):**

    - Install Docker and dependencies
    - Show Docker group errors (THIS IS NORMAL)
    - Exit with instructions to logout and reconnect

    **Expected Normal Warnings:**

    ```
    Cannot connect to the Docker daemon at unix:///var/run/docker.sock
    usermod: group 'docker' does not exist
    ERROR: Failed to add user to docker group
    ```

    ❌ Don't panic - these errors are completely expected!

    **You MUST do this (reconnection required):**

    ```bash
    exit  # Step 1: Close SSH connection
    ssh your_username@192.168.1.XXX  # Step 2: Reconnect to Pi
    cd ~/pihole-server  # Step 3: Navigate to project (REQUIRED!)
    ```

    **If Docker fails to start (common issue):**

    ```bash
    # Fix Docker group issue (run these if needed)
    sudo groupadd docker
    sudo usermod -aG docker $USER
    sudo chown root:docker /var/run/docker.sock
    sudo chmod 660 /var/run/docker.sock
    sudo systemctl start docker
    ```

    **Alternative (most reliable):** Simply reboot your Pi:

    ```bash
    sudo reboot
    # Then reconnect and navigate back: cd ~/pihole-server
    ```

    **Stage 2 (Second Run):**

    ```bash
    cd ~/pihole-server  # Navigate to project directory
    ./scripts/deploy.sh  # Run again - will deploy services successfully
    ```

#### Option B: Step-by-Step Deployment

1.  **Clone and configure** (same as Option A, steps 1-2)

2.  **Prepare and run setup scripts:**

    ```bash
    sudo apt update && sudo apt install -y dos2unix dnsutils
    dos2unix .env scripts/*.sh
    chmod +x scripts/*.sh
    ./scripts/setup.sh
    ```

    - **Important:** If `setup.sh` installs Docker, you'll need to **log out and
      log back in** for group changes to take effect.
    - **SSH Port Warning:** If you encounter SSH connection issues after setup,
      check that `/etc/ssh/sshd_config` has `Port 22` (not `Port 222222`).

3.  **Deploy services:**
    ```bash
    ./scripts/quick-deploy.sh
    ```

### Step 3: Configure Your Router (Refer to [RASPBERRY_PI_SERVER_SETUP.md](RASPBERRY_PI_SERVER_SETUP.md) for details)

1.  Access your router's admin interface.
2.  Locate DNS settings.
3.  Set Primary DNS to your Raspberry Pi's static IP (e.g., `192.168.1.XXX`).
4.  Save and apply settings.

### Step 4: Verify Installation (Refer to [RASPBERRY_PI_SERVER_SETUP.md](RASPBERRY_PI_SERVER_SETUP.md) for details)

1.  **Test DNS Resolution:** Verify ad-blocking and normal domain resolution
    from your Pi and other network devices.

    ```bash
    # Test DNS resolution using Pi-hole
    dig @192.168.1.XXX google.com # Replace with your Pi's IP
    ```

    **If DNS queries fail**: The deployment script should automatically
    configure Pi-hole network permissions. If issues persist, run:
    `docker exec pihole pihole -a -i all`

2.  **Check Web Interfaces:**

    **Always Available:**

    - **Pi-hole Admin**: `http://192.168.1.XXX/admin` (replace with your Pi's
      IP)
      - Login with `PIHOLE_PASSWORD` from your `.env` file

    **Available if `ENABLE_MONITORING=true`:**

    - **Grafana**: `http://192.168.1.XXX:3000`
      - ✅ **Auto-configured**: Login `admin/[UNIVERSAL_PASSWORD]` (set in .env)
      - ✅ **Zero-setup**: Prometheus data source and Pi-hole dashboard ready!
    - **Uptime Kuma**: `http://192.168.1.XXX:3001`
      - ✅ **Auto-configured**: Login `admin/[UNIVERSAL_PASSWORD]` (set in .env)
      - ✅ **Zero-setup**: Admin account already created!
    - **Prometheus**: `http://192.168.1.XXX:9090`
      - Direct metrics interface (advanced users)
    - **Portainer**: `http://192.168.1.XXX:9000`
      - Visual Docker container management
      - Create admin password on first visit

3.  **Verify Ad Blocking:** Confirm ads are blocked on websites.

## 🔧 IP Address Configuration

### Critical IP Settings

You must configure these IP addresses correctly for the system to work:

#### 1. Pi Static IP (`PI_STATIC_IP`)

- **Set during**: OS flashing with Raspberry Pi Imager
- **Used for**: All service URLs, router DNS configuration, SSH access
- **Example**: `192.168.1.100` (replace `100` with your chosen IP)
- **Must match**: The IP you set in Raspberry Pi Imager

#### 2. Gateway IP (`PI_GATEWAY`)

- **Set during**: OS flashing with Raspberry Pi Imager
- **Used for**: Router monitoring and network recovery
- **Default**: `192.168.1.1` (most home routers)
- **Must match**: Your router's actual IP address

#### 3. Docker Network IPs (Automatic)

- **Pi-hole Container**: `172.25.0.3` (internal Docker network)
- **Unbound Container**: `172.25.0.2` (internal Docker network)
- **Monitoring Network**: `172.26.0.0/24` (internal Docker network)
- **No action needed**: These are automatically configured

### IP Address Usage Throughout System

| Service       | URL Format                   | Example                      |
| ------------- | ---------------------------- | ---------------------------- |
| Pi-hole Admin | `http://192.168.1.XXX/admin` | `http://192.168.1.100/admin` |
| Grafana       | `http://192.168.1.XXX:3000`  | `http://192.168.1.100:3000`  |
| Uptime Kuma   | `http://192.168.1.XXX:3001`  | `http://192.168.1.100:3001`  |
| Prometheus    | `http://192.168.1.XXX:9090`  | `http://192.168.1.100:9090`  |
| Portainer     | `http://192.168.1.XXX:9000`  | `http://192.168.1.100:9000`  |

**Remember**: Replace `XXX` with your actual Pi's IP address everywhere!

## 🔒 Security Best Practices

### Password Security

- **Use one strong password** for all services (`UNIVERSAL_PASSWORD`)
- **Set a memorable but secure password** (12+ characters, mixed case, numbers,
  symbols)
- **Easy to remember** - no need to manage multiple passwords

### Network Security

- **All services are LAN-accessible** for easy management
- **Prometheus**: `http://192.168.1.XXX:9090` (LAN accessible)
- **Admin UIs**: Accessible from any device on your LAN

### Service Access

- **Pi-hole**: `http://192.168.1.XXX/admin` (LAN accessible)
- **Grafana**: `http://192.168.1.XXX:3000` (LAN accessible)
- **Uptime Kuma**: `http://192.168.1.XXX:3001` (LAN accessible)
- **Prometheus**: `http://192.168.1.XXX:9090` (LAN accessible)
- **Portainer**: `http://192.168.1.XXX:9000` (LAN accessible)

### Firewall Configuration

The system uses `nftables` for firewall protection. Key rules:

- **Default policy**: Drop all incoming traffic
- **Allow established connections**: Essential for active sessions
- **Allow SSH**: On configured port (default 22)
- **Allow DNS**: Port 53 (TCP/UDP) for Pi-hole
- **Allow Web Interfaces**: Ports 80, 443, 3000, 3001, 9000, 9090, 8787

## Common Issues & Quick Fixes

### SSH Host Key Changed Warning (After Reflashing Pi)

If you see this scary warning when trying to SSH:

```
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
```

**This is NORMAL after reflashing your Pi!** The new OS has different SSH keys.

**Quick Fix (Windows):**

```powershell
# Remove the old key from known_hosts
ssh-keygen -R 192.168.1.XXX
```

**Quick Fix (Linux/Mac):**

```bash
# Remove the old key from known_hosts
ssh-keygen -R 192.168.1.XXX
```

**Alternative:** Edit `~/.ssh/known_hosts` and delete the line for your Pi's IP
address.

After removing the old key, SSH will work normally and ask you to accept the new
key.

### Comprehensive Port and System Configuration

The system uses a comprehensive set of environment variables for complete
customization. All configurations are defined in your `.env` file:

#### **Port Configuration**

```bash
# Core Service Ports
SSH_PORT=22              # SSH access port
DNS_PORT=53              # Pi-hole DNS service
HTTP_PORT=80             # Pi-hole web interface
HTTPS_PORT=443           # HTTPS (for future SSL)

# Monitoring Ports
GRAFANA_PORT=3000        # Grafana dashboard
UPTIME_KUMA_PORT=3001    # Uptime monitoring
PROMETHEUS_PORT=9090     # Metrics (localhost only)
NODE_EXPORTER_PORT=9100  # System metrics (localhost only)
```

#### **System Performance Tuning**

```bash
# Network Performance
NETWORK_BUFFER_SIZE=26214400  # Network buffer size (bytes)

# Memory Management
VM_SWAPPINESS=1               # Swap usage (0-100, lower = less swap)
VM_DIRTY_RATIO=15             # Memory page management
VM_DIRTY_BACKGROUND_RATIO=5   # Background memory management
FS_FILE_MAX=65536             # Max open file descriptors
```

#### **Docker Resource Limits**

```bash
# Pi-hole Resources
PIHOLE_CPU_LIMIT=1.0          # CPU cores for Pi-hole
PIHOLE_MEMORY_LIMIT=512M      # Memory limit for Pi-hole
PIHOLE_MEMORY_RESERVATION=256M # Guaranteed memory

# Unbound Resources
UNBOUND_CPU_LIMIT=0.5         # CPU cores for Unbound
UNBOUND_MEMORY_LIMIT=256M     # Memory limit for Unbound
UNBOUND_MEMORY_RESERVATION=128M # Guaranteed memory
```

**Key Benefits:**

- ✅ **Single source of truth** - Change ports in one place
- ✅ **Automatic consistency** - Firewall, Docker, and monitoring all sync
- ✅ **Performance tuning** - Optimize for your specific hardware
- ✅ **Resource management** - Control CPU and memory allocation
- ✅ **Future-proof** - Easy to customize without editing multiple files

**Important Notes:**

- All variables have sensible defaults if not specified
- Changing ports automatically updates firewall rules
- Resource limits prevent any single service from overwhelming the Pi
- System tuning optimizes performance for Raspberry Pi hardware

### Deploy Script Exits After Setup (Normal Behavior)

If `./scripts/deploy.sh` exits with Docker group errors, this is **completely
normal** for fresh installations:

**Quick Reminder Steps:**

```bash
exit  # Step 1: Close SSH connection
ssh your_username@192.168.1.XXX  # Step 2: Reconnect to Pi
cd ~/pihole-server  # Step 3: Navigate to project (REQUIRED!)
./scripts/deploy.sh  # Step 4: Run again - will work perfectly
```

**If Docker won't start (common):**

```bash
sudo reboot  # Most reliable fix
# Or manually fix: sudo groupadd docker && sudo usermod -aG docker $USER
```

(See detailed explanation in Option A deployment section above)

### Docker Service Won't Start

If you see `Failed to resolve group docker` or `docker.socket failed`:

**Quick Fix:**

```bash
sudo reboot  # Restart Pi (most reliable)
```

**Manual Fix:**

```bash
sudo groupadd docker
sudo usermod -aG docker $USER
sudo chown root:docker /var/run/docker.sock
sudo chmod 660 /var/run/docker.sock
sudo systemctl start docker
```

### DNS Queries Fail

If `dig @192.168.1.XXX google.com` times out:

```bash
docker exec pihole pihole -a -i all
```

### Container Won't Start

Check logs for specific error messages:

```bash
docker logs pihole
docker logs unbound
```

## Service Management & Maintenance

For detailed information on service management, monitoring, backups,
troubleshooting, and performance optimization, refer to the following
documentation:

- **Detailed Setup Guide:**
  [RASPBERRY_PI_SERVER_SETUP.md](RASPBERRY_PI_SERVER_SETUP.md)
- **Troubleshooting:** [docs/troubleshooting.md](docs/troubleshooting.md)
- **Security Hardening:**
  [docs/security-hardening.md](docs/security-hardening.md)
- **LAN-Only Stack Plan:**
  [docs/LAN_ONLY_STACK_PLAN.md](docs/LAN_ONLY_STACK_PLAN.md)

### Quick Commands:

```bash
# Start/Stop/Restart all services via systemd service (if setup.sh was used)
sudo systemctl start pihole-server.service
sudo systemctl stop pihole-server.service
sudo systemctl restart pihole-server.service
sudo systemctl status pihole-server.service

# Alternative: Direct Docker Compose commands
cd ~/pihole-server
docker compose -f docker/docker-compose.core.yml up -d              # Start core services
docker compose -f docker/docker-compose.core.yml down              # Stop core services
./scripts/deploy-monitoring.sh                                     # Deploy monitoring stack
docker compose -f docker/monitoring/docker-compose.monitoring.yml down  # Stop monitoring

# View individual container logs
docker logs pihole              # Always available
docker logs unbound            # Always available
docker logs grafana           # If monitoring deployed
docker logs prometheus        # If monitoring deployed
docker logs uptime-kuma       # If monitoring deployed
docker logs node-exporter     # If monitoring deployed

# Check container status
docker ps                     # Show all running containers
docker compose -f docker/docker-compose.core.yml ps    # Core services only
```

---

**Congratulations!** You have successfully deployed your Raspberry Pi home
server. Your system is now running with:

✅ **Core Services (Always Active):**

- Pi-hole DNS filtering and ad-blocking
- Unbound recursive DNS resolver
- Automatic network permission configuration

✅ **Optional Services (If Enabled):**

- **Grafana monitoring dashboards** (auto-configured with Prometheus data
  source)
- **Prometheus metrics collection** (ARM64 compatible)
- **Uptime Kuma status monitoring** (auto-configured admin account)
- **Portainer Docker management** (visual container management)

✅ **System Features:**

- **Zero-configuration deployment** (Grafana + Uptime Kuma auto-setup)
- **Router reboot resilience** (automatic detection and recovery with monitoring
  flags)
- **Automated backups and health checks**
- **Systemd service management**
- **Self-healing container restart policies**

**Next Steps:**

1. Configure your router to use `192.168.1.XXX` as primary DNS
2. Test ad-blocking on your devices
3. Monitor your system via the web interfaces
4. **Check router resilience status**: `./scripts/check-router-status.sh`

**🛡️ Router Reboot Protection:**

Your system now automatically detects and recovers from router reboots! Monitor
the resilience system:

```bash
# Check current status
./scripts/check-router-status.sh

# Watch in real-time
./scripts/check-router-status.sh --watch

# View recovery logs
./scripts/check-router-status.sh --logs
```

For detailed information, see:
[Router Reboot Resilience Guide](docs/ROUTER_REBOOT_RESILIENCE.md)

Enjoy your enhanced LAN experience! 🏠🔒
