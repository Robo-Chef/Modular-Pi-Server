# Raspberry Pi Home Server Setup Guide

This document outlines the detailed steps and configurations required to set up your Raspberry Pi 3 B+ as a high-performance, self-contained home server. It includes network-wide ad/tracker blocking (Pi-hole + Unbound), local DNS resolution with DNSSEC validation, and real-time monitoring (Prometheus/Grafana, Uptime Kuma).
For the foundational design principles and rationale behind this LAN-only setup, refer to the [LAN-Only Stack Plan](docs/LAN_ONLY_STACK_PLAN.md).

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

- **Set hostname:** `my-pihole.local`
  _Explanation: Choose a descriptive hostname like `my-pihole.local` to easily identify your Raspberry Pi on your local network. You will set this same value for `PIHOLE_HOSTNAME` in your `.env` file later._
- **Set username and password:**
  - Username: `your_username`
  - Password: `CHANGE_ME`
    _Explanation: Choose a strong, unique username and password. This will be your primary login for the Raspberry Pi via SSH. You will set this same password for `UNIVERSAL_PASSWORD` in your `.env` file later._
- **Configure wireless LAN:** Leave blank (as wired Ethernet is primary)
  _Explanation: For a server, a wired Ethernet connection is generally more stable and reliable than Wi-Fi. We prioritize a wired connection._
- **Set locale settings:**
  - Time Zone: `America/New_York`
    _Explanation: Setting the correct timezone is crucial for accurate logging, scheduling, and overall system functionality. You will set this same value for `TZ` in your `.env` file later._
  - Keyboard Layout: (Default, can confirm later)
- **Enable SSH:** `✓` **Use password authentication**
  _Explanation: SSH (Secure Shell) allows you to remotely access and control your Raspberry Pi from another computer. Enabling password authentication is for initial setup, which will later be hardened with key-based authentication for enhanced security._
- **Options:**
  - Eject media when finished: `✓`
  - Enable telemetry: `✓`
    _Explanation: Enabling telemetry provides anonymous usage data to the Raspberry Pi Foundation, helping them improve future versions of the Imager and OS. This is optional and can be disabled if preferred._
  - Play sound when finished: `✗`

---

## 💻 **Post-OS-Flash Setup (via SSH)**

Once the Pi has booted with the new OS, you should be able to SSH into it:

_**Important:** The `your_username` and `192.168.1.XXX` values here should match what you configured during the initial OS setup in the Raspberry Pi Imager._

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

    \_**Crucial:** Open the newly created `.env` file and replace all placeholder values (e.g., `CHANGE_ME`, `your_timezone`, `192.168.1.XXX`) with your desired, secure, and unique settings. At minimum set:

    - `TZ` (e.g., `Australia/Sydney`)
    - `PI_STATIC_IP` (your Pi's LAN IP)
    - `PIHOLE_PASSWORD` (admin password)
    - `GRAFANA_ADMIN_PASSWORD` (if monitoring enabled)
    - Optional: Watchtower email vars if you want update notifications

    _Ensure you save the changes to `.env` after editing._

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

## 🌐 **Router Configuration for Pi-hole DNS**

For network-wide ad blocking and DNS resolution, your router needs to be configured to use your Raspberry Pi (running Pi-hole) as its primary DNS server. The exact steps vary by router model and internet service provider (ISP).

1.  **Access Your Router's Administration Interface:**

    - Typically, you can access your router by entering its gateway IP address (e.g., `192.168.1.1` from your `.env` file) into a web browser.
    - Log in with your router's administrative credentials.

2.  **Locate DNS Settings:**

    - Navigate to the network, WAN, or DHCP settings section of your router's interface.
    - Find the fields for Primary DNS Server and (optionally) Secondary DNS Server.

3.  **Set Primary DNS to Raspberry Pi's Static IP:**

    - Enter your Raspberry Pi's static IP address (configured as `PI_STATIC_IP` in your `.env` file, e.g., `192.168.1.XXX`) as the **Primary DNS Server**.
    - For the Secondary DNS, you can either leave it blank (if your router allows) or set it to a public DNS server like `8.8.8.8` (Google DNS) as a fallback.

4.  **Consider DHCP Configuration (Optional but Recommended):**

    - For optimal Pi-hole functionality (e.g., seeing individual client names instead of just the router's IP), it is often recommended to **disable your router's DHCP server** and enable Pi-hole's built-in DHCP server.
    - If you choose to do this, ensure Pi-hole's DHCP server is configured **before** disabling it on your router to avoid network interruption.
    - Refer to the Pi-hole documentation for detailed instructions on configuring its DHCP server.

5.  **Save and Apply Settings:**
    - Save the changes on your router. Your router may reboot to apply the new settings.

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
  - ![Screenshot: Pi-hole Admin Panel showing blocked queries and network activity]
- **Test ad blocking from Windows PC:**
  - `nslookup doubleclick.net ${PI_STATIC_IP}` (Should return `0.0.0.0`)
  - `nslookup google.com ${PI_STATIC_IP}` (Should return real IP)
- **Test extreme ad blocking site:** Visit `https://canyoublockit.com/extreme-test/`

---

## 🔄 **Router Reboot Resilience Test**

This test is crucial to ensure that your Pi-hole server and all its services recover gracefully and maintain consistent network performance after routine network interruptions, such as daily router reboots or ISP-initiated network refreshes.

1.  Re-enable your router's daily 4 AM reboot schedule.
2.  After 4 AM, verify that Pi-hole and all services are still running and accessible.
