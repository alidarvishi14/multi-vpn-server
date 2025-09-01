#!/usr/bin/env python3
"""
Simple subscription service that generates correct VLESS URLs
"""

from flask import Flask, Response
import base64

app = Flask(__name__)

# Configuration
CLIENT_ID = "3b331a0b-fe16-4c0a-9e25-26ba0ac6f57b"
SERVERS = [
    {"name": "Finland", "host": "freedomacrossborders.shop", "port": 8443},
    {"name": "Bahrain", "host": "154.205.146.151", "port": 8443}
]

@app.route('/sub/<user>')
def subscription(user):
    """Generate subscription for any user"""
    configs = []
    
    for server in SERVERS:
        # Simple VLESS URL without encryption
        vless_url = f"vless://{CLIENT_ID}@{server['host']}:{server['port']}?encryption=none&type=tcp#{server['name']}"
        configs.append(vless_url)
    
    # Join configs and base64 encode
    content = '\n'.join(configs)
    encoded = base64.b64encode(content.encode()).decode()
    
    return Response(encoded, mimetype='text/plain')

@app.route('/sub/<user>/raw')
def subscription_raw(user):
    """Generate raw subscription (not encoded)"""
    configs = []
    
    for server in SERVERS:
        vless_url = f"vless://{CLIENT_ID}@{server['host']}:{server['port']}?encryption=none&type=tcp#{server['name']}"
        configs.append(vless_url)
    
    return Response('\n'.join(configs), mimetype='text/plain')

@app.route('/health')
def health():
    return {"status": "ok", "servers": len(SERVERS)}

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5556)