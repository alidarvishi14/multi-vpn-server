#!/bin/bash

# VPN Server Diagnostic Script
# Generates comprehensive diagnostic report for troubleshooting

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================"
echo "    VPN Server Diagnostic Report"
echo "    Generated: $(date)"
echo "========================================"
echo ""

# System Information
echo -e "${BLUE}=== SYSTEM INFORMATION ===${NC}"
echo "Hostname: $(hostname)"
echo "IP Address: $(hostname -I | awk '{print $1}')"
echo "OS: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p)"
echo ""

# Resource Usage
echo -e "${BLUE}=== RESOURCE USAGE ===${NC}"
echo "CPU Load:"
uptime | awk -F'load average:' '{ print "  Load Average:" $2 }'
echo ""
echo "Memory Usage:"
free -h | grep -E "^Mem|^Swap" | awk '{printf "  %-7s Total: %-8s Used: %-8s Free: %-8s\n", $1, $2, $3, $4}'
echo ""
echo "Disk Usage:"
df -h | grep -E "^/dev/" | awk '{printf "  %-20s Size: %-8s Used: %-8s Avail: %-8s Usage: %s\n", $1, $2, $3, $4, $5}'
echo ""

# Service Status
echo -e "${BLUE}=== SERVICE STATUS ===${NC}"
services=("x-ui" "simple-sub" "scalable-sub" "nginx" "ssh")
for service in "${services[@]}"; do
    if systemctl list-units --all | grep -q "$service.service"; then
        status=$(systemctl is-active $service 2>/dev/null || echo "unknown")
        if [ "$status" = "active" ]; then
            echo -e "$service: ${GREEN}● active${NC}"
            # Get additional info
            systemctl status $service --no-pager 2>/dev/null | grep -E "Active:|Main PID:" | sed 's/^/  /'
        elif [ "$status" = "inactive" ]; then
            echo -e "$service: ${YELLOW}○ inactive${NC}"
        else
            echo -e "$service: ${RED}● failed${NC}"
            # Show last error
            journalctl -u $service -n 3 --no-pager 2>/dev/null | sed 's/^/  /'
        fi
    else
        echo -e "$service: ${RED}not installed${NC}"
    fi
done
echo ""

# Network Status
echo -e "${BLUE}=== NETWORK STATUS ===${NC}"
echo "Open Ports:"
ss -tlnp 2>/dev/null | grep LISTEN | awk '{print "  " $4 " (" $6 ")"}' | sed 's/users:(("//g' | sed 's/".*//g' | head -20
echo ""
echo "Firewall Status:"
if command -v ufw &> /dev/null; then
    ufw status | head -10 | sed 's/^/  /'
else
    echo "  UFW not installed"
fi
echo ""

# VPN Specific Checks
echo -e "${BLUE}=== VPN CONFIGURATION ===${NC}"
echo "VPN Ports Status:"
for port in 8443 54321 5556 443 80; do
    if ss -tlnp 2>/dev/null | grep -q ":$port "; then
        echo -e "  Port $port: ${GREEN}OPEN${NC}"
    else
        echo -e "  Port $port: ${RED}CLOSED${NC}"
    fi
done
echo ""

# Configuration Files
echo "Configuration Files:"
configs=(
    "/etc/x-ui/x-ui.db"
    "/usr/local/x-ui/bin/config.json"
    "/opt/multi-vpn-server/.env"
    "/opt/multi-vpn-server/configs/servers.json"
    "/opt/multi-vpn-server/configs/nodes.json"
)
for config in "${configs[@]}"; do
    if [ -f "$config" ]; then
        size=$(ls -lh "$config" 2>/dev/null | awk '{print $5}')
        echo -e "  $config: ${GREEN}EXISTS${NC} (${size})"
    else
        echo -e "  $config: ${RED}MISSING${NC}"
    fi
done
echo ""

# SSL Certificates
echo -e "${BLUE}=== SSL CERTIFICATES ===${NC}"
if command -v certbot &> /dev/null; then
    certbot certificates 2>/dev/null | grep -E "Certificate Name:|Expiry Date:|VALID:" | sed 's/^/  /' || echo "  No certificates found"
else
    echo "  Certbot not installed"
fi
echo ""

# Connection Test
echo -e "${BLUE}=== CONNECTIVITY TESTS ===${NC}"
echo "Internet Connectivity:"
if ping -c 1 -W 2 google.com &> /dev/null; then
    echo -e "  Google.com: ${GREEN}OK${NC}"
else
    echo -e "  Google.com: ${RED}FAILED${NC}"
fi

