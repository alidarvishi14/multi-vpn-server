# Auto-Update Setup Guide

This guide explains how to configure your VPN servers to automatically pull and apply updates from your git repository.

## Quick Setup

Run this on each server:
```bash
cd /opt/multi-vpn-server
./scripts/setup-auto-update.sh
```

## How It Works

The auto-update system:
1. **Checks git repository** every 5 minutes (configurable)
2. **Pulls new changes** if updates are available
3. **Automatically restarts** affected services
4. **Logs all actions** to `/var/log/vpn-auto-update.log`

## Features

### Smart Service Restart
The update script only restarts services that need it:
- Changes to `subscription/*.py` → Restarts subscription service
- Changes to `configs/nginx/*` → Reloads Nginx
- Changes to `configs/nodes.json` → Restarts subscription service
- Changes to `x-ui/*` → Restarts X-UI panel

### Safe Updates
- Tests configurations before applying
- Logs all actions for troubleshooting
- Can rollback if needed

## Installation Methods

### Method 1: Automatic (Recommended)
```bash
# Runs every 5 minutes via systemd timer
systemctl enable vpn-auto-update.timer
systemctl start vpn-auto-update.timer
```

### Method 2: Manual
```bash
# Run updates manually when needed
/opt/multi-vpn-server/scripts/auto-update.sh
```

### Method 3: Via Cron (Alternative)
```bash
# Add to crontab for custom schedule
*/10 * * * * /opt/multi-vpn-server/scripts/auto-update.sh
```

## Configuration

### For Public Repositories
No additional setup needed. The script will pull from the public repo.

### For Private Repositories

1. **Generate SSH Deploy Key:**
```bash
ssh-keygen -t ed25519 -C "vpn-auto-update" -f ~/.ssh/vpn_deploy_key
```

2. **Add to GitHub:**
- Go to your repo → Settings → Deploy keys
- Add the public key (`~/.ssh/vpn_deploy_key.pub`)
- Enable "Allow write access" if needed

3. **Configure Git:**
```bash
cd /opt/multi-vpn-server
git config core.sshCommand "ssh -i ~/.ssh/vpn_deploy_key"
```

## Monitoring

### Check Update Status
```bash
# View timer status
systemctl status vpn-auto-update.timer

# View last update run
systemctl status vpn-auto-update.service

# Watch logs in real-time
tail -f /var/log/vpn-auto-update.log
```

### Manual Update
```bash
# Force an immediate update
systemctl start vpn-auto-update.service

# Or run directly
/opt/multi-vpn-server/scripts/auto-update.sh
```

## Customization

### Change Update Frequency
Edit `/etc/systemd/system/vpn-auto-update.timer`:
```ini
[Timer]
OnCalendar=*:0/5  # Every 5 minutes
# Change to:
OnCalendar=*:0/15  # Every 15 minutes
OnCalendar=hourly  # Every hour
OnCalendar=daily   # Once per day
```

Then reload:
```bash
systemctl daemon-reload
systemctl restart vpn-auto-update.timer
```

### Disable Auto-Updates
```bash
systemctl stop vpn-auto-update.timer
systemctl disable vpn-auto-update.timer
```

## Webhook Support (Advanced)

For instant updates on push, you can set up a webhook receiver:

1. **Install webhook handler:**
```bash
apt-get install webhook
```

2. **Configure webhook:**
```json
[
  {
    "id": "update-vpn",
    "execute-command": "/opt/multi-vpn-server/scripts/auto-update.sh",
    "command-working-directory": "/opt/multi-vpn-server"
  }
]
```

3. **Add to GitHub:**
- Repo → Settings → Webhooks
- Payload URL: `http://your-server:9000/hooks/update-vpn`
- Content type: `application/json`
- Events: Just the push event

## Troubleshooting

### Updates Not Working
```bash
# Check git status
cd /opt/multi-vpn-server
git status
git remote -v

# Test manual pull
git pull

# Check logs
tail -50 /var/log/vpn-auto-update.log
```

### Service Not Restarting
```bash
# Check service status
systemctl status simple-sub
systemctl status x-ui

# View service logs
journalctl -u simple-sub -n 50
```

### Permission Issues
```bash
# Fix permissions
chown -R root:root /opt/multi-vpn-server
chmod +x /opt/multi-vpn-server/scripts/*.sh
```

## Security Notes

1. **Use Deploy Keys** for private repos (read-only access)
2. **Monitor Logs** regularly for unusual activity
3. **Test Updates** in staging environment first
4. **Backup** before enabling auto-updates:
```bash
./scripts/backup.sh
```

## Best Practices

1. **Use Branches** for different environments:
   - `master` → Production
   - `staging` → Testing
   - `develop` → Development

2. **Tag Releases** for version control:
```bash
git tag -a v1.0.0 -m "Stable release"
git push origin v1.0.0
```

3. **Test First** on one server before deploying to all

4. **Monitor After Updates** to ensure services are running correctly

## Example Workflow

1. Make changes locally
2. Test thoroughly
3. Commit and push to GitHub:
```bash
git add .
git commit -m "Update configuration"
git push origin master
```
4. Servers automatically pull and apply changes within 5 minutes
5. Check logs to confirm successful update

That's it! Your servers will now stay in sync with your git repository automatically.