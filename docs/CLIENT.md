# Client Configuration Guide

This guide covers how to set up VPN clients on various platforms to connect to your Multi-VPN Server.

## Table of Contents
- [Prerequisites](#prerequisites)
- [iOS (Shadowrocket)](#ios-shadowrocket)
- [Android (v2rayNG)](#android-v2rayng)
- [Windows (v2rayN)](#windows-v2rayn)
- [macOS (V2RayX)](#macos-v2rayx)
- [Linux (v2ray-core)](#linux-v2ray-core)
- [Connection Methods](#connection-methods)
- [Troubleshooting](#troubleshooting)

## Prerequisites

Before connecting, you'll need:
1. Your subscription URL: `https://sub.yourdomain.com/sub/{username}`
2. Or direct connection string (VLESS URL)
3. A compatible VPN client for your platform

## iOS (Shadowrocket)

### Installation
1. Purchase and install [Shadowrocket](https://apps.apple.com/app/shadowrocket/id932747118) from App Store (~$2.99)
2. Alternative: Use TestFlight version if available

### Configuration
1. Open Shadowrocket
2. Tap the "+" button in top-right corner
3. Select "Type" → "Subscribe"
4. Enter your subscription URL:
   ```
   https://sub.yourdomain.com/sub/yourusername
   ```
5. Tap "Done" to save
6. Pull down to refresh the server list
7. Select a server and toggle the connection switch

### Settings Optimization
- Enable "Global Routing" for all traffic
- Set "On Demand" for automatic connection
- Configure DNS: Settings → DNS → Add custom DNS

## Android (v2rayNG)

### Installation
1. Download from [Google Play](https://play.google.com/store/apps/details?id=com.v2ray.ang)
2. Or download APK from [GitHub Releases](https://github.com/2dust/v2rayNG/releases)

### Configuration
1. Open v2rayNG
2. Tap "+" → "Import config from subscription"
3. Enter subscription URL:
   ```
   https://sub.yourdomain.com/sub/yourusername
   ```
4. Tap "✓" to save
5. Pull down to update subscription
6. Select a server and tap the "V" button to connect

### Advanced Settings
- Routing: Settings → Routing Settings
- DNS: Settings → DNS Settings
- Enable "VPN Service Mode" for system-wide proxy

## Windows (v2rayN)

### Installation
1. Download from [GitHub Releases](https://github.com/2dust/v2rayN/releases)
2. Extract the ZIP file
3. Run `v2rayN.exe` as Administrator

### Configuration
1. Click "Subscription" → "Subscription settings"
2. Click "Add" and enter:
   - Alias: `My VPN`
   - URL: `https://sub.yourdomain.com/sub/yourusername`
3. Click "OK" to save
4. Click "Subscription" → "Update subscription"
5. Select a server from the list
6. Right-click system tray icon → "System proxy" → "Auto configure"

### Windows-Specific Settings
- Enable "Start with Windows": Settings → General
- Configure PAC/Global proxy mode
- Set custom DNS if needed

## macOS (V2RayX)

### Installation
1. Download from [GitHub Releases](https://github.com/Cenmrev/V2RayX/releases)
2. Move to Applications folder
3. Open and grant permissions

### Configuration
1. Click V2RayX icon in menu bar
2. Select "Configure" → "Subscribe"
3. Add subscription URL
4. Click "Update" to fetch servers
5. Select server and click "Load"
6. Toggle "V2Ray: On" to connect

### macOS Tips
- Grant network permissions when prompted
- Configure automatic proxy in Network Settings
- Use ClashX as alternative client

## Linux (v2ray-core)

### Installation
```bash
# Download v2ray-core
wget https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-64.zip
unzip v2ray-linux-64.zip -d v2ray
cd v2ray

# Make executable
chmod +x v2ray v2ctl
```

### Manual Configuration
Create config file `/etc/v2ray/config.json`:
```json
{
  "inbounds": [{
    "port": 1080,
    "protocol": "socks",
    "settings": {
      "auth": "noauth"
    }
  }],
  "outbounds": [{
    "protocol": "vless",
    "settings": {
      "vnext": [{
        "address": "your-server.com",
        "port": 8443,
        "users": [{
          "id": "your-uuid-here",
          "encryption": "none"
        }]
      }]
    },
    "streamSettings": {
      "network": "tcp"
    }
  }]
}
```

### Running as Service
```bash
# Create systemd service
sudo cat > /etc/systemd/system/v2ray.service << EOF
[Unit]
Description=V2Ray Service
After=network.target

[Service]
Type=simple
User=nobody
ExecStart=/usr/local/bin/v2ray -config /etc/v2ray/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Start service
sudo systemctl enable v2ray
sudo systemctl start v2ray
```

## Connection Methods

### Method 1: Subscription (Recommended)
- Automatically updates server list
- Easy server switching
- Syncs across updates
- URL format: `https://sub.yourdomain.com/sub/{username}`

### Method 2: Direct Connection String
Use VLESS URL directly:
```
vless://uuid@server:port?encryption=none&type=tcp#ServerName
```

Example:
```
vless://3b331a0b-fe16-4c0a-9e25-26ba0ac6f57b@finland.example.com:8443?encryption=none&type=tcp#Finland
```

### Method 3: Manual Configuration
Configure client manually with:
- Protocol: VLESS
- Address: Server IP/Domain
- Port: 8443
- UUID: Your client ID
- Encryption: none
- Network: TCP

## Speed Optimization

### Client-Side Optimization
1. **DNS Settings**
   - Use fast DNS: 1.1.1.1, 8.8.8.8
   - Enable DNS over HTTPS

2. **Routing Rules**
   - Bypass local addresses
   - Direct connection for local sites
   - Proxy for blocked content

3. **Connection Settings**
   - Enable MUX for better concurrency
   - Adjust buffer sizes if supported

### Network Testing
Test connection speed:
```bash
# Test latency
ping your-server.com

# Test download speed
curl -o /dev/null http://speed.hetzner.de/100MB.bin

# Test with VPN
curl --socks5 127.0.0.1:1080 -o /dev/null http://speed.hetzner.de/100MB.bin
```

## Multi-Server Usage

### Automatic Server Selection
Some clients support automatic server selection based on:
- Lowest latency
- Least load
- Geographic proximity

### Manual Server Switching
1. Update subscription to get latest server list
2. Test each server's latency
3. Select optimal server for your location

## Security Best Practices

1. **Keep Clients Updated**
   - Regular updates for security patches
   - New features and optimizations

2. **Secure Your Credentials**
   - Don't share subscription URLs
   - Use unique usernames
   - Rotate UUIDs periodically

3. **Network Security**
   - Use HTTPS for subscription URLs
   - Verify server certificates
   - Enable kill switch if available

## Troubleshooting

### Connection Issues
- **Cannot connect**: Check firewall settings
- **Slow speed**: Try different servers
- **Frequent disconnects**: Check network stability

### Subscription Issues
- **Cannot update**: Verify subscription URL
- **Empty server list**: Check server status
- **Authentication failed**: Verify credentials

### Platform-Specific Issues
- **iOS**: Reset network settings
- **Android**: Clear app cache
- **Windows**: Run as Administrator
- **macOS**: Grant accessibility permissions
- **Linux**: Check systemd logs

## Performance Metrics

Monitor your connection:
```bash
# Check connection status
curl ipinfo.io

# Test speed
speedtest-cli

# Monitor traffic
vnstat -l
```

## Support

For client-specific issues:
- Check client's GitHub issues
- Join client's Telegram group
- Read official documentation

For server issues:
- Check server status
- Review server logs
- Contact administrator