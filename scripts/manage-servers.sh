#!/bin/bash

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SERVERS_CONFIG="/opt/multi-vpn-server/configs/servers.json"

# Function to display menu
show_menu() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}   VPN Server Management Tool   ${NC}"
    echo -e "${BLUE}================================${NC}"
    echo "1. List all servers"
    echo "2. Check server status"
    echo "3. Add new server"
    echo "4. Remove server"
    echo "5. Restart services on server"
    echo "6. Update server configuration"
    echo "7. Sync all servers"
    echo "8. Monitor server health"
    echo "9. Generate server report"
    echo "0. Exit"
    echo ""
}

# List all servers
list_servers() {
    echo -e "${GREEN}Configured VPN Servers:${NC}"
    python3 << EOF
import json
with open('$SERVERS_CONFIG', 'r') as f:
    config = json.load(f)
    for i, server in enumerate(config['servers'], 1):
        print(f"{i}. {server['name']} ({server['ip']})")
        print(f"   - VPN Port: {server['vpn_port']}")
        print(f"   - Panel Port: {server['panel_port']}")
        print(f"   - Location: {server.get('location', 'Unknown')}")
EOF
}

# Check server status
check_status() {
    echo -e "${GREEN}Checking server status...${NC}"
    python3 << 'EOF'
import json
import subprocess
import concurrent.futures

def check_server(server):
    name = server['name']
    ip = server['ip']
    vpn_port = server['vpn_port']
    
    # Check ping
    ping_result = subprocess.run(['ping', '-c', '1', '-W', '2', ip], 
                                capture_output=True, text=True)
    ping_ok = ping_result.returncode == 0
    
    # Check VPN port
    nc_result = subprocess.run(['nc', '-zv', '-w', '2', ip, str(vpn_port)], 
                               capture_output=True, text=True, stderr=subprocess.STDOUT)
    vpn_ok = 'succeeded' in nc_result.stdout or 'open' in nc_result.stdout
    
    return {
        'name': name,
        'ip': ip,
        'ping': '✓' if ping_ok else '✗',
        'vpn': '✓' if vpn_ok else '✗'
    }

with open('/opt/multi-vpn-server/configs/servers.json', 'r') as f:
    config = json.load(f)
    servers = config['servers']

print("\nServer Status Report:")
print("-" * 50)
print(f"{'Server':<15} {'IP':<20} {'Ping':<10} {'VPN':<10}")
print("-" * 50)

with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
    results = executor.map(check_server, servers)
    for result in results:
        print(f"{result['name']:<15} {result['ip']:<20} {result['ping']:<10} {result['vpn']:<10}")
EOF
}

# Add new server
add_server() {
    ./scripts/add-server.sh "$@"
}

# Remove server
remove_server() {
    echo -e "${YELLOW}Select server to remove:${NC}"
    list_servers
    read -p "Enter server number: " SERVER_NUM
    
    python3 << EOF
import json

with open('$SERVERS_CONFIG', 'r') as f:
    config = json.load(f)

try:
    server_index = int('$SERVER_NUM') - 1
    removed = config['servers'].pop(server_index)
    
    with open('$SERVERS_CONFIG', 'w') as f:
        json.dump(config, f, indent=2)
    
    print(f"Server {removed['name']} removed successfully")
except (IndexError, ValueError):
    print("Invalid server number")
EOF
}

# Restart services on server
restart_services() {
    echo -e "${YELLOW}Select server:${NC}"
    list_servers
    read -p "Enter server number: " SERVER_NUM
    
    python3 << 'EOF'
import json
import subprocess
import sys

server_num = int(sys.argv[1]) - 1

with open('/opt/multi-vpn-server/configs/servers.json', 'r') as f:
    config = json.load(f)
    
try:
    server = config['servers'][server_num]
    ip = server['ip']
    name = server['name']
    
    print(f"Restarting services on {name}...")
    
    # SSH commands to restart services
    commands = [
        f"ssh root@{ip} 'systemctl restart x-ui'",
        f"ssh root@{ip} 'systemctl restart nginx'"
    ]
    
    for cmd in commands:
        subprocess.run(cmd, shell=True)
    
    print("Services restarted successfully")
except IndexError:
    print("Invalid server number")
EOF
}

# Update server configuration
update_config() {
    echo -e "${YELLOW}Updating server configurations...${NC}"
    
    # Sync configurations to all servers
    python3 << 'EOF'
import json
import subprocess

with open('/opt/multi-vpn-server/configs/servers.json', 'r') as f:
    config = json.load(f)

for server in config['servers']:
    print(f"Updating {server['name']}...")
    
    # Copy configuration files
    subprocess.run([
        'scp', 
        '/opt/multi-vpn-server/configs/servers.json',
        f"root@{server['ip']}:/opt/vpn-config/"
    ])
    
print("Configuration update complete")
EOF
}

# Sync all servers
sync_servers() {
    echo -e "${GREEN}Synchronizing all servers...${NC}"
    
    if [ -f "/opt/multi-vpn-server/subscription/sync/xui_master_sync.py" ]; then
        python3 /opt/multi-vpn-server/subscription/sync/xui_master_sync.py
    else
        echo -e "${RED}Sync script not found${NC}"
    fi
}

# Monitor server health
monitor_health() {
    echo -e "${GREEN}Starting health monitor (Press Ctrl+C to stop)...${NC}"
    
    while true; do
        clear
        echo -e "${BLUE}=== VPN Server Health Monitor ===${NC}"
        echo "$(date)"
        echo ""
        
        check_status
        
        echo ""
        echo "Refreshing in 30 seconds..."
        sleep 30
    done
}

# Generate server report
generate_report() {
    REPORT_FILE="/tmp/vpn-server-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "VPN Server Infrastructure Report"
        echo "================================="
        echo "Generated: $(date)"
        echo ""
        
        echo "Server List:"
        echo "------------"
        list_servers
        echo ""
        
        echo "Server Status:"
        echo "--------------"
        check_status
        echo ""
        
        echo "Configuration:"
        echo "--------------"
        cat $SERVERS_CONFIG
        echo ""
        
        echo "Active Connections:"
        echo "------------------"
        for server in $(python3 -c "import json; c=json.load(open('$SERVERS_CONFIG')); print(' '.join([s['ip'] for s in c['servers']]))"); do
            echo "Server: $server"
            ssh root@$server "ss -tn state established '( sport = :8443 )' | wc -l" 2>/dev/null || echo "N/A"
        done
    } > $REPORT_FILE
    
    echo -e "${GREEN}Report generated: $REPORT_FILE${NC}"
}

# Main loop
while true; do
    show_menu
    read -p "Select option: " choice
    
    case $choice in
        1) list_servers ;;
        2) check_status ;;
        3) 
            read -p "Server name: " name
            read -p "Server IP: " ip
            read -p "VPN port (8443): " port
            port=${port:-8443}
            add_server --name "$name" --ip "$ip" --port "$port"
            ;;
        4) remove_server ;;
        5) restart_services ;;
        6) update_config ;;
        7) sync_servers ;;
        8) monitor_health ;;
        9) generate_report ;;
        0) 
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done