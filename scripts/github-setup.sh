#!/bin/bash

# GitHub Repository Setup Script for GitOps Lab
# This script helps setup a new GitHub repository for the GitOps lab

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}===========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===========================================${NC}"
}

# Check if required tools are installed
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check git
    if ! command -v git &> /dev/null; then
        print_error "Git is not installed. Please install git first."
        exit 1
    fi
    print_status "✅ Git is installed"
    
    # Check if we can access GitHub
    if ! git ls-remote https://github.com/octocat/Hello-World.git &> /dev/null; then
        print_error "Cannot access GitHub. Please check your internet connection."
        exit 1
    fi
    print_status "✅ GitHub is accessible"
    
    # Check if gh CLI is available (optional)
    if command -v gh &> /dev/null; then
        print_status "✅ GitHub CLI (gh) is available"
        GH_AVAILABLE=true
    else
        print_warning "GitHub CLI (gh) is not installed. Manual repository creation will be needed."
        GH_AVAILABLE=false
    fi
}

# Collect user information
collect_info() {
    print_header "Repository Configuration"
    
    echo "Please provide the following information:"
    echo ""
    
    read -p "GitHub username: " GITHUB_USERNAME
    read -p "Repository name [gitops-lab]: " REPO_NAME
    REPO_NAME=${REPO_NAME:-gitops-lab}
    
    read -p "Repository description [GitOps Laboratory with ArgoCD, Flux, and Kubernetes]: " REPO_DESC
    REPO_DESC=${REPO_DESC:-"GitOps Laboratory with ArgoCD, Flux, and Kubernetes"}
    
    echo ""
    echo "Repository will be created as: https://github.com/${GITHUB_USERNAME}/${REPO_NAME}"
    echo "Description: ${REPO_DESC}"
    echo ""
    
    read -p "Is this correct? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_error "Setup cancelled by user"
        exit 1
    fi
}

# Create repository using GitHub CLI
create_repo_with_gh() {
    print_header "Creating Repository with GitHub CLI"
    
    # Check if user is logged in
    if ! gh auth status &> /dev/null; then
        print_status "Logging into GitHub..."
        gh auth login
    fi
    
    # Create repository
    print_status "Creating repository: ${GITHUB_USERNAME}/${REPO_NAME}"
    gh repo create "${REPO_NAME}" \
        --description "${REPO_DESC}" \
        --public \
        --clone \
        --add-readme
    
    cd "${REPO_NAME}"
    REPO_PATH=$(pwd)
    print_status "✅ Repository created and cloned to: ${REPO_PATH}"
}

# Manual repository creation instructions
manual_repo_creation() {
    print_header "Manual Repository Creation"
    
    print_warning "GitHub CLI not available. Please create repository manually:"
    echo ""
    echo "1. Go to: https://github.com/new"
    echo "2. Repository name: ${REPO_NAME}"
    echo "3. Description: ${REPO_DESC}"
    echo "4. Set as Public"
    echo "5. Initialize with README"
    echo "6. Click 'Create repository'"
    echo ""
    
    read -p "Press Enter after creating the repository..."
    
    print_status "Cloning repository..."
    git clone "https://github.com/${GITHUB_USERNAME}/${REPO_NAME}.git"
    cd "${REPO_NAME}"
    REPO_PATH=$(pwd)
    print_status "✅ Repository cloned to: ${REPO_PATH}"
}

# Copy lab content to repository
setup_lab_content() {
    print_header "Setting Up Lab Content"
    
    LAB_SOURCE="/Volumes/Server/git-remote/github-issarapong/gitops/examples/lab"
    
    if [[ ! -d "$LAB_SOURCE" ]]; then
        print_error "Lab source directory not found: $LAB_SOURCE"
        print_error "Please ensure you're running this from the correct location"
        exit 1
    fi
    
    print_status "Copying lab content from: $LAB_SOURCE"
    
    # Copy specific directories and files, excluding problematic ones
    print_status "Copying foundation directories..."
    cp -r "$LAB_SOURCE/01-foundation" . 2>/dev/null || true
    cp -r "$LAB_SOURCE/02-core-tools" . 2>/dev/null || true
    cp -r "$LAB_SOURCE/03-advanced" . 2>/dev/null || true
    cp -r "$LAB_SOURCE/04-scenarios" . 2>/dev/null || true
    cp -r "$LAB_SOURCE/scripts" . 2>/dev/null || true
    
    # Copy individual files
    print_status "Copying documentation files..."
    cp "$LAB_SOURCE/CONTRIBUTING.md" . 2>/dev/null || true
    cp "$LAB_SOURCE/GETTING-STARTED.md" . 2>/dev/null || true
    cp "$LAB_SOURCE/github-setup.md" . 2>/dev/null || true
    
    # Copy and rename the main README
    cp "$LAB_SOURCE/REPO-README.md" ./README.md 2>/dev/null || true
    
    # Remove any nested gitops-lab directories that might have been created
    find . -name "gitops-lab" -type d -exec rm -rf {} + 2>/dev/null || true
    
    print_status "✅ Lab content copied successfully"
}

