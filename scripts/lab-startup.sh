#!/bin/bash

# GitOps Lab Startup Script
# This script helps you set up and manage the GitOps lab environment

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KUBE_CONTEXT="gitops-lab"
USE_LIMA=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
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

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Banner
show_banner() {
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
    echo -e "${CYAN}GitOps Lab - Comprehensive Learning Environment${NC}"
    echo -e "${CYAN}Docker Desktop • Minikube • Kind • ArgoCD • Flux • Tekton • Helm${NC}"
    echo
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    local missing=()
    
    # Check for required tools
    if ! command -v kubectl &> /dev/null; then
        missing+=("kubectl")
    fi
    
    if ! command -v git &> /dev/null; then
        missing+=("git")
    fi
    
    if ! command -v curl &> /dev/null; then
        missing+=("curl")
    fi
    
    # Check for Kubernetes cluster options
    local kube_available=false
    
    if command -v docker &> /dev/null && docker info &>/dev/null; then
        if docker system info | grep -q "Kubernetes"; then
            log_info "Docker Desktop with Kubernetes detected"
            kube_available=true
        fi
    fi
    
    if command -v minikube &> /dev/null; then
        log_info "Minikube detected"
        kube_available=true
    fi
    
    if command -v kind &> /dev/null; then
        log_info "Kind detected"
        kube_available=true
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing[*]}"
        echo
        echo "Please install the missing tools:"
        for tool in "${missing[@]}"; do
            case $tool in
                kubectl)
                    echo "  kubectl: brew install kubectl"
                    ;;
                git)
                    echo "  Git: brew install git"
                    ;;
                curl)
                    echo "  curl: should be pre-installed on macOS"
                    ;;
            esac
        done
        exit 1
    fi
    
    if [ "$kube_available" = false ]; then
        log_warning "No Kubernetes cluster detected!"
        echo "Please install one of:"
        echo "  - Docker Desktop (with Kubernetes enabled): https://www.docker.com/products/docker-desktop"
        echo "  - Minikube: brew install minikube"
        echo "  - Kind: brew install kind"
        echo
        echo "Or use an existing cluster by setting KUBECONFIG"
        return 1
    fi
    
    log_success "All prerequisites met!"
}

# Kubernetes cluster management
start_kubernetes() {
    log_step "Setting up Kubernetes cluster..."
    
    # Check if cluster is already accessible
    if kubectl cluster-info &>/dev/null; then
        log_success "Kubernetes cluster is already accessible"
        setup_kubeconfig
        return 0
    fi
    
    # Try to start different types of clusters
    if command -v docker &> /dev/null && docker info &>/dev/null; then
        if docker system info | grep -q "Kubernetes"; then
            log_info "Using Docker Desktop Kubernetes"
            setup_kubeconfig
            return 0
        else
            log_warning "Docker Desktop detected but Kubernetes is not enabled"
            log_info "Please enable Kubernetes in Docker Desktop settings"
            return 1
        fi
    fi
    
    if command -v minikube &> /dev/null; then
        log_info "Starting Minikube cluster..."
        minikube start --driver=docker --memory=4096 --cpus=2
        setup_kubeconfig
        return 0
    fi
    
    if command -v kind &> /dev/null; then
        log_info "Creating Kind cluster..."
        kind create cluster --name gitops-lab --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF
        setup_kubeconfig
        return 0
    fi
    
    log_error "No Kubernetes cluster available. Please install Docker Desktop, Minikube, or Kind."
    return 1
}

stop_kubernetes() {
    log_step "Stopping Kubernetes cluster..."
    
    if command -v minikube &> /dev/null && minikube status &>/dev/null; then
        minikube stop
        log_success "Minikube cluster stopped"
        return 0
    fi
    
    if command -v kind &> /dev/null && kind get clusters | grep -q "gitops-lab"; then
        kind delete cluster --name gitops-lab
        log_success "Kind cluster deleted"
        return 0
    fi
    
    log_info "Using Docker Desktop or external cluster - no action needed"
}

# Kubernetes setup
setup_kubernetes() {
    log_step "Verifying Kubernetes setup..."
    
    # Check if cluster is accessible
    if ! kubectl cluster-info &>/dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Please start your cluster first."
        return 1
    fi
    
    log_success "Kubernetes cluster is accessible"
    setup_kubeconfig
    return 0
}

