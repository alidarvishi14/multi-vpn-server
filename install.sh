#!/bin/bash

# Multi-Location VPN Server Installation Script
# Works on any server - just clone and run!

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Detect OS and Server
detect_environment() {
    echo -e "${GREEN}Detecting environment...${NC}"
    
    # Get server IP
    if [ "$SERVER_IP" = "AUTO" ]; then
        export SERVER_IP=$(curl -s ifconfig.me)
    fi
    
    # Detect OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        echo -e "${RED}Cannot detect OS${NC}"
        exit 1
    fi
    
    echo "OS: $OS $VER"
    echo "Server IP: $SERVER_IP"
    echo "Server Name: $SERVER_NAME"
}

# Load configuration
load_config() {
    if [ ! -f .env ]; then
        echo -e "${YELLOW}No .env file found. Creating from template...${NC}"
        cp .env.example .env
        echo -e "${RED}Please edit .env file and run again${NC}"
        exit 1
    fi
    
    # Load environment variables
    export $(cat .env | sed 's/#.*//g' | xargs)
    
    echo -e "${GREEN}Configuration loaded for: $SERVER_NAME${NC}"
}

# Install dependencies
install_dependencies() {
    echo -e "${GREEN}Installing dependencies...${NC}"
    
    apt update
    apt install -y \
        curl \
        wget \
        unzip \
        nginx \
        python3 \
        python3-pip \
        python3-venv \
        certbot \
        python3-certbot-nginx \
        sqlite3 \
        git
}

# Install X-UI Panel
install_xui() {
    echo -e "${GREEN}Installing X-UI panel...${NC}"
    
    # Copy X-UI from package
    cp -r x-ui /usr/local/
    chmod +x /usr/local/x-ui/x-ui
    chmod +x /usr/local/x-ui/x-ui.sh
    
    # Create X-UI database directory
    mkdir -p /etc/x-ui
    
    # Set up X-UI service
    cp x-ui/x-ui.service /etc/systemd/system/
    sed -i "s|/usr/local/x-ui/|/usr/local/x-ui/|g" /etc/systemd/system/x-ui.service
    
    # Initialize X-UI with credentials
    /usr/local/x-ui/x-ui setting -username $XRAY_USERNAME -password $XRAY_PASSWORD
    /usr/local/x-ui/x-ui setting -port $PANEL_PORT
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    
    echo -e "${GREEN}X-UI installed on port $PANEL_PORT${NC}"
}

