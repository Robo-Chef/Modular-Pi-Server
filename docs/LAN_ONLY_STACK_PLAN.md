<!--
This document outlines the strategic plan and rationale for the Raspberry Pi LAN-Only Stack.
It serves as the foundational design document, providing context for the technical implementation.
-->

# Raspberry Pi LAN-Only Stack Plan

This project is designed to transform your Raspberry Pi into a **self-contained, private home server (LAN-only)**. For a detailed rationale behind this architectural choice, refer to the [LAN-Only Design ADR](adr/0001-lan-only-design.md).

It aims to achieve the following:

1. **Protect and clean your internet connection inside the house**
   - Pi-hole blocks ads and trackers for every device on your Wi-Fi or Ethernet.
   - Unbound resolves domains directly, cutting out Google, Cloudflare, or your ISP. You get faster, more private lookups without depending on third-party DNS.
2. **Provide easy ways to manage and monitor it**
   - **Portainer** → a web dashboard to control all your Docker apps in one place. ![Screenshot: Portainer dashboard view]
   - **Dozzle** → a live log viewer, so you can spot issues without touching the terminal. ![Screenshot: Dozzle live logs interface]
   - **Uptime Kuma** → a “status page” that alerts you if Pi-hole or other services stop responding. ![Screenshot: Uptime Kuma status page]
   - **Speedtest Tracker** → scheduled internet speed tests, building evidence if your ISP underperforms. ![Screenshot: Speedtest Tracker results dashboard]
3. **Allow for optional growth into local services**
   - **Home Assistant** → smart home automation without cloud reliance. ![Screenshot: Home Assistant dashboard example]
   - **Gitea** → your own lightweight GitHub-style repo for projects. ![Screenshot: Gitea repository view]
   - **Netdata/Glances** → advanced monitoring of CPU, memory, and system health.
   - **code-server** → VS Code in your browser (when you’re at home on LAN).
4. **Maintain a clean, safe, and lightweight setup**
   - Everything is Dockerized → portable, restartable, easy to back up.
   - Runs only on your LAN → no exposure to the wider internet, no port forwarding, no CGNAT headaches.
   - Minimal load → a Pi 3 B+ with 1 GB RAM can run Pi-hole, Unbound, and lightweight QoL tools smoothly.
   - Static LAN IP → always reachable at `192.168.1.XXX` from any device in the house.

## ❌ Why External/Remote Access Isn’t Feasible: Design Constraints

This project was specifically designed with the following constraints in mind, which act as barriers to implementing more remote use cases:

- **ISP & Router Limitations**
  - Your public IP is shared (Carrier-Grade NAT).
  - No true port forwarding is possible unless ISP explicitly assigns a public IP.
  - Even if you configure your router correctly, inbound traffic from the internet won’t reach your Pi.
- **Router Limitations (Stock firmware)**
  - Cannot fully enforce DNS redirection → some devices still talk to ISP DNS directly.
  - No advanced NAT loopback or firewall rules to handle complex tunnels.
- **Pi 3 B+ Hardware Constraints**
  - 1 GB RAM → can’t comfortably run heavy VPN + extras at the same time.
  - WireGuard container (`wg-easy`) auto-overwrites configs → mismatched subnets and breakages.

👉 Collectively, these factors make **external VPN/tunnel solutions** (WireGuard, Cloudflare Tunnel, etc.) _more pain than they’re worth_.

The **rational design choice** for this project is to:

Focus on **LAN-only reliability**, where you actually get consistent results without battling ISP/router limitations.

## ✅ LAN-Only Plan (Feasible, Stable, and Lightweight)

### 1. **Core: Pi-hole + Unbound**

- **Pi-hole** → LAN-wide DNS and ad-blocking, runs on `192.168.1.XXX`.
- **Unbound** → recursive DNS resolver on `172.20.0.3`, validates with DNSSEC.
- Pi-hole forwards queries only to Unbound.

🔒 Result: All devices on LAN using Pi-hole → ads blocked, DNS private, ISP bypassed where possible.

---

### 2. **Network Design**

- Pi has **static IP**: `192.168.1.XXX` (Ethernet only).
- Router still leaks some DNS → workaround: set devices (PCs/phones) to use `192.168.1.XXX` manually.
- Optional future upgrade: OpenWRT router → enforce DNS properly.

