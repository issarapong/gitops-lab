# Part 4: ArgoCD Setup and Usage

ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes. It monitors Git repositories and automatically deploys changes to your cluster.

## What is ArgoCD?

ArgoCD features:

- **Declarative**: Uses Git as the source of truth
- **Automated**: Continuously monitors and deploys changes
- **Auditable**: Full deployment history and rollback capabilities
- **Secure**: No cluster credentials stored in Git repositories
- **Multi-tenant**: Supports multiple teams and environments
- **UI/CLI**: Rich web UI and powerful CLI tools

## Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Git Repo   │───▶│   ArgoCD    │───▶│ Kubernetes  │
│             │    │  Controller │    │   Cluster   │
│  Manifests  │    │             │    │             │
└─────────────┘    └─────────────┘    └─────────────┘
       ▲                   │
       │                   ▼
┌─────────────┐    ┌─────────────┐
│ Developer   │    │  ArgoCD UI  │
│             │    │             │
└─────────────┘    └─────────────┘
```

## Prerequisites

- Lima VM with k3s running (from previous parts)
- kubectl configured
- Git repository with application manifests

## Installation

### Step 1: Install ArgoCD

```bash
# Shell into Lima VM
limactl shell gitops

# Create argocd namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

### Step 2: Access ArgoCD UI

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access ArgoCD at https://localhost:8080
# Username: admin
# Password: (from command above)
```

### Step 3: Install ArgoCD CLI (Optional)

```bash
# Download ArgoCD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64

# Make executable and move to PATH
chmod +x argocd-linux-amd64
sudo mv argocd-linux-amd64 /usr/local/bin/argocd

# Verify installation
argocd version --client
```

### Step 4: Login with CLI

```bash
# Login to ArgoCD
argocd login localhost:8080

# Change admin password
argocd account update-password
```

## Creating Your First Application

### Method 1: Using the UI

1. Open ArgoCD UI at https://localhost:8080
2. Click "New App"
3. Fill in the application details:
   - **Application Name**: sample-app-dev
   - **Project**: default
   - **Repository URL**: file:///path/to/your/gitops/repo (or GitHub URL)
   - **Path**: clusters/dev/sample-app
   - **Destination Server**: https://kubernetes.default.svc
   - **Namespace**: dev

### Method 2: Using YAML

Create an ArgoCD Application manifest:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sample-app-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-username/gitops-repo
    targetRevision: HEAD
    path: clusters/dev/sample-app
  destination:
    server: https://kubernetes.default.svc
    namespace: dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

Apply the application:

```bash
kubectl apply -f sample-app-dev.yaml
```

### Method 3: Using ArgoCD CLI

```bash
# Create application with CLI
argocd app create sample-app-dev \
  --repo https://github.com/your-username/gitops-repo \
  --path clusters/dev/sample-app \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace dev \
  --sync-policy automated \
  --auto-prune \
  --self-heal
```

## ArgoCD Projects

Projects provide logical grouping and access control:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: sample-project
  namespace: argocd
spec:
  description: Sample project for GitOps lab
  
  # Source repositories
  sourceRepos:
  - 'https://github.com/your-username/gitops-repo'
  
  # Destination clusters and namespaces
  destinations:
  - namespace: 'dev'
    server: https://kubernetes.default.svc
  - namespace: 'staging'
    server: https://kubernetes.default.svc
  - namespace: 'production'
    server: https://kubernetes.default.svc
  
  # Cluster resource whitelist
  clusterResourceWhitelist:
  - group: ''
    kind: Namespace
  
  # Namespace resource whitelist
  namespaceResourceWhitelist:
  - group: 'apps'
    kind: Deployment
  - group: ''
    kind: Service
  - group: ''
    kind: ConfigMap
  - group: ''
    kind: Secret
```

## Sync Policies

### Manual Sync
Applications must be manually synced:

```yaml
syncPolicy: {}
```

### Automated Sync
Applications automatically sync when changes are detected:

```yaml
syncPolicy:
  automated:
    prune: true    # Delete resources not in Git
    selfHeal: true # Override manual changes
```

### Sync Options
Control sync behavior:

```yaml
syncPolicy:
  syncOptions:
  - CreateNamespace=true  # Create namespace if missing
  - PrunePropagationPolicy=foreground
  - PruneLast=true
```

## Application Sets

Manage multiple similar applications:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: sample-app-environments
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - env: dev
        namespace: dev
      - env: staging
        namespace: staging
      - env: production
        namespace: production
  template:
    metadata:
      name: 'sample-app-{{env}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/your-username/gitops-repo
        targetRevision: HEAD
        path: 'clusters/{{env}}/sample-app'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{namespace}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
        - CreateNamespace=true
