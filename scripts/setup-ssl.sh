#!/bin/bash

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Setting up SSL Certificates with Let's Encrypt...${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}" 
   exit 1
fi

# Get domain and email
DOMAIN=${1:-$MAIN_DOMAIN}
EMAIL=${2:-$ADMIN_EMAIL}

if [ -z "$DOMAIN" ]; then
    read -p "Enter your domain name: " DOMAIN
fi

if [ -z "$EMAIL" ]; then
    read -p "Enter your email for SSL notifications: " EMAIL
fi

# Check if Nginx is installed
if ! command -v nginx &> /dev/null; then
    echo -e "${RED}Nginx is not installed. Please run setup-nginx.sh first${NC}"
    exit 1
fi

# Check if certbot is installed
if ! command -v certbot &> /dev/null; then
    echo "Installing certbot..."
    apt-get update
    apt-get install -y certbot python3-certbot-nginx
fi

echo -e "${YELLOW}Obtaining SSL certificates for:${NC}"
echo "  - sub.$DOMAIN"
echo "  - panel.$DOMAIN"
echo "  - $DOMAIN"

# Get SSL certificate for subscription service
echo "Getting SSL for sub.$DOMAIN..."
certbot --nginx -d sub.$DOMAIN --non-interactive --agree-tos --email $EMAIL --redirect

# Get SSL certificate for panel
echo "Getting SSL for panel.$DOMAIN..."
certbot --nginx -d panel.$DOMAIN --non-interactive --agree-tos --email $EMAIL --redirect

# Get SSL certificate for main domain (optional)
echo "Getting SSL for $DOMAIN..."
certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email $EMAIL --redirect || true

# Set up auto-renewal
echo "Setting up automatic certificate renewal..."
cat > /etc/systemd/system/certbot-renewal.service << EOF
[Unit]
Description=Certbot Renewal
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/certbot renew --quiet --post-hook "systemctl reload nginx"
EOF

cat > /etc/systemd/system/certbot-renewal.timer << EOF
[Unit]
Description=Run certbot renewal twice daily
After=network.target

[Timer]
OnCalendar=*-*-* 00,12:00:00
RandomizedDelaySec=3600
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Enable auto-renewal
systemctl daemon-reload
systemctl enable certbot-renewal.timer
systemctl start certbot-renewal.timer

# Test renewal
echo "Testing certificate renewal..."
certbot renew --dry-run

# Reload Nginx with new certificates
systemctl reload nginx

# Save SSL configuration
SSL_CONFIG="/root/.ssl-config"
cat > $SSL_CONFIG << EOF
SSL Configuration
=================
Domain: $DOMAIN
Email: $EMAIL
Certificates Location: /etc/letsencrypt/live/

Configured domains:
- https://sub.$DOMAIN (Subscription Service)
- https://panel.$DOMAIN (Management Panel)
- https://$DOMAIN (Main domain)

Auto-renewal: Enabled (runs twice daily)
EOF

echo -e "${GREEN}SSL Setup Complete!${NC}"
echo "Configuration saved to: $SSL_CONFIG"
cat $SSL_CONFIG

echo -e "${GREEN}All SSL certificates have been configured!${NC}"
echo "Your services are now accessible via HTTPS"