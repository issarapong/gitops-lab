# Part 5: Flux Setup and Usage

Flux is a GitOps toolkit for Kubernetes that automatically ensures that the state of your cluster matches the configuration in Git.

## What is Flux v2?

Flux v2 features:

- **Declarative**: Uses Git as the source of truth
- **Modular**: Composed of specialized controllers
- **Extensible**: Supports custom resources and plugins
- **Secure**: Built-in security scanning and policies
- **Multi-tenancy**: Supports multiple teams and environments
- **Progressive Delivery**: Canary deployments and feature flags

## Architecture

Flux v2 consists of several controllers:

```text
┌─────────────────┐    ┌─────────────────┐
│  Source Controller │    │ Kustomize Controller│
│                 │    │                 │
│ - GitRepository │    │ - Kustomization │
│ - HelmRepository│    │                 │
│ - Bucket        │    │                 │
└─────────────────┘    └─────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐    ┌─────────────────┐
│ Helm Controller │    │Notification Controller│
│                 │    │                 │
│ - HelmRelease   │    │ - Provider      │
│                 │    │ - Alert         │
└─────────────────┘    └─────────────────┘
```

## Prerequisites

- Lima VM with k3s running
- kubectl configured
- Git repository with application manifests

## Installation

### Step 1: Install Flux CLI

```bash
# Shell into Lima VM
limactl shell gitops

# Install Flux CLI
curl -s https://fluxcd.io/install.sh | sudo bash

# Verify installation
flux --version
```

### Step 2: Bootstrap Flux

```bash
# Check cluster prerequisites
flux check --pre

# Bootstrap Flux (using GitHub)
export GITHUB_TOKEN=<your-github-token>
export GITHUB_USER=<your-github-username>

flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=gitops-fleet \
  --branch=main \
  --path=./clusters/lima \
  --personal
```

### Step 3: Verify Installation

```bash
# Check Flux system
flux check

# List Flux resources
kubectl get all -n flux-system

# Check Flux logs
flux logs --follow
```

## Creating Your First GitRepository

### Step 1: Create GitRepository Resource

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: sample-app-repo
  namespace: flux-system
spec:
  interval: 1m
  ref:
    branch: main
  url: https://github.com/your-username/gitops-repo
```

Apply the GitRepository:

```bash
kubectl apply -f - <<EOF
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: sample-app-repo
  namespace: flux-system
spec:
  interval: 1m
  ref:
    branch: main
  url: https://github.com/your-username/gitops-repo
EOF
```

### Step 2: Create Kustomization Resource

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: sample-app-dev
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: sample-app-repo
  path: "./clusters/dev/sample-app"
  prune: true
  validation: client
  targetNamespace: dev
```

Apply the Kustomization:

```bash
kubectl apply -f - <<EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: sample-app-dev
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: sample-app-repo
  path: "./clusters/dev/sample-app"
  prune: true
  validation: client
  targetNamespace: dev
EOF
```

## Flux CLI Commands

```bash
# Get sources
flux get sources git

# Get kustomizations
flux get kustomizations

# Suspend reconciliation
flux suspend kustomization sample-app-dev

# Resume reconciliation
flux resume kustomization sample-app-dev

# Force reconciliation
flux reconcile kustomization sample-app-dev --with-source

# Export resources
flux export source git sample-app-repo
flux export kustomization sample-app-dev
```

## Multi-Environment Setup

### Step 1: Create Environment Structure

```bash
# Directory structure for multi-environment
mkdir -p clusters/{dev,staging,prod}
```

### Step 2: Environment-specific Kustomizations

```yaml
# Dev environment
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: sample-app-dev
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: sample-app-repo
  path: "./clusters/dev"
  prune: true
  targetNamespace: dev
```

```yaml
# Staging environment
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: sample-app-staging
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: sample-app-repo
  path: "./clusters/staging"
  prune: true
  targetNamespace: staging
  dependsOn:
  - name: sample-app-dev
```

```yaml
# Production environment
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: sample-app-prod
  namespace: flux-system
spec:
  interval: 30m
  sourceRef:
    kind: GitRepository
    name: sample-app-repo
  path: "./clusters/prod"
  prune: true
  targetNamespace: production
  dependsOn:
  - name: sample-app-staging
```

