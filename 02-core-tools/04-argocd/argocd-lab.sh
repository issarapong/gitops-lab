#!/bin/bash

# ArgoCD Hands-on Lab Script
# This script demonstrates ArgoCD GitOps workflow

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$SCRIPT_DIR"

echo "🚀 ArgoCD GitOps Lab"
echo "==================="

# Function to show colored output
show_step() {
    echo ""
    echo "🎯 $1"
    echo "----------------------------------------"
}

# Function to show command and wait for user
run_command() {
    echo ""
    echo "💻 Command: $1"
    echo "Press Enter to run..."
    read -r
    eval "$1"
}

# Function to check if ArgoCD is installed
check_argocd() {
    if kubectl get namespace argocd &> /dev/null; then
        echo "✅ ArgoCD namespace exists"
        if kubectl get pods -n argocd | grep -q "Running"; then
            echo "✅ ArgoCD is running"
            return 0
        else
            echo "⚠️  ArgoCD pods are not ready"
            return 1
        fi
    else
        echo "❌ ArgoCD not installed"
        return 1
    fi
}

# Function to install ArgoCD
install_argocd() {
    show_step "Installing ArgoCD"
    
    echo "Creating ArgoCD namespace..."
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    echo "Installing ArgoCD components..."
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    echo "Waiting for ArgoCD to be ready (this may take a few minutes)..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
    
    echo "✅ ArgoCD installation completed!"
}

# Function to get ArgoCD admin password
get_admin_password() {
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Unable to get password"
}

# Function to setup port forwarding
setup_port_forward() {
    show_step "Setting up ArgoCD UI Access"
    
    # Check if port 8080 is already in use
    if lsof -Pi :8080 -sTCP:LISTEN -t >/dev/null ; then
        echo "⚠️  Port 8080 is already in use. Killing existing processes..."
        pkill -f "kubectl.*port-forward.*argocd-server" || true
        sleep 2
    fi
    
    echo "Starting port forward to ArgoCD UI..."
    echo "ArgoCD UI will be available at: http://localhost:8080"
    echo "Username: admin"
    echo "Password: $(get_admin_password)"
    echo ""
    echo "Starting port-forward in background..."
    kubectl port-forward svc/argocd-server -n argocd 8080:443 &
    PORT_FORWARD_PID=$!
    echo "Port-forward PID: $PORT_FORWARD_PID"
    sleep 3
    
    echo ""
    echo "🌐 Open your browser and go to: http://localhost:8080"
    echo "⚠️  You may see a security warning - click 'Advanced' and 'Proceed'"
    echo ""
    echo "Press Enter when you're ready to continue..."
    read -r
}

# Function to create sample applications
create_sample_apps() {
    show_step "Creating Sample Applications"
    
    # Create namespaces
    echo "Creating target namespaces..."
    kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace staging --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -
    
    # Create ArgoCD Application for dev environment
    echo "Creating ArgoCD Application for dev environment..."
    
    cat > "$LAB_DIR/sample-app-dev.yaml" << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sample-app-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/issarapong/gitops-lab
    targetRevision: HEAD
    path: 01-foundation/03-gitops-intro/clusters/dev/sample-app
  destination:
    server: https://kubernetes.default.svc
    namespace: dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

    kubectl apply -f "$LAB_DIR/sample-app-dev.yaml"
    
    echo "✅ Sample application created!"
    echo "You can now see it in the ArgoCD UI"
}

# Function to demonstrate GitOps workflow
demo_gitops_workflow() {
    show_step "GitOps Workflow Demonstration"
    
    echo "🔍 Checking application status..."
    run_command "kubectl get applications -n argocd"
    
    echo ""
    echo "🔍 Checking deployed resources..."
    run_command "kubectl get all -n dev"
    
    echo ""
    echo "📊 ArgoCD Application Details:"
    kubectl get application sample-app-dev -n argocd -o jsonpath='{.status.sync.status}' | xargs echo "Sync Status:"
    kubectl get application sample-app-dev -n argocd -o jsonpath='{.status.health.status}' | xargs echo "Health Status:"
    
    echo ""
    echo "🎯 This demonstrates the GitOps workflow:"
    echo "1. Application configuration is stored in Git"
    echo "2. ArgoCD monitors the Git repository"
    echo "3. Changes are automatically deployed to Kubernetes"
    echo "4. Actual state is reconciled with desired state"
}

# Function to demonstrate ArgoCD CLI
demo_argocd_cli() {
    show_step "ArgoCD CLI Demonstration"
    
    if ! command -v argocd &> /dev/null; then
        echo "ArgoCD CLI not installed. Showing kubectl alternatives..."
        echo ""
        echo "📋 List applications:"
        run_command "kubectl get applications -n argocd"
        
        echo ""
        echo "📋 Get application details:"
        run_command "kubectl get application sample-app-dev -n argocd -o yaml"
        
        echo ""
        echo "🔄 To install ArgoCD CLI:"
        echo "  macOS: brew install argocd"
        echo "  Linux: curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
        
    else
        echo "ArgoCD CLI found! Demonstrating CLI commands..."
        
        # Check if already logged in, if not show login command
        if ! argocd account get --auth-token="" &>/dev/null; then
            echo ""
            echo "🔑 First, login to ArgoCD CLI:"
            echo "argocd login localhost:8080"
            echo "Username: admin"
            echo "Password: $(get_admin_password)"
            echo ""
            echo "Run the login command manually, then press Enter to continue..."
            read -r
        fi
        
        echo ""
        echo "📋 List applications:"
        run_command "argocd app list"
        
        echo ""
        echo "📋 Get application details:"
        run_command "argocd app get sample-app-dev"
        
        echo ""
        echo "🔄 Sync application:"
        run_command "argocd app sync sample-app-dev"
    fi
}

