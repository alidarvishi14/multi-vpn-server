# Deployment Guide

## Quick Deploy on Any Server

### 1. Clone the Repository

```bash
# Option A: From GitHub (after you push)
git clone https://github.com/yourusername/multi-vpn-server.git
cd multi-vpn-server

# Option B: From local (copy the folder)
scp -r /opt/multi-vpn-server root@NEW_SERVER_IP:/opt/
ssh root@NEW_SERVER_IP
cd /opt/multi-vpn-server
```

### 2. Configure for Your Server

```bash
cp .env.example .env
nano .env
```

**Key settings to change:**
- `SERVER_NAME` - Unique name (finland, bahrain, usa, etc.)
- `SERVER_LOCATION` - Display location
- `MAIN_DOMAIN` - Your domain from Namecheap
- `ENABLE_SUBSCRIPTION` - true only on main server
- `CLIENT_ID` - Same across all servers for seamless switching

### 3. Run Installation

```bash
./install.sh
```

## Example Deployments

### Main Server (Finland)
```env
SERVER_NAME=finland
SERVER_LOCATION="Helsinki, Finland"
MAIN_DOMAIN=freedomacrossborders.shop
ENABLE_PANEL=true
ENABLE_SUBSCRIPTION=true
CLIENT_ID=3b331a0b-fe16-4c0a-9e25-26ba0ac6f57b
```

### Secondary Server (Bahrain)
```env
SERVER_NAME=bahrain
SERVER_LOCATION="Manama, Bahrain"
MAIN_DOMAIN=freedomacrossborders.shop
ENABLE_PANEL=true
ENABLE_SUBSCRIPTION=false  # Only main server needs this
CLIENT_ID=3b331a0b-fe16-4c0a-9e25-26ba0ac6f57b  # Same as main
```

### Third Server (Germany)
```env
SERVER_NAME=germany
SERVER_LOCATION="Frankfurt, Germany"
MAIN_DOMAIN=freedomacrossborders.shop
ENABLE_PANEL=true
ENABLE_SUBSCRIPTION=false
CLIENT_ID=3b331a0b-fe16-4c0a-9e25-26ba0ac6f57b  # Same as others
```

## DNS Setup (Namecheap)

Add these DNS records:

| Type | Host | Value | Purpose |
|------|------|-------|---------|
| A | @ | MAIN_SERVER_IP | Main domain |
| A | panel | MAIN_SERVER_IP | X-UI Panel |
| A | sub | MAIN_SERVER_IP | Subscription |
| A | finland | FINLAND_IP | Direct access |
| A | bahrain | BAHRAIN_IP | Direct access |

## Post-Installation

### Access Points

- **Subscription**: `https://sub.yourdomain.com/sub/username`
- **Finland Panel**: `https://panel.yourdomain.com/finland/`
- **Bahrain Panel**: `https://panel.yourdomain.com/bahrain/`

### Client Configuration

Users add ONE subscription URL and get ALL servers:
```
https://sub.yourdomain.com/sub/testuser
```

## Maintenance

### Add New Server
1. Deploy this package on new server
2. Set unique `SERVER_NAME` in `.env`
3. Use same `CLIENT_ID` as other servers
4. Run `./install.sh`

### Update All Servers
```bash
git pull
./install.sh --update
```

### Backup
```bash
# Backup X-UI database
cp /etc/x-ui/x-ui.db /backup/

# Backup configs
cp .env /backup/
```

## Troubleshooting

### Port Already in Use
Change `VPN_PORT` in `.env` to 2087, 2096, or 8443

### SSL Certificate Issues
```bash
certbot renew --force-renewal
```

### X-UI Not Starting
```bash
systemctl status x-ui
journalctl -u x-ui -n 50
```

## Security Notes

1. **Never commit `.env` files** with real passwords
2. **Use strong passwords** for X-UI panel
3. **Keep same CLIENT_ID** across servers for user convenience
4. **Regular updates** with `apt update && apt upgrade`