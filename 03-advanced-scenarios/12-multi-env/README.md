# Part 12: Multi-environment Deployment

This section covers implementing robust multi-environment deployment strategies using GitOps principles with real-world scenarios, progressive delivery, and environment promotion workflows.

## Multi-environment Strategy

### Environment Topology

```text
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Feature   │───▶│     Dev     │───▶│   Staging   │───▶│ Production  │
│ Environment │    │             │    │             │    │             │
│  (Preview)  │    │ - Fast CI   │    │ - Full Test │    │ - Manual    │
│             │    │ - Auto Sync │    │ - Auto Sync │    │ - Approval  │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

### Environment Characteristics

| Environment | Purpose | Sync Policy | Resource Allocation | Testing Level |
|-------------|---------|-------------|-------------------|---------------|
| **Feature/Preview** | PR Testing | Automatic | Minimal | Unit + Integration |
| **Development** | Integration | Automatic | Low | Integration + API |
| **Staging** | Pre-production | Automatic | Medium | Full End-to-End |
| **Production** | Live System | Manual | High | Smoke + Monitoring |

## Repository Structure for Multi-env

```text
gitops-platform/
├── applications/           # Application definitions
│   ├── sample-app/
│   │   ├── base/
│   │   └── overlays/
│   └── shared-services/
├── environments/          # Environment-specific configs
│   ├── dev/
│   │   ├── cluster-config/
│   │   ├── applications/
│   │   └── infrastructure/
│   ├── staging/
│   ├── prod/
│   └── preview/
├── infrastructure/        # Shared infrastructure
│   ├── networking/
│   ├── security/
│   └── monitoring/
├── clusters/             # Multi-cluster configs
│   ├── dev-cluster/
│   ├── staging-cluster/
│   └── prod-cluster/
└── scripts/              # Automation scripts
    ├── promote.sh
    └── validate.sh
```

## Environment Configuration

### Development Environment

```yaml
# environments/dev/config/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: development

resources:
- ../../../applications/sample-app/base
- ../../../infrastructure/monitoring
- ../../../infrastructure/networking

commonLabels:
  environment: development
  stability: unstable
  cost-center: development

# Development-specific settings
replicas:
- name: sample-app
  count: 1

patches:
- target:
    kind: Deployment
  patch: |-
    - op: replace
      path: /spec/template/spec/containers/0/resources
      value:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 500m
          memory: 256Mi
- target:
    kind: Deployment
  patch: |-
    - op: add
      path: /spec/template/spec/containers/0/env/-
      value:
        name: LOG_LEVEL
        value: DEBUG
    - op: add
      path: /spec/template/spec/containers/0/env/-
      value:
        name: ENVIRONMENT
        value: development

configMapGenerator:
- name: environment-config
  literals:
  - database_url=postgresql://dev-db:5432/devdb
  - redis_url=redis://dev-redis:6379
  - external_api_url=https://api-dev.example.com
  - debug_enabled=true
  - metrics_enabled=true
```

### Staging Environment

```yaml
# environments/staging/config/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: staging

resources:
- ../../../applications/sample-app/base
- ../../../infrastructure/monitoring
- ../../../infrastructure/networking
- ../../../infrastructure/security

commonLabels:
  environment: staging
  stability: testing
  cost-center: engineering

replicas:
- name: sample-app
  count: 2

patches:
- target:
    kind: Deployment
  patch: |-
    - op: replace
      path: /spec/template/spec/containers/0/resources
      value:
        requests:
          cpu: 250m
          memory: 256Mi
        limits:
          cpu: 1000m
          memory: 512Mi
- target:
    kind: Deployment
  patch: |-
    - op: add
      path: /spec/template/spec/containers/0/env/-
      value:
        name: LOG_LEVEL
        value: INFO
    - op: add
      path: /spec/template/spec/containers/0/env/-
      value:
        name: ENVIRONMENT
        value: staging

# Staging-specific configuration
configMapGenerator:
- name: environment-config
  literals:
  - database_url=postgresql://staging-db:5432/stagingdb
  - redis_url=redis://staging-redis:6379
  - external_api_url=https://api-staging.example.com
  - debug_enabled=false
  - metrics_enabled=true
  - performance_monitoring=true

# Add ingress for staging
patchesStrategicMerge:
- ingress.yaml
```

### Production Environment

```yaml
# environments/prod/config/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: production

resources:
- ../../../applications/sample-app/base
- ../../../infrastructure/monitoring
- ../../../infrastructure/networking
- ../../../infrastructure/security
- hpa.yaml
- pdb.yaml

