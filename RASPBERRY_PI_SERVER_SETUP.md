# Raspberry Pi Home Server Setup Guide

This document outlines the detailed steps and configurations required to set up your Raspberry Pi 3 B+ as a high-performance, self-contained home server. It includes network-wide ad/tracker blocking (Pi-hole + Unbound), local DNS resolution with DNSSEC validation, and real-time monitoring (Prometheus/Grafana, Uptime Kuma).

---

## 📋 **Hardware & Network Overview**

- **Hardware:** Raspberry Pi 3 B+
- **Hostname:** `my-pihole.local` (Configured via `PIHOLE_HOSTNAME` in `.env`)
- **Static IP:** `192.168.1.XXX/24` (Configured via `PI_STATIC_IP` in `.env`)
- **Gateway:** `192.168.1.1` (Configured via `PI_GATEWAY` in `.env`)
- **Primary DNS (for Pi itself, before Pi-hole is up):** `8.8.8.8, 8.8.4.4` (Configured via `PI_DNS_SERVERS` in `.env`)
- **Universal Password:** `CHANGE_ME` (Configured via `UNIVERSAL_PASSWORD` in `.env`)
- **Time Zone:** `America/New_York` (Configured via `TZ` in `.env`)

---

## 📝 **Initial Pi OS Setup (via Raspberry Pi Imager)**

When flashing Raspberry Pi OS (64-bit Full recommended) onto your SD card using the Raspberry Pi Imager, use the **OS Customisation (Ctrl+Shift+X)** settings as follows:

_**Note:** Values for hostname, username, password, and timezone should match those configured in your `.env` file (copied from `env.example`)._

- **Set hostname:** `my-pihole.local` (Match `PIHOLE_HOSTNAME` in `.env`)
- **Set username and password:**
  - Username: `your_username` (You can change this, but remember to update `scripts/setup.sh` and other relevant files if you do.)
  - Password: `CHANGE_ME` (Match `UNIVERSAL_PASSWORD` in `.env`)
- **Configure wireless LAN:** Leave blank (as wired Ethernet is primary)
- **Set locale settings:**
  - Time Zone: `America/New_York` (Match `TZ` in `.env`)
  - Keyboard Layout: (Default, can confirm later)
- **Enable SSH:** `✓` **Use password authentication**
- **Options:**
  - Eject media when finished: `✓`
  - Enable telemetry: `✓`
  - Play sound when finished: `✗`

---

## 💻 **Post-OS-Flash Setup (via SSH)**

Once the Pi has booted with the new OS, you should be able to SSH into it:

_**Note:** Ensure all placeholder values (e.g., `your_username`, `192.168.1.XXX`, `CHANGE_ME`) match your `.env` configuration (copied from `env.example`)._

1.  **Wait 3-5 minutes** for the Pi to fully boot.
2.  **SSH into the Pi:**

    ```bash
    ssh your_username@192.168.1.XXX # Use the static IP from your .env
    ```

    (Password: `CHANGE_ME` - Match `UNIVERSAL_PASSWORD` from `.env`)

3.  **Clone the project:**

    ```bash
    git clone https://github.com/Robo-Chef/BorkHole.git ~/pihole-server
    cd ~/pihole-server
    ```

4.  **Copy `env.example` to `.env` and configure:**

    ```bash
    cp env.example .env
    nano .env
    ```

    _Ensure the following values are set with your desired personalized details (these are examples from `env.example`):_

    ```ini
    UNIVERSAL_PASSWORD=CHANGE_ME
    PIHOLE_PASSWORD=CHANGE_ME_PIHOLE
    PIHOLE_ADMIN_EMAIL=admin@yourdomain.local
    TZ=America/New_York
    PI_STATIC_IP=192.168.1.XXX
    PI_GATEWAY=192.168.1.1
    PI_DNS_SERVERS=8.8.8.8,8.8.4.4
    GRAFANA_ADMIN_PASSWORD=CHANGE_ME_GRAFANA
    ```

    _Save and exit (`Ctrl+O`, `Enter`, `Ctrl+X`)._

