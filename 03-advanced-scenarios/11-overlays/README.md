# Part 11: Advanced Overlay Patterns

This section covers advanced overlay patterns for managing complex multi-environment, multi-tenant, and multi-cluster deployments using Kustomize and other configuration management tools.

## What are Overlay Patterns?

Overlay patterns provide:

- **Environment Separation**: Different configurations per environment
- **Multi-tenancy**: Isolated configurations for different teams/customers
- **Feature Flags**: Conditional feature deployment
- **Cross-cutting Concerns**: Shared configurations across multiple applications
- **Progressive Rollouts**: Gradual feature deployment strategies

## Advanced Kustomize Patterns

### 1. Hierarchical Overlays

```text
overlays/
├── common/                 # Shared across all environments
│   ├── kustomization.yaml
│   ├── monitoring.yaml
│   └── networking.yaml
├── cloud/                  # Cloud-specific configs
│   ├── aws/
│   │   ├── kustomization.yaml
│   │   ├── storage.yaml
│   │   └── networking.yaml
│   └── gcp/
│       ├── kustomization.yaml
│       └── storage.yaml
└── environments/           # Environment-specific
    ├── dev/
    │   ├── aws/
    │   └── gcp/
    ├── staging/
    └── prod/
```

#### Common Base Configuration

```yaml
# overlays/common/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

# Common labels for all environments
commonLabels:
  managed-by: kustomize
  project: sample-app

# Common monitoring
patchesStrategicMerge:
- monitoring.yaml
- networking.yaml
```

```yaml
# overlays/common/monitoring.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/path: "/metrics"
        prometheus.io/port: "8080"
    spec:
      containers:
      - name: app
        env:
        - name: METRICS_ENABLED
          value: "true"
```

#### Cloud-specific Overlays

```yaml
# overlays/cloud/aws/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../common

patchesStrategicMerge:
- storage.yaml
- networking.yaml

# AWS-specific labels
commonLabels:
  cloud-provider: aws
```

```yaml
# overlays/cloud/aws/storage.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app
spec:
  template:
    spec:
      containers:
      - name: app
        env:
        - name: STORAGE_TYPE
          value: "s3"
        - name: AWS_REGION
          value: "us-west-2"
        volumeMounts:
        - name: aws-credentials
          mountPath: /var/secrets/aws
          readOnly: true
      volumes:
      - name: aws-credentials
        secret:
          secretName: aws-credentials
```

#### Environment + Cloud Composition

```yaml
# overlays/environments/prod/aws/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: production

resources:
- ../../../cloud/aws

# Production-specific settings
replicas:
- name: sample-app
  count: 5

patches:
- target:
    kind: Deployment
    name: sample-app
  patch: |-
    - op: replace
      path: /spec/template/spec/containers/0/resources/limits/cpu
      value: "2000m"
    - op: replace
      path: /spec/template/spec/containers/0/resources/limits/memory
      value: "2Gi"

# Production labels
commonLabels:
  environment: production
  tier: critical
```

### 2. Component-based Architecture

```text
components/
├── database/
│   ├── kustomization.yaml
│   ├── postgresql.yaml
│   └── redis.yaml
├── monitoring/
│   ├── kustomization.yaml
│   ├── prometheus.yaml
│   └── grafana.yaml
├── security/
│   ├── kustomization.yaml
│   ├── network-policy.yaml
│   └── pod-security-policy.yaml
└── ingress/
    ├── kustomization.yaml
    ├── nginx-ingress.yaml
    └── cert-manager.yaml
```

#### Database Component

```yaml
# components/database/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

resources:
- postgresql.yaml
- redis.yaml

# Component-specific transformations
commonLabels:
  component: database

configMapGenerator:
- name: database-config
  literals:
  - POSTGRES_DB=appdb
  - REDIS_HOST=redis-service
```

#### Using Components in Overlays

