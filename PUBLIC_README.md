# linux-desktop-seed

Production-ready automation for deploying a complete Linux desktop environment on Ubuntu servers with RDP access, AI tools (OpenCLAW), automatic crash detection, and continuous monitoring.

## What This Project Does

The deployment script (`deploy-desktop.sh`) installs and configures:

- **Desktop Environment:** GNOME Desktop (touch-friendly, tablet-optimized)
- **RDP Server:** xrdp with Xvnc for Windows/Android Remote Desktop access
- **Development Tools:** VS Code, Claude Code, OpenRouter CLI, Chromium
- **Infrastructure:** Terraform, Terragrunt for Infrastructure-as-Code
- **Reliability:** Automatic crash detection (30 sec response), memory management
- **Security:** GNOME Keyring for secure credential storage
- **Extensions:** Cascade Windows tool for window management
- **Monitoring:** Continuous health checks with threshold-based alerting

## Quick Start

```bash
# Clone this repository
git clone https://github.com/DarojaAI/linux-desktop-seed-public.git
cd linux-desktop-seed-public

# Run the deployment script
sudo bash deploy-desktop.sh
```

## Requirements

- Ubuntu 20.04, 22.04, or 24.04
- Root access (sudo)
- Internet connection for package downloads
- At least 4GB RAM (8GB recommended)

## Post-Deployment

After deployment, you can connect via:

- **RDP:** `SERVER_IP:3389` (use any RDP client)
- **SSH:** `root@SERVER_IP`

### Default Credentials

- **Username:** `desktopuser` (created automatically)
- **Password:** Set via `DESKTOP_PASSWORD` environment variable during deployment

## Optional: OpenCLAW AI Agent

To enable the OpenCLAW AI agent with Discord integration:

1. Create a Discord bot and get its token
2. Create a Discord channel for the agent
3. Get your OpenRouter API key
4. Configure these environment variables when deploying:
   - `DISCORD_BOT_TOKEN`
   - `OPENROUTER_API_KEY`
   - `OPENCLAW_DISCORD_CHANNEL_ID`
   - `OPENCLAW_DISCORD_GUILD_ID`
   - `OPENCLAW_DISCORD_ALLOWED_USER` (your Discord user ID)

## Project Structure

```
.
├── deploy-desktop.sh      # Main deployment script
├── scripts/
│   ├── deploy/            # Deployment modules
│   ├── install/           # Installation scripts
│   └── maintenance/       # Maintenance scripts
├── config/                # Configuration files
├── etc/xrdp/              # xrdp configuration
└── tests/                 # Validation scripts
```

## GitHub Actions Workflow

This repo includes GitHub Actions workflow templates in `.github/workflows/`.

To use:

1. Copy `.github/workflows/deploy.yml.sample` to `.github/workflows/deploy.yml`
2. Configure the required secrets and variables (see the template comments)
3. Adjust the `environment:` name to match your GitHub environment

## Documentation

| Document | Description |
|----------|-------------|
| [QUICK-DEPLOY.md](docs/QUICK-DEPLOY.md) | 5-minute deployment walkthrough |
| [usage-guide.md](docs/usage-guide.md) | Using installed tools |
| [crash-recovery-guide.md](docs/crash-recovery-guide.md) | Understanding crash detection |
| [keyring-guide.md](docs/keyring-guide.md) | Credential storage setup |

## Support

- Open an issue for bugs or feature requests
- Check `docs/TROUBLESHOOTING.md` for common issues

## License

MIT License - see LICENSE file for details