commonLabels:
  environment: production
  stability: stable
  cost-center: operations
  criticality: high

replicas:
- name: sample-app
  count: 5

patches:
- target:
    kind: Deployment
  patch: |-
    - op: replace
      path: /spec/template/spec/containers/0/resources
      value:
        requests:
          cpu: 500m
          memory: 512Mi
        limits:
          cpu: 2000m
          memory: 1Gi
- target:
    kind: Deployment
  patch: |-
    - op: add
      path: /spec/template/spec/containers/0/env/-
      value:
        name: LOG_LEVEL
        value: WARN
    - op: add
      path: /spec/template/spec/containers/0/env/-
      value:
        name: ENVIRONMENT
        value: production
    - op: add
      path: /spec/template/spec/containers/0/env/-
      value:
        name: PRODUCTION_MODE
        value: "true"

configMapGenerator:
- name: environment-config
  literals:
  - database_url=postgresql://prod-db-cluster:5432/proddb
  - redis_url=redis://prod-redis-cluster:6379
  - external_api_url=https://api.example.com
  - debug_enabled=false
  - metrics_enabled=true
  - performance_monitoring=true
  - security_scanning=true
  - backup_enabled=true

images:
- name: sample-app
  newTag: "stable"
```

## GitOps Tools Integration

### ArgoCD Multi-environment Setup

```yaml
# argocd/projects/platform-project.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: platform
  namespace: argocd
