#!/bin/bash

# Kustomize Hands-on Lab Script
# This script demonstrates Kustomize configuration management

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$SCRIPT_DIR/02-core-tools/06-kustomize"

echo "🔧 Kustomize Configuration Management Lab"
echo "=========================================="

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

# Function to show diff between environments
show_diff() {
    local env1=$1
    local env2=$2
    
    echo ""
    echo "📊 Comparing $env1 vs $env2:"
    echo "kubectl kustomize $LAB_DIR/overlays/$env1 > /tmp/kustomize-$env1.yaml"
    kubectl kustomize "$LAB_DIR/overlays/$env1" > "/tmp/kustomize-$env1.yaml"
    
    echo "kubectl kustomize $LAB_DIR/overlays/$env2 > /tmp/kustomize-$env2.yaml" 
    kubectl kustomize "$LAB_DIR/overlays/$env2" > "/tmp/kustomize-$env2.yaml"
    
    echo ""
    echo "Key differences:"
    diff "/tmp/kustomize-$env1.yaml" "/tmp/kustomize-$env2.yaml" || true
}

# Check prerequisites
show_step "Checking prerequisites"
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo "❌ No Kubernetes cluster found. Please ensure your cluster is running."
    exit 1
fi

echo "✅ kubectl found"
echo "✅ Kubernetes cluster accessible"

# Show lab structure
show_step "Lab Structure Overview"
echo "📁 Kustomize Lab Structure:"
tree "$LAB_DIR" 2>/dev/null || find "$LAB_DIR" -type f | head -20

# Part 1: Understanding Base Configuration
show_step "Part 1: Understanding Base Configuration"
echo "Base configuration contains common resources that all environments share."

run_command "kubectl kustomize $LAB_DIR/base"

# Part 2: Environment-specific Overlays
show_step "Part 2: Environment-specific Overlays"

echo ""
echo "🧪 Development Environment (dev):"
run_command "kubectl kustomize $LAB_DIR/overlays/dev"

echo ""
echo "🎭 Staging Environment (staging):"
run_command "kubectl kustomize $LAB_DIR/overlays/staging"

echo ""
echo "🏭 Production Environment (prod):"
run_command "kubectl kustomize $LAB_DIR/overlays/prod"

# Part 3: Comparing Environments
show_step "Part 3: Comparing Environments"
show_diff "dev" "staging"
show_diff "staging" "prod"

# Part 4: Hands-on Deployment
show_step "Part 4: Hands-on Deployment"

echo ""
echo "Let's deploy to different environments and see the differences:"

# Create namespaces
echo ""
echo "📦 Creating namespaces..."
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace staging --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -

# Deploy to dev
echo ""
echo "🧪 Deploying to Development:"
run_command "kubectl apply -k $LAB_DIR/overlays/dev"

# Deploy to staging
echo ""
echo "🎭 Deploying to Staging:"
run_command "kubectl apply -k $LAB_DIR/overlays/staging"

# Deploy to production
echo ""
echo "🏭 Deploying to Production:"
run_command "kubectl apply -k $LAB_DIR/overlays/prod"

# Part 5: Verification
show_step "Part 5: Verification"

echo ""
echo "🔍 Checking deployments across environments:"
run_command "kubectl get deployments -n dev -o wide"
run_command "kubectl get deployments -n staging -o wide"
run_command "kubectl get deployments -n production -o wide"

echo ""
echo "📊 Resource differences:"
echo "Dev replicas:"
kubectl get deployment sample-app -n dev -o jsonpath='{.spec.replicas}'
echo ""
echo "Staging replicas:"
kubectl get deployment sample-app -n staging -o jsonpath='{.spec.replicas}'
echo ""
echo "Production replicas:"
kubectl get deployment sample-app -n production -o jsonpath='{.spec.replicas}'
echo ""

# Part 6: Advanced Kustomize Features
show_step "Part 6: Advanced Features Demo"

echo ""
echo "🎨 Let's try some advanced Kustomize features:"

# Show image transformation
echo ""
echo "Image transformations:"
echo "Base image: nginx:1.21"
echo "Dev image: $(kubectl get deployment sample-app -n dev -o jsonpath='{.spec.template.spec.containers[0].image}')"
echo "Staging image: $(kubectl get deployment sample-app -n staging -o jsonpath='{.spec.template.spec.containers[0].image}')"
echo "Production image: $(kubectl get deployment sample-app -n production -o jsonpath='{.spec.template.spec.containers[0].image}')"

# Show labels
echo ""
echo "Environment labels:"
echo "Dev labels:"
kubectl get deployment sample-app -n dev -o jsonpath='{.metadata.labels}' | jq .
echo "Staging labels:"
kubectl get deployment sample-app -n staging -o jsonpath='{.metadata.labels}' | jq .
echo "Production labels:"
kubectl get deployment sample-app -n production -o jsonpath='{.metadata.labels}' | jq .

# Cleanup
show_step "Cleanup (Optional)"
echo ""
echo "🧹 Would you like to clean up the deployed resources? (y/n)"
read -r cleanup_choice

if [[ $cleanup_choice =~ ^[Yy]$ ]]; then
    echo "Cleaning up..."
    kubectl delete -k "$LAB_DIR/overlays/dev" || true
    kubectl delete -k "$LAB_DIR/overlays/staging" || true
    kubectl delete -k "$LAB_DIR/overlays/prod" || true
    
    kubectl delete namespace dev --ignore-not-found=true
    kubectl delete namespace staging --ignore-not-found=true
    kubectl delete namespace production --ignore-not-found=true
    
    echo "✅ Cleanup completed"
fi

echo ""
echo "🎉 Kustomize Lab Completed!"
echo ""
echo "📚 What you learned:"
echo "• Base and overlay structure"
echo "• Environment-specific configurations"  
echo "• Image and replica transformations"
echo "• Strategic merge patches"
echo "• Label and namespace management"
echo ""
echo "🔗 Next steps:"
echo "• Try modifying kustomization.yaml files"
echo "• Experiment with different patch strategies"
echo "• Integrate with ArgoCD or Flux"
echo "• Explore Kustomize generators and transformers"
