#!/bin/bash

# GitOps Lab Quick Start Guide

echo "🚀 GitOps Lab Quick Start"
echo "========================="
echo

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STARTUP_SCRIPT="$SCRIPT_DIR/lab-startup.sh"

echo "The GitOps lab startup script is located at:"
echo "  $STARTUP_SCRIPT"
echo

echo "Quick commands:"
echo "  ./scripts/lab-startup.sh setup    # Complete lab setup"
echo "  ./scripts/lab-startup.sh tools    # Install GitOps tools"
echo "  ./scripts/lab-startup.sh status   # Check lab status"
echo "  ./scripts/lab-startup.sh help     # Show all commands"
echo

echo "To create convenient aliases, add these to your ~/.zshrc:"
echo
cat << 'EOF'
# GitOps Lab Aliases
alias lab='~/path/to/gitops/examples/lab/scripts/lab-startup.sh'
alias lab-setup='lab setup'
alias lab-status='lab status'
alias lab-shell='limactl shell gitops'
alias lab-kubectl='KUBECONFIG=~/.kube/config-gitops-lab kubectl'

# Function to navigate lab parts
lab-go() {
    lab go $1 && cd $(pwd)
}

# Set GitOps lab environment
lab-env() {
    export KUBECONFIG=~/.kube/config-gitops-lab
    echo "✓ GitOps lab environment active"
    echo "  KUBECONFIG: $KUBECONFIG"
}
EOF

echo
echo "After adding aliases, reload your shell:"
echo "  source ~/.zshrc"
echo
echo "Then you can use:"
echo "  lab setup      # Setup everything"
echo "  lab-status     # Check status"
echo "  lab-go 4       # Go to ArgoCD section"
echo "  lab-env        # Set environment"
echo "  lab-kubectl    # Use kubectl with lab cluster"
echo
