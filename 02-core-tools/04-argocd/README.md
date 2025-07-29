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

- Kubernetes cluster running (Docker Desktop, Minikube, or Kind)
- kubectl configured and connected to your cluster  
- Git repository with application manifests
- ArgoCD installed (check with `kubectl get pods -n argocd`)

## Installation

### Step 1: Install ArgoCD

```bash
# Create argocd namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready (this may take a few minutes)
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Verify ArgoCD installation
kubectl get pods -n argocd
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
# For macOS (using Homebrew)
brew install argocd

# For Linux (manual download)
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd-linux-amd64
sudo mv argocd-linux-amd64 /usr/local/bin/argocd

# For Windows (using Chocolatey)
choco install argocd-cli

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
   - **Repository URL**: `https://github.com/issarapong/gitops-lab`
   - **Path**: `01-foundation/03-gitops-intro/clusters/dev/sample-app`
   - **Destination Server**: `https://kubernetes.default.svc`
   - **Namespace**: dev

### Method 2: Using YAML

**Create file:** `sample-app-dev.yaml`

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
    repoURL: https://github.com/issarapong/gitops-lab
    targetRevision: HEAD
    path: 01-foundation/03-gitops-intro/clusters/dev/sample-app
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

**Apply the application:**

```bash
# Create the application manifest
kubectl apply -f sample-app-dev.yaml

# Verify application creation
kubectl get applications -n argocd
```

### Method 3: Using ArgoCD CLI

```bash
# Create application with CLI
argocd app create sample-app-dev \
  --repo https://github.com/issarapong/gitops-lab \
  --path 01-foundation/03-gitops-intro/clusters/dev/sample-app \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace dev \
  --sync-policy automated \
  --auto-prune \
  --self-heal
```

## ArgoCD Projects

**Create file:** `sample-project.yaml`

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
  - 'https://github.com/issarapong/gitops-lab'
  
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

**Apply the project:**

```bash
# Create the project
kubectl apply -f sample-project.yaml

# Verify project creation
kubectl get appprojects -n argocd
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

**Create file:** `sample-app-applicationset.yaml`

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
        repoURL: https://github.com/issarapong/gitops-lab
        targetRevision: HEAD
        path: '01-foundation/03-gitops-intro/clusters/{{env}}/sample-app'
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

**Apply the ApplicationSet:**

```bash
# Create the ApplicationSet
kubectl apply -f sample-app-applicationset.yaml

# Verify ApplicationSet creation
kubectl get applicationsets -n argocd

# Check generated applications
kubectl get applications -n argocd
```

## Multi-Environment Management

### Environment-specific Applications

**Action:** Create individual applications for each environment

```bash
# Create applications for each environment
argocd app create sample-app-dev \
  --repo https://github.com/issarapong/gitops-lab \
  --path 01-foundation/03-gitops-intro/clusters/dev/sample-app \
  --dest-namespace dev

argocd app create sample-app-staging \
  --repo https://github.com/issarapong/gitops-lab \
  --path 01-foundation/03-gitops-intro/clusters/staging/sample-app \
  --dest-namespace staging

argocd app create sample-app-prod \
  --repo https://github.com/issarapong/gitops-lab \
  --path 01-foundation/03-gitops-intro/clusters/prod/sample-app \
  --dest-namespace production

# Verify all applications
argocd app list
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

**Create file:** `private-repo-secret.yaml`

Use SSH keys for private repositories:

```yaml
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

**Apply the repository secret:**

```bash
# Create the secret
kubectl apply -f private-repo-secret.yaml

# Verify repository connection
argocd repo list
```

### RBAC Configuration

**Create file:** `argocd-rbac-cm.yaml`

```yaml
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

**Apply the RBAC configuration:**

```bash
# Apply RBAC policy
kubectl apply -f argocd-rbac-cm.yaml

# Restart ArgoCD server to reload RBAC
kubectl rollout restart deployment argocd-server -n argocd

# Verify RBAC policy
argocd account list
```

## App of Apps Pattern

**Create file:** `app-of-apps.yaml`

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
    repoURL: https://github.com/issarapong/gitops-lab
    targetRevision: HEAD
    path: 02-core-tools/04-argocd/applications
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Apply the App of Apps:**

```bash
# Create the app of apps
kubectl apply -f app-of-apps.yaml

# Verify the app of apps
kubectl get applications -n argocd

# Check child applications managed by app of apps
argocd app get app-of-apps --show-managed-resources
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

**Create file:** `argocd-notifications-cm.yaml`

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

**Apply the notifications configuration:**

```bash
# Create Slack token secret first
kubectl create secret generic slack-token \
  --from-literal=slack-token=your-slack-bot-token \
  -n argocd

# Apply notifications configuration
kubectl apply -f argocd-notifications-cm.yaml

# Restart notifications controller
kubectl rollout restart deployment argocd-notifications-controller -n argocd
```

## Performance Tuning

### Controller Settings

**Create file:** `argocd-cmd-params-cm.yaml`

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

**Apply performance tuning:**

```bash
# Apply performance configuration
kubectl apply -f argocd-cmd-params-cm.yaml

# Restart ArgoCD application controller
kubectl rollout restart deployment argocd-application-controller -n argocd

# Monitor controller performance
kubectl top pod -n argocd
```

## Clean Up

**Action:** Remove ArgoCD applications and components

```bash
# Delete applications
argocd app delete sample-app-dev
argocd app delete sample-app-staging
argocd app delete sample-app-prod

# Delete application namespaces
kubectl delete namespace dev staging production

# Delete ArgoCD completely
kubectl delete namespace argocd

# Verify cleanup
kubectl get namespaces
kubectl get applications -A
```

## Next Steps

Excellent! You now have ArgoCD managing your GitOps deployments. Next, let's explore Flux as an alternative GitOps tool in [Part 5: Flux Setup](../05-flux/README.md).

## Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/operator-manual/best_practices/)
- [ArgoCD Examples](https://github.com/argoproj/argocd-example-apps)
