#!/bin/bash

# Fixed GitHub Repository Setup Script for GitOps Lab
# This version fixes the directory structure issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}===========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===========================================${NC}"
}

# Manual setup with correct structure
setup_correct_repo() {
    print_header "Setting Up GitOps Lab Repository (Manual)"
    
    echo "We'll create the repository structure manually to ensure correctness."
    echo ""
    echo "Steps:"
    echo "1. Create new GitHub repository manually"
    echo "2. Clone and setup with correct structure"
    echo "3. Copy content properly"
    echo ""
    
    read -p "Enter your GitHub username: " GITHUB_USERNAME
    read -p "Repository name [gitops-lab]: " REPO_NAME
    REPO_NAME=${REPO_NAME:-gitops-lab}
    
    REPO_URL="https://github.com/${GITHUB_USERNAME}/${REPO_NAME}"
    
    echo ""
    print_status "Repository URL will be: $REPO_URL"
    echo ""
    echo "Please follow these steps:"
    echo ""
    echo "1. Go to: https://github.com/new"
    echo "2. Repository name: $REPO_NAME"
    echo "3. Description: GitOps Laboratory with ArgoCD, Flux, and Kubernetes"
    echo "4. Set as Public"
    echo "5. Initialize with README"
    echo "6. Click 'Create repository'"
    echo ""
    
    read -p "Press Enter after creating the repository on GitHub..."
    
    # Clone repository
    print_status "Cloning repository..."
    if [[ -d "$REPO_NAME" ]]; then
        rm -rf "$REPO_NAME"
    fi
    
    git clone "$REPO_URL"
    cd "$REPO_NAME"
    
    # Setup correct structure
    print_header "Setting Up Correct Directory Structure"
    
    LAB_SOURCE="/Volumes/Server/git-remote/github-issarapong/gitops/examples/lab"
    
    # Create main directories
    mkdir -p 01-foundation 02-core-tools 03-advanced-scenarios scripts
    
    # Copy foundation content
    print_status "Copying 01-foundation..."
    cp -r "$LAB_SOURCE/01-foundation"/* ./01-foundation/
    
    # Copy core tools
    print_status "Copying 02-core-tools..."
    cp -r "$LAB_SOURCE/02-core-tools"/* ./02-core-tools/
    
    # Copy advanced scenarios (rename from 03-advanced)
    print_status "Copying 03-advanced-scenarios..."
    if [[ -d "$LAB_SOURCE/03-advanced" ]]; then
        cp -r "$LAB_SOURCE/03-advanced"/* ./03-advanced-scenarios/
    fi
    
    # Copy additional scenarios
    if [[ -d "$LAB_SOURCE/04-scenarios" ]]; then
        cp -r "$LAB_SOURCE/04-scenarios"/* ./03-advanced-scenarios/
    fi
    
    # Copy scripts
    print_status "Copying scripts..."
    cp -r "$LAB_SOURCE/scripts"/* ./scripts/
    
    # Copy documentation files
    print_status "Copying documentation..."
    cp "$LAB_SOURCE/CONTRIBUTING.md" ./
    cp "$LAB_SOURCE/REPO-README.md" ./README.md
    
    # Create .gitignore
    print_status "Creating .gitignore..."
    cat > .gitignore << 'EOF'
# Kubernetes
.kube/
kubeconfig*
*.kubeconfig

# Secrets
secrets/
*.secret
*.key
*.pem

# Temporary files
*.tmp
*.log

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Build artifacts
dist/
build/
target/

# Node modules
node_modules/
package-lock.json

# Python
__pycache__/
*.pyc
.venv/
EOF
    
    # Update repository URLs
    print_header "Updating Repository URLs"
    
    print_status "Updating ArgoCD applications..."
    find . -name "*.yaml" -type f -exec sed -i '' "s|repoURL:.*github.com.*|repoURL: ${REPO_URL}|g" {} \; 2>/dev/null || true
    find . -name "*.yaml" -type f -exec sed -i '' "s|url:.*github.com.*|url: ${REPO_URL}|g" {} \; 2>/dev/null || true
    
    print_status "Updating documentation..."
    find . -name "*.md" -exec sed -i '' "s|https://github.com/your-org/gitops-.*|${REPO_URL}|g" {} \; 2>/dev/null || true
    find . -name "*.md" -exec sed -i '' "s|https://github.com/YOUR_USERNAME/gitops-lab|${REPO_URL}|g" {} \; 2>/dev/null || true
    
    # Show final structure
    print_header "Final Repository Structure"
    tree -L 2 || find . -type d -not -path './.git*' | head -20
    
    # Commit and push
    print_header "Committing and Pushing"
    
    git add .
    git commit -m "Complete GitOps lab setup with correct structure

- 01-foundation: Kubernetes setup and GitOps intro
- 02-core-tools: ArgoCD, Flux, and Kustomize
- 03-advanced-scenarios: Multi-cluster, secrets, monitoring
- scripts: Automation and setup tools
- Updated all repository URLs to ${REPO_URL}"
    
    git push origin main
    
    # Create environment branches
    print_status "Creating environment branches..."
    
    git checkout -b development
    git push origin development
    
    git checkout -b staging
    git push origin staging
    
    git checkout -b production
    git push origin production
    
    git checkout main
    
    print_header "Setup Complete!"
    echo ""
    echo "🎉 Repository created successfully!"
    echo ""
    echo "Repository: $REPO_URL"
    echo "Structure: Correct GitOps lab layout"
    echo "Branches: main, development, staging, production"
    echo ""
    echo "Next steps:"
    echo "1. cd $REPO_NAME"
    echo "2. ./scripts/lab-startup.sh"
    echo ""
}

# Run the setup
setup_correct_repo
