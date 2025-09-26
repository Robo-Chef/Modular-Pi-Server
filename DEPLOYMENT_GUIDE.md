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

#### **Option A: One-Command Deployment (Recommended)**

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

    - **Required:** Update `UNIVERSAL_PASSWORD`, `TZ`, `PI_STATIC_IP`,
      `PIHOLE_HOSTNAME`
    - **Optional:** Set `ENABLE_MONITORING=true` for Grafana/Uptime Kuma
    - **Network:** Use default `172.20.0.x` network unless you have conflicts

3.  **Deploy everything:**

    ```bash
    ./scripts/deploy.sh
    ```

    **Important - Two-Stage Process:** On fresh systems, this script will:

    **Stage 1 (First Run):**

    - Install Docker and dependencies
    - Show Docker group errors (THIS IS NORMAL - see below)
    - Exit with instructions to logout and reconnect

    **You MUST do this:** `exit` then SSH back in:
    `ssh your_username@192.168.1.XXX`

    **Stage 2 (Second Run):**

    - Run `./scripts/deploy.sh` again
    - Deploy all services successfully

    **Expected Normal Warnings (Don't Panic!):**

    - ❌ `Cannot connect to the Docker daemon` - Normal during fresh install
    - ❌ `usermod: group 'docker' does not exist` - Normal, fixed by
      logout/login
    - ❌ `Failed to add user to docker group` - Normal, requires reconnection
    - ✅ These errors are expected and will be resolved after reconnecting

#### **Option B: Step-by-Step Deployment**

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
4.  **(Optional):** Disable router's DHCP and enable Pi-hole's DHCP server for
    better client recognition.
5.  Save and apply settings.

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
      - Default login: `admin/admin` (change on first login)
    - **Uptime Kuma**: `http://192.168.1.XXX:3001`
      - Create admin account on first visit

3.  **Verify Ad Blocking:** Confirm ads are blocked on websites.

## Common Issues & Quick Fixes

### Deploy Script Exits After Setup (Normal Behavior)

If `./scripts/deploy.sh` exits with Docker group errors, this is **completely
normal** for fresh installations:

**What You'll See (Normal):**

```
Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?
usermod: group 'docker' does not exist
[DATE TIME] ERROR: Failed to add user to docker group.
```

**What To Do:**

1. **Don't panic** - these errors are expected
2. Log out of SSH: `exit`
3. Log back in: `ssh your_username@192.168.1.XXX`
4. Navigate back: `cd ~/pihole-server`
5. Run deploy script again: `./scripts/deploy.sh`
6. **Second run will work perfectly**

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
docker compose -f docker/docker-compose.core.yml up -d    # Start core services
docker compose -f docker/docker-compose.core.yml down    # Stop core services

# View individual container logs
docker logs pihole              # Always available
docker logs unbound            # Always available
docker logs grafana           # If ENABLE_MONITORING=true
docker logs prometheus        # If ENABLE_MONITORING=true
docker logs uptime-kuma       # If ENABLE_MONITORING=true

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

- Grafana monitoring dashboards
- Prometheus metrics collection
- Uptime Kuma status monitoring

✅ **System Features:**

- Automated backups and health checks
- Systemd service management
- Self-healing container restart policies

**Next Steps:**

1. Configure your router to use `192.168.1.XXX` as primary DNS
2. Test ad-blocking on your devices
3. Monitor your system via the web interfaces

Enjoy your enhanced LAN experience! 🏠🔒
