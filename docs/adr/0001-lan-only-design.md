# 0001-lan-only-design

## Title: LAN-Only Design for Raspberry Pi Home Server

## Status: Accepted

## Context

The Raspberry Pi Home Server project aims to provide a robust and easy-to-deploy solution for common home server functionalities (ad-blocking, monitoring, optional services) using a Raspberry Pi 3 B+.

A key architectural decision was made early in the project to strictly limit network access to the local area network (LAN) only, explicitly avoiding external exposure or internet-facing services.

This decision was influenced by:

- **Hardware Limitations:** The Raspberry Pi 3 B+ has limited processing power and memory, which can be easily saturated by internet-facing services under even moderate load or attack.
- **Security Complexity:** Exposing services to the internet significantly increases the attack surface and requires robust security measures (e.g., advanced firewall rules, intrusion detection, regular vulnerability patching, secure certificate management, DDoS protection) that are complex to implement and maintain on a personal home server.
- **ISP Limitations (e.g., CGNAT):** Many Internet Service Providers (ISPs) implement Carrier-Grade NAT (CGNAT), which prevents direct inbound connections from the internet to devices within a home network, making external access challenging or impossible without additional services (e.g., VPN tunnel, cloudflare tunnel).
- **Primary Use Case:** The primary goal of this project is to serve local network needs (e.g., ad-blocking for all LAN devices, local monitoring dashboards, self-hosted Git for local development) without requiring remote access.
- **Simplified Troubleshooting:** A LAN-only setup drastically reduces the complexity of network configuration and troubleshooting, focusing efforts on internal network stability.

## Decision

We decide to implement the Raspberry Pi Home Server with a strict LAN-only network configuration. All services are designed to be accessible only from devices connected to the same local network as the Raspberry Pi. No port forwarding, external DNS registration, or internet-facing tunnels will be configured by default within this project.

## Consequences

### Positive

- **Significantly Reduced Attack Surface:** The server is not directly exposed to the vast majority of internet-based threats, greatly enhancing its inherent security.
- **Simplified Security Management:** Less effort is required for firewall configuration, intrusion detection, and certificate management for external access.
- **Optimized Performance:** Resources on the Raspberry Pi are dedicated to serving local network requests, preventing performance degradation from external internet traffic or attacks.
- **Compliance with ISP Restrictions:** The design naturally accommodates ISP restrictions like CGNAT without requiring workarounds.
- **Clear Scope and Focus:** The LAN-only constraint provides a clear boundary for feature development and simplifies the project's overall architecture.

### Negative

- **No External Access:** Users cannot directly access server services (e.g., Pi-hole admin, Grafana dashboards, Gitea) from outside their local network.
- **Limited Collaboration:** For services like Gitea, collaboration is restricted to users physically present on the local network or connected via a VPN (configured separately, outside the scope of this project).
- **No Remote Management (Direct):** Direct remote management via SSH or web interfaces from outside the LAN is not supported by default. Alternative secure remote access methods (e.g., VPN into home network) must be set up independently by the user if required.

## Alternatives Considered

- **VPN Server on Pi:** Setting up a VPN server (e.g., WireGuard, OpenVPN) on the Raspberry Pi to allow secure remote access. This was deemed too complex to include by default, as it requires dynamic DNS, port forwarding (often blocked by CGNAT), and additional client-side configuration.
- **Cloudflare Tunnel/Ngrok:** Using services like Cloudflare Tunnel or Ngrok to expose local services to the internet securely. While these abstract away some networking complexity, they introduce reliance on third-party services, potential performance overhead, and still require careful security configuration beyond the scope of a simple home server project.
