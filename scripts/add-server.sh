#!/bin/bash

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to display usage
usage() {
    echo "Usage: $0 --name <server_name> --ip <server_ip> [--port <vpn_port>] [--panel-port <panel_port>]"
    echo ""
    echo "Options:"
    echo "  --name         Server location name (e.g., 'Germany', 'Singapore')"
    echo "  --ip           Server IP address"
    echo "  --port         VPN port (default: 8443)"
    echo "  --panel-port   X-UI panel port (default: 54321)"
    echo "  --help         Display this help message"
    echo ""
    echo "Example:"
    echo "  $0 --name Germany --ip 1.2.3.4 --port 8443"
    exit 1
}

# Default values
VPN_PORT=8443
PANEL_PORT=54321
SSH_KEY_PATH="/root/.ssh/id_rsa"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            SERVER_NAME="$2"
            shift 2
            ;;
        --ip)
            SERVER_IP="$2"
            shift 2
            ;;
        --port)
            VPN_PORT="$2"
            shift 2
            ;;
        --panel-port)
            PANEL_PORT="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Validate required arguments
if [ -z "$SERVER_NAME" ] || [ -z "$SERVER_IP" ]; then
    echo -e "${RED}Error: Server name and IP are required${NC}"
    usage
fi

echo -e "${GREEN}Adding new VPN server: $SERVER_NAME ($SERVER_IP)${NC}"

# Configuration file paths
SERVERS_CONFIG="/opt/multi-vpn-server/configs/servers.json"
NGINX_CONFIG="/etc/nginx/sites-available/vpn-panel"

# Create servers config if it doesn't exist
if [ ! -f "$SERVERS_CONFIG" ]; then
    mkdir -p $(dirname "$SERVERS_CONFIG")
    echo '{"servers": []}' > "$SERVERS_CONFIG"
fi

# Generate SSH key if needed
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N ""
fi

echo -e "${YELLOW}Step 1: Setting up remote server${NC}"
echo "Please ensure the following on the remote server ($SERVER_IP):"
echo "1. SSH access is configured"
echo "2. Root access or sudo privileges"
echo ""
read -p "Press Enter when ready to continue..."

# Copy SSH key to remote server
echo "Copying SSH key to remote server..."
ssh-copy-id -i "$SSH_KEY_PATH.pub" root@$SERVER_IP || {
    echo -e "${YELLOW}Manual SSH key setup may be required${NC}"
}

# Create setup script for remote server
REMOTE_SETUP_SCRIPT="/tmp/setup_vpn_${SERVER_NAME}.sh"
cat > $REMOTE_SETUP_SCRIPT << 'EOSCRIPT'
#!/bin/bash

# Update system
apt-get update
apt-get upgrade -y