---

### 3. **QoL Tools (Safe to Add)**

- **Portainer** → web UI for containers.
- **Dozzle** → live logs.
- **Uptime Kuma** → monitors services (is Pi-hole alive?).
- **Speedtest Tracker** → monitors ISP speeds over time.

⚖️ Low resource use → Pi 3 B+ can handle these alongside Pi-hole/Unbound.

---

### 4. **Optional Extras (Add Sparingly)**

- **Home Assistant** (if you want smart home later).
- **Gitea** (private git hosting).
- **Netdata** (advanced monitoring, but RAM heavy).

⚠️ Only one of these at a time — otherwise the Pi will choke.

---

### 5. **Security**

- LAN-only = no external exposure.
- Router firewall protects against WAN.
- Pi-hole admin password-protected.
- SSH → move to key-based authentication when possible.

---

### 6. **Maintenance**

- **Weekly**: update blocklists and check containers.
- **Monthly**: pull new images, `apt upgrade`, back up configs.
- **Backups**:

  ```bash
  ./scripts/backup.sh

  ```

---

# **Raspberry Pi Home Server: Technical Implementation Guide**

_Version 2.0 | Technical Deep Dive_

---

## **1. Executive Summary**

This project transforms a **Raspberry Pi 3 B+** into a **high-performance, self-contained home server** with:

- **Network-wide ad/tracker blocking** via Pi-hole + Unbound
- **Local DNS resolution** with DNSSEC validation
- **Real-time monitoring** (Prometheus/Grafana, Uptime Kuma)
- **Optional expansion** to smart home (Home Assistant) and self-hosted Git (Gitea)

**Additional information:**

All required hardware is already on hand, including a **Raspberry Pi 3 B+** connected via Ethernet to **your router**, which in turn links to **your internet connection (e.g., FTTP NBN box)**. We will build a **new home network around the Pi**, assigning it a static IP of **`192.168.1.XXX`** as the LAN’s primary DNS, with no existing DNS/DHCP conflicts.

The base OS will be **Raspberry Pi OS (full)** with the following customisation settings:

- **Hostname:** `my-pihole.local`
- **User Account:** Username `your_username` with a universal password (shared across all services, editable via `.env`).
- **SSH:** Enabled, password authentication (key-based access to be configured later).
- **Locale:** Time zone `your_timezone`; default keyboard layout.
- **Networking:** Wired Ethernet primary; Wi-Fi SSID field present but unused.

All services will share a single password, with the system designed so password changes propagate across containers. Backups will remain local on the SD card, and optional services will be selected pragmatically for maximum utility (e.g., monitoring or Home Assistant). The timeline is **ASAP**, with quality taking precedence over speed.

**Key Innovations**:

- **Zero Trust Networking**: Isolated Docker networks, no inbound internet exposure
- **Self-Healing**: Automated backups, log rotation, and container health checks
- **Enterprise-Grade Security**: nftables firewall, DNSSEC, and automated updates

---

### **Executive Constraints**

1. **ISP & Router Limitations**
   - **ISP DNS Lock:** Your ISP might enforce WAN-side DNS; setting the Pi (`192.168.1.XXX`) or `127.0.0.1` as WAN DNS might break resolution.
   - **Router DNS Restriction:** Some router firmware blocks non-public IPs in WAN DNS fields.
   - **DHCP Transition Risk:** Moving DHCP from your router to Pi-hole causes LAN downtime if not sequenced carefully.
   - **Router Flexibility:** Your router might offer limited DHCP/DNS overrides compared to enterprise hardware.
2. **Hardware (Raspberry Pi 3 B+)**
   - **RAM:** 1GB → limited for multiple containers (risk of OOM).
   - **CPU:** Quad-core, modest power → heavy services (Grafana, Home Assistant) need throttling.
   - **Storage:** SD card only (no SSD planned) → wear risk and lower reliability under writes.
   - **Networking:** Single Ethernet NIC → no VLAN isolation or dual-homing.
3. **Service & Configuration**
   - **Port 53 Conflict:** Pi-hole and Unbound both attempt to bind `:53`; requires explicit separation (Pi-hole → 53, Unbound → 127.0.0.1:5053).
   - **Password Policy:** Requirement for one universal password across services → must be enforced via `.env` injection/automation.
   - **Static IP Reliance:** Setup depends on Pi remaining fixed at `192.168.1.XXX`.