# Create .gitignore file
create_gitignore() {
    print_status "Creating .gitignore file..."
    
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
.DS_Store

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
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

# macOS
.DS_Store
.AppleDouble
.LSOverride
EOF
    
    print_status "✅ .gitignore created"
}

# Update repository URLs in configuration files
update_repo_urls() {
    print_header "Updating Repository URLs"
    
    REPO_URL="https://github.com/${GITHUB_USERNAME}/${REPO_NAME}"
    
    print_status "Updating ArgoCD applications..."
    if [[ -d "02-core-tools/04-argocd/applications" ]]; then
        find 02-core-tools/04-argocd/applications -name "*.yaml" -exec sed -i '' "s|repoURL:.*|repoURL: ${REPO_URL}|g" {} \;
    fi
    
    print_status "Updating Flux configurations..."
    if [[ -d "02-core-tools/05-flux" ]]; then
        find 02-core-tools/05-flux -name "*.yaml" -exec sed -i '' "s|url:.*github.com.*|url: ${REPO_URL}|g" {} \;
    fi
    
    print_status "Updating documentation..."
    find . -name "*.md" -exec sed -i '' "s|https://github.com/your-org/gitops-.*|${REPO_URL}|g" {} \;
    find . -name "*.md" -exec sed -i '' "s|https://github.com/YOUR_USERNAME/gitops-lab|${REPO_URL}|g" {} \;
    
    print_status "✅ Repository URLs updated"
}

# Create environment branches
create_branches() {
    print_header "Creating Environment Branches"
    
    print_status "Creating development branch..."
    git checkout -b development
    git push origin development
    
    print_status "Creating staging branch..."
    git checkout -b staging  
    git push origin staging
    
    print_status "Creating production branch..."
    git checkout -b production
    git push origin production
    
    git checkout main
    print_status "✅ Environment branches created (development, staging, production)"
}

# Commit and push changes
commit_and_push() {
    print_header "Committing and Pushing Changes"
    
    print_status "Adding all files..."
    git add .
    
    print_status "Creating initial commit..."
    git commit -m "Initial GitOps lab setup

- Complete lab structure with foundation and core tools
- Kubernetes setup without Lima dependency  
- ArgoCD and Flux configurations
- GitOps introduction with working examples
- Multi-environment deployment demos
- Updated repository URLs for ${REPO_URL}"
    
    print_status "Pushing to GitHub..."
    git push origin main
    
    print_status "✅ Changes committed and pushed to GitHub"
}

# Generate summary
generate_summary() {
    print_header "Setup Complete!"
    
    echo ""
    echo "🎉 Your GitOps lab repository is ready!"
    echo ""
    echo "Repository Details:"
    echo "  📍 URL: https://github.com/${GITHUB_USERNAME}/${REPO_NAME}"
    echo "  📁 Local path: ${REPO_PATH}"
    echo "  🌿 Branches: main, development, staging, production"
    echo ""
    echo "Next Steps:"
    echo "  1. Review the lab documentation: cat README.md"
    echo "  2. Start the lab: ./scripts/lab-startup.sh"
    echo "  3. Explore GitOps examples: cd 01-foundation/03-gitops-intro"
    echo ""
    echo "Happy learning with GitOps! 🚀"
    echo ""
}

# Main execution
main() {
    print_header "GitOps Lab - GitHub Repository Setup"
    
    check_prerequisites
    collect_info
    
    if [[ "$GH_AVAILABLE" == true ]]; then
        create_repo_with_gh
    else
        manual_repo_creation
    fi
    
    setup_lab_content
    create_gitignore
    update_repo_urls
    commit_and_push
    create_branches
    generate_summary
}

# Run main function
main "$@"
