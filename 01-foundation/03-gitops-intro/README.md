# Part 3: GitOps Introduction

GitOps is a paradigm for managing infrastructure and applications where Git repositories serve as the single source of truth for declarative infrastructure and applications.

## What is GitOps?

GitOps principles:

1. **Declarative**: The entire system is described declaratively
2. **Versioned and Immutable**: Configuration is stored in Git with full history
3. **Pulled Automatically**: Software agents automatically pull changes from Git
4. **Continuously Reconciled**: Software agents continuously reconcile the desired and actual state

## GitOps Workflow

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Developer │    │  Git Repo   │    │ GitOps Tool │    │  Kubernetes │
│             │───▶│             │───▶│             │───▶│   Cluster   │
│   Commits   │    │ Manifests   │    │  (ArgoCD/   │    │             │
│             │    │             │    │   Flux)     │    │             │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

## Repository Structure

A typical GitOps repository structure:

```
gitops-repo/
├── apps/                    # Application definitions
│   └── sample-app/
│       ├── deployment.yaml
│       └── service.yaml
├── infrastructure/          # Infrastructure components
│   ├── monitoring/
│   └── networking/
└── clusters/               # Environment-specific configs
    ├── dev/
    ├── staging/
    └── prod/
```

## Sample Application

We've created a sample nginx application with the following structure:

### Base Application (`apps/sample-app/`)

- `deployment.yaml`: Defines the application deployment
- `service.yaml`: Defines the service to expose the application

### Environment Configurations (`clusters/*/sample-app/`)

Each environment has its own kustomization that modifies the base application:

- **Dev**: 1 replica, development environment
- **Staging**: 2 replicas, staging environment  
- **Production**: 5 replicas, production environment, alpine image

## Testing the Configuration

### Step 1: Create Namespaces

```bash
# Create namespaces for each environment
kubectl create namespace dev
kubectl create namespace staging
kubectl create namespace production
```

### Step 2: Apply Dev Configuration

```bash
# Navigate to the gitops intro directory
cd /Volumes/Server/git-remote/github-issarapong/gitops/examples/lab/01-foundation/03-gitops-intro

# Apply dev configuration using kustomize
kubectl apply -k clusters/dev/sample-app/

# Check the deployment
kubectl get all -n dev
```

### Step 3: Apply Staging Configuration

```bash
# Apply staging configuration
kubectl apply -k clusters/staging/sample-app/

# Check the deployment
kubectl get all -n staging
```

### Step 4: Apply Production Configuration

```bash
# Apply production configuration
kubectl apply -k clusters/prod/sample-app/

# Check the deployment
kubectl get all -n production
```

### Step 5: Verify Differences

```bash
# Compare deployments across environments
kubectl get deployments -A | grep sample-app

# Check environment variables
kubectl get deployment sample-app -n dev -o jsonpath='{.spec.template.spec.containers[0].env[0].value}'
kubectl get deployment sample-app -n staging -o jsonpath='{.spec.template.spec.containers[0].env[0].value}'
kubectl get deployment sample-app -n production -o jsonpath='{.spec.template.spec.containers[0].env[0].value}'
```

## GitOps Benefits

### 1. Version Control
- All changes are tracked in Git
- Easy rollbacks using Git history
- Audit trail of who changed what and when

### 2. Declarative Configuration
- Describe desired state, not steps to achieve it
- Self-healing: system automatically corrects drift
- Predictable and repeatable deployments

### 3. Automation
- Automatic deployment from Git commits
- Reduced manual errors
- Faster deployment cycles

### 4. Security
- No cluster credentials in CI/CD pipelines
- Pull-based deployment model
- Git-based access control

### 5. Observability
- Clear deployment history in Git
- Easy to see what's deployed where
- Simplified troubleshooting

## GitOps Patterns

### 1. App of Apps Pattern

The "App of Apps" pattern allows you to manage multiple applications through a single ArgoCD application:

```yaml
# argocd-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: lab-applications
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/issarapong/gitops-lab
    targetRevision: HEAD
    path: 01-foundation/03-gitops-intro/clusters/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

This pattern is useful for:
- Managing multiple microservices
- Organizing applications by team or environment  
- Centralized application lifecycle management

### 2. Environment Promotion

Environment promotion in GitOps follows a controlled workflow where changes flow from development to higher environments:

```bash
# Development to Staging promotion
git checkout staging
git merge dev
git push origin staging

# Staging to Production promotion  
git checkout production
git merge staging
git push origin production

# Alternative: Using pull requests for promotion
# 1. Create PR: dev → staging
# 2. Review and merge
# 3. Create PR: staging → production
# 4. Review and merge
```

In our lab structure, you can simulate this by updating the kustomization files:

```bash
# Example: Promote a configuration change
# 1. Test in dev environment
kubectl apply -k clusters/dev/sample-app/

