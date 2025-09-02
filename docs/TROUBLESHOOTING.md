# Troubleshooting Guide

This guide helps you diagnose and fix common issues with your Multi-VPN Server setup.

## Table of Contents
- [Quick Diagnostics](#quick-diagnostics)
- [Installation Issues](#installation-issues)
- [Service Issues](#service-issues)
- [Connection Problems](#connection-problems)
- [Performance Issues](#performance-issues)
- [SSL/Certificate Issues](#sslcertificate-issues)
- [Subscription Service Issues](#subscription-service-issues)
- [X-UI Panel Issues](#x-ui-panel-issues)
- [Backup/Restore Issues](#backuprestore-issues)
- [Advanced Debugging](#advanced-debugging)

## Quick Diagnostics

Run this diagnostic script to check system health:
```bash
#!/bin/bash
echo "=== System Health Check ==="
echo "1. Service Status:"
systemctl status x-ui --no-pager | grep Active
systemctl status simple-sub --no-pager | grep Active
systemctl status nginx --no-pager | grep Active

echo -e "\n2. Port Status:"
ss -tlnp | grep -E "8443|54321|5556|443|80"

echo -e "\n3. Disk Space:"
df -h | grep -E "^/dev/"

echo -e "\n4. Memory Usage:"
free -h

echo -e "\n5. Network Connectivity:"
ping -c 1 google.com > /dev/null && echo "Internet: OK" || echo "Internet: FAILED"

echo -e "\n6. SSL Certificates:"
certbot certificates 2>/dev/null | grep -E "Certificate Name|Expiry Date"
```

## Installation Issues

### Script Fails to Run
**Problem**: Installation script exits with error
```bash
./install.sh: Permission denied
```

**Solution**:
```bash
chmod +x install.sh
sudo ./install.sh
```

### Missing Dependencies
**Problem**: Package installation fails
```bash
E: Unable to locate package x-ui
```

**Solution**:
```bash
# Update package lists
apt-get update

# Install missing dependencies
apt-get install -y curl wget unzip python3 python3-pip

# Retry installation
./install.sh
```

### Network Timeout During Installation
**Problem**: Downloads fail or timeout

**Solution**:
```bash
# Use proxy if behind firewall
export http_proxy=http://proxy.server:port
export https_proxy=http://proxy.server:port

# Or use mirror repositories
sed -i 's/archive.ubuntu.com/mirrors.your-region.com/g' /etc/apt/sources.list
```

## Service Issues

### X-UI Service Won't Start
**Problem**: X-UI fails to start
```
Job for x-ui.service failed
```

**Diagnosis**:
```bash
# Check logs
journalctl -u x-ui -n 50

# Check configuration
/usr/local/x-ui/x-ui check

# Verify database
ls -la /etc/x-ui/x-ui.db
```

**Solutions**:
```bash
# Reset X-UI configuration
/usr/local/x-ui/x-ui reset

# Reinstall X-UI
bash <(curl -Ls https://raw.githubusercontent.com/alireza0/x-ui/master/install.sh)

# Restore from backup
./scripts/restore.sh /root/vpn-backups/latest.tar.gz
```

### Subscription Service Crashes
**Problem**: simple-sub.service keeps restarting

**Diagnosis**:
```bash
# Check service logs
journalctl -u simple-sub -f

# Test Python script
python3 /opt/multi-vpn-server/subscription/simple-sub.py
```

**Solutions**:
```bash
# Fix Python dependencies
cd /opt/multi-vpn-server/subscription
pip3 install -r requirements.txt

# Check configuration files
cat /opt/multi-vpn-server/subscription/nodes.json

# Fix permissions
chmod 755 /opt/multi-vpn-server/subscription/*.py
```

### Nginx Configuration Errors
**Problem**: Nginx fails to reload
```
nginx: [emerg] duplicate location "/"
```

**Solution**:
```bash
# Test configuration
nginx -t

# Fix syntax errors
nano /etc/nginx/sites-available/vpn-subscription

# Remove conflicting sites
rm /etc/nginx/sites-enabled/default

# Reload
systemctl reload nginx
```

## Connection Problems

### Cannot Connect to VPN
**Problem**: Client cannot establish connection

**Diagnosis Checklist**:
1. Server reachability
```bash
# From client machine
ping server-ip
telnet server-ip 8443
```

2. Firewall rules
```bash
# On server
ufw status
iptables -L -n
```

3. Service status
```bash
systemctl status x-ui
ss -tlnp | grep 8443
```

**Solutions**:
```bash
# Open firewall ports
ufw allow 8443/tcp
ufw reload

# Check Xray configuration
/usr/local/x-ui/bin/xray -test -config /usr/local/x-ui/bin/config.json

# Restart services
systemctl restart x-ui
```

### Connection Drops Frequently
**Problem**: VPN disconnects randomly

**Possible Causes**:
- Network instability
- Server overload
- Client timeout settings
- ISP throttling

**Solutions**:
```bash
# Increase server resources
# Check CPU/Memory usage
top

# Adjust Xray settings
# Edit /usr/local/x-ui/bin/config.json
# Increase timeout values

# Enable BBR congestion control
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
```

### Slow Connection Speed
**Problem**: VPN speed is significantly slower than expected

**Diagnosis**:
```bash
# Test server network speed
speedtest-cli

# Check server load
uptime
iostat -x 1

# Monitor network traffic
iftop
```

**Optimization**:
```bash
# Enable TCP optimization
cat >> /etc/sysctl.conf << EOF
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
EOF
sysctl -p

# Adjust Xray buffer size
# In config.json, add:
"sockopt": {
  "tcpFastOpen": true,
  "tcpNoDelay": true
}
```

## Performance Issues

### High CPU Usage
**Problem**: Server CPU constantly at 100%

**Diagnosis**:
```bash
# Identify process
top -c
htop

# Check for attacks
netstat -an | grep :8443 | wc -l
fail2ban-client status
```

**Solution**:
```bash
# Limit connections per IP
iptables -A INPUT -p tcp --dport 8443 -m connlimit --connlimit-above 10 -j REJECT

# Enable rate limiting
# In X-UI panel, set user traffic limits

# Install fail2ban
apt-get install fail2ban
```

### Memory Leaks
**Problem**: Memory usage grows over time

**Solution**:
```bash
# Set up automatic restart
cat > /etc/systemd/system/x-ui-restart.timer << EOF
[Unit]
Description=Restart X-UI weekly

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl enable x-ui-restart.timer
```

## SSL/Certificate Issues

### Certificate Renewal Failed
**Problem**: Let's Encrypt renewal fails

**Diagnosis**:
```bash
# Test renewal
certbot renew --dry-run

# Check logs
tail -f /var/log/letsencrypt/letsencrypt.log
```

**Solutions**:
```bash
# Manual renewal
certbot renew --force-renewal

# Fix webroot path
certbot certonly --webroot -w /var/www/html -d sub.domain.com

# Use DNS challenge
certbot certonly --manual --preferred-challenges dns -d domain.com
```

### SSL Handshake Errors
**Problem**: HTTPS connections fail

**Solution**:
```bash
# Check certificate validity
openssl s_client -connect sub.domain.com:443 -servername sub.domain.com

# Verify Nginx SSL configuration
nginx -t

# Regenerate certificates
certbot delete --cert-name sub.domain.com
certbot --nginx -d sub.domain.com
```

## Subscription Service Issues

### Empty Subscription Response
**Problem**: Subscription URL returns no servers

**Diagnosis**:
```bash
# Test subscription service
curl http://localhost:5556/sub/testuser

# Check nodes configuration
cat /opt/multi-vpn-server/subscription/nodes.json
```

**Solution**:
```bash
# Fix nodes.json format
python3 -m json.tool /opt/multi-vpn-server/subscription/nodes.json

# Restart service
systemctl restart simple-sub

# Check Python errors
python3 /opt/multi-vpn-server/subscription/simple-sub.py
```

### Subscription URL Not Accessible
**Problem**: Cannot reach subscription URL

**Solution**:
```bash
# Check DNS resolution
nslookup sub.domain.com

# Verify Nginx proxy
curl -I https://sub.domain.com/sub/test

# Check firewall
ufw allow 443/tcp
```

## X-UI Panel Issues

### Cannot Access Panel
**Problem**: Panel URL returns error or timeout

**Solutions**:
```bash
# Reset panel path
/usr/local/x-ui/x-ui setting -webBasePath /newpath/

# Reset admin credentials
/usr/local/x-ui/x-ui setting -username newadmin
/usr/local/x-ui/x-ui setting -password newpass123

# Check panel port
ss -tlnp | grep 54321
```

### Database Corruption
**Problem**: X-UI shows database errors

**Solution**:
```bash
# Backup current database
cp /etc/x-ui/x-ui.db /etc/x-ui/x-ui.db.backup

# Reset database
rm /etc/x-ui/x-ui.db
systemctl restart x-ui

# Restore from backup
./scripts/restore.sh /root/vpn-backups/latest.tar.gz
```

## Backup/Restore Issues

### Backup Fails
**Problem**: Backup script errors out

**Solution**:
```bash
# Check disk space
df -h

# Verify permissions
ls -la /root/vpn-backups/

# Run with debug
bash -x ./scripts/backup.sh
```

### Restore Doesn't Work
**Problem**: Services don't start after restore

**Solution**:
```bash
# Check restored files
ls -la /etc/x-ui/
ls -la /opt/multi-vpn-server/

# Fix permissions
chmod 600 /opt/vpn-subscription/ssh_keys/*
chmod +x /opt/multi-vpn-server/subscription/*.py

# Reinstall services
systemctl daemon-reload
systemctl enable x-ui simple-sub nginx
```

## Advanced Debugging

### Enable Debug Logging

**X-UI Debug**:
```bash
# Edit config.json
"log": {
  "loglevel": "debug"
}
```

**Nginx Debug**:
```nginx
error_log /var/log/nginx/error.log debug;
```

**Python Debug**:
```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

### Network Packet Analysis
```bash
# Capture VPN traffic
tcpdump -i any -w vpn.pcap port 8443

# Analyze with Wireshark
# Download vpn.pcap and open in Wireshark
```

### System Resource Monitoring
```bash
# Install monitoring tools
apt-get install htop iotop iftop nethogs

# Monitor in real-time
htop              # CPU/Memory
iotop             # Disk I/O
iftop             # Network traffic
nethogs           # Per-process network
```

### Log Analysis
```bash
# Centralize logs
journalctl -u x-ui -u simple-sub -u nginx --since "1 hour ago"

# Search for errors
grep -i error /var/log/syslog

# Monitor logs in real-time
tail -f /var/log/nginx/error.log
```

## Getting Help

If issues persist:

1. **Collect Information**:
```bash
# Generate diagnostic report
./scripts/diagnostic.sh > diagnostic-report.txt
```

2. **Check Documentation**:
- Review README.md
- Read CLIENT.md for client issues
- Check project wiki

3. **Community Support**:
- GitHub Issues
- Discord/Telegram groups
- Stack Overflow

4. **Provide Details**:
- OS version
- Error messages
- Configuration files
- Steps to reproduce

Remember to sanitize sensitive information before sharing logs or configurations!