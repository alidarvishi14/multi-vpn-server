#!/bin/bash

# Deployment script for scalable VPN subscription service

SERVER_TYPE=$1
SERVER_NAME=$2
SERVER_HOST=$3

if [ -z "$SERVER_TYPE" ] || [ -z "$SERVER_NAME" ]; then
    echo "Usage: ./deploy-scalable.sh [master|client] [server-name] [server-host]"
    echo "Example: ./deploy-scalable.sh master Finland freedomacrossborders.shop"
    echo "Example: ./deploy-scalable.sh client Bahrain 154.205.146.39"
    exit 1
fi

# Generate secure keys if not exist
if [ ! -f /opt/vpn-subscription/.env ]; then
    JWT_SECRET=$(openssl rand -hex 32)
    API_KEY=$(openssl rand -hex 24)
    
    cat > /opt/vpn-subscription/.env << EOF
NODE_TYPE=$SERVER_TYPE
NODE_NAME=$SERVER_NAME
NODE_HOST=$SERVER_HOST
MASTER_API=https://freedomacrossborders.shop:5000
JWT_SECRET=$JWT_SECRET
API_KEY=$API_KEY
CACHE_TTL=300
PORT=5000
EOF
    echo "Created .env file with secure keys"
fi

# Install dependencies
pip3 install flask requests pyjwt

# Create systemd service
cat > /etc/systemd/system/vpn-scalable.service << EOF
[Unit]
Description=Scalable VPN Subscription Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/vpn-subscription
EnvironmentFile=/opt/vpn-subscription/.env
ExecStart=/usr/bin/python3 /opt/vpn-subscription/scalable-sub.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Initial data files for master
if [ "$SERVER_TYPE" == "master" ]; then
    # Create initial users file
    if [ ! -f /opt/vpn-subscription/users.json ]; then
        cat > /opt/vpn-subscription/users.json << EOF
{
  "testuser": "3b331a0b-fe16-4c0a-9e25-26ba0ac6f57b",
  "ali": "aae97e4b-8509-4c9b-8f1c-8c5095e1497b"
}
EOF
    fi
    
    # Create initial nodes file
    if [ ! -f /opt/vpn-subscription/nodes.json ]; then
        cat > /opt/vpn-subscription/nodes.json << EOF
[
  {
    "name": "Finland",
    "host": "freedomacrossborders.shop",
    "port": 8443,
    "region": "EU",
    "capacity": 1000
  },
  {
    "name": "Bahrain",
    "host": "154.205.146.39",
    "port": 8443,
    "region": "ME",
    "capacity": 500
  }
]
EOF
    fi
fi

# Reload and start service
systemctl daemon-reload
systemctl enable vpn-scalable.service
systemctl restart vpn-scalable.service

echo "Deployment complete for $SERVER_NAME ($SERVER_TYPE)"
echo "Service status:"
systemctl status vpn-scalable.service --no-pager

# Show API examples
if [ "$SERVER_TYPE" == "master" ]; then
    echo ""
    echo "Master API endpoints:"
    echo "  Add user: curl -X POST http://$SERVER_HOST:5000/api/v1/users -H 'X-API-Key: YOUR_KEY' -H 'Content-Type: application/json' -d '{\"username\":\"newuser\",\"uuid\":\"generated-uuid\"}'"
    echo "  Get users: curl http://$SERVER_HOST:5000/api/v1/users -H 'X-API-Key: YOUR_KEY'"
    echo "  Add node: curl -X POST http://$SERVER_HOST:5000/api/v1/nodes -H 'X-API-Key: YOUR_KEY' -H 'Content-Type: application/json' -d '{\"name\":\"Germany\",\"host\":\"1.2.3.4\",\"port\":8443}'"
fi