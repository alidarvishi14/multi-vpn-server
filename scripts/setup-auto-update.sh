#!/bin/bash

# Setup script for auto-update functionality
# This configures your server to automatically pull updates from git

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  Setting up Auto-Update        ${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Get git remote URL
cd /opt/multi-vpn-server
GIT_REMOTE=$(git config --get remote.origin.url 2>/dev/null || echo "not configured")

echo -e "${YELLOW}Current git remote:${NC} $GIT_REMOTE"
echo ""

# Method selection
echo "Choose update method:"
echo "1) Automatic (check every 5 minutes)"
echo "2) Manual only (run update command when needed)"
echo ""
read -p "Select option (1-2): " UPDATE_METHOD

# Make scripts executable
chmod +x scripts/auto-update.sh

# Copy systemd files
cp configs/systemd/vpn-auto-update.service /etc/systemd/system/
cp configs/systemd/vpn-auto-update.timer /etc/systemd/system/

# Reload systemd
systemctl daemon-reload

if [ "$UPDATE_METHOD" = "1" ]; then
    # Enable automatic updates
    systemctl enable vpn-auto-update.timer
    systemctl start vpn-auto-update.timer
    
    echo -e "${GREEN}✓ Automatic updates enabled${NC}"
    echo "Updates will be checked every 5 minutes"
    echo ""
    echo "To check timer status:"
    echo "  systemctl status vpn-auto-update.timer"
    echo ""
    echo "To view update logs:"
    echo "  tail -f /var/log/vpn-auto-update.log"
    echo ""
    echo "To manually trigger update:"
    echo "  systemctl start vpn-auto-update.service"
    
else
    # Manual mode
    echo -e "${GREEN}✓ Manual update mode configured${NC}"
    echo ""
    echo "To manually update, run:"
    echo "  /opt/multi-vpn-server/scripts/auto-update.sh"
    echo "Or:"
    echo "  systemctl start vpn-auto-update.service"
fi

echo ""
echo -e "${YELLOW}Important Notes:${NC}"
echo "1. Make sure your servers have SSH key access to git repo"
echo "2. The script will auto-restart services when their configs change"
echo "3. Check /var/log/vpn-auto-update.log for update history"
echo ""

# Optional: Setup git credentials (for private repos)
read -p "Is this a private repository? (y/n): " IS_PRIVATE

if [ "$IS_PRIVATE" = "y" ]; then
    echo ""
    echo -e "${YELLOW}For private repositories, you need to:${NC}"
    echo "1. Use SSH URL: git@github.com:username/repo.git"
    echo "2. Add deploy key to your repo settings"
    echo ""
    echo "Generate deploy key:"
    echo "  ssh-keygen -t ed25519 -C 'vpn-auto-update' -f ~/.ssh/vpn_deploy_key"
    echo ""
    echo "Then add the public key to your GitHub repo:"
    echo "  Settings -> Deploy keys -> Add deploy key"
    echo ""
    echo "Configure git to use the key:"
    echo "  git config core.sshCommand 'ssh -i ~/.ssh/vpn_deploy_key'"
fi

echo -e "${GREEN}✓ Auto-update setup complete!${NC}"