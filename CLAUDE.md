# Important Information for Claude

## Current VPN Setup

### Active Servers
1. **Finland** (Primary)
   - IP: 46.62.146.210
   - Domain: freedomacrossborders.shop
   - Port: 8443
   - Provider: Hetzner
   - Purpose: General use, stable connection

2. **Bahrain** (Optimized for Dubai)
   - IP: 154.205.146.39
   - Port: 443 (stealth mode)
   - Provider: Lightnode
   - Latency from Dubai: 45-75ms
   - Purpose: WhatsApp calls from Dubai/UAE

### Key Findings from Testing
- **Best latency from Dubai**: Dubai local server (14-15ms) > Bahrain (45-75ms) > Singapore (113ms)
- **Avoid**: Mumbai (180ms - routes via Singapore/Paris)
- **Port 443 is optimal**: Reduces ISP throttling, looks like HTTPS traffic

### Server Credentials
- SSH keys located in: `/opt/vpn-subscription/ssh_keys/`
- Bahrain SSH: `ssh -i /opt/vpn-subscription/ssh_keys/bahrain-server-rsa root@154.205.146.39`

### Subscription Service
- URL: `http://freedomacrossborders.shop:5000/sub/{username}`
- Service: `/opt/vpn-subscription/simple-sub.py`
- Restart: `systemctl restart simple-sub`

### User IDs
- testuser: 3b331a0b-fe16-4c0a-9e25-26ba0ac6f57b
- ali: aae97e4b-8509-4c9b-8f1c-8c5095e1497b

### Testing Commands
```bash
# Test latency
ping -c 4 154.205.146.39  # Bahrain
ping -c 4 46.62.146.210   # Finland

# Check services
systemctl status simple-sub
systemctl status nginx
systemctl status x-ui

# Test subscription
curl -s http://localhost:5000/sub/ali | base64 -d
```

### Optimization Notes
- BBR congestion control enabled on Bahrain server
- Using VLESS protocol with TCP
- Port 443 provides better performance than 8443 in UAE

## Repository
- GitHub: https://github.com/alidarvishi14/multi-vpn-server
- Auto-update available but not yet deployed