# 2. Copy successful changes to staging
cp clusters/dev/sample-app/kustomization.yaml clusters/staging/sample-app/
# Edit staging-specific values (replicas, etc.)

# 3. Apply to staging
kubectl apply -k clusters/staging/sample-app/

# 4. Promote to production after validation
cp clusters/staging/sample-app/kustomization.yaml clusters/prod/sample-app/
# Edit production-specific values
kubectl apply -k clusters/prod/sample-app/
```

### 3. Feature Branch Deployments

Create temporary environments for testing feature branches:

```yaml
# feature-branch-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sample-app-feature-auth
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/issarapong/gitops-lab
    targetRevision: feature/authentication
    path: 01-foundation/03-gitops-intro/clusters/dev/sample-app
  destination:
    server: https://kubernetes.default.svc
    namespace: feature-auth
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

Manual testing with feature branches:

```bash
# Create feature namespace
kubectl create namespace feature-test

# Test feature branch configuration locally
cd /path/to/feature-branch
kubectl apply -k clusters/dev/sample-app/ -n feature-test

# Clean up after testing
kubectl delete namespace feature-test
```

### 4. Kustomize Overlay Pattern

Our lab demonstrates the Kustomize overlay pattern for environment-specific configurations:

```bash
# Base application (shared configuration)
apps/sample-app/
├── deployment.yaml    # Base deployment
├── service.yaml      # Base service  
└── kustomization.yaml # Base kustomization

# Environment overlays
clusters/
├── dev/sample-app/
│   └── kustomization.yaml     # 1 replica, dev environment
├── staging/sample-app/ 
│   └── kustomization.yaml     # 2 replicas, staging environment
└── prod/sample-app/
    └── kustomization.yaml     # 3 replicas, production environment
```

Benefits of this pattern:
- **DRY principle**: Base configuration shared across environments
- **Environment isolation**: Each environment has its own namespace and config
- **Easy comparison**: Clear differences between environments
- **Version control**: All changes tracked in Git

Example differences in our lab:

```bash
# Dev: 1 replica, ENVIRONMENT=dev
kubectl get deployment sample-app -n dev -o jsonpath='{.spec.replicas}'
kubectl get deployment sample-app -n dev -o jsonpath='{.spec.template.spec.containers[0].env[0].value}'

# Staging: 2 replicas, ENVIRONMENT=staging  
kubectl get deployment sample-app -n staging -o jsonpath='{.spec.replicas}'
kubectl get deployment sample-app -n staging -o jsonpath='{.spec.template.spec.containers[0].env[0].value}'

# Production: 3 replicas, ENVIRONMENT=production
kubectl get deployment sample-app -n production -o jsonpath='{.spec.replicas}'
kubectl get deployment sample-app -n production -o jsonpath='{.spec.template.spec.containers[0].env[0].value}'
```

## Best Practices

### 1. Repository Structure
- Separate application code from deployment manifests
- Use separate repositories for different teams/environments
- Keep sensitive data in separate secret management systems

### 2. Branch Strategy
- Use environment branches (dev, staging, prod)
- Tag releases for production deployments
- Use feature branches for preview environments

### 3. Security
- Use sealed secrets or external secret management
- Implement proper RBAC in Git repositories
- Rotate secrets regularly

### 4. Monitoring
- Monitor Git repository changes
- Set up alerts for deployment failures
- Track deployment metrics and rollback frequency

## Common Anti-patterns

### ❌ Don't Do This

1. **Storing secrets in Git**: Never commit passwords or API keys
2. **Manual kubectl commands**: Avoid imperative changes to production
3. **Direct cluster access**: Don't bypass GitOps for "quick fixes"
4. **Mixing environments**: Don't use same manifests for all environments

### ✅ Do This Instead

1. **Use secret management tools**: External Secrets, Sealed Secrets
2. **Make changes via Git**: All changes should go through pull requests
3. **Use GitOps tools**: Let ArgoCD/Flux handle deployments
4. **Environment-specific configs**: Use Kustomize or Helm for variations

## Clean Up

```bash
# Remove test deployments
kubectl delete namespace dev
kubectl delete namespace staging  
kubectl delete namespace production
```

## Next Steps

Now that you understand GitOps principles, let's implement them with ArgoCD in [Part 4: ArgoCD Setup](../../02-core-tools/04-argocd/README.md).

## Additional Resources

- [OpenGitOps Principles](https://opengitops.dev/)
- [GitOps Working Group](https://github.com/gitops-working-group/gitops-working-group)
- [Weaveworks GitOps Guide](https://www.weave.works/technologies/gitops/)