# Setup kubeconfig
setup_kubeconfig() {
    log_step "Setting up kubeconfig..."
    
    # Create kubeconfig directory
    mkdir -p ~/.kube
    
    # Check if we're using Kind
    if command -v kind &> /dev/null && kind get clusters | grep -q "gitops-lab"; then
        log_info "Using Kind cluster kubeconfig"
        kind get kubeconfig --name gitops-lab > ~/.kube/config-gitops-lab
    # Check if we're using Minikube
    elif command -v minikube &> /dev/null && minikube status &>/dev/null; then
        log_info "Using Minikube kubeconfig"
        minikube kubectl -- config view --raw > ~/.kube/config-gitops-lab
    # Check if we're using Docker Desktop
    elif kubectl config current-context | grep -q "docker-desktop"; then
        log_info "Using Docker Desktop kubeconfig"
        kubectl config view --raw > ~/.kube/config-gitops-lab
    # Use existing kubeconfig
    else
        log_info "Using existing kubeconfig"
        if [ -f ~/.kube/config ]; then
            cp ~/.kube/config ~/.kube/config-gitops-lab
        else
            log_error "No kubeconfig found"
            return 1
        fi
    fi
    
    # Set permissions
    chmod 600 ~/.kube/config-gitops-lab
    
    # Update KUBECONFIG environment variable
    export KUBECONFIG="$HOME/.kube/config-gitops-lab"
    
    log_success "Kubeconfig setup complete!"
    log_info "To use this config in new shells, run: export KUBECONFIG=$HOME/.kube/config-gitops-lab"
}

# Install GitOps tools
install_argocd() {
    log_step "Installing ArgoCD..."
    
    export KUBECONFIG="$HOME/.kube/config-gitops-lab"
    
    # Create argocd namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Install ArgoCD
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    log_info "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
    
    # Get ArgoCD admin password
    local argocd_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    log_success "ArgoCD installed successfully!"
    log_info "ArgoCD admin password: $argocd_password"
    log_info "Access ArgoCD UI: kubectl port-forward svc/argocd-server -n argocd 8080:443"
}

install_flux() {
    log_step "Installing Flux..."
    
    export KUBECONFIG="$HOME/.kube/config-gitops-lab"
    
    # Install Flux CLI if not present
    if ! command -v flux &> /dev/null; then
        log_info "Installing Flux CLI..."
        curl -s https://fluxcd.io/install.sh | sudo bash
    fi
    
    # Check if Flux is already installed
    if kubectl get namespace flux-system &>/dev/null; then
        log_success "Flux is already installed"
        return 0
    fi
    
    # Install Flux
    flux install
    
    log_success "Flux installed successfully!"
}

# Lab navigation
show_lab_structure() {
    echo -e "${CYAN}GitOps Lab Structure:${NC}"
    echo
    echo "📚 01-foundation/"
    echo "   ├── 01-kubernetes-setup/  - Native Kubernetes setup (Docker/Minikube/Kind)"
    echo "   ├── 02-kubernetes-basics/ - Kubernetes fundamentals"
    echo "   └── 03-gitops-intro/      - GitOps principles"
    echo
    echo "🔧 02-core-tools/"
    echo "   ├── 04-argocd/            - ArgoCD GitOps CD"
    echo "   ├── 05-flux/              - Flux GitOps toolkit"
    echo "   ├── 06-kustomize/         - Configuration management"
    echo "   └── 07-helm/              - Package management"
    echo
    echo "🚀 03-advanced/"
    echo "   ├── 08-external-secrets/  - Secret management"
    echo "   ├── 09-keptn/             - Application lifecycle"
    echo "   ├── 10-jenkins-x/         - Cloud-native CI/CD"
    echo "   └── 11-overlays/          - Advanced patterns"
    echo
    echo "🌍 04-scenarios/"
    echo "   └── 12-multi-env/         - Multi-environment deployment"
    echo
}

# Quick navigation functions
go_to_part() {
    local part=$1
    case $part in
        1) cd "$LAB_ROOT/01-foundation/01-kubernetes-setup" ;;
        2) cd "$LAB_ROOT/01-foundation/02-kubernetes-basics" ;;
        3) cd "$LAB_ROOT/01-foundation/03-gitops-intro" ;;
        4) cd "$LAB_ROOT/02-core-tools/04-argocd" ;;
        5) cd "$LAB_ROOT/02-core-tools/05-flux" ;;
        6) cd "$LAB_ROOT/02-core-tools/06-kustomize" ;;
        7) cd "$LAB_ROOT/02-core-tools/07-helm" ;;
        8) cd "$LAB_ROOT/03-advanced/08-external-secrets" ;;
        9) cd "$LAB_ROOT/03-advanced/09-keptn" ;;
        10) cd "$LAB_ROOT/03-advanced/10-jenkins-x" ;;
        11) cd "$LAB_ROOT/03-advanced/11-overlays" ;;
        12) cd "$LAB_ROOT/04-scenarios/12-multi-env" ;;
        *) 
            log_error "Invalid part number. Use 1-12"
            return 1
            ;;
    esac
    log_success "Navigated to Part $part"
    pwd
}