```yaml
# overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: production

resources:
- ../../base

components:
- ../../components/database
- ../../components/monitoring
- ../../components/security
- ../../components/ingress

# Override component settings
patches:
- target:
    kind: StatefulSet
    name: postgresql
  patch: |-
    - op: replace
      path: /spec/replicas
      value: 3
    - op: replace
      path: /spec/template/spec/containers/0/resources/requests/memory
      value: "2Gi"
```

### 3. Multi-tenant Patterns

```text
tenants/
├── tenant-a/
│   ├── base/
│   │   ├── kustomization.yaml
│   │   └── tenant-config.yaml
│   └── environments/
│       ├── dev/
│       ├── staging/
│       └── prod/
├── tenant-b/
│   ├── base/
│   └── environments/
└── shared/
    ├── components/
    └── policies/
```

#### Tenant Base Configuration

```yaml
# tenants/tenant-a/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../../base
- tenant-config.yaml

namePrefix: tenant-a-
namespace: tenant-a

commonLabels:
  tenant: tenant-a
  billing-code: "12345"

# Tenant-specific resource quotas
patchesStrategicMerge:
- resource-quota.yaml
```

```yaml
# tenants/tenant-a/base/tenant-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: tenant-config
data:
  tenant-name: "Tenant A"
  features: "feature-a,feature-b"
  tier: "premium"
  support-contact: "support-tenant-a@company.com"

---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-quota
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    persistentvolumeclaims: "10"
    services: "20"
```

#### Tenant Environment Overlay

```yaml
# tenants/tenant-a/environments/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

# Production settings for tenant-a
replicas:
- name: sample-app
  count: 3

patches:
- target:
    kind: ConfigMap
    name: tenant-config
  patch: |-
    - op: replace
      path: /data/features
      value: "feature-a,feature-b,premium-feature"
    - op: add
      path: /data/environment
      value: "production"

# Tenant-specific ingress
patchesStrategicMerge:
- ingress-override.yaml
```

### 4. Feature Flag Patterns

#### Feature Toggle Configuration

```yaml
# overlays/features/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

# Feature flags via ConfigMap generator
configMapGenerator:
- name: feature-flags
  literals:
  - FEATURE_NEW_UI=true
  - FEATURE_BETA_API=false
  - FEATURE_ADVANCED_ANALYTICS=true
  - FEATURE_A_B_TESTING=true
  options:
    disableNameSuffixHash: true

# Apply feature flags to deployment
patches:
- target:
    kind: Deployment
    name: sample-app
  patch: |-
    - op: add
      path: /spec/template/spec/containers/0/envFrom/-
      value:
        configMapRef:
          name: feature-flags
```

#### Progressive Feature Rollout

```yaml
# overlays/rollout/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

# Canary deployment with feature flag
replicas:
- name: sample-app
  count: 2
- name: sample-app-canary
  count: 1

patchesStrategicMerge:
- canary-deployment.yaml
- traffic-split.yaml
```

```yaml
# overlays/rollout/canary-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app-canary
spec:
  selector:
    matchLabels:
      app: sample-app
      version: canary
  template:
    metadata:
      labels:
        app: sample-app
        version: canary
    spec:
      containers:
      - name: app
        image: sample-app:canary
        env:
        - name: FEATURE_NEW_ALGORITHM
          value: "true"
        - name: VERSION
          value: "canary"
```

### 5. Cross-cutting Concerns

#### Security Policies Overlay

```yaml
# overlays/security/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

# Apply security policies
patchesStrategicMerge:
- security-context.yaml
- network-policy.yaml
- pod-security-policy.yaml

# Security labels
commonLabels:
  security-scan: "required"
  compliance: "required"
```

```yaml
# overlays/security/security-context.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 3000
        fsGroup: 2000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: app
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: tmp-volume
          mountPath: /tmp
        - name: cache-volume
          mountPath: /app/cache
      volumes:
      - name: tmp-volume
        emptyDir: {}
      - name: cache-volume
        emptyDir: {}
```

#### Monitoring Overlay