# Setup subscription service
setup_subscription() {
    if [ "$ENABLE_SUBSCRIPTION" != "true" ]; then
        echo -e "${YELLOW}Subscription service not enabled for this server${NC}"
        return
    fi
    
    echo -e "${GREEN}Setting up subscription service...${NC}"
    
    # Create subscription directory
    mkdir -p /opt/vpn-subscription
    
    # Copy subscription service
    cp -r subscription/* /opt/vpn-subscription/
    
    # Create Python virtual environment
    cd /opt/vpn-subscription
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
    deactivate
    
    # Update configuration
    sed -i "s/SERVER_NAME_PLACEHOLDER/$SERVER_NAME/g" simple-sub.py
    sed -i "s/SERVER_IP_PLACEHOLDER/$SERVER_IP/g" simple-sub.py
    sed -i "s/VPN_PORT_PLACEHOLDER/$VPN_PORT/g" simple-sub.py
    
    # Create systemd service
    cp configs/systemd/simple-sub.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable simple-sub
    systemctl start simple-sub
    
    echo -e "${GREEN}Subscription service started on port $SUBSCRIPTION_PORT${NC}"
}

# Setup Nginx
setup_nginx() {
    echo -e "${GREEN}Configuring Nginx...${NC}"
    
    # Panel subdomain (if enabled)
    if [ "$ENABLE_PANEL" = "true" ]; then
        cat > /etc/nginx/sites-available/panel.$MAIN_DOMAIN << EOF
server {
    listen 80;
    server_name panel.$MAIN_DOMAIN;
    
    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name panel.$MAIN_DOMAIN;
    
    location /$SERVER_NAME/ {
        proxy_pass http://127.0.0.1:$PANEL_PORT/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF
        ln -sf /etc/nginx/sites-available/panel.$MAIN_DOMAIN /etc/nginx/sites-enabled/
    fi
    
    # Subscription subdomain (if enabled)
    if [ "$ENABLE_SUBSCRIPTION" = "true" ]; then
        cat > /etc/nginx/sites-available/sub.$MAIN_DOMAIN << EOF
server {
    listen 80;
    server_name sub.$MAIN_DOMAIN;
    
    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name sub.$MAIN_DOMAIN;
    
    location / {
        proxy_pass http://127.0.0.1:$SUBSCRIPTION_PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
    }
}
EOF
        ln -sf /etc/nginx/sites-available/sub.$MAIN_DOMAIN /etc/nginx/sites-enabled/
    fi
    
    systemctl reload nginx
}

# Setup SSL certificates
setup_ssl() {
    if [ "$ENABLE_SSL" != "true" ]; then
        echo -e "${YELLOW}SSL not enabled${NC}"
        return
    fi
    
    echo -e "${GREEN}Setting up SSL certificates...${NC}"
    
    if [ "$ENABLE_PANEL" = "true" ]; then
        certbot --nginx -d panel.$MAIN_DOMAIN --non-interactive --agree-tos --email $SSL_EMAIL
    fi
    
    if [ "$ENABLE_SUBSCRIPTION" = "true" ]; then
        certbot --nginx -d sub.$MAIN_DOMAIN --non-interactive --agree-tos --email $SSL_EMAIL
    fi
}

# Configure VLESS inbound
configure_vless() {
    echo -e "${GREEN}Configuring VLESS protocol...${NC}"
    
    # Generate or use existing client ID
    if [ "$CLIENT_ID" = "auto" ]; then
        CLIENT_ID=$(uuidgen)
        echo "CLIENT_ID=$CLIENT_ID" >> .env
    fi
    
    # Add VLESS configuration to X-UI database
    sqlite3 /etc/x-ui/x-ui.db << EOF
DELETE FROM inbounds WHERE remark='$SERVER_NAME-VLESS';
INSERT INTO inbounds (
    user_id, up, down, total, remark, enable, expiry_time,
    listen, port, protocol, settings, stream_settings, tag, sniffing
) VALUES (
    1, 0, 0, 0, '$SERVER_NAME-VLESS', 1, 0, '',
    $VPN_PORT, 'vless',
    '{"clients":[{"id":"$CLIENT_ID","email":"user@$SERVER_NAME","flow":"","limitIp":0,"totalGB":0,"expiryTime":0,"enable":true}],"decryption":"none","fallbacks":[]}',
    '{"network":"tcp","security":"none","tcpSettings":{"acceptProxyProtocol":false,"header":{"type":"none"}}}',
    'inbound-vless-$VPN_PORT',
    '{"enabled":true,"destOverride":["http","tls"]}'
);
EOF
    
    # Restart X-UI to apply changes
    systemctl restart x-ui
    
    echo -e "${GREEN}VLESS configured on port $VPN_PORT${NC}"
    echo -e "${YELLOW}Client ID: $CLIENT_ID${NC}"
}

# Show connection info
show_info() {
    echo -e "\n${GREEN}═══════════════════════════════════════════════${NC}"
    echo -e "${GREEN}     VPN Server Installation Complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════${NC}\n"
    
    echo -e "${YELLOW}Server Information:${NC}"
    echo "  Name: $SERVER_NAME"
    echo "  Location: $SERVER_LOCATION"
    echo "  IP: $SERVER_IP"
    echo ""
    
    if [ "$ENABLE_PANEL" = "true" ]; then
        echo -e "${YELLOW}X-UI Panel:${NC}"
        echo "  URL: https://panel.$MAIN_DOMAIN/$SERVER_NAME/"
        echo "  Username: $XRAY_USERNAME"
        echo "  Password: $XRAY_PASSWORD"
        echo ""
    fi
    
    if [ "$ENABLE_SUBSCRIPTION" = "true" ]; then
        echo -e "${YELLOW}Subscription Service:${NC}"
        echo "  URL: https://sub.$MAIN_DOMAIN/sub/{username}"
        echo ""
    fi
    
    echo -e "${YELLOW}VPN Connection:${NC}"
    echo "  Protocol: VLESS"
    echo "  Port: $VPN_PORT"
    echo "  Client ID: $CLIENT_ID"
    echo ""
    
    echo -e "${YELLOW}Direct Connection String:${NC}"
    echo "  vless://$CLIENT_ID@$SERVER_IP:$VPN_PORT#$SERVER_NAME"
    echo ""
    
    echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
}

# Main installation flow
main() {
    echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
    echo -e "${GREEN}   Multi-Location VPN Server Installer${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════${NC}\n"
    
    load_config
    detect_environment
    install_dependencies
    install_xui
    setup_subscription
    setup_nginx
    setup_ssl
    configure_vless
    show_info
    
    echo -e "${GREEN}Installation complete! Save the information above.${NC}"
}

# Run main function
main "$@"