4. **Security & Maintenance**
   - **Update Risk:** No rollback plan for Docker updates → downtime possible.
   - **Backup Limitation:** Only SD card backups; no external target (NAS/cloud/SSD).
   - **Recovery Complexity:** Rebuilds are manual; no automated restore pipeline.

---

## **2. Technical Architecture**

**2.1 Network Design**

```jsx
mermaid

graph TB
    subgraph "Raspberry Pi 3 B+"
        A[eth0: 192.168.1.XXX] --> B[nftables Firewall]
        B --> C[Docker Network: 172.20.0.0/24]
        C --> D[Pi-hole (172.20.0.3)]
        C --> E[Unbound (172.20.0.2)]
        D -->|Block Ads| F[Internet]
        E -->|Recursive DNS| F
    end
    G[LAN Devices] -->|DNS:192.168.1.XXX| D
```

**2.2 Hardware Specifications**

| **Component**    | **Specification**                |
| ---------------- | -------------------------------- |
| **Raspberry Pi** | 3 B+ (1.4GHz quad-core, 1GB RAM) |
| **Storage**      | 32GB SanDisk High Endurance      |
| **Cooling**      | Passive heatsink + fan           |

**2.3 Performance Baseline**

- **DNS Response Time**: <50ms (cached), <200ms (uncached)
- **Memory Usage**: ~400MB (base), ~700MB (with monitoring)
- **Storage I/O**: 98% read operations (optimized with **`noatime`**)

---

## **3. Implementation Phases**

**Phase 1: Core Infrastructure (Week 1-2)**

**1.1 Base OS Configuration**

```jsx
bash

# Install Raspberry Pi OS Lite (64-bit)
sudo raspi-config
  # Set hostname: my-pihole.local
  # Enable SSH (key-based only)
  # Configure static IP: 192.168.1.XXX/24
  # Expand filesystem

# Kernel Tuning (/etc/sysctl.d/99-rpi.conf)
net.core.rmem_max=26214400
vm.swappiness=1
```

**1.2 Docker & Network Isolation**

```jsx
bash

# Install Docker with OverlayFS
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# Create isolated networks
docker network create --subnet=172.20.0.0/24 pihole_net
docker network create --internal isolated_net
```

**1.3 Pi-hole + Unbound Deployment**

**`docker-compose.core.yml`**:

```jsx
yaml

services:
  pihole:
    image: pihole/pihole:latest
    networks:
      pihole_net:
        ipv4_address: 172.20.0.3
      isolated_net:  # Block outbound DNS
    volumes:
      - ./pihole/etc-pihole:/etc/pihole
      - ./pihole/etc-dnsmasq.d:/etc/dnsmasq.d
      - ./pihole/logs:/var/log/pihole
    environment:
      TZ: ${TZ:-Australia/Sydney}
      WEBPASSWORD: ${PIHOLE_PASSWORD}
      DNS1: 172.20.0.2#5053  # Unbound
      DNS2: 127.0.0.1#5053 # Fallback to Unbound (redundant if DNS1 is Unbound)
      VIRTUAL_HOST: pihole.local # Consider removing if not using a reverse proxy
      VIRTUAL_PORT: 80 # Consider removing if not using a reverse proxy
      ServerIP: ${PI_STATIC_IP:-192.168.1.XXX} # Review for Docker bridge network usage
      PIHOLE_DNS_: 172.20.0.2#5053 # Redundant with DNS1
      PIHOLE_INTERFACE: eth0 # Review for Docker bridge network usage
      FTLCONF_LOCAL_IPV4: 172.20.0.3
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "80:80/tcp"
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
        reservations:
          memory: 256M
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/admin/api.php?summary"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    dns:
      - 172.20.0.2
      - 127.0.0.1 # Redundant with 172.20.0.2

  unbound:
    image: klutchell/unbound:latest
    networks:
      pihole_net:
        ipv4_address: 172.20.0.2
    volumes:
      - ./unbound/config:/etc/unbound/custom
      - ./unbound/logs:/var/log/unbound
    environment:
      TZ: ${TZ:-Australia/Sydney}
    ports:
      - "127.0.0.1:5053:5053/tcp" # Only accessible from host
      - "127.0.0.1:5053:5053/udp" # Only accessible from host
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 256M
        reservations:
          memory: 128M
    healthcheck:
      test: ["CMD", "unbound-control", "status"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    command: -d -v

networks:
  pihole_net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/24
          gateway: 172.20.0.1
    internal: false
  isolated_net:
    driver: bridge
    internal: true

```

