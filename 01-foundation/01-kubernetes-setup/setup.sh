#!/bin/bash

# Kubernetes Setup Overview
# Quick selection of setup method

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

clear
echo -e "${CYAN}"
cat << 'EOF'
   ______ _ _    ____            _               _     
  / _____(_) |  / __ \          | |             | |    
 | |  __ _| |_| |  | |_ __  ___ | |     __ _  __| |__  
 | | |_ | | __| |  | | '_ \/ __|| |    / _` |/ _` |  _ \ 
 | |__| | | |_| |__| | |_) \__ \| |___| (_| | (_| | |_) |
  \_____| |\__|\____/| .__/|___/|______\__,_|\__,_|____/
       _/ |          | |                               
      |__/           |_|                               

EOF
echo -e "${NC}"
echo -e "${CYAN}GitOps Lab - Kubernetes Setup${NC}"
echo

echo "Choose your Kubernetes setup method:"
echo
echo -e "${GREEN}1)${NC} Docker Desktop    (Recommended for beginners)"
echo -e "${YELLOW}2)${NC} Minikube         (Lightweight, single-node)"
echo -e "${BLUE}3)${NC} Kind             (Multi-node, advanced)"
echo
echo -e "${CYAN}4)${NC} Skip setup       (Use existing cluster)"
echo -e "${RED}5)${NC} Exit"
echo

read -p "Enter your choice (1-5): " choice

case $choice in
    1)
        echo -e "${GREEN}Setting up Docker Desktop...${NC}"
        ./docker-desktop-setup.sh
        ;;
    2)
        echo -e "${YELLOW}Setting up Minikube...${NC}"
        ./minikube-setup.sh
        ;;
    3)
        echo -e "${BLUE}Setting up Kind...${NC}"
        ./kind-setup.sh
        ;;
    4)
        echo -e "${CYAN}Using existing cluster...${NC}"
        if kubectl cluster-info &>/dev/null; then
            echo -e "${GREEN}✓ Kubernetes cluster is accessible${NC}"
            kubectl cluster-info
            echo
            echo "Next steps:"
            echo "  cd ../../.."
            echo "  ./scripts/lab-startup.sh tools"
        else
            echo -e "${RED}✗ No accessible Kubernetes cluster found${NC}"
            echo "Please set up Kubernetes first"
        fi
        ;;
    5)
        echo "Goodbye!"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid choice. Please run the script again.${NC}"
        exit 1
        ;;
esac
