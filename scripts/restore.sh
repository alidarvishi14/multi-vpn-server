#!/bin/bash

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check arguments
if [ $# -eq 0 ]; then
    echo "Usage: $0 <backup_file.tar.gz> [--force]"
    echo ""
    echo "Options:"
    echo "  --force  Skip confirmation prompts"
    echo ""
    echo "Example:"
    echo "  $0 /root/vpn-backups/vpn-backup-20240101_120000.tar.gz"
    exit 1
fi

BACKUP_FILE="$1"
FORCE_RESTORE=false

# Parse additional arguments
if [ "$2" == "--force" ]; then
    FORCE_RESTORE=true
fi

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}Error: Backup file not found: $BACKUP_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}VPN Configuration Restore${NC}"
echo "Backup file: $BACKUP_FILE"

# Verify checksum if available
CHECKSUM_FILE="${BACKUP_FILE}.sha256"
if [ -f "$CHECKSUM_FILE" ]; then
    echo "Verifying backup integrity..."
    if sha256sum -c "$CHECKSUM_FILE" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Backup integrity verified${NC}"
    else
        echo -e "${RED}✗ Backup integrity check failed${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}Warning: No checksum file found, skipping integrity check${NC}"
fi

# Confirmation
if [ "$FORCE_RESTORE" != true ]; then
    echo ""
    echo -e "${YELLOW}WARNING: This will overwrite existing configurations!${NC}"
    echo "The following will be restored:"
    echo "- X-UI database and configuration"
    echo "- Subscription service files"
    echo "- Nginx configuration"
    echo "- SSL certificates"
    echo "- Environment files"
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "Restore cancelled"
        exit 0
    fi
fi

# Create temporary directory for extraction
TEMP_DIR="/tmp/vpn-restore-$$"
mkdir -p "$TEMP_DIR"

echo -e "${YELLOW}Extracting backup...${NC}"
tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"