## Helm Integration

### Step 1: Add Helm Repository

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: nginx-helm
  namespace: flux-system
spec:
  interval: 10m
  url: https://kubernetes.github.io/ingress-nginx
```

### Step 2: Create HelmRelease

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: nginx-ingress
  namespace: flux-system
spec:
  interval: 15m
  chart:
    spec:
      chart: ingress-nginx
      version: "4.7.1"
      sourceRef:
        kind: HelmRepository
        name: nginx-helm
  values:
    controller:
      replicaCount: 2
      service:
        type: LoadBalancer
  targetNamespace: ingress-nginx
  install:
    createNamespace: true
```

## Image Automation

### Step 1: Install Image Automation Controllers

```bash
flux install --components-extra=image-reflector-controller,image-automation-controller
```

### Step 2: Create ImageRepository

```yaml
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageRepository
metadata:
  name: nginx-repo
  namespace: flux-system
spec:
  image: nginx
  interval: 1m
```

### Step 3: Create ImagePolicy

```yaml
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImagePolicy
metadata:
  name: nginx-policy
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: nginx-repo
  policy:
    semver:
      range: ">=1.20.0"
```

### Step 4: Create ImageUpdateAutomation

```yaml
apiVersion: image.toolkit.fluxcd.io/v1beta1
kind: ImageUpdateAutomation
metadata:
  name: sample-app-auto
  namespace: flux-system
spec:
  interval: 30m
  sourceRef:
    kind: GitRepository
    name: sample-app-repo
  git:
    checkout:
      ref:
        branch: main
    commit:
      author:
        email: fluxcdbot@users.noreply.github.com
        name: fluxcdbot
      messageTemplate: |
        Automated image update
        
        Automation name: {{ .AutomationObject }}
        
        Files:
        {{ range $filename, $_ := .Updated.Files -}}
        - {{ $filename }}
        {{ end -}}
        
        Objects:
        {{ range $resource, $_ := .Updated.Objects -}}
        - {{ $resource.Kind }} {{ $resource.Name }}
        {{ end -}}
        
        Images:
        {{ range .Updated.Images -}}
        - {{.}}
        {{ end -}}
    push:
      branch: main
  update:
    path: "./clusters"
    strategy: Setters
```

## Notifications and Alerts

### Step 1: Create Notification Provider

```yaml
# Slack provider
apiVersion: notification.toolkit.fluxcd.io/v1beta1
kind: Provider
metadata:
  name: slack
  namespace: flux-system
spec:
  type: slack
  channel: gitops-alerts
  secretRef:
    name: slack-webhook-url
```

### Step 2: Create Alert

```yaml
apiVersion: notification.toolkit.fluxcd.io/v1beta1
kind: Alert
metadata:
  name: sample-app-alert
  namespace: flux-system
spec:
  providerRef:
    name: slack
  eventSeverity: info
  eventSources:
  - kind: Kustomization
    name: sample-app-dev
  - kind: Kustomization
    name: sample-app-staging
  - kind: Kustomization
    name: sample-app-prod
  summary: "Sample app deployment status"
```

## Multi-tenancy with Flux

### Step 1: Create Tenant Namespace

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-a
  labels:
    toolkit.fluxcd.io/tenant: tenant-a
```

### Step 2: Create Tenant GitRepository

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: tenant-a-repo
  namespace: tenant-a
spec:
  interval: 1m
  ref:
    branch: main
  url: https://github.com/tenant-a/apps
```

### Step 3: Create Tenant Kustomization

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: tenant-a-apps
  namespace: tenant-a
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: tenant-a-repo
  path: "./apps"
  prune: true
  validation: client
```

## Progressive Delivery with Flagger

### Step 1: Install Flagger

```bash
# Add Flagger Helm repository
flux create source helm flagger \
  --url=https://flagger.app

# Install Flagger
flux create helmrelease flagger \
  --source=HelmRepository/flagger \
  --chart=flagger \
  --target-namespace=flagger-system \
  --create-target-namespace=true
