# 📋 Deployment Checklist - Raspberry Pi Home Server

## **Pre-Deployment (Before Flashing Pi OS)**

- [ ] **Hardware Ready**

  - [ ] Raspberry Pi 3 B+ with 32GB+ SD card
  - [ ] Ethernet cable
  - [ ] Power supply (5V/2.5A recommended)
  - [ ] MicroSD card reader

- [ ] **Network Planning**
  - [ ] Choose static IP for Pi (e.g., 192.168.1.XXX)
  - [ ] Note your router's gateway IP (e.g., 192.168.1.1)
  - [ ] Choose hostname (e.g., my-pihole.local)
  - [ ] Choose strong password

## **Pi OS Flashing (Raspberry Pi Imager)**

- [ ] **Download Raspberry Pi Imager**
- [ ] **Flash Raspberry Pi OS (64-bit) Full**
- [ ] **Configure Advanced Options (Ctrl+Shift+X)**:
  - [ ] **Hostname**: `my-pihole.local`
  - [ ] **Username**: `your_username`
  - [ ] **Password**: `YourSecurePassword123!`
  - [ ] **Timezone**: `America/New_York` (or your timezone)
  - [ ] **Enable SSH**: ✓ Use password authentication
  - [ ] **Static IP**: `192.168.1.XXX/24`
  - [ ] **Gateway**: `192.168.1.1`
  - [ ] **DNS**: `8.8.8.8,8.8.4.4`

## **Post-Flash Setup**

- [ ] **Insert SD card into Pi and boot**
- [ ] **Wait 3-5 minutes for first boot**
- [ ] **SSH into Pi**:
  ```bash
  ssh your_username@192.168.1.XXX
  ```

## **Project Deployment**

- [ ] **Clone Repository**:

  ```bash
  git clone https://github.com/Robo-Chef/Modular-Pi-Server.git ~/pihole-server
  cd ~/pihole-server
  ```

- [ ] **Configure Environment**:

  ```bash
  cp env.example .env
  nano .env  # Update with your values
  ```

- [ ] **Validate Configuration**:

  ```bash
  ./scripts/validate-config.sh
  ```

- [ ] **Deploy Services**:
  ```bash
  ./scripts/deploy.sh
  ```

## **Post-Deployment Verification**

- [ ] **Test Core Services**:

  ```bash
  # DNS resolution
  dig @192.168.1.XXX google.com

  # Ad blocking
  dig @192.168.1.XXX doubleclick.net  # Should return 0.0.0.0
  ```

- [ ] **Access Web Interfaces**:

  - [ ] Pi-hole Admin: `http://192.168.1.XXX/admin`
  - [ ] Grafana: `http://192.168.1.XXX:3000`
  - [ ] Uptime Kuma: `http://192.168.1.XXX:3001`

- [ ] **Run Comprehensive Tests**:
  ```bash
  ./scripts/test-deployment.sh
  ```

## **Router Configuration**

- [ ] **Access Router Admin Interface**
- [ ] **Set Primary DNS** to Pi's IP (`192.168.1.XXX`)
- [ ] **Optional**: Disable router DHCP
- [ ] **Optional**: Enable Pi-hole DHCP in admin panel
- [ ] **Save and Apply Settings**

## **Final Verification**

- [ ] **Test from Client Device**:

  ```bash
  # From Windows PC
  nslookup google.com 192.168.1.XXX
  nslookup doubleclick.net 192.168.1.XXX  # Should return 0.0.0.0
  ```

- [ ] **Check Pi-hole Logs**:

  ```bash
  docker logs pihole
  ```

- [ ] **Monitor Resource Usage**:
  ```bash
  htop
  docker stats
  ```

## **Optional Services Setup**

- [ ] **Enable Optional Services** (in `.env`):

  ```bash
  ENABLE_PORTAINER=true      # Docker management
  ENABLE_DOZZLE=true        # Log viewer
  ENABLE_SPEEDTEST_TRACKER=true  # Speed monitoring
  ```

- [ ] **Redeploy with Optional Services**:
  ```bash
  ./scripts/quick-deploy.sh
  ```

## **Security Hardening**

- [ ] **Change Default Passwords**
- [ ] **Enable SSH Key Authentication**
- [ ] **Review Firewall Rules**: `sudo nft list ruleset`
- [ ] **Enable Automatic Updates**
- [ ] **Set Up Monitoring Alerts**

## **Maintenance Setup**

- [ ] **Test Backup System**:

  ```bash
  ./scripts/maintenance.sh backup
  ```

- [ ] **Schedule Regular Maintenance**:
  ```bash
  # Add to crontab
  crontab -e
  # Add: 0 2 * * 0 /home/your_username/pihole-server/scripts/maintenance.sh full
  ```

## **Troubleshooting Checklist**

If issues occur:

- [ ] **Check Service Status**: `./scripts/maintenance.sh status`
- [ ] **View Container Logs**: `docker logs <container_name>`
- [ ] **Validate Configuration**: `./scripts/validate-config.sh`
- [ ] **Check Network Connectivity**: `ping 8.8.8.8`
- [ ] **Verify Firewall**: `sudo nft list ruleset`
- [ ] **Check Resource Usage**: `htop`, `df -h`, `free -h`

## **Success Criteria**

Deployment is successful when:

- [ ] ✅ All containers are running (`docker ps`)
- [ ] ✅ DNS resolution works from clients
- [ ] ✅ Ad blocking is active
- [ ] ✅ Web interfaces are accessible
- [ ] ✅ Monitoring shows data
- [ ] ✅ No error messages in logs
- [ ] ✅ Resource usage is reasonable (<80% CPU, <90% memory)

---

**🎉 Congratulations!** Your Raspberry Pi Home Server is now running
successfully!

**📚 Next Steps:**

- Explore Grafana dashboards
- Configure Pi-hole blocklists
- Set up Uptime Kuma monitors
- Enable additional optional services
- Review security hardening guide
