# GitOps Lab Configuration
# This file contains configuration for the lab startup script

# Lima VM Configuration
LIMA_VM_NAME="gitops"
LIMA_MEMORY="4GB"
LIMA_CPUS="2"
LIMA_DISK="20GB"

# Kubernetes Configuration
KUBERNETES_VERSION="v1.28.4+k3s1"
KUBECONFIG_NAME="config-gitops-lab"

# GitOps Tools Versions
ARGOCD_VERSION="stable"
FLUX_VERSION="latest"
HELM_VERSION="v3.13.0"

# Lab Directories
LAB_PARTS=(
    "01-foundation/01-lima-setup"
    "01-foundation/02-kubernetes-basics"
    "01-foundation/03-gitops-intro"
    "02-core-tools/04-argocd"
    "02-core-tools/05-flux"
    "02-core-tools/06-kustomize"
    "02-core-tools/07-helm"
    "03-advanced/08-external-secrets"
    "03-advanced/09-keptn"
    "03-advanced/10-jenkins-x"
    "03-advanced/11-overlays"
    "04-scenarios/12-multi-env"
)

# URLs and Resources
ARGOCD_INSTALL_URL="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
FLUX_INSTALL_URL="https://fluxcd.io/install.sh"

# Default namespaces
DEFAULT_NAMESPACES=(
    "gitops-lab"
    "argocd"
    "flux-system"
    "external-secrets"
    "keptn"
)

# Port forwards for common services
declare -A SERVICE_PORTS=(
    ["argocd-server"]="8080:443"
    ["grafana"]="3000:80"
    ["prometheus"]="9090:9090"
    ["jenkins"]="8081:8080"
)

# Environment variables for lab
export LAB_ENVIRONMENT="development"
export LAB_CLUSTER_NAME="gitops-lab-cluster"
export LAB_DOMAIN="lab.local"
