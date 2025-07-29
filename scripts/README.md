# GitOps Lab Scripts

This directory contains automation scripts to help you set up and manage the GitOps lab environment.

## Scripts Overview

### 🚀 `lab-startup.sh`
**Main lab management script** - Handles complete lab lifecycle including Lima VM, Kubernetes, and GitOps tools.

#### Quick Commands:
```bash
# Complete setup (recommended for first-time users)
./scripts/lab-startup.sh setup

# Install GitOps tools (after setup)
./scripts/lab-startup.sh tools

# Check what's running
./scripts/lab-startup.sh status

# Navigate to lab sections
./scripts/lab-startup.sh go 4    # Go to ArgoCD section
./scripts/lab-startup.sh go 7    # Go to Helm section

# Shell into the Lima VM
./scripts/lab-startup.sh shell

# Show lab structure
./scripts/lab-startup.sh lab

# Clean up everything
./scripts/lab-startup.sh cleanup
```

### ⚡ `quick-start.sh`
**Setup guide** - Shows you how to get started and create useful aliases.

```bash
./scripts/quick-start.sh
```

### ⚙️ `lab-config.sh`
**Configuration file** - Contains settings for VM resources, tool versions, and environment variables.

## Getting Started

### 1. First Time Setup

```bash
# Navigate to the lab directory
cd /path/to/gitops/examples/lab

# Run complete setup
./scripts/lab-startup.sh setup

# Install GitOps tools
./scripts/lab-startup.sh tools

# Check everything is working
./scripts/lab-startup.sh status
```

### 2. Create Convenient Aliases

Add these to your `~/.zshrc` or `~/.bashrc`:

```bash
# GitOps Lab Aliases
alias lab='~/path/to/gitops/examples/lab/scripts/lab-startup.sh'
alias lab-setup='lab setup'
alias lab-status='lab status'
alias lab-shell='limactl shell gitops'
alias lab-kubectl='KUBECONFIG=~/.kube/config-gitops-lab kubectl'

# Function to navigate lab parts
lab-go() {
    lab go $1
}

# Set GitOps lab environment
lab-env() {
    export KUBECONFIG=~/.kube/config-gitops-lab
    echo "✓ GitOps lab environment active"
}
```

Reload your shell:
```bash
source ~/.zshrc
```

### 3. Daily Usage

```bash
# Start your lab session
lab-env                    # Set environment
lab-status                 # Check what's running

# Navigate to different sections
lab-go 1                   # Lima setup
lab-go 4                   # ArgoCD
lab-go 5                   # Flux
lab-go 12                  # Multi-environment

# Work with Kubernetes
lab-kubectl get pods       # List pods
lab-kubectl get namespaces # List namespaces

# Access services
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Shell into VM when needed
lab-shell
```

## Lab Parts Navigation

| Part | Description | Command |
|------|-------------|---------|
| 1 | Lima Setup | `lab-go 1` |
| 2 | Kubernetes Basics | `lab-go 2` |
| 3 | GitOps Introduction | `lab-go 3` |
| 4 | ArgoCD | `lab-go 4` |
| 5 | Flux | `lab-go 5` |
| 6 | Kustomize | `lab-go 6` |
| 7 | Helm | `lab-go 7` |
| 8 | External Secrets | `lab-go 8` |
| 9 | Keptn | `lab-go 9` |
| 10 | Jenkins X | `lab-go 10` |
| 11 | Overlay Patterns | `lab-go 11` |
| 12 | Multi-environment | `lab-go 12` |

## Common Workflows

### Starting a New Lab Session

```bash
# Check if everything is running
lab-status

# If Lima VM is stopped, start it
lab start

# Set environment for kubectl
lab-env

# Verify cluster access
lab-kubectl cluster-info
```

### Installing New Tools

```bash
# ArgoCD
lab-kubectl create namespace argocd
lab-kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Flux
flux install

# External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace
```

### Accessing Web UIs

```bash
# ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open: https://localhost:8080
# Username: admin
# Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Grafana (if installed)
kubectl port-forward svc/grafana -n monitoring 3000:80
# Open: http://localhost:3000

# Prometheus (if installed)
kubectl port-forward svc/prometheus-server -n monitoring 9090:80
# Open: http://localhost:9090
```

### Troubleshooting

#### Lima VM Issues
```bash
# Check Lima status
limactl list

# Restart Lima VM
lab stop
lab start

# Shell into VM for debugging
lab-shell
```

#### Kubernetes Issues
```bash
# Check cluster status
lab-kubectl cluster-info

# Check node status
lab-kubectl get nodes

# Check system pods
lab-kubectl get pods -A

# Restart k3s in VM
lab-shell
sudo systemctl restart k3s
```

#### Tool Installation Issues
```bash
# Check if namespaces exist
lab-kubectl get namespaces

# Check pod status
lab-kubectl get pods -n argocd
lab-kubectl get pods -n flux-system

# View logs
lab-kubectl logs -n argocd deployment/argocd-server
```

## Resource Management

### VM Resources
The Lima VM is configured with:
- **Memory**: 4GB (configurable in `lab-config.sh`)
- **CPUs**: 2 cores
- **Disk**: 20GB

### Cleaning Up
```bash
# Stop everything
lab cleanup

# Just stop VM (keeps data)
lab stop

# Remove specific tools
lab-kubectl delete namespace argocd
lab-kubectl delete namespace flux-system
```

## Advanced Usage

### Custom Configuration
Edit `scripts/lab-config.sh` to customize:
- VM resources
- Tool versions
- Default namespaces
- Port forwards

### Multiple Environments
The scripts support setting up multiple environments by changing the `LIMA_VM_NAME` in the config.

### Backup and Restore
```bash
# Backup important configs
cp ~/.kube/config-gitops-lab ~/backup/

# Export Lima VM
limactl stop gitops
cp -r ~/.lima/gitops ~/backup/lima-gitops

# Restore
cp -r ~/backup/lima-gitops ~/.lima/gitops
limactl start gitops
```

## Support

If you encounter issues:

1. **Check status**: `lab-status`
2. **View logs**: Check Lima and k3s logs
3. **Reset environment**: `lab cleanup` then `lab setup`
4. **Shell access**: `lab-shell` for direct VM access

## Contributing

To improve these scripts:
1. Test changes thoroughly
2. Update documentation
3. Consider backward compatibility
4. Add error handling for edge cases