# Status check
check_status() {
    log_step "Checking lab status..."
    
    echo -e "${CYAN}Kubernetes Status:${NC}"
    export KUBECONFIG="$HOME/.kube/config-gitops-lab"
    
    if kubectl cluster-info &>/dev/null; then
        echo -e "  ${GREEN}✓ Kubernetes cluster is accessible${NC}"
        
        # Check nodes
        local node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
        echo -e "  ${GREEN}✓ Nodes: $node_count${NC}"
        
        # Check cluster type
        if kubectl config current-context | grep -q "docker-desktop"; then
            echo -e "  ${GREEN}✓ Using Docker Desktop${NC}"
        elif kubectl config current-context | grep -q "minikube"; then
            echo -e "  ${GREEN}✓ Using Minikube${NC}"
        elif kubectl config current-context | grep -q "kind"; then
            echo -e "  ${GREEN}✓ Using Kind${NC}"
        else
            echo -e "  ${GREEN}✓ Using custom cluster${NC}"
        fi
        
        # Check ArgoCD
        if kubectl get namespace argocd &>/dev/null; then
            if kubectl get deployment argocd-server -n argocd &>/dev/null; then
                echo -e "  ${GREEN}✓ ArgoCD is installed${NC}"
            else
                echo -e "  ${YELLOW}⚠ ArgoCD namespace exists but deployment not found${NC}"
            fi
        else
            echo -e "  ${YELLOW}⚠ ArgoCD is not installed${NC}"
        fi
        
        # Check Flux
        if kubectl get namespace flux-system &>/dev/null; then
            echo -e "  ${GREEN}✓ Flux is installed${NC}"
        else
            echo -e "  ${YELLOW}⚠ Flux is not installed${NC}"
        fi
        
    else
        echo -e "  ${RED}✗ Cannot connect to Kubernetes cluster${NC}"
        echo
        echo "To fix this, try:"
        echo "  - Enable Kubernetes in Docker Desktop"
        echo "  - Start Minikube: minikube start"
        echo "  - Create Kind cluster: kind create cluster --name gitops-lab"
    fi
}

# Cleanup function
cleanup_lab() {
    log_step "Cleaning up lab environment..."
    
    read -p "This will clean up resources and optionally stop the cluster. Continue? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Remove kubeconfig
        if [ -f ~/.kube/config-gitops-lab ]; then
            rm ~/.kube/config-gitops-lab
            log_success "Removed kubeconfig"
        fi
        
        # Ask about cluster cleanup
        read -p "Do you want to stop/delete the Kubernetes cluster? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            stop_kubernetes
        fi
        
        log_success "Lab cleanup complete!"
    else
        log_info "Cleanup cancelled"
    fi
}

# Quick setup function
quick_setup() {
    log_step "Running quick setup..."
    
    if ! check_prerequisites; then
        return 1
    fi
    
    start_kubernetes
    setup_kubernetes
    
    log_success "Quick setup complete!"
    log_info "Run './lab-startup.sh tools' to install GitOps tools"
}

# Install tools
install_tools() {
    log_step "Installing GitOps tools..."
    
    export KUBECONFIG="$HOME/.kube/config-gitops-lab"
    
    # Check if cluster is accessible
    if ! kubectl cluster-info &>/dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Run setup first."
        exit 1
    fi
    
    install_argocd
    install_flux
    
    log_success "All GitOps tools installed!"
}

# Help function
show_help() {
    echo "GitOps Lab Startup Script"
    echo
    echo "Usage: $0 [command]"
    echo
    echo "Commands:"
    echo "  setup        - Run quick setup (Kubernetes + GitOps tools)"
    echo "  tools        - Install GitOps tools (ArgoCD, Flux)"
    echo "  start        - Start Kubernetes cluster"
    echo "  stop         - Stop Kubernetes cluster"
    echo "  status       - Check lab status"
    echo "  lab          - Show lab structure"
    echo "  go <part>    - Navigate to lab part (1-12)"
    echo "  cleanup      - Clean up lab environment"
    echo "  help         - Show this help"
    echo
    echo "Examples:"
    echo "  $0 setup     - Quick setup"
    echo "  $0 go 4      - Go to ArgoCD section"
    echo "  $0 status    - Check what's running"
    echo
    echo "Kubernetes Options:"
    echo "  - Docker Desktop (recommended): Enable Kubernetes in settings"
    echo "  - Minikube: minikube start"
    echo "  - Kind: kind create cluster --name gitops-lab"
    echo
}

# Export useful functions for interactive use
export_functions() {
    cat >> ~/.bashrc << 'EOF'

# GitOps Lab Functions
alias lab-status='~/gitops/examples/lab/scripts/lab-startup.sh status'
alias lab-kubectl='KUBECONFIG=~/.kube/config-gitops-lab kubectl'

# Function to go to lab parts
lab-go() {
    ~/gitops/examples/lab/scripts/lab-startup.sh go $1
}

# Set GitOps lab kubeconfig
lab-kube() {
    export KUBECONFIG="$HOME/.kube/config-gitops-lab"
    echo "Using GitOps lab kubeconfig"
}
EOF
}

# Main execution
main() {
    show_banner
    
    case "${1:-help}" in
        setup)
            quick_setup
            ;;
        tools)
            install_tools
            ;;
        start)
            check_prerequisites
            start_kubernetes
            ;;
        stop)
            stop_kubernetes
            ;;
        status)
            check_status
            ;;
        lab)
            show_lab_structure
            ;;
        go)
            if [ -z "${2:-}" ]; then
                log_error "Please specify a part number (1-12)"
                exit 1
            fi
            go_to_part "$2"
            ;;
        cleanup)
            cleanup_lab
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
