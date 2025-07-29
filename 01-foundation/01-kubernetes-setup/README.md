# Part 1: Native Kubernetes Setup

This section covers setting up Kubernetes on macOS without Lima, using native options that provide better performance and integration.

## Prerequisites

- **macOS**: 10.15+ (Catalina or later)
- **Homebrew**: Package manager for macOS
- **Docker Desktop**: Recommended for beginners
- **8GB+ RAM**: Recommended for running the full lab

## Kubernetes Options

### Option 1: Docker Desktop (Recommended)

Docker Desktop provides the easiest Kubernetes setup with excellent macOS integration.

#### Installation
```bash
# Install Docker Desktop
brew install --cask docker

# Start Docker Desktop and enable Kubernetes in Settings
# Docker Desktop → Settings → Kubernetes → Enable Kubernetes
```

#### Features
- ✅ Native macOS integration
- ✅ Built-in load balancer
- ✅ Automatic storage provisioning
- ✅ Easy port forwarding
- ✅ File system sharing
- ✅ No VM overhead

#### Verification
```bash
# Check cluster status
kubectl cluster-info

# Check nodes
kubectl get nodes

# Check context
kubectl config current-context
# Should show: docker-desktop
```

### Option 2: Minikube

Minikube provides a lightweight, single-node Kubernetes cluster.

#### Installation
```bash
# Install Minikube
brew install minikube

# Start cluster
minikube start --driver=docker --memory=4096 --cpus=2

# Enable addons
minikube addons enable ingress
minikube addons enable dashboard
```

#### Features
- ✅ Lightweight and fast
- ✅ Multiple driver options
- ✅ Add-on ecosystem
- ✅ Easy cluster management
- ❌ Single node only

#### Useful Commands
```bash
# Start cluster
minikube start

# Stop cluster
minikube stop

# Delete cluster
minikube delete

# Access dashboard
minikube dashboard

# Get cluster IP
minikube ip
```

### Option 3: Kind (Kubernetes in Docker)

Kind runs Kubernetes clusters using Docker containers as nodes.

#### Installation
```bash
# Install Kind
brew install kind

# Create cluster
kind create cluster --name gitops-lab

# Create multi-node cluster
kind create cluster --name gitops-lab --config kind-config.yaml
```

#### Multi-node Configuration (kind-config.yaml)
```yaml
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
- role: worker
- role: worker
```

#### Features
- ✅ Multi-node clusters
- ✅ Fast startup/teardown
- ✅ CI/CD friendly
- ✅ Multiple cluster support
- ❌ Requires Docker knowledge

## Lab Setup Script

Use the automated setup script for quick installation:

```bash
# Quick setup (detects and uses available option)
./scripts/lab-startup.sh setup

# Check status
./scripts/lab-startup.sh status

# Install GitOps tools
./scripts/lab-startup.sh tools
```

## Troubleshooting

### Common Issues

#### Docker Desktop Issues
```bash
# Reset Docker Desktop
# Docker Desktop → Troubleshoot → Reset to factory defaults

# Check Docker status
docker info

# Restart Docker service
killall Docker && open /Applications/Docker.app
```

#### Minikube Issues
```bash
# Delete and recreate cluster
minikube delete
minikube start --driver=docker

# Check driver status
minikube status

# View logs
minikube logs
```

#### Kind Issues
```bash
# List clusters
kind get clusters

# Delete cluster
kind delete cluster --name gitops-lab

# Check Docker containers
docker ps -a | grep kind
```

### Resource Requirements

| Setup | RAM | CPU | Disk | Nodes |
|-------|-----|-----|------|-------|
| Docker Desktop | 4GB+ | 2+ | 20GB+ | 1 |
| Minikube | 2GB+ | 2+ | 10GB+ | 1 |
| Kind | 2GB+ | 2+ | 10GB+ | 1-3 |

### Performance Tips

1. **Allocate sufficient resources**
   - Docker Desktop: Settings → Resources
   - Minikube: `--memory` and `--cpus` flags

2. **Use SSD storage** for better I/O performance

3. **Close unnecessary applications** to free up resources

4. **Monitor resource usage**
   ```bash
   # Check cluster resource usage
   kubectl top nodes
   kubectl top pods --all-namespaces
   ```

## Next Steps

Once your Kubernetes cluster is running:

1. **Verify setup**: `kubectl get nodes`
2. **Install GitOps tools**: `./scripts/lab-startup.sh tools`
3. **Continue to Part 2**: Kubernetes Basics

## Why Not Lima?

While Lima is a great tool, we've moved away from it for this lab because:

- **Native options are faster**: No VM overhead
- **Better resource efficiency**: Direct access to host resources
- **Easier networking**: No complex VM networking setup
- **macOS optimization**: Tools are optimized for macOS
- **Industry standard**: Most teams use these tools directly

The skills you learn with Docker Desktop, Minikube, or Kind transfer directly to production environments.