# Find the backup directory (it should be the only directory in TEMP_DIR)
BACKUP_DIR=$(ls -d ${TEMP_DIR}/*/ | head -n1)

# Display backup information
if [ -f "${BACKUP_DIR}/backup-info.txt" ]; then
    echo ""
    echo "Backup Information:"
    echo "==================="
    cat "${BACKUP_DIR}/backup-info.txt"
    echo ""
fi

echo -e "${YELLOW}Stopping services...${NC}"
systemctl stop x-ui 2>/dev/null || true
systemctl stop simple-sub 2>/dev/null || true
systemctl stop scalable-sub 2>/dev/null || true
systemctl stop nginx 2>/dev/null || true

echo -e "${YELLOW}Restoring configurations...${NC}"

# Restore X-UI database
if [ -d "${BACKUP_DIR}/x-ui" ]; then
    echo "- Restoring X-UI database..."
    mkdir -p /etc
    rm -rf /etc/x-ui.bak 2>/dev/null || true
    [ -d "/etc/x-ui" ] && mv /etc/x-ui /etc/x-ui.bak
    cp -r "${BACKUP_DIR}/x-ui" /etc/
fi

# Restore X-UI configuration
if [ -d "${BACKUP_DIR}/x-ui-config" ]; then
    echo "- Restoring X-UI configuration..."
    mkdir -p /usr/local/x-ui/bin
    cp "${BACKUP_DIR}/x-ui-config/config.json" /usr/local/x-ui/bin/ 2>/dev/null || true
fi

# Restore subscription service
if [ -d "${BACKUP_DIR}/subscription" ]; then
    echo "- Restoring subscription service..."
    mkdir -p /opt/multi-vpn-server
    rm -rf /opt/multi-vpn-server/subscription.bak 2>/dev/null || true
    [ -d "/opt/multi-vpn-server/subscription" ] && mv /opt/multi-vpn-server/subscription /opt/multi-vpn-server/subscription.bak
    cp -r "${BACKUP_DIR}/subscription" /opt/multi-vpn-server/
fi

if [ -d "${BACKUP_DIR}/vpn-subscription" ]; then
    echo "- Restoring vpn-subscription..."
    rm -rf /opt/vpn-subscription.bak 2>/dev/null || true
    [ -d "/opt/vpn-subscription" ] && mv /opt/vpn-subscription /opt/vpn-subscription.bak
    cp -r "${BACKUP_DIR}/vpn-subscription" /opt/
fi

# Restore Nginx configuration
if [ -d "${BACKUP_DIR}/nginx" ]; then
    echo "- Restoring Nginx configuration..."
    cp "${BACKUP_DIR}/nginx/"* /etc/nginx/sites-available/ 2>/dev/null || true
    # Re-enable sites
    for site in ${BACKUP_DIR}/nginx/vpn-*; do
        site_name=$(basename "$site")
        ln -sf /etc/nginx/sites-available/$site_name /etc/nginx/sites-enabled/
    done
fi

# Restore SSL certificates
if [ -d "${BACKUP_DIR}/letsencrypt" ]; then
    echo "- Restoring SSL certificates..."
    rm -rf /etc/letsencrypt.bak 2>/dev/null || true
    [ -d "/etc/letsencrypt" ] && mv /etc/letsencrypt /etc/letsencrypt.bak
    cp -r "${BACKUP_DIR}/letsencrypt" /etc/
fi

# Restore environment files
if [ -f "${BACKUP_DIR}/.env" ]; then
    echo "- Restoring environment files..."
    cp "${BACKUP_DIR}/.env" /opt/multi-vpn-server/ 2>/dev/null || true
fi

if [ -f "${BACKUP_DIR}/vpn-subscription.env" ]; then
    cp "${BACKUP_DIR}/vpn-subscription.env" /opt/vpn-subscription/.env 2>/dev/null || true
fi

# Restore server configurations
if [ -d "${BACKUP_DIR}/configs" ]; then
    echo "- Restoring server configurations..."
    mkdir -p /opt/multi-vpn-server
    rm -rf /opt/multi-vpn-server/configs.bak 2>/dev/null || true
    [ -d "/opt/multi-vpn-server/configs" ] && mv /opt/multi-vpn-server/configs /opt/multi-vpn-server/configs.bak
    cp -r "${BACKUP_DIR}/configs" /opt/multi-vpn-server/
fi

# Restore SSH keys
if [ -d "${BACKUP_DIR}/ssh_keys" ]; then
    echo "- Restoring SSH keys..."
    mkdir -p /opt/vpn-subscription
    rm -rf /opt/vpn-subscription/ssh_keys.bak 2>/dev/null || true
    [ -d "/opt/vpn-subscription/ssh_keys" ] && mv /opt/vpn-subscription/ssh_keys /opt/vpn-subscription/ssh_keys.bak
    cp -r "${BACKUP_DIR}/ssh_keys" /opt/vpn-subscription/
    chmod 600 /opt/vpn-subscription/ssh_keys/* 2>/dev/null || true
fi

# Restore server credentials
if [ -d "${BACKUP_DIR}/.vpn-servers" ]; then
    echo "- Restoring server credentials..."
    rm -rf /root/.vpn-servers.bak 2>/dev/null || true
    [ -d "/root/.vpn-servers" ] && mv /root/.vpn-servers /root/.vpn-servers.bak
    cp -r "${BACKUP_DIR}/.vpn-servers" /root/
fi

# Restore systemd services
if [ -d "${BACKUP_DIR}/systemd" ]; then
    echo "- Restoring systemd services..."
    cp "${BACKUP_DIR}/systemd/"*.service /etc/systemd/system/ 2>/dev/null || true
    systemctl daemon-reload
fi

# Set correct permissions
echo "- Setting permissions..."
chmod +x /opt/multi-vpn-server/subscription/*.py 2>/dev/null || true
chmod +x /opt/vpn-subscription/*.py 2>/dev/null || true
chmod +x /opt/multi-vpn-server/scripts/*.sh 2>/dev/null || true

# Clean up temporary files
rm -rf "$TEMP_DIR"

echo -e "${YELLOW}Starting services...${NC}"

# Start services
if [ -f "/etc/systemd/system/x-ui.service" ]; then
    systemctl enable x-ui
    systemctl start x-ui
    echo "- X-UI service started"
fi

if [ -f "/etc/systemd/system/simple-sub.service" ]; then
    systemctl enable simple-sub
    systemctl start simple-sub
    echo "- Subscription service started"
fi

if command -v nginx &> /dev/null; then
    nginx -t && systemctl start nginx
    echo "- Nginx service started"
fi

echo ""
echo -e "${GREEN}✓ Restore completed successfully!${NC}"
echo ""
echo "Service Status:"
echo "==============="
systemctl status x-ui --no-pager 2>/dev/null | grep Active || echo "X-UI: not running"
systemctl status simple-sub --no-pager 2>/dev/null | grep Active || echo "Simple-Sub: not running"
systemctl status nginx --no-pager 2>/dev/null | grep Active || echo "Nginx: not running"

echo ""
echo "Please verify that all services are working correctly."
echo "Backup files have been preserved with .bak extension if you need to rollback."