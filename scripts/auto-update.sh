#!/bin/bash

# Auto-update script for Multi-VPN Server
# Pulls latest changes from git and applies them

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
REPO_DIR="/opt/multi-vpn-server"
LOG_FILE="/var/log/vpn-auto-update.log"
BRANCH="master"  # Change this to your branch

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo -e "$1"
}

# Change to repository directory
cd "$REPO_DIR"

log_message "${YELLOW}Checking for updates...${NC}"

# Fetch latest changes without merging
git fetch origin "$BRANCH" --quiet

# Check if there are any changes
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/"$BRANCH")

if [ "$LOCAL" = "$REMOTE" ]; then
    log_message "${GREEN}Already up to date${NC}"
    exit 0
fi

log_message "${YELLOW}Updates available. Pulling changes...${NC}"

# Store current commit for rollback if needed
PREVIOUS_COMMIT=$LOCAL

# Pull the latest changes
if git pull origin "$BRANCH" --quiet; then
    log_message "${GREEN}✓ Git pull successful${NC}"
else
    log_message "${RED}✗ Git pull failed${NC}"
    exit 1
fi

# Check what files changed
CHANGED_FILES=$(git diff --name-only "$PREVIOUS_COMMIT" HEAD)

# Flags to determine what needs to be restarted
RESTART_SUBSCRIPTION=false
RESTART_NGINX=false
RESTART_XUI=false

# Check which services need restart based on changed files
for file in $CHANGED_FILES; do
    case $file in
        subscription/*.py)
            RESTART_SUBSCRIPTION=true
            ;;
        configs/nginx/*)
            RESTART_NGINX=true
            ;;
        configs/servers.json|configs/nodes.json)
            RESTART_SUBSCRIPTION=true
            ;;
        x-ui/*)
            RESTART_XUI=true
            ;;
    esac
done

log_message "${YELLOW}Applying updates...${NC}"

# Update Python dependencies if requirements.txt changed
if echo "$CHANGED_FILES" | grep -q "requirements.txt"; then
    log_message "Updating Python dependencies..."
    cd "$REPO_DIR/subscription"
    pip3 install -r requirements.txt --quiet
    cd "$REPO_DIR"
fi

# Update nginx configs if changed
if [ "$RESTART_NGINX" = true ]; then
    log_message "Updating Nginx configuration..."
    
    # Copy nginx configs to proper location
    for conf in configs/nginx/*.conf; do
        if [ -f "$conf" ]; then
            filename=$(basename "$conf")
            # Replace domain placeholder with actual domain from .env
            if [ -f ".env" ]; then
                source .env
                sed "s/DOMAIN_PLACEHOLDER/${MAIN_DOMAIN}/g" "$conf" > "/etc/nginx/sites-available/$filename"
            else
                cp "$conf" "/etc/nginx/sites-available/"
            fi
        fi
    done
    
    # Test nginx configuration
    if nginx -t 2>/dev/null; then
        systemctl reload nginx
        log_message "${GREEN}✓ Nginx reloaded${NC}"
    else
        log_message "${RED}✗ Nginx config test failed, not reloading${NC}"
    fi
fi

# Restart subscription service if needed
if [ "$RESTART_SUBSCRIPTION" = true ]; then
    log_message "Restarting subscription service..."
    
    # Check which service is running
    if systemctl is-active --quiet simple-sub; then
        systemctl restart simple-sub
        log_message "${GREEN}✓ simple-sub restarted${NC}"
    fi
    
    if systemctl is-active --quiet scalable-sub; then
        systemctl restart scalable-sub
        log_message "${GREEN}✓ scalable-sub restarted${NC}"
    fi
fi

# Restart X-UI if needed
if [ "$RESTART_XUI" = true ]; then
    log_message "Restarting X-UI..."
    if systemctl is-active --quiet x-ui; then
        systemctl restart x-ui
        log_message "${GREEN}✓ X-UI restarted${NC}"
    fi
fi

# Run any new scripts that were added
if echo "$CHANGED_FILES" | grep -q "scripts/.*\.sh"; then
    # Make sure all scripts are executable
    chmod +x scripts/*.sh
    log_message "${GREEN}✓ Script permissions updated${NC}"
fi

# Update systemd services if changed
if echo "$CHANGED_FILES" | grep -q "configs/systemd/.*\.service"; then
    log_message "Updating systemd services..."
    
    for service in configs/systemd/*.service; do
        if [ -f "$service" ]; then
            filename=$(basename "$service")
            cp "$service" "/etc/systemd/system/$filename"
        fi
    done
    
    systemctl daemon-reload
    log_message "${GREEN}✓ Systemd services updated${NC}"
fi

log_message "${GREEN}✓ Update completed successfully!${NC}"
log_message "Updated from $PREVIOUS_COMMIT to $(git rev-parse HEAD)"

# Optional: Send notification (uncomment and configure as needed)
# curl -X POST https://your-webhook-url.com/notify \
#   -H "Content-Type: application/json" \
#   -d "{\"text\":\"VPN server updated to $(git rev-parse HEAD)\"}"

exit 0