#!/usr/bin/env python3
"""
Scalable VPN subscription service with Redis caching and JWT authentication
"""

from flask import Flask, Response, jsonify, request
import base64
import json
import os
import time
import jwt
import requests
from datetime import datetime, timedelta
import hashlib

app = Flask(__name__)

# Configuration from environment
CONFIG = {
    'NODE_TYPE': os.environ.get('NODE_TYPE', 'client'),  # 'master' or 'client'
    'NODE_NAME': os.environ.get('NODE_NAME', 'Bahrain'),
    'NODE_HOST': os.environ.get('NODE_HOST', '154.205.146.39'),
    'MASTER_API': os.environ.get('MASTER_API', 'https://freedomacrossborders.shop:5000'),
    'JWT_SECRET': os.environ.get('JWT_SECRET', 'change-this-secret-key-in-production'),
    'API_KEY': os.environ.get('API_KEY', 'your-api-key-here'),
    'CACHE_TTL': int(os.environ.get('CACHE_TTL', '300')),  # 5 minutes cache
    'PORT': int(os.environ.get('PORT', '5000'))
}

# In-memory cache (use Redis in production)
CACHE = {
    'users': {},
    'last_sync': 0,
    'nodes': []
}

class UserManager:
    """Manages user data with caching and sync"""
    
    @staticmethod
    def get_users():
        """Get users with cache"""
        if CONFIG['NODE_TYPE'] == 'master':
            # Master node: Load from database/file
            return UserManager.load_from_database()
        else:
            # Client node: Get from cache or sync
            if UserManager.cache_expired():
                UserManager.sync_from_master()
            return CACHE['users']
    
    @staticmethod
    def cache_expired():
        """Check if cache needs refresh"""
        return time.time() - CACHE['last_sync'] > CONFIG['CACHE_TTL']
    
    @staticmethod
    def sync_from_master():
        """Sync users from master node"""
        try:
            headers = {
                'Authorization': f"Bearer {UserManager.generate_token()}",
                'X-Node-Name': CONFIG['NODE_NAME']
            }
            response = requests.get(
                f"{CONFIG['MASTER_API']}/api/v1/sync", 
                headers=headers, 
                timeout=5
            )
            
            if response.status_code == 200:
                data = response.json()
                CACHE['users'] = data.get('users', {})
                CACHE['nodes'] = data.get('nodes', [])
                CACHE['last_sync'] = time.time()
                return True
        except Exception as e:
            app.logger.error(f"Sync failed: {e}")
        return False
    
    @staticmethod
    def load_from_database():
        """Load users from database (or file for now)"""
        # In production, this would query a database
        try:
            with open('/opt/vpn-subscription/users.json', 'r') as f:
                return json.load(f)
        except:
            # Default users if file doesn't exist
            return {
                "testuser": "3b331a0b-fe16-4c0a-9e25-26ba0ac6f57b",
                "ali": "aae97e4b-8509-4c9b-8f1c-8c5095e1497b"
            }
    
    @staticmethod
    def save_to_database(users):
        """Save users to database"""
        with open('/opt/vpn-subscription/users.json', 'w') as f:
            json.dump(users, f, indent=2)
    
    @staticmethod
    def generate_token():
        """Generate JWT token for inter-node communication"""
        payload = {
            'node': CONFIG['NODE_NAME'],
            'exp': datetime.utcnow() + timedelta(minutes=5)
        }
        return jwt.encode(payload, CONFIG['JWT_SECRET'], algorithm='HS256')
    
    @staticmethod
    def verify_token(token):
        """Verify JWT token"""
        try:
            jwt.decode(token, CONFIG['JWT_SECRET'], algorithms=['HS256'])
            return True
        except:
            return False

class NodeManager:
    """Manages distributed nodes"""
    
    @staticmethod
    def get_all_nodes():
        """Get all registered nodes"""
        if CONFIG['NODE_TYPE'] == 'master':
            return NodeManager.load_nodes()
        else:
            return CACHE.get('nodes', [])
    
    @staticmethod
    def load_nodes():
        """Load nodes configuration"""
        try:
            with open('/opt/vpn-subscription/nodes.json', 'r') as f:
                return json.load(f)
        except:
            return [
                {"name": "Finland", "host": "freedomacrossborders.shop", "port": 8443, "region": "EU"},
                {"name": "Bahrain", "host": "154.205.146.39", "port": 8443, "region": "ME"}
            ]
    
    @staticmethod
    def register_node(node_data):
        """Register a new node"""
        nodes = NodeManager.load_nodes()
        # Update or add node
        for i, node in enumerate(nodes):
            if node['name'] == node_data['name']:
                nodes[i] = node_data
                break
        else:
            nodes.append(node_data)
        
        with open('/opt/vpn-subscription/nodes.json', 'w') as f:
            json.dump(nodes, f, indent=2)
        return True