# Install X-UI
bash <(curl -Ls https://raw.githubusercontent.com/alireza0/x-ui/master/install.sh)

# Configure X-UI
PANEL_PATH=$(openssl rand -hex 8)
ADMIN_USER="admin_$(openssl rand -hex 4)"
ADMIN_PASS=$(openssl rand -base64 12)

/usr/local/x-ui/x-ui setting -port PANEL_PORT_PLACEHOLDER
/usr/local/x-ui/x-ui setting -webBasePath /$PANEL_PATH/
/usr/local/x-ui/x-ui setting -username $ADMIN_USER
/usr/local/x-ui/x-ui setting -password $ADMIN_PASS

# Configure firewall
ufw allow PANEL_PORT_PLACEHOLDER/tcp
ufw allow VPN_PORT_PLACEHOLDER/tcp
ufw --force enable

# Create VLESS inbound
cat > /tmp/vless_config.json << EOF
{
  "port": VPN_PORT_PLACEHOLDER,
  "protocol": "vless",
  "settings": {
    "clients": [
      {
        "id": "3b331a0b-fe16-4c0a-9e25-26ba0ac6f57b",
        "level": 0
      }
    ],
    "decryption": "none"
  },
  "streamSettings": {
    "network": "tcp"
  }
}
EOF

# Output configuration
echo "PANEL_URL=http://SERVER_IP_PLACEHOLDER:PANEL_PORT_PLACEHOLDER/$PANEL_PATH/"
echo "ADMIN_USER=$ADMIN_USER"
echo "ADMIN_PASS=$ADMIN_PASS"
EOSCRIPT

# Replace placeholders
sed -i "s/PANEL_PORT_PLACEHOLDER/$PANEL_PORT/g" $REMOTE_SETUP_SCRIPT
sed -i "s/VPN_PORT_PLACEHOLDER/$VPN_PORT/g" $REMOTE_SETUP_SCRIPT
sed -i "s/SERVER_IP_PLACEHOLDER/$SERVER_IP/g" $REMOTE_SETUP_SCRIPT

echo -e "${YELLOW}Step 2: Installing VPN software on remote server${NC}"

# Copy and execute script on remote server
scp $REMOTE_SETUP_SCRIPT root@$SERVER_IP:/tmp/setup_vpn.sh
REMOTE_OUTPUT=$(ssh root@$SERVER_IP "bash /tmp/setup_vpn.sh" | tail -3)

# Parse output
PANEL_URL=$(echo "$REMOTE_OUTPUT" | grep PANEL_URL | cut -d= -f2)
ADMIN_USER=$(echo "$REMOTE_OUTPUT" | grep ADMIN_USER | cut -d= -f2)
ADMIN_PASS=$(echo "$REMOTE_OUTPUT" | grep ADMIN_PASS | cut -d= -f2)

echo -e "${YELLOW}Step 3: Updating local configuration${NC}"

# Add server to configuration
SERVER_CONFIG=$(cat <<EOF
{
  "name": "$SERVER_NAME",
  "ip": "$SERVER_IP",
  "vpn_port": $VPN_PORT,
  "panel_port": $PANEL_PORT,
  "panel_url": "$PANEL_URL",
  "admin_user": "$ADMIN_USER",
  "admin_pass": "$ADMIN_PASS",
  "added_date": "$(date -Iseconds)"
}
EOF
)

# Update servers.json using Python
python3 << EOF
import json

with open('$SERVERS_CONFIG', 'r') as f:
    config = json.load(f)

new_server = $SERVER_CONFIG

config['servers'].append(new_server)

with open('$SERVERS_CONFIG', 'w') as f:
    json.dump(config, f, indent=2)
EOF

# Update subscription service configuration
SUB_CONFIG="/opt/multi-vpn-server/subscription/nodes.json"
if [ -f "$SUB_CONFIG" ]; then
    python3 << EOF
import json

with open('$SUB_CONFIG', 'r') as f:
    nodes = json.load(f)

nodes.append({
    "name": "$SERVER_NAME",
    "host": "$SERVER_IP",
    "port": $VPN_PORT,
    "uuid": "3b331a0b-fe16-4c0a-9e25-26ba0ac6f57b",
    "type": "vless"
})

with open('$SUB_CONFIG', 'w') as f:
    json.dump(nodes, f, indent=2)
EOF
fi

# Update Nginx configuration for panel proxy
if [ -f "$NGINX_CONFIG" ]; then
    SERVER_NAME_LOWER=$(echo "$SERVER_NAME" | tr '[:upper:]' '[:lower:]')
    
    # Add new location block before the last closing brace
    sed -i "/location \/ {/i\\
    location /${SERVER_NAME_LOWER}/ {\\
        proxy_pass http://${SERVER_IP}:${PANEL_PORT}/;\\
        proxy_http_version 1.1;\\
        proxy_set_header Upgrade \$http_upgrade;\\
        proxy_set_header Connection 'upgrade';\\
        proxy_set_header Host \$host;\\
        proxy_cache_bypass \$http_upgrade;\\
    }\\
" $NGINX_CONFIG
    
    # Reload Nginx
    nginx -t && systemctl reload nginx
fi

# Clean up
rm -f $REMOTE_SETUP_SCRIPT

# Save server credentials
CREDS_FILE="/root/.vpn-servers/${SERVER_NAME}.conf"
mkdir -p $(dirname "$CREDS_FILE")
cat > "$CREDS_FILE" << EOF
Server: $SERVER_NAME
IP: $SERVER_IP
VPN Port: $VPN_PORT
Panel URL: $PANEL_URL
Admin User: $ADMIN_USER
Admin Pass: $ADMIN_PASS
Connection: vless://3b331a0b-fe16-4c0a-9e25-26ba0ac6f57b@${SERVER_IP}:${VPN_PORT}?encryption=none&type=tcp#${SERVER_NAME}
EOF

echo -e "${GREEN}✓ Server added successfully!${NC}"
echo ""
echo "Server Details:"
echo "==============="
cat "$CREDS_FILE"
echo ""
echo -e "${GREEN}The server has been added to your VPN network!${NC}"
echo "Clients will see it in their subscription updates."

# Restart subscription service
if systemctl is-active --quiet simple-sub; then
    systemctl restart simple-sub
    echo "Subscription service restarted"
fi