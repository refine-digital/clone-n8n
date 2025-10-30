# n8n Site Cloner

A script to clone production n8n sites to your local development environment with infrastructure awareness.

## Overview

This script automates the process of cloning a production n8n site (including workflows, database, and configuration) to a local development environment. It's designed to work seamlessly with your existing infrastructure setup.

## Installation

### Quick Install

Clone and install the script globally:

```bash
git clone https://github.com/refine-digital/clone-n8n.git
cd clone-n8n
./install.sh
```

This installs `clone-n8n` to `~/.local/bin` for global CLI access.

### Manual Installation

If you prefer not to install globally, you can use the script directly:

```bash
git clone https://github.com/refine-digital/clone-n8n.git
cd clone-n8n
./clone-n8n.sh <infrastructure> <domain>
```

### Requirements

After installation, ensure you have:
- Docker and Docker Compose installed and running
- Infrastructure already cloned and running (use `clone-infrastructure.sh` first)
- SSH access configured to the production server
- The infrastructure's nginx-proxy and required networks must be running

## Usage

If installed globally via `install.sh`:

```bash
clone-n8n <infrastructure> <domain> [folder] [--clean]
```

Or use the script directly:

```bash
./clone-n8n.sh <infrastructure> <domain> [folder] [--clean]
```

### Arguments

- `infrastructure` - Infrastructure name (e.g., `dev-fi-01`, `refine-digital-app`)
- `domain` - Production n8n domain (e.g., `ai.refine.digital`)
- `folder` - (Optional) Destination folder. Defaults to `${HOME}/ProjectFiles/n8n/`
  - Use `.` for current directory
- `--clean` - (Optional) Remove existing site before cloning

### Examples

```bash
# Using globally installed command
clone-n8n dev-fi-01 ai.refine.digital
clone-n8n dev-fi-01 ai.refine.digital ~/ProjectFiles/n8n/
clone-n8n dev-fi-01 ai.refine.digital --clean

# Or using the script directly
./clone-n8n.sh dev-fi-01 ai.refine.digital
./clone-n8n.sh dev-fi-01 ai.refine.digital .
./clone-n8n.sh dev-fi-01 ai.refine.digital ~/ProjectFiles/n8n/ --clean
```

## Naming Convention

The script follows a consistent naming pattern:

- **Infrastructure**: Same name for production and local (e.g., `dev-fi-01`)
- **Local domain**: Automatically prefixed with `local-` (e.g., `local-ai.refine.digital`)
- **Site directory**: Dashes replace dots (e.g., `local-ai-refine-digital`)

## What Gets Cloned

1. **Site Files**: All configuration files, nginx config, etc.
2. **n8n Data**: Complete n8n data directory including:
   - SQLite database with workflows and credentials
   - Binary data
   - Custom nodes
   - SSH keys and git repositories
3. **Environment Configuration**: Updated for local development
4. **Docker Compose**: Pre-configured for local infrastructure

## Directory Structure

After cloning, your local n8n site will have this structure:

```
local-ai-refine-digital/
├── app/                      # Application files (if any)
├── config/
│   └── nginx/               # Nginx configuration
├── data/                    # n8n data directory
│   ├── database.sqlite      # n8n SQLite database
│   ├── binaryData/          # Workflow binary data
│   ├── nodes/               # Custom nodes
│   ├── git/                 # Git repositories
│   └── ssh/                 # SSH keys
├── logs/
│   └── nginx/               # Nginx logs
├── .env                     # Environment variables (updated for local)
└── docker-compose.yml       # Docker Compose config (generated)
```

## How It Works

The script performs these steps:

1. **Infrastructure Verification** - Ensures infrastructure is set up and running
2. **SSH Configuration** - Retrieves SSH settings from infrastructure
3. **Clean Up** (optional) - Removes existing local installation if `--clean` is used
4. **Download Site Files** - Syncs all site configuration files
5. **Download n8n Data** - Downloads the complete n8n data directory with workflows
6. **Extract Data** - Extracts the n8n data archive
7. **Update Configuration** - Updates `.env` for local domain
8. **Create Docker Compose** - Generates local `docker-compose.yml`
9. **Create Network** - Sets up Docker network for the site
10. **Start Containers** - Launches n8n and nginx containers
11. **Configure Access** - Sets up Cloudflared tunnel (if available)
12. **Cleanup** - Removes temporary files

## Managing Your Local Site

```bash
# Navigate to site directory
cd ~/ProjectFiles/n8n/local-ai-refine-digital

# Start the site
docker-compose up -d

# Stop the site
docker-compose down

# View logs
docker-compose logs -f

# View n8n logs specifically
docker-compose logs -f n8n
```

## Accessing Your Local Site

Once cloned and running:

- **With Cloudflared**: `https://local-ai.refine.digital`
- **Without Cloudflared**: Configure hosts file or use nginx-proxy

To enable HTTPS access via Cloudflared:
1. Edit `~/.{infrastructure}/config/cloudflared/config.yml`
2. Add your local domain configuration
3. Restart: `docker restart cloudflared`

## Re-cloning a Site

To refresh a local site with the latest production data:

```bash
./clone-n8n.sh dev-fi-01 ai.refine.digital --clean
```

The `--clean` flag will:
- Stop and remove existing containers
- Remove the site directory
- Remove Docker networks
- Clean up any temporary files

## Differences from WordPress Clone

While similar to the WordPress cloner, the n8n version has key differences:

1. **No Database Server**: n8n uses SQLite embedded database
2. **Data Directory**: Clones the entire `data/` directory instead of MySQL dump
3. **Simpler Stack**: Just n8n + nginx (no separate DB or Redis)
4. **No URL Replacement**: n8n handles domain changes via environment variables

## Troubleshooting

### Docker Not Running

```
Error: Docker is not running
```

**Solution**: Start Docker Desktop before running the script.

The script checks if Docker is running at the start and will exit with a clear error message if Docker is not available.

### Infrastructure Not Running

```
Error: Required infrastructure containers are not running
```

**Solution**: Start your infrastructure first:
```bash
cd ~/.{infrastructure}
docker-compose up -d
```

### SSH Connection Failed

```
Error: Could not find SSH host for infrastructure
```

**Solution**: Ensure infrastructure was cloned properly with SSH config:
```bash
cd ~/ProjectFiles/infrastructure
./clone-infrastructure.sh {infrastructure} {server-ip}
```

### Network Already Exists

This is normal if you're re-cloning. The script handles this automatically.

### Container Name Conflict

The script automatically removes conflicting containers before starting new ones.

## Log Files

Each clone operation creates a log file:
- Location: `~/ProjectFiles/n8n/clone-YYYYMMDD-HHMMSS.log`
- Contains: Complete output of the clone operation
- Useful for: Debugging issues or reviewing what was done

## Testing

To test the script was created correctly (replace with your actual infrastructure):

```bash
cd ~/ProjectFiles/clone-n8n
./clone-n8n.sh dev-fi-01 ai.refine.digital ~/ProjectFiles/n8n/
```

## Security Notes

- n8n credentials and workflows are cloned to local environment
- Database contains encrypted credentials (using n8n's encryption key)
- Keep your local environment secure
- Don't commit the `data/` directory to version control

## Support

For issues or questions:
1. Check the log file in `~/ProjectFiles/n8n/`
2. Verify infrastructure is running: `docker ps`
3. Check network connectivity: `ssh {infrastructure}`
4. Review Docker logs: `docker-compose logs`