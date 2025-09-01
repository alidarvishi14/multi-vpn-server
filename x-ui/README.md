# X-UI Panel

This directory contains the X-UI management panel v1.8.12 by alireza0.

## Contents

- `x-ui` - Main X-UI binary
- `x-ui.sh` - Management script
- `x-ui.service` - Systemd service file
- `bin/` - Xray core and geo data files
  - `xray-linux-amd64` - Xray core binary
  - `geoip.dat` - IP geolocation database
  - `geosite.dat` - Site geolocation database

## Installation

The main `install.sh` script handles the installation automatically.

## Manual Commands

```bash
# Check X-UI settings
/usr/local/x-ui/x-ui settings

# Change admin username/password
/usr/local/x-ui/x-ui setting -username admin -password newpassword

# Change panel port
/usr/local/x-ui/x-ui setting -port 54321

# Restart X-UI
systemctl restart x-ui
```

## Default Paths

- Installation: `/usr/local/x-ui/`
- Database: `/etc/x-ui/x-ui.db`
- Config: `/usr/local/x-ui/bin/config.json`