```yaml
# overlays/monitoring/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base
- servicemonitor.yaml
- alerts.yaml

# Monitoring annotations
commonAnnotations:
  monitoring.coreos.com/scrape: "true"
  monitoring.coreos.com/path: "/metrics"
  monitoring.coreos.com/port: "8080"

patches:
- target:
    kind: Deployment
    name: sample-app
  patch: |-
    - op: add
      path: /spec/template/spec/containers/0/env/-
      value:
        name: METRICS_ENABLED
        value: "true"
    - op: add
      path: /spec/template/spec/containers/0/ports/-
      value:
        name: metrics
        containerPort: 8080
        protocol: TCP
```

## Advanced Helm Patterns

### 1. Umbrella Charts

```text
umbrella-chart/
├── Chart.yaml
├── values.yaml
├── charts/                 # Subcharts
│   ├── app-1/
│   ├── app-2/
│   └── shared-services/
└── templates/
    ├── namespace.yaml
    └── network-policy.yaml
```

```yaml
# Chart.yaml
apiVersion: v2
name: platform-umbrella
description: Complete platform deployment
version: 1.0.0
dependencies:
- name: sample-app
  version: "0.1.0"
  repository: "file://./charts/sample-app"
  condition: sample-app.enabled
- name: database
  version: "11.6.12"
  repository: "https://charts.bitnami.com/bitnami"
  condition: database.enabled
- name: monitoring
  version: "19.0.3"
  repository: "https://prometheus-community.github.io/helm-charts"
  condition: monitoring.enabled
```

### 2. Chart Templates with Overlays

```yaml
# values-prod.yaml
global:
  environment: production
  replicaCount: 3
  resources:
    limits:
      cpu: 1000m
      memory: 1Gi

sample-app:
  enabled: true
  image:
    tag: "1.2.3"
  ingress:
    enabled: true
    hosts:
    - sample-app.production.com

database:
  enabled: true
  primary:
    persistence:
      size: 100Gi
  auth:
    existingSecret: database-credentials

monitoring:
  enabled: true
  prometheus:
    prometheusSpec:
      retention: "30d"
      storageSpec:
        volumeClaimTemplate:
          spec:
            resources:
              requests:
                storage: 50Gi
```

## GitOps Integration Patterns

### 1. App of Apps with Overlays

```yaml
# argocd/app-of-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/issarapong/gitops-lab
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

```yaml
# applications/sample-app-envs.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: sample-app-environments
  namespace: argocd
spec:
  generators:
  - matrix:
      generators:
      - list:
          elements:
          - env: dev
            namespace: dev
            replicaCount: 1
          - env: staging
            namespace: staging
            replicaCount: 2
          - env: prod
            namespace: production
            replicaCount: 5
      - clusters: {}
  template:
    metadata:
      name: 'sample-app-{{env}}-{{name}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/your-org/k8s-manifests
        targetRevision: HEAD
        path: 'overlays/{{env}}'
      destination:
        server: '{{server}}'
        namespace: '{{namespace}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
        - CreateNamespace=true
```

### 2. Flux with Overlay Patterns

```yaml
# flux/clusters/production/kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: platform-production
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: platform-repo
  path: "./overlays/prod"
  prune: true
  validation: client
  timeout: 5m
  postBuild:
    substitute:
      cluster_name: "production-cluster"
      region: "us-west-2"
    substituteFrom:
    - kind: ConfigMap
      name: cluster-config
    - kind: Secret
      name: cluster-secrets
```

## Testing Overlay Patterns

### 1. Kustomize Testing

```bash
# Test overlay build
kubectl kustomize overlays/prod/ > test-output.yaml

# Validate with kubeval
kubectl kustomize overlays/prod/ | kubeval

# Dry-run apply
kubectl kustomize overlays/prod/ | kubectl apply --dry-run=client -f -

# Compare environments
diff <(kubectl kustomize overlays/staging/) <(kubectl kustomize overlays/prod/)
```

### 2. Helm Testing

```bash
# Test template rendering
helm template sample-app ./charts/sample-app \
  --values values-prod.yaml \
  --debug

# Test with different values
helm template sample-app ./charts/sample-app \
  --values values-dev.yaml \
  --set replicaCount=1

