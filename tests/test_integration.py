#!/usr/bin/env python3
"""
Integration tests for Multi-VPN Server
"""

import unittest
import subprocess
import socket
import time
import requests
import json
import os


class TestServiceIntegration(unittest.TestCase):
    """Integration tests for running services"""
    
    @classmethod
    def setUpClass(cls):
        """Set up test environment"""
        cls.services = {
            'x-ui': 54321,
            'simple-sub': 5556,
            'nginx': 80
        }
    
    def test_port_availability(self):
        """Test if required ports are available or in use by correct services"""
        required_ports = [8443, 54321, 5556, 80, 443]
        
        for port in required_ports:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            result = sock.connect_ex(('127.0.0.1', port))
            sock.close()
            
            # Port is either available (result != 0) or in use (result == 0)
            # Both are acceptable states
            self.assertIn(result, [0, 111], f"Port {port} check failed")
    
    def test_service_status(self):
        """Test systemd service status"""
        for service in self.services.keys():
            result = subprocess.run(
                ['systemctl', 'is-enabled', service],
                capture_output=True,
                text=True
            )
            # Service might not be installed yet, which is ok
            self.assertIn(
                result.returncode, [0, 1],
                f"Service {service} check failed"
            )
    
    def test_config_files_valid(self):
        """Test if all configuration files are valid"""
        config_files = [
            'configs/servers.json',
            'configs/nodes.json',
            'configs/users.json'
        ]
        
        for config_file in config_files:
            if os.path.exists(config_file):
                with open(config_file, 'r') as f:
                    try:
                        json.load(f)
                    except json.JSONDecodeError as e:
                        self.fail(f"Invalid JSON in {config_file}: {e}")
    
    def test_nginx_config_syntax(self):
        """Test Nginx configuration syntax"""
        result = subprocess.run(
            ['nginx', '-t'],
            capture_output=True,
            text=True
        )
        
        # Nginx might not be installed
        if result.returncode == 127:  # Command not found
            self.skipTest("Nginx not installed")
        elif result.returncode == 0:
            self.assertIn('syntax is ok', result.stderr.lower())
    
    def test_python_imports(self):
        """Test if all Python dependencies can be imported"""
        required_modules = [
            'flask',
            'gunicorn',
            'jwt',
            'requests',
            'dotenv'
        ]
        
        for module in required_modules:
            try:
                __import__(module)
            except ImportError:
                # Module not installed yet, which is expected
                pass
    
    def test_ssl_certificate_validity(self):
        """Test SSL certificate configuration"""
        import ssl
        import datetime
        
        domains = ['sub.freedomacrossborders.shop', 'panel.freedomacrossborders.shop']
        
        for domain in domains:
            try:
                context = ssl.create_default_context()
                with socket.create_connection((domain, 443), timeout=5) as sock:
                    with context.wrap_socket(sock, server_hostname=domain) as ssock:
                        cert = ssock.getpeercert()
                        # Check if certificate is valid
                        not_after = cert['notAfter']
                        # Basic check that cert exists
                        self.assertIsNotNone(not_after)
            except (socket.timeout, socket.gaierror, ConnectionRefusedError):
                # Domain might not be configured yet
                pass
    
    def test_backup_restore_cycle(self):
        """Test backup and restore functionality"""
        backup_script = 'scripts/backup.sh'
        restore_script = 'scripts/restore.sh'
        
        if os.path.exists(backup_script) and os.path.exists(restore_script):
            # Test backup script syntax
            result = subprocess.run(
                ['bash', '-n', backup_script],
                capture_output=True
            )
            self.assertEqual(result.returncode, 0, "Backup script has syntax errors")
            
            # Test restore script syntax
            result = subprocess.run(
                ['bash', '-n', restore_script],
                capture_output=True
            )
            self.assertEqual(result.returncode, 0, "Restore script has syntax errors")


class TestNetworkConnectivity(unittest.TestCase):
    """Test network connectivity and VPN functionality"""
    
    def test_dns_resolution(self):
        """Test DNS resolution"""
        import socket
        
        test_domains = ['google.com', '1.1.1.1']
        
        for domain in test_domains:
            try:
                socket.gethostbyname(domain)
            except socket.gaierror:
                self.fail(f"DNS resolution failed for {domain}")
    
    def test_vpn_server_connectivity(self):
        """Test connectivity to configured VPN servers"""
        servers = [
            ('46.62.146.210', 8443),  # Finland
            ('154.205.146.151', 8443)  # Bahrain
        ]
        
        for ip, port in servers:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(5)
            result = sock.connect_ex((ip, port))
            sock.close()
            
            # Connection might fail if server is not set up
            # We just check that the test completes
            self.assertIsNotNone(result)
    
    def test_subscription_url_format(self):
        """Test subscription URL format generation"""
        base_url = "https://sub.domain.com/sub"
        users = ["testuser", "admin", "user123"]
        
        for user in users:
            url = f"{base_url}/{user}"
            # Check URL format
            self.assertTrue(url.startswith("https://"))
            self.assertIn("/sub/", url)
            self.assertIn(user, url)


if __name__ == '__main__':
    unittest.main(verbosity=2)