```

## Multi-Environment Management

### Environment-specific Applications

```bash
# Create applications for each environment
argocd app create sample-app-dev \
  --repo https://github.com/your-username/gitops-repo \
  --path clusters/dev/sample-app \
  --dest-namespace dev

argocd app create sample-app-staging \
  --repo https://github.com/your-username/gitops-repo \
  --path clusters/staging/sample-app \
  --dest-namespace staging

argocd app create sample-app-prod \
  --repo https://github.com/your-username/gitops-repo \
  --path clusters/prod/sample-app \
  --dest-namespace production
```

### Progressive Deployment

Use different sync policies per environment:

```yaml
# Dev: Fully automated
syncPolicy:
  automated:
    prune: true
    selfHeal: true

# Staging: Auto-sync, manual prune
syncPolicy:
  automated:
    selfHeal: true

# Production: Manual sync only
syncPolicy: {}
```

## Monitoring and Observability

### Application Health

ArgoCD tracks application health:

- **Healthy**: All resources are healthy
- **Progressing**: Resources are being updated
- **Degraded**: Some resources are unhealthy
- **Suspended**: Application is suspended
- **Missing**: Resources are missing
- **Unknown**: Health status is unknown

### Sync Status

- **Synced**: Git matches cluster state
- **OutOfSync**: Git differs from cluster state
- **Unknown**: Sync status is unknown

### ArgoCD CLI Commands

```bash
# List applications
argocd app list

# Get application details
argocd app get sample-app-dev

# Sync application
argocd app sync sample-app-dev

# View application history
argocd app history sample-app-dev

# Rollback application
argocd app rollback sample-app-dev

# Delete application
argocd app delete sample-app-dev
```

## Troubleshooting

### Common Issues

#### Application Stuck in Progressing

```bash
# Check application events
kubectl describe application sample-app-dev -n argocd

# Check resource status
argocd app get sample-app-dev --show-operation
```

#### Sync Fails with Permission Error

```bash
# Check RBAC settings
kubectl get clusterrole argocd-application-controller -o yaml

# Check service account
kubectl get serviceaccount argocd-application-controller -n argocd -o yaml
```

#### Resource Health Check Fails

```yaml
# Add custom health check
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  resource.customizations: |
    your-crd-group/YourCRD:
      health.lua: |
        if obj.status ~= nil then
          if obj.status.phase == "Ready" then
            return {status = "Healthy", message = "Resource is ready"}
          end
        end
        return {status = "Progressing", message = "Waiting for resource to be ready"}
```

## Security Best Practices

### Repository Access

```yaml
# Use SSH keys for private repositories
apiVersion: v1
kind: Secret
metadata:
  name: private-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
data:
  type: Z2l0
  url: Z2l0QGdpdGh1Yi5jb206eW91ci11c2VybmFtZS9wcml2YXRlLXJlcG8uZ2l0
  sshPrivateKey: <base64-encoded-ssh-private-key>
```

### RBAC Configuration

```yaml
# ArgoCD RBAC policy
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    p, role:admin, applications, *, */*, allow
    p, role:admin, clusters, *, *, allow
    p, role:admin, repositories, *, *, allow
    
    p, role:developer, applications, get, default/*, allow
    p, role:developer, applications, sync, default/dev-*, allow
    
    g, your-github-org:admin-team, role:admin
    g, your-github-org:dev-team, role:developer
```

## App of Apps Pattern

Manage multiple applications with a single "app of apps":

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-username/gitops-repo
    targetRevision: HEAD
    path: applications
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Webhooks and Notifications

### GitHub Webhook

```bash
# Configure webhook URL in GitHub repository settings
# Webhook URL: https://your-argocd-server/api/webhook
# Content type: application/json
# Events: push, pull_request
```

### Slack Notifications

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.slack: |
    token: $slack-token
  template.app-deployed: |
    message: |
      Application {{.app.metadata.name}} is now running new version.
  trigger.on-deployed: |
    - when: app.status.operationState.phase in ['Succeeded'] and app.status.health.status == 'Healthy'
      send: [app-deployed]
  subscriptions: |
    - recipients:
      - slack:your-channel
      triggers:
      - on-deployed
```

## Performance Tuning

### Controller Settings

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmd-params-cm
  namespace: argocd
data:
  application.operation.timeout: "300"
  controller.operation.processors: "10"
  controller.status.processors: "20"
```

## Clean Up

```bash
# Delete applications
argocd app delete sample-app-dev
argocd app delete sample-app-staging
argocd app delete sample-app-prod

# Delete ArgoCD
kubectl delete namespace argocd
```

## Next Steps

Excellent! You now have ArgoCD managing your GitOps deployments. Next, let's explore Flux as an alternative GitOps tool in [Part 5: Flux Setup](../05-flux/README.md).

## Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/operator-manual/best_practices/)
- [ArgoCD Examples](https://github.com/argoproj/argocd-example-apps)