# Validate output
helm template sample-app ./charts/sample-app \
  --values values-prod.yaml | kubeval
```

### 3. Automated Testing

```yaml
# .github/workflows/test-overlays.yml
name: Test Overlays
on:
  pull_request:
    paths:
    - 'overlays/**'
    - 'base/**'

jobs:
  test-kustomize:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        overlay: [dev, staging, prod]
    steps:
    - uses: actions/checkout@v2
    - name: Test overlay
      run: |
        kubectl kustomize overlays/${{ matrix.overlay }}/ > /tmp/output.yaml
        kubeval /tmp/output.yaml
    - name: Security scan
      run: |
        kubectl kustomize overlays/${{ matrix.overlay }}/ | \
        docker run --rm -i aquasec/trivy config --exit-code 1 -
```

## Best Practices

### 1. Organization Patterns

```text
# Recommended structure
├── base/                   # Common resources
├── components/            # Reusable components
├── overlays/             # Environment-specific
│   ├── dev/
│   ├── staging/
│   └── prod/
├── tenants/              # Multi-tenant configs
├── clusters/             # Multi-cluster configs
└── tests/                # Testing configurations
```

### 2. Naming Conventions

```yaml
# Consistent naming
namePrefix: "${ENVIRONMENT}-"
nameSuffix: "-${VERSION}"

commonLabels:
  app.kubernetes.io/name: sample-app
  app.kubernetes.io/component: backend
  app.kubernetes.io/part-of: platform
  app.kubernetes.io/managed-by: kustomize
  app.kubernetes.io/version: "1.2.3"
  environment: production
  tenant: tenant-a
```

### 3. Resource Management

```yaml
# Consistent resource patterns
patches:
- target:
    kind: Deployment
  patch: |-
    - op: replace
      path: /spec/template/spec/containers/0/resources
      value:
        requests:
          cpu: "{{ .Values.resources.requests.cpu }}"
          memory: "{{ .Values.resources.requests.memory }}"
        limits:
          cpu: "{{ .Values.resources.limits.cpu }}"
          memory: "{{ .Values.resources.limits.memory }}"
```

### 4. Security Patterns

```yaml
# Apply security consistently
commonAnnotations:
  seccomp.security.alpha.kubernetes.io/pod: runtime/default

patches:
- target:
    kind: Deployment
  patch: |-
    - op: add
      path: /spec/template/spec/securityContext
      value:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
```

## Troubleshooting

### Common Issues

#### Overlay Conflicts

```bash
# Debug overlay application
kubectl kustomize overlays/prod/ --enable-alpha-plugins -v=6

# Check for naming conflicts
kubectl kustomize overlays/prod/ | grep -E '^  name:'

# Validate final output
kubectl kustomize overlays/prod/ | kubectl apply --dry-run=client -f -
```

#### Resource Ordering

```yaml
# Use transformers for ordering
transformers:
- ordering-transformer.yaml

# ordering-transformer.yaml
apiVersion: builtin
kind: OrderTransformer
metadata:
  name: ordering
spec:
  order:
  - Namespace
  - ResourceQuota
  - ServiceAccount
  - Secret
  - ConfigMap
  - PersistentVolume
  - PersistentVolumeClaim
  - Service
  - Deployment
  - Ingress
```

## Clean Up

```bash
# Clean up test deployments
kubectl delete -k overlays/dev/
kubectl delete -k overlays/staging/
kubectl delete -k overlays/prod/

# Clean up namespaces
kubectl delete namespace dev staging production tenant-a tenant-b
```

## Next Steps

Excellent! You now understand advanced overlay patterns for complex deployments. Next, let's explore real-world scenarios starting with [Part 12: Multi-environment Deployment](../../04-scenarios/12-multi-env/README.md).

## Additional Resources

- [Kustomize Advanced Patterns](https://kubectl.docs.kubernetes.io/guides/config_management/)
- [Helm Chart Patterns](https://helm.sh/docs/chart_best_practices/)
- [GitOps Toolkit](https://toolkit.fluxcd.io/)
- [ArgoCD Patterns](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/)