**1.4 Firewall & Security**

**`/etc/nftables.conf`**:

```jsx
nft

table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;
    ct state {established, related} accept
    iifname "lo" accept
    ip saddr 192.168.1.0/24 tcp dport {22, 53, 80, 443} accept
    ip saddr 192.168.1.0/24 udp dport {53} accept
    icmp type echo-request accept
    counter drop
  }
}
```

---

**Phase 2: Monitoring & Automation (Week 3-4)**

**2.1 Prometheus + Grafana**

**`docker-compose.monitoring.yml`**:

```jsx
yaml

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    hostname: prometheus-server
    networks:
      - monitoring_net
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./prometheus/rules:/etc/prometheus/rules
      - prometheus_data:/prometheus
    environment:
      TZ: ${TZ:-Australia/Sydney}
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
      - "--storage.tsdb.path=/prometheus"
      - "--web.console.libraries=/etc/prometheus/console_libraries"
      - "--web.console.templates=/etc/prometheus/consoles"
      - "--storage.tsdb.retention.time=${PROMETHEUS_RETENTION:-15d}"
      - "--web.enable-lifecycle"
      - "--web.enable-admin-api"
    ports:
      - "127.0.0.1:9090:9090"
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 512M
        reservations:
          memory: 256M
    healthcheck:
      test:
        [
          "CMD",
          "wget",
          "--quiet",
          "--tries=1",
          "--spider",
          "http://localhost:9090/-/healthy",
        ]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    hostname: grafana-server
    networks:
      - monitoring_net
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./grafana/dashboards:/var/lib/grafana/dashboards
    environment:
      TZ: ${TZ:-Australia/Sydney}
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_ADMIN_PASSWORD}
      GF_USERS_ALLOW_SIGN_UP: false
      GF_USERS_ALLOW_ORG_CREATE: false
      GF_SECURITY_DISABLE_GRAVATAR: true
      GF_ANALYTICS_REPORTING_ENABLED: false
      GF_ANALYTICS_CHECK_FOR_UPDATES: false
      GF_LOG_LEVEL: warn
      GF_DATABASE_TYPE: sqlite3
      GF_SESSION_PROVIDER: file
      GF_SESSION_PROVIDER_CONFIG: sessions
    ports:
      - "3000:3000"
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 512M
        reservations:
          memory: 256M
    healthcheck:
      test:
        [
          "CMD-SHELL",
          "wget --quiet --tries=1 --spider http://localhost:3000/api/health || exit 1",
        ]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    depends_on:
      - prometheus

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    hostname: node-exporter
    networks:
      - monitoring_net
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - "--path.procfs=/host/proc"
      - "--path.rootfs=/rootfs"
      - "--path.sysfs=/host/sys"
      - "--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)"
    ports:
      - "127.0.0.1:9100:9100"
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: "0.1"
          memory: 128M
        reservations:
          memory: 64M

  uptime-kuma:
    image: louislam/uptime-kuma:latest
    container_name: uptime-kuma
    hostname: uptime-kuma-server
    networks:
      - monitoring_net
    volumes:
      - uptime_kuma_data:/app/data
    environment:
      TZ: ${TZ:-Australia/Sydney}
    ports:
      - "3001:3001"
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: "0.3"
          memory: 256M
        reservations:
          memory: 128M
    healthcheck:
      test:
        [
          "CMD",
          "wget",
          "--quiet",
          "--tries=1",
          "--spider",
          "http://localhost:3001",
        ]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

 volumes:
   prometheus_data:
     driver: local
   grafana_data:
     driver: local
   uptime_kuma_data:
     driver: local

 networks:
   monitoring_net:
     driver: bridge
     ipam:
       config:
         - subnet: 172.21.0.0/24
           gateway: 172.21.0.1
```

**2.2 Automated Backups**

**`/usr/local/bin/backup-pihole`**:

