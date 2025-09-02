# Multi-Location VPN Setup Guide

## Architecture Overview

This setup creates a scalable multi-location VPN service with:
- **Master Server (Finland)**: Manages users and configuration
- **Client Servers (Bahrain, etc)**: Sync users from master
- **X-UI Panel**: Web interface for VPN management
- **Subscription Service**: Generates VPN configuration URLs
- **Automatic Sync**: Users added in X-UI automatically sync to all servers

## Prerequisites

1. Servers with Ubuntu 22.04
2. Domain name with DNS management
3. SSH access to servers

## Setup Instructions

### 1. Master Server (Finland)

```bash
# Clone repository
cd /opt
git clone https://github.com/alidarvishi14/multi-vpn-server.git
cd multi-vpn-server

# Configure environment
cp .env.example .env
# Edit .env with your settings:
# - SERVER_NAME=finland
# - SERVER_IP=your-server-ip
# - MAIN_DOMAIN=freedomacrossborders.shop

# Run installation
./install.sh

# Deploy subscription service
cd subscription
bash deploy-scalable.sh master Finland freedomacrossborders.shop

# Start sync services
python3 sync/xui_sync.py --watch &
python3 sync/xui_master_sync.py --watch &
```

### 2. Client Server (Bahrain)

```bash
# Clone repository
cd /opt
git clone https://github.com/alidarvishi14/multi-vpn-server.git
cd multi-vpn-server

# Configure environment
cp .env.example .env
# Edit .env:
# - SERVER_NAME=bahrain
# - SERVER_IP=your-server-ip
# - ENABLE_PANEL=false
# - ENABLE_SUBSCRIPTION=false

# Run installation
./install.sh

# Configure DNS
# Add A record in your DNS: bahrain.freedomacrossborders.shop → server-ip

# Get SSL certificate
certbot certonly --nginx -d bahrain.freedomacrossborders.shop --non-interactive --agree-tos --email admin@yourdomain.com

# Deploy subscription service as client
cd subscription
bash deploy-scalable.sh client Bahrain bahrain.freedomacrossborders.shop

# Configure network for VPN
sysctl -w net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf

# Get network interface name
IFACE=$(ip route | grep default | awk '{print $5}')

# Setup NAT
iptables -t nat -A POSTROUTING -o $IFACE -j MASQUERADE
iptables -A FORWARD -j ACCEPT

# Make persistent
cat > /etc/systemd/system/vpn-network.service << EOF
[Unit]
Description=VPN Network Configuration
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'sysctl -w net.ipv4.ip_forward=1 && iptables -t nat -A POSTROUTING -o $IFACE -j MASQUERADE && iptables -A FORWARD -j ACCEPT'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable vpn-network
systemctl start vpn-network
```

### 3. Configure Sync Between Servers

On the master server, update the sync configuration:

```bash
# Edit /opt/vpn-subscription/.env on both servers with matching:
JWT_SECRET=your-secret-key
API_KEY=your-api-key

# Update nodes.json on master
cat > /opt/vpn-subscription/nodes.json << EOF
[
  {
    "name": "Finland",
    "host": "freedomacrossborders.shop",
    "port": 8443,
    "region": "EU"
  },
  {
    "name": "Bahrain",
    "host": "bahrain.freedomacrossborders.shop",
    "port": 8443,
    "region": "ME"
  }
]
EOF

# Restart services
systemctl restart vpn-scalable
systemctl restart xui-sync
systemctl restart xui-master-sync
```

## Service Management

### Check Service Status
```bash
systemctl status x-ui          # VPN server
systemctl status vpn-scalable  # Subscription service
systemctl status xui-sync      # X-UI to subscription sync
systemctl status xui-master-sync # Master to client sync
```

### View Logs
```bash
journalctl -u x-ui -f
journalctl -u vpn-scalable -f
```

## Adding Users

1. **Via X-UI Panel**: https://panel.freedomacrossborders.shop
   - Login with admin credentials
   - Add user in Inbounds section
   - User automatically syncs to all servers

2. **Via API**:
```bash
curl -X POST http://freedomacrossborders.shop:5000/api/v1/users \
  -H 'X-API-Key: your-api-key' \
  -H 'Content-Type: application/json' \
  -d '{"username":"newuser","uuid":"generated-uuid"}'
```

## Subscription URLs

Users can get their VPN configuration from:
- `http://freedomacrossborders.shop:5000/sub/username`
- `http://bahrain.freedomacrossborders.shop:5000/sub/username`

Both will provide configs for all available servers.

## Troubleshooting

### VPN Connection Works But No Internet
Check IP forwarding and NAT:
```bash
sysctl net.ipv4.ip_forward  # Should be 1
iptables -t nat -L POSTROUTING -n -v  # Should show MASQUERADE rule
```

### Users Not Syncing
```bash
# Check sync services
systemctl status xui-sync
systemctl status xui-master-sync

# Manual sync
python3 /opt/vpn-subscription/xui_sync.py
python3 /opt/vpn-subscription/xui_master_sync.py
```

### Port 8443 Not Accessible
```bash
# Check if service is running
ss -tlnp | grep 8443

# Check firewall
ufw status
iptables -L INPUT -n -v
```

## Security Notes

1. Change default X-UI admin password immediately
2. Use strong API keys in production
3. Keep SSL certificates updated
4. Regularly update system packages
5. Monitor logs for suspicious activity

## Adding More Servers

1. Follow "Client Server" setup on new server
2. Add server to nodes.json on master
3. Add server info to xui_master_sync.py
4. Restart sync services

## Backup

Important files to backup:
- `/etc/x-ui/x-ui.db` - User database
- `/opt/vpn-subscription/users.json` - User list
- `/opt/vpn-subscription/nodes.json` - Server list
- `/opt/vpn-subscription/.env` - Configuration