if ping -c 1 -W 2 1.1.1.1 &> /dev/null; then
    echo -e "  DNS (1.1.1.1): ${GREEN}OK${NC}"
else
    echo -e "  DNS (1.1.1.1): ${RED}FAILED${NC}"
fi
echo ""

# Server Connectivity (if servers.json exists)
if [ -f "/opt/multi-vpn-server/configs/servers.json" ]; then
    echo "VPN Server Connectivity:"
    python3 << 'EOF' 2>/dev/null || echo "  Unable to check servers"
import json
import subprocess
import sys

try:
    with open('/opt/multi-vpn-server/configs/servers.json', 'r') as f:
        config = json.load(f)
        for server in config['servers']:
            result = subprocess.run(['ping', '-c', '1', '-W', '2', server['ip']], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                print(f"  {server['name']} ({server['ip']}): \033[0;32mOK\033[0m")
            else:
                print(f"  {server['name']} ({server['ip']}): \033[0;31mFAILED\033[0m")
except Exception as e:
    print(f"  Error checking servers: {e}")
EOF
    echo ""
fi

# Recent Logs
echo -e "${BLUE}=== RECENT ERROR LOGS ===${NC}"
echo "X-UI Errors (last 5):"
journalctl -u x-ui -p err -n 5 --no-pager 2>/dev/null | sed 's/^/  /' || echo "  No errors or service not found"
echo ""
echo "Nginx Errors (last 5):"
tail -5 /var/log/nginx/error.log 2>/dev/null | sed 's/^/  /' || echo "  No errors or log not found"
echo ""

# Active Connections
echo -e "${BLUE}=== ACTIVE CONNECTIONS ===${NC}"
echo "VPN Connections (port 8443):"
connection_count=$(ss -tn state established '( sport = :8443 )' 2>/dev/null | wc -l)
echo "  Active connections: $((connection_count - 1))"
echo ""

# Performance Metrics
echo -e "${BLUE}=== PERFORMANCE METRICS ===${NC}"
echo "Network Statistics:"
if command -v vnstat &> /dev/null; then
    vnstat --oneline 2>/dev/null | awk -F';' '{print "  Today: RX " $4 " TX " $5}' || echo "  vnstat not configured"
else
    echo "  vnstat not installed"
fi
echo ""

# Docker Status (if using Docker)
if command -v docker &> /dev/null; then
    echo -e "${BLUE}=== DOCKER STATUS ===${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | sed 's/^/  /'
    echo ""
fi

# Security Checks
echo -e "${BLUE}=== SECURITY CHECKS ===${NC}"
echo "Failed SSH Attempts (last 10):"
grep "Failed password" /var/log/auth.log 2>/dev/null | tail -5 | sed 's/^/  /' || echo "  No failed attempts or log not accessible"
echo ""

# Summary
echo -e "${BLUE}=== DIAGNOSTIC SUMMARY ===${NC}"
errors=0
warnings=0

# Check critical services
for service in x-ui nginx; do
    if ! systemctl is-active --quiet $service 2>/dev/null; then
        echo -e "${RED}✗ Critical service $service is not running${NC}"
        ((errors++))
    fi
done

# Check critical ports
for port in 8443; do
    if ! ss -tlnp 2>/dev/null | grep -q ":$port "; then
        echo -e "${RED}✗ Critical port $port is not open${NC}"
        ((errors++))
    fi
done

# Check disk space
disk_usage=$(df / | awk 'NR==2 {print int($5)}')
if [ $disk_usage -gt 90 ]; then
    echo -e "${RED}✗ Disk usage critical: ${disk_usage}%${NC}"
    ((errors++))
elif [ $disk_usage -gt 75 ]; then
    echo -e "${YELLOW}⚠ Disk usage high: ${disk_usage}%${NC}"
    ((warnings++))
fi

# Check memory
mem_usage=$(free | awk '/^Mem:/ {print int($3/$2 * 100)}')
if [ $mem_usage -gt 90 ]; then
    echo -e "${RED}✗ Memory usage critical: ${mem_usage}%${NC}"
    ((errors++))
elif [ $mem_usage -gt 75 ]; then
    echo -e "${YELLOW}⚠ Memory usage high: ${mem_usage}%${NC}"
    ((warnings++))
fi

if [ $errors -eq 0 ] && [ $warnings -eq 0 ]; then
    echo -e "${GREEN}✓ All systems operational${NC}"
else
    echo ""
    echo "Issues found: $errors errors, $warnings warnings"
fi

echo ""
echo "========================================"
echo "    End of Diagnostic Report"
echo "========================================"