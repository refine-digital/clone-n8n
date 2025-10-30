#!/bin/bash

################################################################################
# Installation Script for clone-n8n
# Installs script to ~/.local/bin for system-wide CLI access
# Supports updates when new releases are available
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

VERSION="1.0.0"

echo -e "${GREEN}=== Installing clone-n8n v${VERSION} ===${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Target installation directory
INSTALL_DIR="${HOME}/.local/bin"

# Create installation directory if it doesn't exist
if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}Creating installation directory: ${INSTALL_DIR}${NC}"
    mkdir -p "$INSTALL_DIR"
fi

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
    echo -e "${YELLOW}Warning: ${INSTALL_DIR} is not in your PATH${NC}"
    echo ""
    echo "Add this line to your shell configuration file:"
    echo -e "${BLUE}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
    echo ""

    # Detect shell and suggest appropriate file
    if [ -n "$ZSH_VERSION" ]; then
        SHELL_CONFIG="~/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        SHELL_CONFIG="~/.bashrc"
    else
        SHELL_CONFIG="your shell configuration file"
    fi

    echo "For example, run:"
    echo -e "${BLUE}echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ${SHELL_CONFIG}${NC}"
    echo -e "${BLUE}source ${SHELL_CONFIG}${NC}"
    echo ""

    read -p "Continue with installation? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 1
    fi
fi

# Check if clone-infrastructure is installed
echo -e "${YELLOW}Checking dependencies...${NC}"
if ! command -v clone-infrastructure &> /dev/null; then
    echo -e "${YELLOW}⚠ clone-infrastructure not found${NC}"
    echo ""
    echo "clone-n8n requires clone-infrastructure to be installed first."
    echo "Please install clone-infrastructure before installing clone-n8n:"
    echo ""
    echo "  cd ~/ProjectFiles/clone-infrastructure"
    echo "  ./install.sh"
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 1
    fi
else
    echo -e "${GREEN}✓ clone-infrastructure is installed${NC}"
fi

# Check if already installed (for updates)
UPDATING=false
if [ -f "${INSTALL_DIR}/clone-n8n" ]; then
    UPDATING=true
    echo -e "${YELLOW}Existing installation found - updating...${NC}"
fi

# Install script
if [ "$UPDATING" = true ]; then
    echo -e "${YELLOW}Updating script...${NC}"
else
    echo -e "${YELLOW}Installing script...${NC}"
fi

# Copy and rename (remove .sh extension)
cp "${SCRIPT_DIR}/clone-n8n.sh" "${INSTALL_DIR}/clone-n8n"

# Make executable
chmod +x "${INSTALL_DIR}/clone-n8n"

if [ "$UPDATING" = true ]; then
    echo -e "${GREEN}✓ Updated clone-n8n${NC}"
else
    echo -e "${GREEN}✓ Installed clone-n8n${NC}"
fi
echo ""

# Verify installation
echo -e "${YELLOW}Verifying installation...${NC}"
if command -v clone-n8n &> /dev/null; then
    echo -e "${GREEN}✓ clone-n8n is available in PATH${NC}"
else
    echo -e "${YELLOW}⚠ clone-n8n not found in PATH${NC}"
    echo "  You may need to restart your terminal or run: source ${SHELL_CONFIG}"
fi

echo ""
if [ "$UPDATING" = true ]; then
    echo -e "${GREEN}=== Update Complete ===${NC}"
else
    echo -e "${GREEN}=== Installation Complete ===${NC}"
fi
echo ""
echo "Installed command:"
echo "  • clone-n8n - Clone n8n sites"
echo ""
echo "Usage examples:"
echo "  clone-n8n dev-fi-01 ai.refine.digital"
echo "  clone-n8n dev-fi-01 ai.refine.digital . --clean"
echo "  clone-n8n dev-fi-01 ai.refine.digital ~/sites"
echo ""
echo "For more information:"
echo "  cat ${SCRIPT_DIR}/README.md"
echo ""

# Check if PATH was modified
if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
    echo -e "${YELLOW}Remember to add ${INSTALL_DIR} to your PATH:${NC}"
    echo -e "${BLUE}echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ${SHELL_CONFIG}${NC}"
    echo -e "${BLUE}source ${SHELL_CONFIG}${NC}"
    echo ""
fi

# Update instructions
if [ "$UPDATING" = true ]; then
    echo -e "${BLUE}To check for future updates:${NC}"
    echo "  cd ${SCRIPT_DIR}"
    echo "  git pull"
    echo "  ./install.sh"
    echo ""
fi