5.  **Fix line endings for scripts (install `dos2unix` first):**

    ```bash
    sudo apt update && sudo apt install -y dos2unix
    dos2unix .env scripts/*.sh
    ```

6.  **Make scripts executable:**

    ```bash
    chmod +x scripts/*.sh
    ```

7.  **Run the initial setup script:**

    ```bash
    ./scripts/setup.sh
    ```

    This installs Docker, creates project directories, configures kernel parameters, and sets up `nftables`.

---

## ⚙️ **Router-Resilient Service Startup Configuration**

This is crucial for handling daily router reboots. We will configure the `systemd` service for your Docker Compose setup to wait for the network to be fully online before starting services.

1.  **Edit the `systemd` service file:** (Assuming the service created by `setup.sh` is `pihole-server.service`)

    ```bash
    sudo nano /etc/systemd/system/pihole-server.service
    ```

    _Ensure the `[Unit]` section contains these lines (add if missing or modify if different):_

    ```ini
    [Unit]
    Description=BorkHole Docker Compose Application
    Requires=docker.service
    After=docker.service network-online.target
    Wants=network-online.target
    ```

    _Save and exit (`Ctrl+O`, `Enter`, `Ctrl+X`)._

2.  **Reload systemd and enable/start the service:**

    ```bash
    sudo systemctl daemon-reload
    sudo systemctl enable pihole-server.service
    sudo systemctl start pihole-server.service
    ```

3.  **Verify Docker containers:**

    ```bash
    docker ps
    ```

    You should see `pihole`, `unbound`, `grafana`, etc., all in `Up` status.

---

## 🛡️ **Pi-hole Adlist & Regex Configuration**

Log into the Pi-hole Admin Panel (`http://${PI_STATIC_IP}/admin`, password `CHANGE_ME_PIHOLE` from `.env`)

1.  **Update Adlists (Adlists → Add lists):**

    - `https://raw.githubusercontent.com/AdguardTeam/AdguardFilters/master/BaseFilter/BaseFilter.txt`
    - `https://raw.githubusercontent.com/AdguardTeam/AdguardFilters/master/SpywareFilter/SpywareFilter.txt`
    - `https://raw.githubusercontent.com/AdguardTeam/AdguardFilters/master/MobileFilter/sections/tracking.txt`
    - `https://raw.githubusercontent.com/StevenBlack/hosts/master/data/urlhaus.txt`
    - `https://raw.githubusercontent.com/StevenBlack/hosts/master/data/feodo.txt`
    - `https://raw.githubusercontent.com/StevenBlack/hosts/master/data/zeus.txt`
    - `https://raw.githubusercontent.com/StevenBlack/hosts/master/data/malware.txt`
    - Click "Save and Update" or force a Gravity update via SSH (`docker exec pihole pihole -g`).

2.  **Add Aggressive Regex Filters (Regex filtering → Add regex filter):**

    - `/\.*popup\.\*/i`
    - `/\.*redirect\.\*/i`
    - `/\.*popunder\.\*/i`
    - `/\.*interstitial\.\*/i`
    - `/\.*banner\.*ad\.\*/i`
    - `/\.*native\.*ad\.\*/i`
    - `/\.*push\.*notification\.\*/i`
    - `/\.*in\.*page\.*push\.\*/i`
    - `/\.*video\.*ad\.\*/i`
    - `/\.*direct\.*link\.*ad\.\*/i`

---

## ✔️ **Verification**

- **Test Pi-hole functionality:**
  - `dig @${PI_STATIC_IP} doubleclick.net` (Should return `0.0.0.0`)
  - `dig @${PI_STATIC_IP} google.com` (Should return real IP)
- **Test ad blocking from Windows PC:**
  - `nslookup doubleclick.net ${PI_STATIC_IP}` (Should return `0.0.0.0`)
  - `nslookup google.com ${PI_STATIC_IP}` (Should return real IP)
- **Test extreme ad blocking site:** Visit `https://canyoublockit.com/extreme-test/`

---

## 🔄 **Router Reboot Resilience Test**

1.  Re-enable your router's daily 4 AM reboot schedule.
2.  After 4 AM, verify that Pi-hole and all services are still running and accessible.