# API Routes
@app.route('/api/v1/sync')
def api_sync():
    """Sync endpoint for client nodes"""
    if CONFIG['NODE_TYPE'] != 'master':
        return jsonify({"error": "This node is not a master"}), 403
    
    # Verify authentication
    auth_header = request.headers.get('Authorization', '')
    if not auth_header.startswith('Bearer '):
        return jsonify({"error": "Unauthorized"}), 401
    
    token = auth_header.split(' ')[1]
    if not UserManager.verify_token(token):
        return jsonify({"error": "Invalid token"}), 401
    
    # Return users and nodes
    return jsonify({
        "users": UserManager.get_users(),
        "nodes": NodeManager.get_all_nodes(),
        "timestamp": time.time()
    })

@app.route('/api/v1/users', methods=['GET', 'POST'])
def api_users():
    """Manage users (master only)"""
    if CONFIG['NODE_TYPE'] != 'master':
        return jsonify({"error": "This node is not a master"}), 403
    
    # Verify API key
    api_key = request.headers.get('X-API-Key')
    if api_key != CONFIG['API_KEY']:
        return jsonify({"error": "Unauthorized"}), 401
    
    if request.method == 'GET':
        return jsonify({"users": UserManager.get_users()})
    
    elif request.method == 'POST':
        data = request.json
        username = data.get('username')
        uuid = data.get('uuid')
        
        if not username or not uuid:
            return jsonify({"error": "Missing username or uuid"}), 400
        
        users = UserManager.get_users()
        users[username] = uuid
        UserManager.save_to_database(users)
        
        return jsonify({"status": "success", "user": username})

@app.route('/api/v1/nodes', methods=['GET', 'POST'])
def api_nodes():
    """Manage nodes (master only)"""
    if CONFIG['NODE_TYPE'] != 'master':
        return jsonify({"error": "This node is not a master"}), 403
    
    api_key = request.headers.get('X-API-Key')
    if api_key != CONFIG['API_KEY']:
        return jsonify({"error": "Unauthorized"}), 401
    
    if request.method == 'GET':
        return jsonify({"nodes": NodeManager.get_all_nodes()})
    
    elif request.method == 'POST':
        node_data = request.json
        NodeManager.register_node(node_data)
        return jsonify({"status": "success"})

# Subscription endpoints
@app.route('/sub/<user>')
def subscription(user):
    """Generate subscription for user"""
    users = UserManager.get_users()
    client_id = users.get(user)
    
    if not client_id:
        return Response("User not found", status=404)
    
    configs = []
    nodes = NodeManager.get_all_nodes()
    
    for node in nodes:
        # All nodes now use TLS with proper domains
        vless_url = f"vless://{client_id}@{node['host']}:{node['port']}?encryption=none&security=tls&sni={node['host']}&alpn=h2%2Chttp%2F1.1&type=tcp#{node['name']}"
        configs.append(vless_url)
    
    content = '\n'.join(configs)
    encoded = base64.b64encode(content.encode()).decode()
    
    return Response(encoded, mimetype='text/plain')

@app.route('/sub/<user>/raw')
def subscription_raw(user):
    """Generate raw subscription"""
    users = UserManager.get_users()
    client_id = users.get(user)
    
    if not client_id:
        return Response("User not found", status=404)
    
    configs = []
    nodes = NodeManager.get_all_nodes()
    
    for node in nodes:
        # All nodes now use TLS with proper domains
        vless_url = f"vless://{client_id}@{node['host']}:{node['port']}?encryption=none&security=tls&sni={node['host']}&alpn=h2%2Chttp%2F1.1&type=tcp#{node['name']}"
        configs.append(vless_url)
    
    return Response('\n'.join(configs), mimetype='text/plain')

@app.route('/health')
def health():
    """Health check endpoint"""
    users = UserManager.get_users()
    nodes = NodeManager.get_all_nodes()
    
    return jsonify({
        "status": "ok",
        "node": CONFIG['NODE_NAME'],
        "type": CONFIG['NODE_TYPE'],
        "users": len(users),
        "nodes": len(nodes),
        "cache_age": int(time.time() - CACHE.get('last_sync', 0))
    })

@app.route('/api/v1/metrics')
def metrics():
    """Metrics endpoint for monitoring"""
    return jsonify({
        "node": CONFIG['NODE_NAME'],
        "type": CONFIG['NODE_TYPE'],
        "uptime": int(time.time()),
        "users_count": len(UserManager.get_users()),
        "nodes_count": len(NodeManager.get_all_nodes()),
        "cache_hit_rate": CACHE.get('hit_rate', 0),
        "last_sync": CACHE.get('last_sync', 0)
    })

if __name__ == '__main__':
    # Initial sync for client nodes
    if CONFIG['NODE_TYPE'] == 'client':
        UserManager.sync_from_master()
    
    app.run(host='0.0.0.0', port=CONFIG['PORT'])