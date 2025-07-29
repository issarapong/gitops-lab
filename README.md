# GitOps Laboratory 🚀

A comprehensive hands-on laboratory for learning GitOps principles and practices using Kubernetes, ArgoCD, and Flux.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.25+-blue.svg)](https://kubernetes.io/)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-Latest-orange.svg)](https://argoproj.github.io/argo-cd/)
[![Flux](https://img.shields.io/badge/Flux-v2-purple.svg)](https://fluxcd.io/)

## 🎯 What You'll Learn

- **GitOps Fundamentals**: Core principles and workflows
- **Kubernetes Deployment**: Native Kubernetes setup (Docker Desktop, Minikube, Kind)
- **ArgoCD**: Declarative continuous deployment
- **Flux v2**: GitOps toolkit implementation
- **Kustomize**: Configuration management and environment promotion
- **Multi-Environment**: Dev, staging, and production workflows

## 🏗️ Repository Structure

```
gitops-lab/
├── 📁 01-foundation/           # Core concepts and setup
│   ├── 01-kubernetes-setup/   # Native Kubernetes installation
│   ├── 02-kubernetes-basics/  # Kubernetes fundamentals
│   └── 03-gitops-intro/       # GitOps principles + working examples
├── 📁 02-core-tools/           # GitOps tools
│   ├── 04-argocd/            # ArgoCD installation and examples
│   ├── 05-flux/              # Flux v2 setup and workflows
│   └── 06-kustomize/         # Advanced Kustomize patterns
├── 📁 03-advanced-scenarios/   # Real-world scenarios
│   ├── 07-multi-cluster/     # Multi-cluster management
│   ├── 08-secrets-management/# Secret handling best practices
│   └── 09-monitoring/        # Observability and monitoring
├── 📁 scripts/                # Automation scripts
│   ├── lab-startup.sh        # 🚀 Main lab automation
│   ├── troubleshoot.sh       # 🔧 Diagnostic tools
│   └── github-setup.sh       # 📦 Repository setup
└── 📄 README.md              # This file
```

## 🚀 Quick Start

### Prerequisites

- **Kubernetes**: Docker Desktop, Minikube, or Kind
- **Git**: Version control
- **kubectl**: Kubernetes CLI
- **curl**: For downloading tools

### Option 1: Automated Setup (Recommended)

```bash
# Clone this repository
git clone https://github.com/issarapong/gitops-lab.git
cd gitops-lab

# Run the lab startup script
./scripts/lab-startup.sh
```

The script will:
- ✅ Check prerequisites
- ✅ Start Kubernetes cluster
- ✅ Install ArgoCD and Flux
- ✅ Deploy sample applications
- ✅ Provide guided navigation

### Option 2: Manual Setup

```bash
# 1. Setup Kubernetes
cd 01-foundation/01-kubernetes-setup
./setup.sh

# 2. Learn Kubernetes basics
cd ../02-kubernetes-basics
./run-examples.sh

# 3. Explore GitOps concepts
cd ../03-gitops-intro
kubectl apply -k clusters/dev/sample-app/
```

## 🧪 Hands-On Examples

### Multi-Environment Deployment

Experience GitOps environment promotion:

```bash
# Create namespaces
kubectl create namespace dev
kubectl create namespace staging
kubectl create namespace production

# Deploy to all environments
kubectl apply -k 01-foundation/03-gitops-intro/clusters/dev/sample-app/
kubectl apply -k 01-foundation/03-gitops-intro/clusters/staging/sample-app/
kubectl apply -k 01-foundation/03-gitops-intro/clusters/prod/sample-app/

# Verify different configurations
kubectl get deployments -A | grep sample-app
```

**Results**:
- **Dev**: 1 replica, development configuration
- **Staging**: 2 replicas, staging configuration  
- **Production**: 3 replicas, production configuration

### ArgoCD GitOps Workflow

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Apply lab applications
kubectl apply -f 02-core-tools/04-argocd/applications/github-sample-apps.yaml

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### Flux GitOps Workflow

```bash
# Install Flux CLI
curl -s https://fluxcd.io/install.sh | sudo bash

# Bootstrap Flux
flux bootstrap github \
  --owner=YOUR_USERNAME \
  --repository=gitops-lab \
  --branch=main \
  --path=./clusters/production

# Apply GitRepository and Kustomizations
kubectl apply -f 02-core-tools/05-flux/github-gitrepository.yaml
```

## 🌟 Key Features

### ✅ **No Lima Dependency**
- Uses native Kubernetes (Docker Desktop/Minikube/Kind)
- Cross-platform compatibility
- Simple setup process

### ✅ **Working Examples**
- Complete multi-environment deployment
- Real GitOps workflows
- Practical configurations

### ✅ **Comprehensive Coverage**
- GitOps principles and patterns
- ArgoCD and Flux implementations
- Kustomize overlay patterns
- Environment promotion workflows

### ✅ **Production-Ready Patterns**
- Secret management
- Multi-cluster scenarios
- Monitoring and observability
- Security best practices

## 🎓 Learning Path

### 📚 **Foundation (Start Here)**
1. [Kubernetes Setup](01-foundation/01-kubernetes-setup/README.md) - Native K8s installation
2. [Kubernetes Basics](01-foundation/02-kubernetes-basics/README.md) - Core concepts
3. [GitOps Introduction](01-foundation/03-gitops-intro/README.md) - Principles + examples

### 🔧 **Core Tools**
4. [ArgoCD](02-core-tools/04-argocd/README.md) - Declarative CD
5. [Flux v2](02-core-tools/05-flux/README.md) - GitOps toolkit
6. [Kustomize](02-core-tools/06-kustomize/README.md) - Configuration management

### 🏢 **Advanced Scenarios**
7. [Multi-Cluster](03-advanced-scenarios/07-multi-cluster/README.md) - Scale across clusters
8. [Secrets Management](03-advanced-scenarios/08-secrets-management/README.md) - Secure operations
9. [Monitoring](03-advanced-scenarios/09-monitoring/README.md) - Observability

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Workflow

```bash
# Fork the repository
# Clone your fork
git clone https://github.com/issarapong/gitops-lab.git

# Create feature branch
git checkout -b feature/your-improvement

# Make changes and test
./scripts/lab-startup.sh  # Verify everything works

# Commit and push
git commit -m "Add: your improvement"
git push origin feature/your-improvement

# Create Pull Request
```

## 🆘 Troubleshooting

### Common Issues

**Kubernetes not starting?**
```bash
./scripts/troubleshoot.sh
```

**ArgoCD login issues?**
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

**Flux not syncing?**
```bash
flux get all
flux logs --follow
```

## 📖 Additional Resources

- [GitOps Principles](https://opengitops.dev/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Flux Documentation](https://fluxcd.io/flux/)
- [Kustomize Documentation](https://kustomize.io/)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- GitOps Working Group for principles and patterns
- ArgoCD and Flux communities for excellent tools
- Kubernetes community for the foundation
- All contributors and learners using this lab

---

**Happy GitOps Learning!** 🎉

Start your journey: `./scripts/lab-startup.sh`