spec:
  description: Platform applications across all environments
  
  sourceRepos:
  - 'https://github.com/issarapong/gitops-lab
  
  destinations:
  - namespace: 'development'
    server: 'https://kubernetes.default.svc'
  - namespace: 'staging'
    server: 'https://kubernetes.default.svc'
  - namespace: 'production'
    server: 'https://kubernetes.default.svc'
  - namespace: 'preview-*'
    server: 'https://kubernetes.default.svc'
  
  clusterResourceWhitelist:
  - group: ''
    kind: Namespace
  - group: 'networking.k8s.io'
    kind: NetworkPolicy
  
  namespaceResourceWhitelist:
  - group: '*'
    kind: '*'
  
  roles:
  - name: developers
    description: Developers can sync dev and staging
    policies:
    - p, proj:platform:developers, applications, sync, platform/dev-*, allow
    - p, proj:platform:developers, applications, sync, platform/staging-*, allow
    - p, proj:platform:developers, applications, get, platform/*, allow
    groups:
    - developers
  
  - name: operators
    description: Operators can manage all environments
    policies:
    - p, proj:platform:operators, applications, *, platform/*, allow
    groups:
    - operators
```

```yaml
# argocd/applications/applicationset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: platform-environments
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - env: dev
        namespace: development
        project: platform
        syncPolicy: |
          automated:
            prune: true
            selfHeal: true
          syncOptions:
          - CreateNamespace=true
      - env: staging
        namespace: staging
        project: platform
        syncPolicy: |
          automated:
            prune: true
            selfHeal: true
          syncOptions:
          - CreateNamespace=true
      - env: prod
        namespace: production
        project: platform
        syncPolicy: |
          syncOptions:
          - CreateNamespace=true
  template:
    metadata:
      name: 'platform-{{env}}'
      labels:
        environment: '{{env}}'
    spec:
      project: '{{project}}'
      source:
        repoURL: https://github.com/issarapong/gitops-lab
        targetRevision: HEAD
        path: 'environments/{{env}}/config'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{namespace}}'
      syncPolicy: '{{syncPolicy}}'
```

### Flux Multi-environment Setup

```yaml
# flux/clusters/dev/kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: platform-dev
  namespace: flux-system
spec:
  interval: 1m
  sourceRef:
    kind: GitRepository
    name: platform-repo
  path: "./environments/dev/config"
  prune: true
  timeout: 5m
  validation: client
  targetNamespace: development
  postBuild:
    substitute:
      environment: "development"
      cluster_name: "dev-cluster"
```

```yaml
# flux/clusters/staging/kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: platform-staging
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: platform-repo
  path: "./environments/staging/config"
  prune: true
  timeout: 10m
  validation: client
  targetNamespace: staging
  dependsOn:
  - name: platform-dev
  postBuild:
    substitute:
      environment: "staging"
      cluster_name: "staging-cluster"
```

```yaml
# flux/clusters/prod/kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: platform-prod
  namespace: flux-system
spec:
  interval: 30m
  sourceRef:
    kind: GitRepository
    name: platform-repo
  path: "./environments/prod/config"
  prune: false  # Manual approval for production
  timeout: 15m
  validation: client
  targetNamespace: production
  suspend: true  # Manual approval required
  postBuild:
    substitute:
      environment: "production"
      cluster_name: "prod-cluster"
```

## Environment Promotion Pipeline

### Automated Promotion Script

```bash
#!/bin/bash
# scripts/promote.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
FROM_ENV=""
TO_ENV=""
APP_NAME=""
VERSION=""
DRY_RUN=false
SKIP_TESTS=false

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --from-env ENV        Source environment (dev, staging)"
    echo "  --to-env ENV          Target environment (staging, prod)"
    echo "  --app APP_NAME        Application name"
    echo "  --version VERSION     Version to promote"
    echo "  --dry-run             Show what would be done"
    echo "  --skip-tests          Skip validation tests"
    echo "  -h, --help            Show this help"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --from-env)
            FROM_ENV="$2"
            shift 2
            ;;
        --to-env)
            TO_ENV="$2"
            shift 2
            ;;
        --app)
            APP_NAME="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option $1"
            usage
            ;;
    esac
done

# Validation
validate_inputs() {
    if [[ -z "$FROM_ENV" ]] || [[ -z "$TO_ENV" ]] || [[ -z "$APP_NAME" ]] || [[ -z "$VERSION" ]]; then
        echo "Error: Missing required parameters"
        usage
    fi
    
    if [[ ! -d "$REPO_ROOT/environments/$FROM_ENV" ]]; then
        echo "Error: Source environment '$FROM_ENV' not found"
        exit 1
    fi
    
    if [[ ! -d "$REPO_ROOT/environments/$TO_ENV" ]]; then
        echo "Error: Target environment '$TO_ENV' not found"
        exit 1
    fi
}

# Run tests for the target environment
run_tests() {
    if [[ "$SKIP_TESTS" == "true" ]]; then
        echo "Skipping tests..."
        return 0
    fi
    
    echo "Running validation tests for $TO_ENV environment..."
    
    # Build and validate manifests
    echo "Validating Kubernetes manifests..."
    kubectl kustomize "$REPO_ROOT/environments/$TO_ENV/config" > /tmp/manifests.yaml
    
    # Validate with kubeval
    if command -v kubeval &> /dev/null; then
        kubeval /tmp/manifests.yaml
    fi
    
    # Security scanning
    if command -v trivy &> /dev/null; then
        echo "Running security scan..."
        trivy config /tmp/manifests.yaml
    fi
    
    # Custom validation script
    if [[ -f "$REPO_ROOT/scripts/validate-$TO_ENV.sh" ]]; then
        echo "Running custom validation for $TO_ENV..."
        "$REPO_ROOT/scripts/validate-$TO_ENV.sh" "$APP_NAME" "$VERSION"
    fi
}

# Update image version in target environment
update_version() {
    local env_dir="$REPO_ROOT/environments/$TO_ENV/config"
    local kustomization_file="$env_dir/kustomization.yaml"
    
    echo "Updating $APP_NAME to version $VERSION in $TO_ENV environment..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] Would update $kustomization_file"
        echo "[DRY RUN] Setting image $APP_NAME:$VERSION"
        return 0
    fi
    
    # Update kustomization.yaml with new image version
    if grep -q "name: $APP_NAME" "$kustomization_file"; then
        # Update existing image
        yq eval -i "(.images[] | select(.name == \"$APP_NAME\").newTag) = \"$VERSION\"" "$kustomization_file"
    else
        # Add new image entry
        yq eval -i ".images += [{\"name\": \"$APP_NAME\", \"newTag\": \"$VERSION\"}]" "$kustomization_file"
    fi
    
    echo "Updated $APP_NAME to version $VERSION"
}

# Create pull request
create_pull_request() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] Would create pull request for promotion"
        return 0
    fi
    
    # Create branch
    local branch="promote-$APP_NAME-$VERSION-to-$TO_ENV"
    git checkout -b "$branch"
    
    # Commit changes
    git add "environments/$TO_ENV/config/kustomization.yaml"
    git commit -m "Promote $APP_NAME to $VERSION in $TO_ENV environment

- Application: $APP_NAME
- Version: $VERSION
- Source: $FROM_ENV
- Target: $TO_ENV
- Promoted by: $(git config user.name)
- Date: $(date -Iseconds)"
    
    # Push branch
    git push origin "$branch"
    
    # Create PR using GitHub CLI if available
    if command -v gh &> /dev/null; then
        gh pr create \
            --title "Promote $APP_NAME v$VERSION to $TO_ENV" \
            --body "## Promotion Details

- **Application**: $APP_NAME
- **Version**: $VERSION
- **Source Environment**: $FROM_ENV
- **Target Environment**: $TO_ENV
- **Promoted by**: $(git config user.name)

## Validation Status
- [ ] Manifests validated
- [ ] Security scan passed
- [ ] Custom validation passed

## Deployment Notes
Please review the changes and approve for deployment to $TO_ENV." \
            --assignee "@me"
    else
        echo "Created branch '$branch'. Please create a pull request manually."
    fi
}

# Main execution
main() {
    echo "Starting promotion process..."
    echo "From: $FROM_ENV"
    echo "To: $TO_ENV"
    echo "App: $APP_NAME"
    echo "Version: $VERSION"
    echo "Dry run: $DRY_RUN"
    echo
    
    validate_inputs
    run_tests
    update_version
    create_pull_request
    
    echo "Promotion process completed successfully!"
}

# Execute main function
main
```

### GitHub Actions Workflow

```yaml
# .github/workflows/environment-promotion.yml
name: Environment Promotion

on:
  pull_request:
    types: [closed]
    branches: [main]
    paths:
    - 'environments/*/config/**'

jobs:
  detect-promotion:
    if: github.event.pull_request.merged == true
    runs-on: ubuntu-latest
    outputs:
      promote-to-staging: ${{ steps.check.outputs.promote-to-staging }}
      promote-to-prod: ${{ steps.check.outputs.promote-to-prod }}
      app-name: ${{ steps.check.outputs.app-name }}
      version: ${{ steps.check.outputs.version }}
    steps:
    - uses: actions/checkout@v3
      with:
        fetch-depth: 2
    
    - name: Detect promotion
      id: check
      run: |
        # Check if dev environment was updated
        if git diff HEAD~1 HEAD --name-only | grep -q "environments/dev/config/"; then
          echo "promote-to-staging=true" >> $GITHUB_OUTPUT
          # Extract app name and version from changes
          APP_NAME=$(git diff HEAD~1 HEAD environments/dev/config/kustomization.yaml | grep "name:" | head -1 | awk '{print $3}')
          VERSION=$(git diff HEAD~1 HEAD environments/dev/config/kustomization.yaml | grep "newTag:" | head -1 | awk '{print $3}')
          echo "app-name=$APP_NAME" >> $GITHUB_OUTPUT
          echo "version=$VERSION" >> $GITHUB_OUTPUT
        fi
        
        # Check if staging environment was updated
        if git diff HEAD~1 HEAD --name-only | grep -q "environments/staging/config/"; then
          echo "promote-to-prod=true" >> $GITHUB_OUTPUT
        fi

  promote-to-staging:
    needs: detect-promotion
    if: needs.detect-promotion.outputs.promote-to-staging == 'true'
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Auto-promote to staging
      run: |
        ./scripts/promote.sh \
          --from-env dev \
          --to-env staging \
          --app ${{ needs.detect-promotion.outputs.app-name }} \
          --version ${{ needs.detect-promotion.outputs.version }}
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  promote-to-prod:
    needs: detect-promotion
    if: needs.detect-promotion.outputs.promote-to-prod == 'true'
    runs-on: ubuntu-latest
    environment: production-approval
    steps:
    - uses: actions/checkout@v3
    
    - name: Manual approval for production
      uses: trstringer/manual-approval@v1
      with:
        secret: ${{ secrets.GITHUB_TOKEN }}
        approvers: ops-team,senior-developers
        minimum-approvals: 2
        issue-title: "Deploy to Production: ${{ needs.detect-promotion.outputs.app-name }} v${{ needs.detect-promotion.outputs.version }}"
    
    - name: Promote to production
      run: |
        ./scripts/promote.sh \
          --from-env staging \
          --to-env prod \
          --app ${{ needs.detect-promotion.outputs.app-name }} \
          --version ${{ needs.detect-promotion.outputs.version }}
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Monitoring and Observability

### Environment Health Dashboard

```yaml
# monitoring/grafana-dashboard-environments.json
{
  "dashboard": {
    "title": "Multi-Environment Health",
    "panels": [
      {
        "title": "Application Versions by Environment",
        "type": "table",
        "targets": [
          {
            "expr": "kube_deployment_labels{label_app=\"sample-app\"}",
            "format": "table"
          }
        ]
      },
      {
        "title": "Environment Resource Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(rate(container_cpu_usage_seconds_total[5m])) by (namespace)",
            "legendFormat": "{{namespace}}"
          }
        ]
      },
      {
        "title": "Deployment Success Rate",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(rate(argocd_app_reconcile_count{phase=\"Succeeded\"}[24h])) / sum(rate(argocd_app_reconcile_count[24h]))"
          }
        ]
      }
    ]
  }
}
```

### Alerts for Environment Issues

```yaml
# monitoring/alerts/environment-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: environment-alerts
spec:
  groups:
  - name: environment-health
    rules:
    - alert: EnvironmentSyncFailed
      expr: argocd_app_health_status{health_status!="Healthy"} == 1
      for: 5m
      labels:
        severity: warning
        environment: "{{ $labels.dest_namespace }}"
      annotations:
        summary: "Environment sync failed"
        description: "ArgoCD application {{ $labels.name }} in {{ $labels.dest_namespace }} is not healthy"
    
    - alert: EnvironmentVersionMismatch
      expr: |
        count by (app) (
          count by (app, version) (
            kube_deployment_labels{label_app!=""}
          )
        ) > 1
      for: 10m
      labels:
        severity: info
      annotations:
        summary: "Multiple versions detected"
        description: "Application {{ $labels.app }} has multiple versions running across environments"
    
    - alert: ProductionDeploymentPending
      expr: argocd_app_sync_status{dest_namespace="production",sync_status="OutOfSync"} == 1
      for: 30m
      labels:
        severity: warning
      annotations:
        summary: "Production deployment pending"
        description: "Production environment has pending changes for over 30 minutes"
```

## Best Practices

### 1. Environment Isolation

```yaml
# Network policies for environment isolation
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: environment-isolation
  namespace: development
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: development
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: development
  - to: []  # Allow egress to external services
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
```

### 2. Resource Quotas per Environment

```yaml
# Resource quotas
apiVersion: v1
kind: ResourceQuota
metadata:
  name: environment-quota
  namespace: development
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    persistentvolumeclaims: "10"
    services: "20"
    secrets: "50"
    configmaps: "50"
```

### 3. Environment-specific Service Accounts

```yaml
# Service account with environment-specific permissions
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-service-account
  namespace: development
  annotations:
    iam.gke.io/gcp-service-account: dev-workload-identity@project.iam.gserviceaccount.com

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: development
  name: app-role
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch"]
```

## Troubleshooting Multi-environment Issues

### Common Problems

#### Version Drift Detection

```bash
#!/bin/bash
# scripts/check-version-drift.sh

echo "Checking version drift across environments..."

for env in dev staging prod; do
    echo "=== $env environment ==="
    kubectl kustomize "environments/$env/config" | \
        grep -E "image:|newTag:" | \
        sed 's/^[[:space:]]*//' | \
        sort
    echo
