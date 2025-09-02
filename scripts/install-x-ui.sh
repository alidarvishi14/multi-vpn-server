#!/bin/bash

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Installing X-UI Management Panel...${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}" 
   exit 1
fi

# Update system
echo "Updating system packages..."
apt-get update
apt-get upgrade -y

# Install dependencies
echo "Installing dependencies..."
apt-get install -y curl wget unzip

# Download and install X-UI
echo "Downloading X-UI..."
bash <(curl -Ls https://raw.githubusercontent.com/alireza0/x-ui/master/install.sh)

# Configure X-UI settings
echo "Configuring X-UI..."
X_UI_CONFIG="/usr/local/x-ui/bin/config.json"

# Set custom port if provided
if [ ! -z "$1" ]; then
    PANEL_PORT=$1
else
    PANEL_PORT=54321
fi

# Set custom path if provided
if [ ! -z "$2" ]; then
    PANEL_PATH=$2
else
    PANEL_PATH=$(openssl rand -hex 8)
fi

# Update X-UI configuration
/usr/local/x-ui/x-ui setting -port $PANEL_PORT
/usr/local/x-ui/x-ui setting -webBasePath /$PANEL_PATH/

# Generate random admin credentials if not provided
if [ -z "$ADMIN_USER" ]; then
    ADMIN_USER="admin_$(openssl rand -hex 4)"
fi

if [ -z "$ADMIN_PASS" ]; then
    ADMIN_PASS=$(openssl rand -base64 12)
fi

# Set admin credentials
/usr/local/x-ui/x-ui setting -username $ADMIN_USER
/usr/local/x-ui/x-ui setting -password $ADMIN_PASS

# Enable and start X-UI service
systemctl enable x-ui
systemctl start x-ui

# Save configuration details
CONFIG_FILE="/root/.x-ui-config"
cat > $CONFIG_FILE << EOF
X-UI Configuration
==================
Panel URL: http://$(hostname -I | awk '{print $1}'):$PANEL_PORT/$PANEL_PATH/
Username: $ADMIN_USER
Password: $ADMIN_PASS
EOF

echo -e "${GREEN}X-UI Installation Complete!${NC}"
echo "Configuration saved to: $CONFIG_FILE"
cat $CONFIG_FILE

# Configure firewall
if command -v ufw &> /dev/null; then
    echo "Configuring firewall..."
    ufw allow $PANEL_PORT/tcp
    ufw allow 8443/tcp  # VPN port
fi

echo -e "${GREEN}Setup complete!${NC}"