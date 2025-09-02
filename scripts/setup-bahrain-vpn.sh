#!/bin/bash

# Setup VPN on Bahrain server with same users as Finland

echo "Setting up VPN on Bahrain server..."

# Stop X-UI temporarily
ssh -i /opt/vpn-subscription/ssh_keys/bahrain-server-rsa root@154.205.146.39 "systemctl stop x-ui"

# Create SQL to add VPN inbound
cat > /tmp/add_vpn.sql << 'EOF'
INSERT INTO inbounds (user_id, up, down, total, remark, enable, expiry_time, listen, port, protocol, settings, stream_settings, tag, sniffing)
VALUES (
  1,
  0,
  0,
  0,
  'VPN-Service',
  1,
  0,
  '',
  8443,
  'vless',
  '{
    "clients": [
      {"email": "testuser@vpn", "enable": true, "id": "3b331a0b-fe16-4c0a-9e25-26ba0ac6f57b", "flow": ""},
      {"email": "ali@vpn", "enable": true, "id": "aae97e4b-8509-4c9b-8f1c-8c5095e1497b", "flow": ""},
      {"email": "john@vpn", "enable": true, "id": "550e8400-e29b-41d4-a716-446655440000", "flow": ""},
      {"email": "dr@vpn", "enable": true, "id": "e1f4daa7-cc1b-4d02-eb8c-239dae9892ed", "flow": ""},
      {"email": "alidarvishi14@vpn", "enable": true, "id": "f99c3c83-af0f-47fc-ab65-e8b44f2c92a5", "flow": ""}
    ],
    "decryption": "none",
    "fallbacks": []
  }',
  '{"network": "tcp", "security": "tls", "tlsSettings": {"serverName": "", "certificates": [{"certificateFile": "/etc/letsencrypt/live/freedomacrossborders.shop/fullchain.pem", "keyFile": "/etc/letsencrypt/live/freedomacrossborders.shop/privkey.pem"}], "alpn": ["h2", "http/1.1"]}, "tcpSettings": {"header": {"type": "none"}}}',
  'inbound-8443',
  '{"enabled": true, "destOverride": ["http", "tls"]}'
);
EOF

# Copy and execute SQL
scp -i /opt/vpn-subscription/ssh_keys/bahrain-server-rsa /tmp/add_vpn.sql root@154.205.146.39:/tmp/
ssh -i /opt/vpn-subscription/ssh_keys/bahrain-server-rsa root@154.205.146.39 "sqlite3 /etc/x-ui/x-ui.db < /tmp/add_vpn.sql"

# Generate self-signed cert for now (replace with Let's Encrypt later)
ssh -i /opt/vpn-subscription/ssh_keys/bahrain-server-rsa root@154.205.146.39 "mkdir -p /etc/letsencrypt/live/freedomacrossborders.shop/ && openssl req -x509 -newkey rsa:4096 -keyout /etc/letsencrypt/live/freedomacrossborders.shop/privkey.pem -out /etc/letsencrypt/live/freedomacrossborders.shop/fullchain.pem -days 365 -nodes -subj '/CN=154.205.146.39'"

# Restart X-UI
ssh -i /opt/vpn-subscription/ssh_keys/bahrain-server-rsa root@154.205.146.39 "systemctl restart x-ui"

echo "Waiting for X-UI to start..."
sleep 5

# Check if port 8443 is listening
ssh -i /opt/vpn-subscription/ssh_keys/bahrain-server-rsa root@154.205.146.39 "ss -tlnp | grep 8443"

echo "VPN setup complete on Bahrain!"