```

### Step 2: Create Canary Deployment

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: sample-app-canary
  namespace: dev
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: sample-app
  progressDeadlineSeconds: 60
  service:
    port: 80
    targetPort: 80
  analysis:
    interval: 1m
    threshold: 5
    iterations: 10
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 1m
    - name: request-duration
      thresholdRange:
        max: 0.5
      interval: 1m
```

## Monitoring Flux

### Step 1: Check System Status

```bash
# Check overall health
flux check

# Get all sources
flux get sources all

# Get all kustomizations
flux get kustomizations

# Get events
flux events
```

### Step 2: Monitor with Prometheus

```yaml
# ServiceMonitor for Flux controllers
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: flux-system
  namespace: flux-system
spec:
  selector:
    matchLabels:
      app.kubernetes.io/instance: flux-system
  endpoints:
  - port: http-prom
    interval: 15s
    path: /metrics
```

## Security Best Practices

### Step 1: Use SSH Keys for Private Repositories

```bash
# Generate SSH key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/flux

# Create secret
kubectl create secret generic ssh-credentials \
  --from-file=identity=~/.ssh/flux \
  --from-file=identity.pub=~/.ssh/flux.pub \
  --from-file=known_hosts=~/.ssh/known_hosts \
  -n flux-system
```

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: private-repo
  namespace: flux-system
spec:
  interval: 1m
  url: ssh://git@github.com/your-username/private-repo
  secretRef:
    name: ssh-credentials
```

### Step 2: Enable Security Scanning

```yaml
# Enable security scanning in Kustomization
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: secure-app
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: sample-app-repo
  path: "./apps/secure-app"
  validation: client
  kubeConfig:
    secretRef:
      name: kubeconfig
```

## Troubleshooting

### Common Issues

#### GitRepository Sync Fails

```bash
# Check GitRepository status
kubectl describe gitrepository sample-app-repo -n flux-system

# Check events
flux events --for GitRepository/sample-app-repo
```

#### Kustomization Fails

```bash
# Check Kustomization status
kubectl describe kustomization sample-app-dev -n flux-system

# Get detailed logs
flux logs --kind=Kustomization --name=sample-app-dev
```

#### Reconciliation Stuck

```bash
# Force reconciliation
flux reconcile source git sample-app-repo
flux reconcile kustomization sample-app-dev
```

## Performance Tuning

### Controller Configuration

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: flux-system-config
  namespace: flux-system
data:
  # Increase concurrent reconciliations
  concurrent: "10"
  # Adjust requeue interval
  requeue-dependency: "30s"
```

## Backup and Disaster Recovery

### Step 1: Backup Flux Configuration

```bash
# Export all Flux resources
flux export source git --all > flux-sources.yaml
flux export kustomization --all > flux-kustomizations.yaml
flux export helmrelease --all > flux-helmreleases.yaml
```

### Step 2: Restore Flux Configuration

```bash
# Restore from backup
kubectl apply -f flux-sources.yaml
kubectl apply -f flux-kustomizations.yaml
kubectl apply -f flux-helmreleases.yaml
```

## Clean Up

```bash
# Uninstall Flux
flux uninstall --namespace=flux-system

# Delete CRDs (optional)
kubectl delete crd -l app.kubernetes.io/part-of=flux
```

## Comparison: Flux vs ArgoCD

| Feature | Flux v2 | ArgoCD |
|---------|---------|---------|
| Architecture | Controller-based | Server-based |
| UI | Limited | Rich Web UI |
| CLI | Powerful | Feature-rich |
| Multi-tenancy | Native | Project-based |
| Helm Support | Native | Plugin-based |
| Image Automation | Built-in | External tools |
| Progressive Delivery | Flagger integration | Argo Rollouts |
| Learning Curve | Moderate | Easier |

## Next Steps

Great! You now understand both ArgoCD and Flux. Next, let's dive deeper into configuration management with [Part 6: Kustomize](../06-kustomize/README.md).

## Additional Resources

- [Flux Documentation](https://fluxcd.io/docs/)
- [Flux GitHub Repository](https://github.com/fluxcd/flux2)
- [Flux Community](https://fluxcd.io/community/)
