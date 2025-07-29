#!/bin/bash

# Minikube Setup Script
# This script helps you set up Minikube for the GitOps lab

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

echo "⛵ Minikube Setup for GitOps Lab"
echo "==============================="
echo

# Check if Minikube is installed
if ! command -v minikube &> /dev/null; then
    log_error "Minikube is not installed"
    echo "Installing Minikube..."
    brew install minikube
fi

# Check if Docker is available (for driver)
if ! command -v docker &> /dev/null; then
    log_warning "Docker is not installed - Minikube will use alternative driver"
fi

log_success "Minikube is available"

# Check if cluster exists and is running
if minikube status &>/dev/null; then
    log_info "Minikube cluster is already running"
    current_profile=$(minikube profile)
    log_info "Current profile: $current_profile"
else
    log_info "Starting Minikube cluster..."
    
    # Determine driver
    DRIVER="docker"
    if ! command -v docker &> /dev/null || ! docker info &>/dev/null; then
        DRIVER="hyperkit"
        log_info "Using hyperkit driver (Docker not available)"
    fi
    
    # Start Minikube with GitOps-optimized settings
    minikube start \
        --driver=$DRIVER \
        --memory=4096 \
        --cpus=2 \
        --disk-size=20g \
        --kubernetes-version=v1.28.0 \
        --addons=ingress,dashboard,storage-provisioner
    
    log_success "Minikube cluster started!"
fi

# Enable useful addons
log_info "Enabling useful addons..."
minikube addons enable ingress
minikube addons enable dashboard
minikube addons enable metrics-server

# Set kubectl context
kubectl config use-context minikube

# Display cluster info
echo
echo "📊 Cluster Information:"
kubectl cluster-info
echo

echo "🔧 Nodes:"
kubectl get nodes
echo

echo "🎯 Enabled Addons:"
minikube addons list | grep enabled
echo

log_success "Minikube is ready for GitOps!"
echo
echo "Useful commands:"
echo "  minikube dashboard    # Open Kubernetes dashboard"
echo "  minikube ip          # Get cluster IP"
echo "  minikube stop        # Stop cluster"
echo "  minikube delete      # Delete cluster"
echo
echo "Next steps:"
echo "  cd ../../.."
echo "  ./scripts/lab-startup.sh tools"