# Function to demonstrate environment promotion
demo_environment_promotion() {
    show_step "Environment Promotion Demo"
    
    echo "Creating applications for all environments..."
    
    # Staging application
    cat > "$LAB_DIR/sample-app-staging.yaml" << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sample-app-staging
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/issarapong/gitops-lab
    targetRevision: HEAD
    path: 01-foundation/03-gitops-intro/clusters/staging/sample-app
  destination:
    server: https://kubernetes.default.svc
    namespace: staging
  syncPolicy:
    automated:
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

    # Production application (manual sync only)
    cat > "$LAB_DIR/sample-app-prod.yaml" << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sample-app-prod
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/issarapong/gitops-lab
    targetRevision: HEAD
    path: 01-foundation/03-gitops-intro/clusters/prod/sample-app
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
EOF

    kubectl apply -f "$LAB_DIR/sample-app-staging.yaml"
    kubectl apply -f "$LAB_DIR/sample-app-prod.yaml"
    
    echo "✅ Applications created for all environments!"
    
    echo ""
    echo "📊 Environment Comparison:"
    run_command "kubectl get deployments -A | grep sample-app"
    
    echo ""
    echo "🎯 Notice the different sync policies:"
    echo "• Dev: Fully automated (auto-sync + auto-prune)"
    echo "• Staging: Semi-automated (auto-sync, manual prune)"  
    echo "• Production: Manual sync only"
}

# Function to cleanup
cleanup_demo() {
    show_step "Cleanup (Optional)"
    
    echo "🧹 Would you like to clean up the demo resources? (y/n)"
    read -r cleanup_choice
    
    if [[ $cleanup_choice =~ ^[Yy]$ ]]; then
        echo "Cleaning up ArgoCD applications..."
        kubectl delete application sample-app-dev -n argocd --ignore-not-found=true
        kubectl delete application sample-app-staging -n argocd --ignore-not-found=true
        kubectl delete application sample-app-prod -n argocd --ignore-not-found=true
        
        echo "Cleaning up application resources..."
        kubectl delete namespace dev --ignore-not-found=true
        kubectl delete namespace staging --ignore-not-found=true
        kubectl delete namespace production --ignore-not-found=true
        
        echo "Stopping port-forward..."
        pkill -f "kubectl.*port-forward.*argocd-server" || true
        
        echo "✅ Cleanup completed"
        echo ""
        echo "Note: ArgoCD itself is still running. To remove ArgoCD completely:"
        echo "kubectl delete namespace argocd"
    fi
}

# Main execution flow
show_step "Prerequisites Check"

# Check Kubernetes cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ No Kubernetes cluster found. Please ensure your cluster is running."
    echo "💡 Try: kubectl cluster-info"
    exit 1
fi

echo "✅ Kubernetes cluster accessible"
kubectl cluster-info | head -1

# Check ArgoCD installation
if ! check_argocd; then
    echo ""
    echo "🤔 Would you like to install ArgoCD now? (y/n)"
    read -r install_choice
    
    if [[ $install_choice =~ ^[Yy]$ ]]; then
        install_argocd
    else
        echo "Please install ArgoCD first and run this script again."
        exit 1
    fi
fi

# Setup ArgoCD UI access
setup_port_forward

# Create sample applications
create_sample_apps

# Wait for applications to sync
echo "Waiting for applications to sync..."
sleep 10

# Demonstrate GitOps workflow
demo_gitops_workflow

# Demonstrate ArgoCD CLI
demo_argocd_cli

# Demonstrate environment promotion
demo_environment_promotion

# Show completion message
echo ""
echo "🎉 ArgoCD Lab Completed!"
echo ""
echo "📚 What you learned:"
echo "• ArgoCD installation and setup"
echo "• GitOps workflow with Git repositories"
echo "• Application creation and management"
echo "• Multi-environment deployment patterns"
echo "• Sync policies and automation"
echo "• ArgoCD UI and CLI usage"
echo ""
echo "🔗 Next steps:"
echo "• Explore ArgoCD ApplicationSets"
echo "• Try App of Apps pattern"
echo "• Set up RBAC and projects"
echo "• Configure notifications and webhooks"
echo "• Compare with Flux in 05-flux lab"
echo ""
echo "🌐 ArgoCD UI: http://localhost:8080"
echo "👤 Username: admin"
echo "🔑 Password: $(get_admin_password)"

# Cleanup option
cleanup_demo

echo ""
echo "🚀 Happy GitOps-ing!"
