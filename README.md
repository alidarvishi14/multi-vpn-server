# Multi-Location VPN Server

A complete multi-server VPN solution with web management panel and subscription service.

## Features

- 🌍 Multi-server support (easily add new locations)
- 🔒 VLESS protocol with TCP
- 🎛️ Web-based management panel (X-UI)
- 📱 Subscription service for easy client setup
- 🔄 Automatic SSL certificates with Let's Encrypt
- 📊 Traffic monitoring and user management

## Architecture

```
┌─────────────────┐         ┌─────────────────┐
│  Client Device  │         │  Client Device  │
│  (iOS/Android)  │         │   (Windows/Mac) │
└────────┬────────┘         └────────┬────────┘
         │                            │
         └──────────┬─────────────────┘
                    │
        ┌───────────▼───────────┐
        │   Subscription URL    │
        │ sub.yourdomain.com    │
        └───────────┬───────────┘
                    │
     ┌──────────────┴──────────────┐
     │                              │
┌────▼─────┐              ┌────────▼────┐
│ Finland  │              │   Bahrain   │
│  Server  │              │   Server    │
│  :8443   │              │   :8443     │
└──────────┘              └─────────────┘
```

## Quick Start

### Prerequisites

- Ubuntu 22.04 servers
- Domain name with DNS management access
- Basic Linux knowledge

### Installation

1. Clone this repository:
```bash
git clone https://github.com/yourusername/multi-vpn-server.git
cd multi-vpn-server
```

2. Run the installation script:
```bash
sudo ./install.sh
```

3. Follow the prompts to:
   - Set your domain name
   - Configure server locations
   - Set admin credentials

## Project Structure

```
multi-vpn-server/
├── install.sh              # Main installation script
├── docker-compose.yml      # Docker setup (optional)
├── scripts/
│   ├── install-x-ui.sh    # X-UI installation
│   ├── setup-nginx.sh     # Nginx configuration
│   ├── setup-ssl.sh       # SSL certificate setup
│   └── add-server.sh      # Add new VPN server
├── configs/
│   ├── nginx/             # Nginx templates
│   ├── systemd/           # Service files
│   └── x-ui/              # X-UI configurations
├── subscription/
│   ├── simple-sub.py      # Subscription service
│   ├── requirements.txt   # Python dependencies
│   └── templates/         # Response templates
└── docs/
    ├── SETUP.md           # Detailed setup guide
    ├── CLIENT.md          # Client configuration
    └── TROUBLESHOOTING.md # Common issues
```

## Configuration

### Environment Variables

Create a `.env` file:

```env
# Domain Configuration
MAIN_DOMAIN=yourdomain.com
PANEL_SUBDOMAIN=panel
SUB_SUBDOMAIN=sub

# Server Locations
SERVERS=finland:IP1,bahrain:IP2

# Ports
VPN_PORT=8443
PANEL_PORT=54321
SUB_PORT=5556

# Admin Credentials
ADMIN_USER=admin
ADMIN_PASS=secure_password
```

### Adding New Servers

```bash
./scripts/add-server.sh --name "Germany" --ip "1.2.3.4" --port 8443
```

## Client Setup

### iOS (Shadowrocket)

1. Install Shadowrocket from App Store
2. Add subscription URL: `https://sub.yourdomain.com/sub/username`
3. Update and connect

### Android (v2rayNG)

1. Install v2rayNG from Google Play
2. Add subscription URL
3. Update and connect

### Windows (v2rayN)

1. Download v2rayN
2. Add subscription URL
3. Update and connect

## Management

### Web Panel Access

- Finland: `https://panel.yourdomain.com/finland/`
- Bahrain: `https://panel.yourdomain.com/bahrain/`

### Command Line

```bash
# Check service status
systemctl status x-ui
systemctl status simple-sub

# View logs
journalctl -u x-ui -f
journalctl -u simple-sub -f

# Restart services
systemctl restart x-ui
systemctl restart simple-sub
```

## Security

- All traffic encrypted with VLESS protocol
- SSL/TLS certificates auto-renewed
- Web panel protected with authentication
- Regular security updates recommended

## Backup

```bash
# Backup configuration and database
./scripts/backup.sh

# Restore from backup
./scripts/restore.sh backup-2024-01-01.tar.gz
```

## Contributing

Pull requests are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

## License

MIT License - see [LICENSE](LICENSE) file

## Support

- Issues: [GitHub Issues](https://github.com/yourusername/multi-vpn-server/issues)
- Documentation: [Wiki](https://github.com/yourusername/multi-vpn-server/wiki)

## Credits

- [X-UI](https://github.com/alireza0/x-ui) - Web management panel
- [Xray-core](https://github.com/XTLS/Xray-core) - VPN protocol implementation