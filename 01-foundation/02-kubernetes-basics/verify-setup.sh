#!/bin/bash

# Kubernetes Basics - Setup Verification Script
# Verifies that Kubernetes is ready for the basics lab

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

echo -e "${CYAN}Kubernetes Basics - Setup Verification${NC}"
echo "======================================"
echo

# Check kubectl is available
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed or not in PATH"
    echo "Please install kubectl:"
    echo "  brew install kubectl"
    exit 1
fi

log_success "kubectl is available"

# Check cluster connectivity
log_info "Checking cluster connectivity..."
if ! kubectl cluster-info &>/dev/null; then
    log_error "Cannot connect to Kubernetes cluster"
    echo "Please ensure your cluster is running:"
    echo "  - Docker Desktop: Enable Kubernetes in settings"
    echo "  - Minikube: minikube start"
    echo "  - Kind: kind create cluster --name gitops-lab"
    exit 1
fi

log_success "Cluster is accessible"

# Get cluster info
log_info "Cluster Information:"
kubectl cluster-info

echo

# Check nodes
log_info "Checking nodes..."
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
echo "Nodes: $NODE_COUNT"
kubectl get nodes

echo

# Check current context
CURRENT_CONTEXT=$(kubectl config current-context)
log_info "Current context: $CURRENT_CONTEXT"

# Determine cluster type
if [[ "$CURRENT_CONTEXT" == *"docker-desktop"* ]]; then
    CLUSTER_TYPE="Docker Desktop"
elif [[ "$CURRENT_CONTEXT" == *"minikube"* ]]; then
    CLUSTER_TYPE="Minikube"
elif [[ "$CURRENT_CONTEXT" == *"kind"* ]]; then
    CLUSTER_TYPE="Kind"
else
    CLUSTER_TYPE="Custom/External"
fi

log_info "Cluster type: $CLUSTER_TYPE"

echo

# Check system pods
log_info "Checking system pods..."
SYSTEM_PODS_READY=$(kubectl get pods -n kube-system --no-headers | grep -c "Running\|Completed" || echo "0")
TOTAL_SYSTEM_PODS=$(kubectl get pods -n kube-system --no-headers | wc -l)

if [ "$SYSTEM_PODS_READY" -eq "$TOTAL_SYSTEM_PODS" ]; then
    log_success "All system pods are ready ($SYSTEM_PODS_READY/$TOTAL_SYSTEM_PODS)"
else
    log_warning "Some system pods are not ready ($SYSTEM_PODS_READY/$TOTAL_SYSTEM_PODS)"
    kubectl get pods -n kube-system
fi

echo

# Check storage classes
log_info "Available storage classes:"
kubectl get storageclass

echo

# Test basic operations
log_info "Testing basic operations..."

# Create a test namespace
TEST_NS="kubernetes-basics-test"
if kubectl get namespace "$TEST_NS" &>/dev/null; then
    log_info "Test namespace already exists"
else
    kubectl create namespace "$TEST_NS"
    log_success "Created test namespace: $TEST_NS"
fi

# Test pod creation
log_info "Testing pod creation..."
kubectl run test-pod --image=nginx:alpine --restart=Never -n "$TEST_NS" &>/dev/null || true

# Wait a moment
sleep 3

# Check pod status
POD_STATUS=$(kubectl get pod test-pod -n "$TEST_NS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")

if [ "$POD_STATUS" = "Running" ]; then
    log_success "Test pod is running"
elif [ "$POD_STATUS" = "Pending" ]; then
    log_warning "Test pod is pending (may need more time)"
else
    log_warning "Test pod status: $POD_STATUS"
fi

# Clean up test resources
kubectl delete namespace "$TEST_NS" &>/dev/null || true

echo

# Summary
log_success "Setup verification complete!"
echo
echo -e "${CYAN}Your Kubernetes cluster is ready for the basics lab!${NC}"
echo
echo "Next steps:"
echo "1. Read through the concepts in README.md"
echo "2. Try the hands-on examples"
echo "3. Work through the exercises"
echo "4. Run './run-examples.sh' to try automated examples"
