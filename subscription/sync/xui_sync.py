#!/usr/bin/env python3
"""
X-UI Integration Module - Syncs X-UI users with subscription service
"""

import sqlite3
import json
import requests
import time
import os
from datetime import datetime

class XUISync:
    def __init__(self):
        self.xui_db = '/etc/x-ui/x-ui.db'
        self.api_url = 'http://localhost:5000/api/v1/users'
        self.api_key = os.environ.get('API_KEY', '3e9ce1f3bccf221b6b3d6158d29f5c75294802deef0ed40f')
        
    def get_xui_users(self):
        """Get all users from X-UI database"""
        users = {}
        try:
            conn = sqlite3.connect(self.xui_db)
            cursor = conn.cursor()
            
            # Get inbounds (VPN configurations)
            cursor.execute("SELECT settings FROM inbounds WHERE enable = 1")
            inbounds = cursor.fetchall()
            
            for inbound in inbounds:
                settings = json.loads(inbound[0])
                if 'clients' in settings:
                    for client in settings['clients']:
                        email = client.get('email', '')
                        uuid = client.get('id', '')
                        if email and uuid:
                            # Use email as username (remove domain if present)
                            username = email.split('@')[0] if '@' in email else email
                            users[username] = uuid
            
            conn.close()
            return users
        except Exception as e:
            print(f"Error reading X-UI database: {e}")
            return {}
    
    def get_subscription_users(self):
        """Get users from subscription service"""
        try:
            headers = {'X-API-Key': self.api_key}
            response = requests.get(self.api_url, headers=headers, timeout=5)
            if response.status_code == 200:
                return response.json().get('users', {})
        except Exception as e:
            print(f"Error getting subscription users: {e}")
        return {}
    
    def add_user_to_subscription(self, username, uuid):
        """Add user to subscription service"""
        try:
            headers = {
                'X-API-Key': self.api_key,
                'Content-Type': 'application/json'
            }
            data = {'username': username, 'uuid': uuid}
            response = requests.post(self.api_url, headers=headers, json=data, timeout=5)
            return response.status_code == 200
        except Exception as e:
            print(f"Error adding user {username}: {e}")
            return False
    
    def sync_users(self):
        """Sync X-UI users to subscription service"""
        xui_users = self.get_xui_users()
        sub_users = self.get_subscription_users()
        
        added = []
        for username, uuid in xui_users.items():
            if username not in sub_users:
                if self.add_user_to_subscription(username, uuid):
                    added.append(username)
                    print(f"Added user: {username}")
        
        return {
            'xui_users': len(xui_users),
            'sub_users': len(sub_users),
            'added': added,
            'timestamp': datetime.now().isoformat()
        }

def main():
    """Run sync once or continuously"""
    import sys
    
    sync = XUISync()
    
    if len(sys.argv) > 1 and sys.argv[1] == '--watch':
        # Continuous sync mode
        print("Starting X-UI sync in watch mode...")
        while True:
            result = sync.sync_users()
            if result['added']:
                print(f"Synced {len(result['added'])} new users")
            time.sleep(60)  # Sync every minute
    else:
        # One-time sync
        result = sync.sync_users()
        print(json.dumps(result, indent=2))

if __name__ == '__main__':
    main()