done
```

#### Environment Sync Issues

```bash
# Check ArgoCD application status
kubectl get applications -n argocd -o custom-columns=\
NAME:.metadata.name,\
HEALTH:.status.health.status,\
SYNC:.status.sync.status,\
NAMESPACE:.spec.destination.namespace

# Force refresh and sync
argocd app sync platform-dev --force
argocd app sync platform-staging --force
```

#### Resource Conflicts

```bash
# Check for resource conflicts
kubectl api-resources --verbs=list --namespaced -o name | \
    xargs -n 1 kubectl get -n development -o name | \
    grep -E "(deployment|service|configmap)" | \
    sort
```

## Clean Up

```bash
# Clean up all environments
for env in development staging production; do
    kubectl delete namespace $env
done

# Clean up ArgoCD resources
kubectl delete applications -n argocd -l environment
kubectl delete appprojects -n argocd platform

# Clean up Flux resources
kubectl delete kustomizations -n flux-system -l environment
```

## Next Steps

Congratulations! You've now implemented a complete multi-environment deployment strategy. The GitOps lab provides you with:

- ✅ **Foundation**: Lima, Kubernetes, GitOps principles
- ✅ **Core Tools**: ArgoCD, Flux, Kustomize, Helm
- ✅ **Advanced Topics**: External Secrets, Keptn, Jenkins X, Overlay Patterns
- ✅ **Real-world Scenarios**: Multi-environment deployment

Continue exploring with the remaining scenarios:
- [Part 13: Disaster Recovery](../13-disaster-recovery/README.md)
- [Part 14: Security Best Practices](../14-security/README.md)

## Additional Resources

- [GitOps Principles](https://opengitops.dev/)
- [Environment Promotion Strategies](https://cloud.google.com/architecture/application-deployment-and-testing-strategies)
- [Multi-environment GitOps](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [Progressive Delivery](https://redhat-scholars.github.io/argocd-tutorial/argocd-tutorial/index.html)
