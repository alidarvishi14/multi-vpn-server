#!/bin/bash

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default backup directory
BACKUP_DIR="/root/vpn-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="vpn-backup-${TIMESTAMP}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        --name)
            BACKUP_NAME="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [--dir <backup_directory>] [--name <backup_name>]"
            echo ""
            echo "Options:"
            echo "  --dir   Backup directory (default: /root/vpn-backups)"
            echo "  --name  Backup name (default: vpn-backup-TIMESTAMP)"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${GREEN}Starting VPN Configuration Backup...${NC}"
echo "Backup name: ${BACKUP_NAME}"

# Create backup directory
mkdir -p "${BACKUP_DIR}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"
mkdir -p "${BACKUP_PATH}"

echo -e "${YELLOW}Backing up configurations...${NC}"

# Backup X-UI database and configuration
if [ -d "/etc/x-ui" ]; then
    echo "- Backing up X-UI database..."
    cp -r /etc/x-ui "${BACKUP_PATH}/"
fi

if [ -d "/usr/local/x-ui" ]; then
    echo "- Backing up X-UI configuration..."
    mkdir -p "${BACKUP_PATH}/x-ui-config"
    cp -r /usr/local/x-ui/bin/config.json "${BACKUP_PATH}/x-ui-config/" 2>/dev/null || true
fi

# Backup subscription service
if [ -d "/opt/multi-vpn-server/subscription" ]; then
    echo "- Backing up subscription service..."
    cp -r /opt/multi-vpn-server/subscription "${BACKUP_PATH}/"
fi

if [ -d "/opt/vpn-subscription" ]; then
    echo "- Backing up vpn-subscription..."
    cp -r /opt/vpn-subscription "${BACKUP_PATH}/"
fi

# Backup Nginx configuration
if [ -d "/etc/nginx/sites-available" ]; then
    echo "- Backing up Nginx configuration..."
    mkdir -p "${BACKUP_PATH}/nginx"
    cp -r /etc/nginx/sites-available/vpn-* "${BACKUP_PATH}/nginx/" 2>/dev/null || true
fi

# Backup SSL certificates
if [ -d "/etc/letsencrypt" ]; then
    echo "- Backing up SSL certificates..."
    cp -r /etc/letsencrypt "${BACKUP_PATH}/"
fi

# Backup environment files
echo "- Backing up environment files..."
cp /opt/multi-vpn-server/.env "${BACKUP_PATH}/" 2>/dev/null || true
cp /opt/multi-vpn-server/.env.example "${BACKUP_PATH}/" 2>/dev/null || true
cp /opt/vpn-subscription/.env "${BACKUP_PATH}/vpn-subscription.env" 2>/dev/null || true

# Backup server configurations
if [ -d "/opt/multi-vpn-server/configs" ]; then
    echo "- Backing up server configurations..."
    cp -r /opt/multi-vpn-server/configs "${BACKUP_PATH}/"
fi

# Backup SSH keys (encrypted)
if [ -d "/opt/vpn-subscription/ssh_keys" ]; then
    echo "- Backing up SSH keys..."
    cp -r /opt/vpn-subscription/ssh_keys "${BACKUP_PATH}/"
fi

if [ -d "/root/.vpn-servers" ]; then
    echo "- Backing up server credentials..."
    cp -r /root/.vpn-servers "${BACKUP_PATH}/"
fi

# Backup systemd service files
echo "- Backing up systemd services..."
mkdir -p "${BACKUP_PATH}/systemd"
cp /etc/systemd/system/x-ui.service "${BACKUP_PATH}/systemd/" 2>/dev/null || true
cp /etc/systemd/system/simple-sub.service "${BACKUP_PATH}/systemd/" 2>/dev/null || true
cp /etc/systemd/system/scalable-sub.service "${BACKUP_PATH}/systemd/" 2>/dev/null || true

# Create backup metadata
cat > "${BACKUP_PATH}/backup-info.txt" << EOF
VPN Backup Information
======================
Timestamp: $(date)
Hostname: $(hostname)
IP Address: $(hostname -I | awk '{print $1}')
Backup Version: 1.0
System: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)

Services Status:
----------------
X-UI: $(systemctl is-active x-ui 2>/dev/null || echo "not installed")
Simple-Sub: $(systemctl is-active simple-sub 2>/dev/null || echo "not installed")
Nginx: $(systemctl is-active nginx 2>/dev/null || echo "not installed")

Included Components:
--------------------
$(ls -1 "${BACKUP_PATH}" | grep -v backup-info.txt | sed 's/^/- /')
EOF

# Create compressed archive
echo -e "${YELLOW}Creating compressed archive...${NC}"
cd "${BACKUP_DIR}"
tar -czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}"

# Calculate checksum
echo "Calculating checksum..."
sha256sum "${BACKUP_NAME}.tar.gz" > "${BACKUP_NAME}.tar.gz.sha256"

# Clean up uncompressed backup
rm -rf "${BACKUP_PATH}"

# Final size
BACKUP_SIZE=$(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)

echo -e "${GREEN}✓ Backup completed successfully!${NC}"
echo ""
echo "Backup Details:"
echo "==============="
echo "Location: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
echo "Size: ${BACKUP_SIZE}"
echo "Checksum: $(cat ${BACKUP_NAME}.tar.gz.sha256 | cut -d' ' -f1)"
echo ""
echo "To restore this backup, run:"
echo "  ./scripts/restore.sh ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"