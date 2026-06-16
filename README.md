# 🧅 Tor Gateway Container

[![Docker Multi-Arch Build](https://github.com/AndrewSaff/tor-gateway/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/AndrewSaff/tor-gateway/actions/workflows/docker-publish.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/565795/tor-gateway.svg)](https://hub.docker.com/r/565795/tor-gateway)
[![Docker Image Size](https://img.shields.io/docker/image-size/565795/tor-gateway/latest)](https://hub.docker.com/r/565795/tor-gateway)
[![Platforms](https://img.shields.io/badge/platforms-amd64%20%7C%20arm64%20%7C%20arm%2Fv7-blue)](https://hub.docker.com/r/565795/tor-gateway/tags)

Lightweight multi-architecture Docker image providing a Tor gateway with Snowflake, obfs4 and WebTunnel support.

---

## 🌐 English

### ✨ Features
- 🚀 **Multi-arch**: `amd64`, `arm64`, `arm/v7`
- 🔒 Built-in pluggable transports: `snowflake-client`, `obfs4proxy`, `webtunnel-client`
- 🌐 **Privoxy** HTTP proxy with DNS-over-Tor (`forward-socks5t`)
- 🛡️ **Non-exit relay** (`ExitRelay 0`)
- 💾 **Reduced disk writes**: `AvoidDiskWrites 1` and stdout-based logging
- 📦 Auto-builds via GitHub Actions
- 🩺 Built-in healthcheck for Tor and Privoxy services

### 📁 Project Structure
```text
tor-gateway/
├── .github/workflows/docker-publish.yml
├── additions/
│   ├── start.sh
│   └── etc/
│       ├── tor/torrc
│       └── privoxy/config
├── Dockerfile
├── docker-compose.yml
├── docker-compose.dev.yml
└── README.md
```

### 🔌 Ports
| Port | Protocol | Service |
|------|----------|--------|
| `5353` | TCP/UDP | DNS over Tor |
| `9040` | TCP | Transparent proxy (TransPort) |
| `9050` | TCP | SOCKS5 proxy |
| `8118` | TCP | Privoxy HTTP proxy |

### 📦 Quick Start
**Docker Compose (recommended):**
```bash
git clone https://github.com/AndrewSaff/tor-gateway.git
cd tor-gateway
docker compose up -d
```
**Development (build locally from Dockerfile):**
```bash
git clone https://github.com/AndrewSaff/tor-gateway.git
cd tor-gateway
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build
```

### ⚠️ Security Notice (LAN/WAN)
By default, this container is intended to work as a **LAN gateway** and listens on `0.0.0.0` for:
- `5353` (DNS over Tor)
- `9040` (Tor TransPort)
- `9050` (SOCKS5)
- `8118` (Privoxy HTTP proxy)

This is intentional for local-network usage.

**Do not expose these ports to the Internet (WAN).**  
You must enforce firewall rules to allow access only from trusted LAN subnets and block all WAN access.

Minimum requirement:
- Allow: trusted LAN ranges only
- Deny: all WAN traffic to `5353/udp`, `5353/tcp`, `9040/tcp`, `9050/tcp`, `8118/tcp`

If you do not need LAN-wide access, bind ports to localhost (`127.0.0.1`) instead.

### Docker CLI:
```bash
docker run -d --name tor-gateway --restart unless-stopped \
  -p 5353:5353/tcp -p 5353:5353/udp \
  -p 9040:9040/tcp -p 9050:9050/tcp -p 8118:8118/tcp \
  -v $(pwd)/tor-data:/var/lib/tor \
  565795/tor-gateway:latest
```

### 💾 Persistent Tor State
This preserves Tor cache, consensus data and state files between container restarts,
reducing bootstrap time and network traffic.
```yaml
volumes:
  - ./tor-data:/var/lib/tor
```

### 🛠️ Custom Configuration
Default configs are baked into the image (additions/etc/). To override them without rebuilding:
1. Create files in the project root:
```bash
cp additions/etc/tor/torrc custom-torrc
cp additions/etc/privoxy/config custom-privoxy
```
2. Edit custom-torrc / custom-privoxy as needed.
3. Uncomment/add in docker-compose.yml:
```yaml
volumes:
  - ./custom-torrc:/etc/tor/torrc:ro
  - ./custom-privoxy:/etc/privoxy/config:ro
```
4. Restart: docker compose down && docker compose up -d

### 📡 MikroTik Deployment
1. Prepare storage
```routeros
/docker set mount-dir=/usb/docker
```
2. Pull image
```routeros
/docker/pull 565795/tor-gateway:latest
```
3. Create & start container
```routeros
/docker/add name=tor-gateway image=565795/tor-gateway:latest root-dir=/usb/docker/tor-gateway
/docker/start tor-gateway
```
4. Configure NAT (Transparent proxying may break some applications, certificate pinning and non-HTTP protocols):
```routeros
/ip/firewall/nat/add chain=dstnat protocol=tcp dst-port=80,443 action=redirect to-ports=9040 comment="Tor TransPort"
```
5. Block WAN access:
   - Never expose ports 5353, 9040, 9050 or 8118 directly to the Internet.
   - Allow access only from trusted LAN networks.
```routeros
/ip/firewall/filter/add chain=input in-interface=wan protocol=tcp dst-port=5353,9040,9050,8118 action=drop comment="Block Tor ports on WAN"
/ip/firewall/filter/add chain=input in-interface=wan protocol=udp dst-port=5353 action=drop comment="Block Tor ports on WAN"
```

### ✅ Verify Connectivity

SOCKS5:
```bash
curl --proxy socks5h://127.0.0.1:9050 https://check.torproject.org/api/ip
```

HTTP Proxy:
```bash
curl -x http://127.0.0.1:8118 https://check.torproject.org/api/ip
```

<!-- -->
<!-- -->
📄 License: MIT. Use at your own risk. Tor is a registered trademark of The Tor Project, Inc.
