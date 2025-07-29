#!/bin/bash

# GitOps Lab Troubleshooting Script
# Run this if you're stuck to diagnose issues

echo "🔍 GitOps Lab Troubleshooting"
echo "=============================="
echo

# Check basic tools
echo "📋 Checking Prerequisites:"
echo

if command -v kubectl &> /dev/null; then
    echo "✅ kubectl installed: $(kubectl version --client --short 2>/dev/null || echo 'version check failed')"
else
    echo "❌ kubectl missing - install with: brew install kubectl"
fi

if command -v git &> /dev/null; then
    echo "✅ git installed: $(git --version)"
else
    echo "❌ git missing - install with: brew install git"
fi

if command -v docker &> /dev/null; then
    echo "✅ docker installed: $(docker --version)"
    if docker info &>/dev/null; then
        echo "✅ Docker daemon running"
        if docker system info | grep -q "Kubernetes"; then
            echo "✅ Docker Desktop Kubernetes enabled"
        else
            echo "⚠️  Docker Desktop Kubernetes disabled - enable in settings"
        fi
    else
        echo "❌ Docker daemon not running"
    fi
else
    echo "⚠️  Docker not installed"
fi

if command -v minikube &> /dev/null; then
    echo "✅ minikube installed: $(minikube version --short 2>/dev/null || echo 'version check failed')"
    if minikube status &>/dev/null; then
        echo "✅ Minikube cluster running"
    else
        echo "ℹ️  Minikube cluster not running"
    fi
else
    echo "ℹ️  Minikube not installed"
fi

if command -v kind &> /dev/null; then
    echo "✅ kind installed: $(kind version 2>/dev/null || echo 'version check failed')"
    if kind get clusters 2>/dev/null | grep -q "gitops-lab"; then
        echo "✅ Kind gitops-lab cluster exists"
    else
        echo "ℹ️  Kind gitops-lab cluster not found"
    fi
else
    echo "ℹ️  Kind not installed"
fi

echo
echo "🔗 Checking Kubernetes Connectivity:"
echo

if kubectl cluster-info &>/dev/null; then
    echo "✅ Can connect to Kubernetes cluster"
    echo "   Context: $(kubectl config current-context)"
    echo "   Nodes: $(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')"
else
    echo "❌ Cannot connect to Kubernetes cluster"
fi

echo
echo "📁 Checking Lab Files:"
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$LAB_ROOT/scripts/lab-startup.sh" ]; then
    echo "✅ Lab startup script found"
    if [ -x "$LAB_ROOT/scripts/lab-startup.sh" ]; then
        echo "✅ Lab startup script is executable"
    else
        echo "⚠️  Lab startup script not executable - run: chmod +x $LAB_ROOT/scripts/lab-startup.sh"
    fi
else
    echo "❌ Lab startup script not found"
fi

if [ -f "$LAB_ROOT/README.md" ]; then
    echo "✅ Lab README found"
else
    echo "❌ Lab README not found"
fi

echo
echo "💡 Recommendations:"
echo

has_kube=false

if command -v docker &> /dev/null && docker info &>/dev/null; then
    if docker system info | grep -q "Kubernetes"; then
        echo "🎯 Use Docker Desktop (already configured)"
        has_kube=true
    else
        echo "🎯 Enable Kubernetes in Docker Desktop settings"
    fi
fi

if command -v minikube &> /dev/null && minikube status &>/dev/null; then
    echo "🎯 Use Minikube (already running)"
    has_kube=true
fi

if command -v kind &> /dev/null && kind get clusters 2>/dev/null | grep -q "gitops-lab"; then
    echo "🎯 Use Kind (gitops-lab cluster exists)"
    has_kube=true
fi

if [ "$has_kube" = false ]; then
    echo "🎯 Install a Kubernetes option:"
    echo "   - Docker Desktop: brew install --cask docker (then enable Kubernetes)"
    echo "   - Minikube: brew install minikube && minikube start"
    echo "   - Kind: brew install kind && kind create cluster --name gitops-lab"
fi

echo
echo "🚀 Next Steps:"
echo
if [ "$has_kube" = true ]; then
    echo "1. Run: ./scripts/lab-startup.sh setup"
    echo "2. Run: ./scripts/lab-startup.sh tools"
    echo "3. Check: ./scripts/lab-startup.sh status"
else
    echo "1. Install/configure Kubernetes (see recommendations above)"
    echo "2. Run: ./scripts/lab-startup.sh setup"
    echo "3. Run: ./scripts/lab-startup.sh tools"
fi

echo
echo "📚 Resources:"
echo "- Getting Started: cat GETTING-STARTED.md"
echo "- Script Help: ./scripts/lab-startup.sh help"
echo "- Lab Structure: ./scripts/lab-startup.sh lab"