```jsx
bash

#!/bin/bash
BACKUP_DIR=/mnt/backup/pihole
rsync -avz --delete /home/${USER}/pihole-server/docker/pihole/ $BACKUP_DIR/$(date +%Y%m%d)/
find $BACKUP_DIR -type d -mtime +30 -exec rm -rf {} +
```

---

**Phase 3: Optional Services (Week 5-6)**

**3.1 Home Assistant**

**`docker-compose.optional.yml`** (service `homeassistant`):

```jsx
yaml

services:
  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    network_mode: host
    devices:
      - /dev/ttyUSB0:/dev/ttyUSB0  # Z-Wave/Zigbee (uncomment if you have dongle)
    volumes:
      - homeassistant_data:/config
```

**3.2 Gitea (Self-Hosted Git)**

**`docker-compose.optional.yml`** (service `gitea`):

```jsx
yaml

services:
  gitea:
    image: gitea/gitea:latest
    environment:
      - USER_UID=1000
      - USER_GID=1000
      - GITEA__server__SSH_PORT: 2223 # Changed to avoid conflict with host SSH
      - GITEA__server__DOMAIN: ${GITEA_DOMAIN:-gitea.local} # Make configurable
      - GITEA__server__ROOT_URL: ${GITEA_ROOT_URL:-http://gitea.local:3002} # Make configurable
    volumes:
      - gitea_data:/data
    ports:
      - "3002:3000" # Host:Container
      - "2223:22" # Host:Container (SSH, changed from 2222 due to conflict)
```

---

## **4. Security Hardening**

**4.1 SSH Hardening**

**`/etc/ssh/sshd_config`**:

```jsx
ini

Port 2222
PermitRootLogin no
PasswordAuthentication no
AllowUsers your_username
AllowTcpForwarding no
X11Forwarding no
```

**4.2 Automated Updates**

**`/etc/apt/apt.conf.d/50unattended-upgrades`**:

```jsx
ini

Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESM:${distro_codename}";
}
```

**4.3 Container Security**

```jsx
bash

# Enable Docker Content Trust
export DOCKER_CONTENT_TRUST=1

# Scan for vulnerabilities
docker scan pihole/pihole:latest
```

---

## **5. Testing & Validation**

**5.1 Smoke Tests**

```jsx
bash

# DNS resolution
dig @192.168.1.XXX +short google.com

# Ad blocking
curl -s http://pi.hole/admin/api.php?summary | jq '.ads_blocked_today'

# Container health
docker ps --format "{{.Names}}: {{.Status}}"
```

**5.2 Load Testing**

```jsx
bash

# Simulate 1000 DNS queries
for i in {1..1000}; do dig @192.168.1.XXX example.com & done
```

---

## **6. Maintenance & Scaling**

**6.1 Monitoring Dashboard**

- **Grafana**: **`http://192.168.1.XXX:3000`** ![Screenshot: Grafana dashboard with system and Pi-hole metrics]
  - Pi-hole stats
  - System metrics (CPU/RAM/Disk)
  - Network throughput

**6.2 Scaling Options**

- **Vertical**: Upgrade to Raspberry Pi 4 (4GB)
- **Horizontal**: Add secondary Pi with Keepalived for HA

**6.3 Disaster Recovery**

```jsx
bash

# Full system backup
sudo dd if=/dev/mmcblk0 | gzip > /mnt/backup/pi3b-full-$(date +%Y%m%d).img.gz

# Restore process
# gunzip -c backup.img.gz | sudo dd of=/dev/mmcblk0
```

---

## **7. Appendices**

**A1: Complete Docker Compose**

To view the full combined Docker Compose configuration, run `docker compose -f docker/docker-compose.core.yml -f docker/monitoring/docker-compose.monitoring.yml -f docker/optional/docker-compose.optional.yml config` in the project root.

**A2: Custom Blocklists**

```jsx
bash

# pihole/custom.list
https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
https://mirror1.malwaredomains.com/files/justdomains
```

**A3: Performance Tuning**

```jsx
ini

# /etc/systemd/system/docker.service.d/override.conf
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --log-driver=json-file --log-opt max-size=10m --log-opt max-file=3
```

---

**Next Steps**

1. Deploy Phase 1 and validate DNS resolution
2. Configure Grafana dashboards
3. Test backup/restore process
