#!/bin/bash

# Kind Setup Script
# This script helps you set up Kind (Kubernetes in Docker) for the GitOps lab

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

CLUSTER_NAME="gitops-lab"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Kind Setup for GitOps Lab"
echo "============================"
echo

# Check if Kind is installed
if ! command -v kind &> /dev/null; then
    log_error "Kind is not installed"
    echo "Installing Kind..."
    brew install kind
fi

# Check if Docker is available
if ! command -v docker &> /dev/null || ! docker info &>/dev/null; then
    log_error "Docker is required for Kind but is not running"
    echo "Please install and start Docker Desktop"
    exit 1
fi

log_success "Kind and Docker are available"

# Check if cluster already exists
if kind get clusters | grep -q "^$CLUSTER_NAME$"; then
    log_info "Kind cluster '$CLUSTER_NAME' already exists"
    read -p "Delete and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Deleting existing cluster..."
        kind delete cluster --name $CLUSTER_NAME
    else
        log_info "Using existing cluster"
        kubectl config use-context kind-$CLUSTER_NAME
        
        # Display cluster info
        echo
        echo "📊 Cluster Information:"
        kubectl cluster-info
        echo
        
        echo "🔧 Nodes:"
        kubectl get nodes
        echo
        
        log_success "Kind cluster is ready!"
        echo "Next steps:"
        echo "  cd ../../.."
        echo "  ./scripts/lab-startup.sh tools"
        exit 0
    fi
fi

# Create cluster with custom configuration
log_info "Creating Kind cluster with multi-node configuration..."

if [ -f "$SCRIPT_DIR/kind-config.yaml" ]; then
    kind create cluster --name $CLUSTER_NAME --config "$SCRIPT_DIR/kind-config.yaml"
else
    log_warning "kind-config.yaml not found, creating basic cluster"
    kind create cluster --name $CLUSTER_NAME
fi

log_success "Kind cluster created!"

# Set kubectl context
kubectl config use-context kind-$CLUSTER_NAME

# Wait for nodes to be ready
log_info "Waiting for nodes to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Install ingress controller for Kind
log_info "Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress controller
log_info "Waiting for ingress controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

# Display cluster info
echo
echo "📊 Cluster Information:"
kubectl cluster-info
echo

echo "🔧 Nodes:"
kubectl get nodes
echo

echo "🌐 Port Forwarding (from kind-config.yaml):"
echo "  HTTP:  localhost:80  → cluster:80"
echo "  HTTPS: localhost:443 → cluster:443"
echo "  K8s API: localhost:6443 → cluster:6443"
echo "  ArgoCD: localhost:9080 → cluster:8080"
echo "  Grafana: localhost:3000 → cluster:3000"
echo

log_success "Kind multi-node cluster is ready for GitOps!"
echo
echo "Useful commands:"
echo "  kind get clusters                    # List clusters"
echo "  kind delete cluster --name $CLUSTER_NAME  # Delete cluster"
echo "  kubectl get nodes                   # Check nodes"
echo "  docker ps | grep kind               # See Kind containers"
echo
echo "Next steps:"
echo "  cd ../../.."
echo "  ./scripts/lab-startup.sh tools"
