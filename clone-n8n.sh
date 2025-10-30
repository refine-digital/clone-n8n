#!/bin/bash

################################################################################
# n8n Site Cloner (Infrastructure-Aware)
# Clones a production n8n site to local development environment
#
# Usage: ./clone-n8n.sh <infrastructure> <domain> [folder] [--clean]
# Example: ./clone-n8n.sh dev-fi-01 ai.refine.digital
#          ./clone-n8n.sh dev-fi-01 ai.refine.digital .
#          ./clone-n8n.sh dev-fi-01 ai.refine.digital ~/sites --clean
#
# Naming Convention:
#   - Infrastructure name stays the same for production and local
#   - Local domain automatically prefixed: local-{domain}
#
# Options:
#   folder     Destination folder (default: ${HOME}/ProjectFiles/n8n/)
#   --clean    Remove existing site before cloning
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Parse arguments
################################################################################
if [ $# -lt 2 ] || [ $# -gt 4 ]; then
    echo -e "${RED}Usage: $0 <infrastructure> <domain> [folder] [--clean]${NC}"
    echo ""
    echo "Arguments:"
    echo "  infrastructure   Infrastructure name (e.g., dev-fi-01, refine-digital-app)"
    echo "  domain           Production n8n domain (e.g., ai.refine.digital)"
    echo "  folder           Destination folder (default: \${HOME}/ProjectFiles/n8n/)"
    echo "                   Use '.' for current directory"
    echo ""
    echo "Naming Convention:"
    echo "  Infrastructure: Same name for production and local (e.g., dev-fi-01)"
    echo "  Local domain: Automatically prefixed with 'local-' (e.g., local-ai.refine.digital)"
    echo ""
    echo "Options:"
    echo "  --clean          Remove existing site before cloning"
    echo ""
    echo "Examples:"
    echo "  $0 dev-fi-01 ai.refine.digital"
    echo "  $0 dev-fi-01 ai.refine.digital ."
    echo "  $0 dev-fi-01 ai.refine.digital ~/sites"
    echo "  $0 dev-fi-01 ai.refine.digital . --clean"
    echo ""
    exit 1
fi

INFRASTRUCTURE=$1
DOMAIN=$2
CLEAN_MODE=false
LOCAL_BASE_DIR="${HOME}/ProjectFiles/n8n"

# Parse optional folder and --clean arguments
if [ $# -ge 3 ]; then
    if [ "$3" == "--clean" ]; then
        CLEAN_MODE=true
    else
        # Third argument is folder
        if [ "$3" == "." ]; then
            LOCAL_BASE_DIR="$(pwd)"
        else
            LOCAL_BASE_DIR="$3"
        fi

        # Check for --clean as fourth argument
        if [ $# -eq 4 ] && [ "$4" == "--clean" ]; then
            CLEAN_MODE=true
        fi
    fi
fi

# Convert to absolute path and ensure directory exists
LOCAL_BASE_DIR=$(cd "$LOCAL_BASE_DIR" 2>/dev/null && pwd || (mkdir -p "$LOCAL_BASE_DIR" && cd "$LOCAL_BASE_DIR" && pwd))

# Automatically generate local domain using naming convention
LOCAL_DOMAIN="local-${DOMAIN}"

# Configuration from infrastructure
INFRA_DIR="${HOME}/.${INFRASTRUCTURE}"
PRODUCTION_USER="fly"

# Domain processing
DOMAIN_NODOTS="${DOMAIN//./}"
PROD_N8N_CONTAINER="${DOMAIN_NODOTS}-n8n-1"
PROD_NGINX_CONTAINER="${DOMAIN_NODOTS}-nginx-1"
LOCAL_CONTAINER_PREFIX="${LOCAL_DOMAIN//./-}"
SITE_DIR="${DOMAIN}"  # Production directory (with dots)
LOCAL_SITE_DIR="${LOCAL_DOMAIN//./-}"  # Local directory (with dashes)

# Setup logging
LOG_FILE="${LOCAL_BASE_DIR}/clone-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo -e "${GREEN}=== n8n Site Cloner ===${NC}"
echo "Infrastructure: ${INFRASTRUCTURE}"
echo "Production Site: https://${DOMAIN}"
echo "Local Site: https://${LOCAL_DOMAIN}"
echo "Destination: ${LOCAL_BASE_DIR}"
echo "Clean mode: ${CLEAN_MODE}"
echo "Log file: ${LOG_FILE}"
echo ""

################################################################################
# Infrastructure Verification
################################################################################
echo -e "${YELLOW}Verifying infrastructure...${NC}"

# Check if infrastructure directory exists
if [ ! -d "${INFRA_DIR}" ]; then
    echo -e "${RED}Error: Infrastructure '${INFRASTRUCTURE}' not found at ${INFRA_DIR}${NC}"
    echo ""
    echo "Please clone the infrastructure first:"
    echo "  cd ../infrastructure"
    echo "  ./clone-infrastructure.sh ${INFRASTRUCTURE} <server-ip>"
    echo ""
    exit 1
fi

# Read infrastructure configuration
if [ ! -f "${INFRA_DIR}/.env" ]; then
    echo -e "${RED}Error: Infrastructure .env file not found${NC}"
    exit 1
fi

# Source infrastructure environment
source "${INFRA_DIR}/.env"

echo "  ✓ Infrastructure directory found"
echo "  ✓ Configuration loaded from infrastructure"

# Check if infrastructure services are running
REQUIRED_CONTAINERS=("nginx-proxy")
MISSING_CONTAINERS=()

for container in "${REQUIRED_CONTAINERS[@]}"; do
    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        MISSING_CONTAINERS+=("$container")
    fi
done

if [ ${#MISSING_CONTAINERS[@]} -gt 0 ]; then
    echo -e "${RED}Error: Required infrastructure containers are not running:${NC}"
    for container in "${MISSING_CONTAINERS[@]}"; do
        echo -e "${RED}  - ${container}${NC}"
    done
    echo ""
    echo -e "${YELLOW}Please start the infrastructure:${NC}"
    echo "  cd ${INFRA_DIR}"
    echo "  docker-compose up -d"
    echo ""
    exit 1
fi

# Verify networks exist
REQUIRED_NETWORKS=("wordpress-sites")
MISSING_NETWORKS=()

for network in "${REQUIRED_NETWORKS[@]}"; do
    if ! docker network ls --format '{{.Name}}' | grep -q "^${network}$"; then
        MISSING_NETWORKS+=("$network")
    fi
done

if [ ${#MISSING_NETWORKS[@]} -gt 0 ]; then
    echo -e "${RED}Error: Required Docker networks do not exist:${NC}"
    for network in "${MISSING_NETWORKS[@]}"; do
        echo -e "${RED}  - ${network}${NC}"
    done
    echo ""
    echo "These should have been created by the infrastructure."
    echo "Try restarting the infrastructure:"
    echo "  cd ${INFRA_DIR}"
    echo "  docker-compose down && docker-compose up -d"
    exit 1
fi

echo -e "${GREEN}✓ Infrastructure verified${NC}"
echo "  - nginx-proxy: running"
echo "  - wordpress-sites network: exists"
echo ""

################################################################################
# Get SSH configuration from infrastructure
################################################################################
echo -e "${YELLOW}Getting SSH configuration...${NC}"

# Find SSH host from infrastructure SSH config
SSH_HOST=$(grep -A 3 "Host.*${INFRASTRUCTURE}" ~/.ssh/config 2>/dev/null | grep "HostName" | awk '{print $2}' | head -1)

if [ -z "$SSH_HOST" ]; then
    echo -e "${RED}Error: Could not find SSH host for infrastructure '${INFRASTRUCTURE}'${NC}"
    echo ""
    echo "Please check your ~/.ssh/config file."
    echo "It should contain an entry created by clone-infrastructure.sh"
    exit 1
fi

# Use the SSH config entry directly
SSH_CONFIG_HOST=$(grep "Host.*${INFRASTRUCTURE}" ~/.ssh/config | awk '{print $2}' | head -1)

echo "  ✓ SSH host: ${PRODUCTION_USER}@${SSH_HOST}"
echo "  ✓ SSH config: ${SSH_CONFIG_HOST}"
echo ""

################################################################################
# Step 0: Clean up existing installation if --clean flag is set
################################################################################
if [ "$CLEAN_MODE" == "true" ]; then
    echo -e "${BLUE}[0/9] Cleaning up existing installation...${NC}"

    # Stop and remove containers
    cd "${LOCAL_BASE_DIR}/${LOCAL_SITE_DIR}" 2>/dev/null || true
    docker-compose -f docker-compose.yml down 2>/dev/null || true
    docker stop ${LOCAL_CONTAINER_PREFIX}-n8n-1 2>/dev/null || true
    docker rm ${LOCAL_CONTAINER_PREFIX}-n8n-1 2>/dev/null || true
    docker stop ${LOCAL_CONTAINER_PREFIX}-nginx-1 2>/dev/null || true
    docker rm ${LOCAL_CONTAINER_PREFIX}-nginx-1 2>/dev/null || true
    echo "  Removed containers"

    # Remove network
    docker network rm ${LOCAL_DOMAIN} 2>/dev/null || true
    echo "  Removed network"

    # Remove site directory
    rm -rf "${LOCAL_BASE_DIR}/${LOCAL_SITE_DIR}" 2>/dev/null || true
    echo "  Removed site directory"

    # Remove temporary files
    rm -f "${LOCAL_BASE_DIR}/${LOCAL_SITE_DIR}-data.tar.gz" 2>/dev/null || true
    echo "  Removed temporary files"

    echo -e "${GREEN}  Cleanup complete${NC}"
    echo ""
fi

################################################################################
# Step 1: Download site files
################################################################################
echo -e "${YELLOW}[1/9] Downloading site files...${NC}"

# Use rsync to efficiently sync only changed files
rsync -avz --delete \
    ${PRODUCTION_USER}@${SSH_CONFIG_HOST}:~/${SITE_DIR}/ \
    "${LOCAL_BASE_DIR}/${LOCAL_SITE_DIR}/"

echo "  Synced site files"

################################################################################
# Step 2: Download n8n data directory
################################################################################
echo -e "${YELLOW}[2/9] Downloading n8n data (database and workflows)...${NC}"

# Create temporary archive on server and download
ssh ${PRODUCTION_USER}@${SSH_CONFIG_HOST} \
    "cd ~/${SITE_DIR} && tar czf /tmp/${DOMAIN_NODOTS}-data.tar.gz data/"

scp ${PRODUCTION_USER}@${SSH_CONFIG_HOST}:/tmp/${DOMAIN_NODOTS}-data.tar.gz \
    "${LOCAL_BASE_DIR}/${LOCAL_SITE_DIR}-data.tar.gz"

# Clean up remote temp file
ssh ${PRODUCTION_USER}@${SSH_CONFIG_HOST} "rm -f /tmp/${DOMAIN_NODOTS}-data.tar.gz"

DATA_SIZE=$(du -h "${LOCAL_BASE_DIR}/${LOCAL_SITE_DIR}-data.tar.gz" | cut -f1)
echo "  Downloaded n8n data: ${DATA_SIZE}"

################################################################################
# Step 3: Extract n8n data
################################################################################
echo -e "${YELLOW}[3/9] Extracting n8n data...${NC}"

cd "${LOCAL_BASE_DIR}/${LOCAL_SITE_DIR}"
tar xzf "${LOCAL_BASE_DIR}/${LOCAL_SITE_DIR}-data.tar.gz"

echo "  Extracted n8n data"

################################################################################
# Step 4: Update local configuration
################################################################################
echo -e "${YELLOW}[4/9] Updating local configuration...${NC}"

# Update .env file for local development
sed -i '' "s|N8N_HOST=${DOMAIN}|N8N_HOST=${LOCAL_DOMAIN}|g" \
    "${LOCAL_BASE_DIR}/${LOCAL_SITE_DIR}/.env"

sed -i '' "s|WEBHOOK_URL=https://${DOMAIN}/|WEBHOOK_URL=https://${LOCAL_DOMAIN}/|g" \
    "${LOCAL_BASE_DIR}/${LOCAL_SITE_DIR}/.env"

sed -i '' "s|WEBHOOK_URL=http://${DOMAIN}/|WEBHOOK_URL=https://${LOCAL_DOMAIN}/|g" \
    "${LOCAL_BASE_DIR}/${LOCAL_SITE_DIR}/.env"

echo "  Updated .env file for local domain"

################################################################################
# Step 5: Create local docker-compose.yml
################################################################################
echo -e "${YELLOW}[5/9] Creating local docker-compose.yml...${NC}"

cat > "${LOCAL_BASE_DIR}/${LOCAL_SITE_DIR}/docker-compose.yml" << COMPOSE_EOF
services:
  n8n:
    image: 'docker.n8n.io/n8nio/n8n:latest'
    restart: unless-stopped
    container_name: ${LOCAL_CONTAINER_PREFIX}-n8n-1
    env_file: ./.env
    environment:
      - N8N_HOST=${LOCAL_DOMAIN}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - 'WEBHOOK_URL=https://${LOCAL_DOMAIN}/'
      - GENERIC_TIMEZONE=UTC
      - N8N_BASIC_AUTH_ACTIVE=false
      - N8N_SECURE_COOKIE=false
      - N8N_METRICS=false
    volumes:
      - './data:/home/node/.n8n'
    user: '1000:1000'
    networks:
      - site-network
  nginx:
    image: 'nginxinc/nginx-unprivileged:alpine'
    restart: always
    container_name: ${LOCAL_CONTAINER_PREFIX}-nginx-1
    environment:
      - 'VIRTUAL_HOST=${LOCAL_DOMAIN}'
      - VIRTUAL_PORT=8080
      - CERT_NAME=
      - HTTPS_METHOD=nohttps
    user: '1000:1000'
    volumes:
      - './logs/nginx:/var/log/nginx'
      - './config/nginx/custom:/etc/nginx/custom'
      - './config/nginx/default.conf:/etc/nginx/conf.d/default.conf'
    depends_on:
      - n8n
    networks:
      - site-network
      - wordpress-sites
networks:
  site-network:
    name: ${LOCAL_DOMAIN}
    external: true
  wordpress-sites:
    name: wordpress-sites
    external: true
COMPOSE_EOF

echo "  Created docker-compose.yml"

################################################################################
# Step 6: Create site network
################################################################################
echo -e "${YELLOW}[6/9] Creating site network...${NC}"

docker network create ${LOCAL_DOMAIN} 2>/dev/null || echo "  Network already exists"

################################################################################
# Step 7: Start containers with docker-compose
################################################################################
echo -e "${YELLOW}[7/9] Starting containers with docker-compose...${NC}"

cd "${LOCAL_BASE_DIR}/${LOCAL_SITE_DIR}"
docker-compose down 2>/dev/null || true

# Force remove any existing containers with same name
docker stop ${LOCAL_CONTAINER_PREFIX}-n8n-1 2>/dev/null || true
docker rm ${LOCAL_CONTAINER_PREFIX}-n8n-1 2>/dev/null || true
docker stop ${LOCAL_CONTAINER_PREFIX}-nginx-1 2>/dev/null || true
docker rm ${LOCAL_CONTAINER_PREFIX}-nginx-1 2>/dev/null || true

docker-compose up -d

echo "  Containers started: ${LOCAL_CONTAINER_PREFIX}-n8n-1, ${LOCAL_CONTAINER_PREFIX}-nginx-1"

# Wait for container to be ready
sleep 5

################################################################################
# Step 8: Configure Cloudflared (if available in infrastructure)
################################################################################
echo -e "${YELLOW}[8/9] Configuring Cloudflared access...${NC}"

# Check if cloudflared is running in infrastructure
if docker ps --format '{{.Names}}' | grep -q "cloudflared"; then
    echo "  ✓ Cloudflared is running in infrastructure"
    echo "  Note: To add ${LOCAL_DOMAIN} to the tunnel, update:"
    echo "       ${INFRA_DIR}/config/cloudflared/config.yml"
    echo "  Then restart: docker restart cloudflared"
else
    echo "  ⚠️  Cloudflared not found in infrastructure"
    echo "  Site will be accessible via nginx-proxy on localhost"
    echo "  For HTTPS access, configure cloudflared in infrastructure"
fi

################################################################################
# Step 9: Cleanup temporary files
################################################################################
echo -e "${YELLOW}[9/9] Cleaning up temporary files...${NC}"

# Remove data archive
if [ -f "${LOCAL_BASE_DIR}/${LOCAL_SITE_DIR}-data.tar.gz" ]; then
    rm -f "${LOCAL_BASE_DIR}/${LOCAL_SITE_DIR}-data.tar.gz"
    echo "  Removed data archive"
fi

echo ""
echo -e "${GREEN}=== Clone Complete! ===${NC}"
echo ""
echo "Infrastructure: ${INFRASTRUCTURE}"
echo "Production: https://${DOMAIN}"
echo "Local: https://${LOCAL_DOMAIN}"
echo ""
echo "Site location: ${LOCAL_BASE_DIR}/${LOCAL_SITE_DIR}"
echo "Containers: ${LOCAL_CONTAINER_PREFIX}-n8n-1, ${LOCAL_CONTAINER_PREFIX}-nginx-1"
echo "Database: SQLite (in data/database.sqlite)"
echo ""
echo "Manage the site:"
echo "  cd ${LOCAL_BASE_DIR}/${LOCAL_SITE_DIR}"
echo "  docker-compose up -d      # Start"
echo "  docker-compose down       # Stop"
echo "  docker-compose logs -f    # View logs"
echo ""
echo "To re-clone this site:"
echo "  ./clone-n8n.sh ${INFRASTRUCTURE} ${DOMAIN} --clean"
echo ""
echo "Log file: ${LOG_FILE}"
echo ""
if docker ps --format '{{.Names}}' | grep -q "cloudflared"; then
    echo -e "${GREEN}Cloudflared is running - configure ${LOCAL_DOMAIN} in infrastructure for HTTPS access${NC}"
else
    echo -e "${YELLOW}Note: Cloudflared not running. Site accessible via http://localhost${NC}"
fi
echo ""
