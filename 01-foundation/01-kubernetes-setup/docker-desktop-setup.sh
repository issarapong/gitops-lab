#!/bin/bash

# Docker Desktop Kubernetes Setup Script
# This script helps you set up Docker Desktop with Kubernetes

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "🐳 Docker Desktop Kubernetes Setup"
echo "=================================="
echo

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed"
    echo "Please install Docker Desktop:"
    echo "  brew install --cask docker"
    echo "  Or download from: https://www.docker.com/products/docker-desktop"
    exit 1
fi

# Check if Docker is running
if ! docker info &>/dev/null; then
    log_error "Docker Desktop is not running"
    echo "Please start Docker Desktop from Applications"
    exit 1
fi

log_success "Docker Desktop is running"

# Check if Kubernetes is enabled
if ! kubectl cluster-info &>/dev/null; then
    log_warning "Kubernetes is not enabled in Docker Desktop"
    echo
    echo "To enable Kubernetes:"
    echo "1. Open Docker Desktop"
    echo "2. Go to Settings → Kubernetes"
    echo "3. Check 'Enable Kubernetes'"
    echo "4. Click 'Apply & Restart'"
    echo
    echo "This may take a few minutes..."
    exit 1
fi

# Check if context is docker-desktop
current_context=$(kubectl config current-context)
if [ "$current_context" != "docker-desktop" ]; then
    log_info "Switching to docker-desktop context"
    kubectl config use-context docker-desktop
fi

log_success "Kubernetes is enabled and ready!"

# Display cluster info
echo
echo "📊 Cluster Information:"
kubectl cluster-info
echo

echo "🔧 Nodes:"
kubectl get nodes
echo

echo "✅ Docker Desktop Kubernetes is ready for GitOps!"
echo
echo "Next steps:"
echo "  cd ../../.."
echo "  ./scripts/lab-startup.sh tools"
