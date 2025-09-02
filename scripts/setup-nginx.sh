#!/bin/bash

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Setting up Nginx Web Server...${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}" 
   exit 1
fi

# Get domain from environment or argument
DOMAIN=${1:-$MAIN_DOMAIN}
if [ -z "$DOMAIN" ]; then
    read -p "Enter your domain name: " DOMAIN
fi

# Install Nginx
echo "Installing Nginx..."
apt-get update
apt-get install -y nginx certbot python3-certbot-nginx

# Create Nginx configuration for subscription service
echo "Creating Nginx configuration..."
cat > /etc/nginx/sites-available/vpn-subscription << EOF
server {
    listen 80;
    server_name sub.$DOMAIN;
    
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name sub.$DOMAIN;
    
    # SSL certificates will be added by certbot
    
    location / {
        proxy_pass http://127.0.0.1:5556;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Create Nginx configuration for panel proxy
cat > /etc/nginx/sites-available/vpn-panel << EOF
server {
    listen 80;
    server_name panel.$DOMAIN;
    
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name panel.$DOMAIN;
    
    # SSL certificates will be added by certbot
    
    # Proxy to different servers based on path
    location /finland/ {
        proxy_pass http://46.62.146.210:54321/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
    
    location /bahrain/ {
        proxy_pass http://154.205.146.151:54321/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
    
    location / {
        return 301 /finland/;
    }
}
EOF

# Enable sites
ln -sf /etc/nginx/sites-available/vpn-subscription /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/vpn-panel /etc/nginx/sites-enabled/

# Remove default site if exists
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
nginx -t

# Reload Nginx
systemctl reload nginx
systemctl enable nginx

echo -e "${GREEN}Nginx setup complete!${NC}"
echo "Next, run setup-ssl.sh to configure SSL certificates"

# Configure firewall
if command -v ufw &> /dev/null; then
    echo "Configuring firewall..."
    ufw allow 'Nginx Full'
    ufw allow 80/tcp
    ufw allow 443/tcp
fi

echo -e "${GREEN}Web server configuration complete!${NC}"