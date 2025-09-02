#!/usr/bin/env python3
"""
X-UI Master Sync - Syncs users from Finland X-UI to all other X-UI servers
This ensures when you add a user in Finland's X-UI, it appears on all servers
"""

import sqlite3
import json
import paramiko
import time
import os

class XUIMasterSync:
    def __init__(self):
        self.master_db = '/etc/x-ui/x-ui.db'
        self.remote_servers = [
            {
                'name': 'Bahrain',
                'host': '154.205.146.39',
                'key_file': '/opt/vpn-subscription/ssh_keys/bahrain-server-rsa',
                'db_path': '/etc/x-ui/x-ui.db'
            }
            # Add more servers here as needed
        ]
    
    def get_master_users(self):
        """Get all VPN users from Finland master"""
        users = {}
        try:
            conn = sqlite3.connect(self.master_db)
            cursor = conn.cursor()
            cursor.execute("SELECT settings FROM inbounds WHERE port = 8443")
            result = cursor.fetchone()
            if result:
                settings = json.loads(result[0])
                for client in settings.get('clients', []):
                    email = client.get('email', '')
                    uuid = client.get('id', '')
                    if email and uuid:
                        users[email] = uuid
            conn.close()
        except Exception as e:
            print(f"Error reading master database: {e}")
        return users
    
    def sync_to_remote(self, server, users):
        """Sync users to a remote X-UI server"""
        try:
            # Create SSH connection
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            ssh.connect(server['host'], username='root', key_filename=server['key_file'])
            
            # Create Python script to run on remote
            clients = []
            for email, uuid in users.items():
                clients.append({
                    "email": email,
                    "enable": True,
                    "id": uuid,
                    "flow": ""
                })
            
            settings = {
                "clients": clients,
                "decryption": "none",
                "fallbacks": []
            }
            
            # Determine certificate path based on server
            if server['name'] == 'Bahrain':
                cert_domain = 'bahrain.freedomacrossborders.shop'
            else:
                cert_domain = 'freedomacrossborders.shop'
            
            stream_settings = {
                "network": "tcp",
                "security": "tls",
                "tlsSettings": {
                    "serverName": cert_domain,
                    "certificates": [{
                        "certificateFile": f"/etc/letsencrypt/live/{cert_domain}/fullchain.pem",
                        "keyFile": f"/etc/letsencrypt/live/{cert_domain}/privkey.pem"
                    }],
                    "alpn": ["h2", "http/1.1"]
                },
                "tcpSettings": {
                    "header": {"type": "none"}
                }
            }
            
            # Update remote database
            update_script = f'''
import sqlite3
import json

settings = {json.dumps(settings)}
stream_settings = {json.dumps(stream_settings)}

conn = sqlite3.connect('{server["db_path"]}')
cursor = conn.cursor()
cursor.execute("UPDATE inbounds SET settings = ?, stream_settings = ? WHERE port = 8443", 
               (json.dumps(settings), json.dumps(stream_settings)))
conn.commit()
conn.close()
print("Updated {len(clients)} users")
'''
            
            # Write script to remote
            stdin, stdout, stderr = ssh.exec_command(f"cat > /tmp/sync_users.py << 'EOF'\n{update_script}\nEOF")
            stdout.read()
            
            # Execute script
            stdin, stdout, stderr = ssh.exec_command("python3 /tmp/sync_users.py")
            output = stdout.read().decode()
            
            # Restart X-UI
            stdin, stdout, stderr = ssh.exec_command("systemctl restart x-ui")
            
            ssh.close()
            return True, output
            
        except Exception as e:
            return False, str(e)
    
    def sync_all(self):
        """Sync to all remote servers"""
        users = self.get_master_users()
        print(f"Found {len(users)} users on master")
        
        results = []
        for server in self.remote_servers:
            print(f"Syncing to {server['name']}...")
            success, message = self.sync_to_remote(server, users)
            if success:
                print(f"  ✓ {server['name']}: {message}")
            else:
                print(f"  ✗ {server['name']}: {message}")
            results.append({'server': server['name'], 'success': success})
        
        return results

def main():
    import sys
    
    sync = XUIMasterSync()
    
    if len(sys.argv) > 1 and sys.argv[1] == '--watch':
        print("Starting X-UI master sync in watch mode...")
        while True:
            sync.sync_all()
            time.sleep(300)  # Sync every 5 minutes
    else:
        results = sync.sync_all()
        print(f"\nSync complete: {sum(1 for r in results if r['success'])}/{len(results)} successful")

if __name__ == '__main__':
    main()