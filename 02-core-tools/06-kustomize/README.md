# Part 6: Kustomize Configuration Management

Kustomize is a Kubernetes configuration management tool that lets you customize YAML configurations without templates. It's built into kubectl and widely used in GitOps workflows.

## What is Kustomize?

Kustomize provides:

- **Template-free**: No templating language required
- **Declarative**: Pure YAML configuration
- **Composable**: Layer configurations for different environments
- **Built-in**: Integrated with kubectl
- **GitOps-friendly**: Works seamlessly with ArgoCD and Flux

## Core Concepts

### Base and Overlays Structure

```text
kustomize-example/
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── overlays/
    ├── dev/
    │   └── kustomization.yaml
    ├── staging/
    │   └── kustomization.yaml
    └── prod/
        └── kustomization.yaml
```

### Key Kustomization Features

1. **Resources**: Base YAML files to include
2. **Patches**: Modifications to apply
3. **Images**: Image tag transformations
4. **Replicas**: Replica count overrides
5. **Generators**: Generate ConfigMaps and Secrets

## Basic Kustomize Commands

```bash
# Build and view output
kubectl kustomize ./base
kubectl kustomize ./overlays/dev

# Apply directly
kubectl apply -k ./overlays/dev

# Dry run
kubectl apply -k ./overlays/dev --dry-run=client -o yaml

# Build to file
kubectl kustomize ./overlays/prod > prod-manifests.yaml
```

## Working with the Examples

Navigate to the examples directory to see the structure:

```bash
cd /Volumes/Server/git-remote/github-issarapong/gitops/examples/lab/02-core-tools/06-kustomize/examples
```

### Step 1: Examine the Base

```bash
# View base resources
cat base/deployment.yaml
cat base/service.yaml
cat base/kustomization.yaml

# Build base configuration
kubectl kustomize base/
```

### Step 2: Build Environment Overlays

```bash
# Build dev overlay
kubectl kustomize overlays/dev/

# Build staging overlay  
kubectl kustomize overlays/staging/

# Build production overlay
kubectl kustomize overlays/prod/
```

### Step 3: Apply to Cluster

```bash
# Create namespaces
kubectl create namespace dev
kubectl create namespace staging  
kubectl create namespace production

# Apply dev environment
kubectl apply -k overlays/dev/

# Apply staging environment
kubectl apply -k overlays/staging/

# Apply production environment
kubectl apply -k overlays/prod/

# Verify deployments
kubectl get all -n dev
kubectl get all -n staging
kubectl get all -n production
```

## Advanced Kustomize Features

### JSON Patches

More precise control over modifications:

```yaml
# Strategic merge patch (simpler)
patchesStrategicMerge:
- deployment-patch.yaml

# JSON patch (more precise)
patches:
- target:
    kind: Deployment
    name: sample-app
  patch: |-
    - op: replace
      path: /spec/replicas
      value: 3
    - op: add
      path: /spec/template/spec/containers/0/env/-
      value:
        name: NEW_VAR
        value: "new-value"
```

### ConfigMap Generation

Generate ConfigMaps from files or literals:

```yaml
configMapGenerator:
- name: app-config
  files:
  - application.properties
  - logging.conf
- name: env-config
  literals:
  - ENV=production
  - DEBUG=false
  options:
    disableNameSuffixHash: true
```

### Secret Generation

Generate Secrets (be careful with Git):

```yaml
secretGenerator:
- name: app-secrets
  literals:
  - username=admin
  - password=secret123
  type: Opaque
```

### Variable Substitution

Use replacements for dynamic values:

```yaml
# In kustomization.yaml
replacements:
- source:
    kind: ConfigMap
    name: app-config
    fieldPath: data.version
  targets:
  - select:
      kind: Deployment
      name: sample-app
    fieldPaths:
    - spec.template.spec.containers.[name=app].image
    options:
      delimiter: ':'
      index: 1
```

### Multi-base Composition

Combine multiple bases:

```yaml
resources:
- ../../../base/app
- ../../../base/database
- ../../../base/monitoring

components:
- ../../../components/ingress
```

### Components

Reusable pieces across environments:

```text
components/
├── monitoring/
│   ├── servicemonitor.yaml
│   └── kustomization.yaml
└── ingress/
    ├── ingress.yaml
    └── kustomization.yaml
```

```yaml
# components/monitoring/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

resources:
- servicemonitor.yaml
```

## Best Practices

### 1. Directory Structure

```text
apps/
├── app1/
│   ├── base/
│   └── overlays/
│       ├── dev/
│       ├── staging/
│       └── prod/
└── app2/
    ├── base/
    └── overlays/
        ├── dev/
        ├── staging/
        └── prod/
```

### 2. Keep Bases Generic

- No environment-specific values in base
- Use overlays for customization
- Keep patches minimal and focused

### 3. Use Meaningful Names

```yaml
namePrefix: myapp-
nameSuffix: -v2

# Results in: myapp-deployment-v2
```

### 4. Version Control Strategy

- Tag releases for production
- Use branches for environments
- Keep secrets out of Git

### 5. Testing

```bash
# Always test before applying
kubectl kustomize overlays/prod/ | kubectl apply --dry-run=client -f -

# Use kubeval for validation
kubectl kustomize overlays/prod/ | kubeval
```

## GitOps Integration

### With ArgoCD

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sample-app-dev
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/your-org/k8s-manifests
    targetRevision: HEAD
    path: apps/sample-app/overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: dev
```

### With Flux

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
  path: "./apps/sample-app/overlays/dev"
  prune: true
  targetNamespace: dev
```

## Common Patterns

### 1. Environment Promotion

```bash
# Promote dev image to staging
kustomize edit set image nginx:1.21-dev nginx:1.21-staging
```

### 2. Feature Flags

```yaml
# Add feature flag via patch
patches:
- target:
    kind: Deployment
    name: sample-app
  patch: |-
    - op: add
      path: /spec/template/spec/containers/0/env/-
      value:
        name: FEATURE_X_ENABLED
        value: "true"
```

### 3. Blue-Green Deployments

```yaml
# Blue version
namePrefix: blue-
commonLabels:
  version: blue

# Green version  
namePrefix: green-
commonLabels:
  version: green
```

### 4. Resource Scaling

```yaml
# Scale by environment
replicas:
- name: sample-app
  count: 1  # dev
# count: 3  # staging  
# count: 10 # production
```

## Troubleshooting

### Common Issues

#### Kustomize Build Fails

```bash
# Check syntax
kubectl kustomize . --enable-alpha-plugins

# Validate individual files
kubectl apply --dry-run=client -f deployment.yaml
```

#### Patches Not Applied

```bash
# Check patch syntax
kubectl kustomize . | grep -A 10 -B 10 "expected-value"

# Use strategic merge instead of JSON patch
patchesStrategicMerge:
- deployment-patch.yaml
```

#### Name Conflicts

```bash
# Use namePrefix/nameSuffix
namePrefix: myapp-
nameSuffix: -v1
```

### Debugging Tips

```bash
# See what kustomize generates
kubectl kustomize overlays/dev/ > debug.yaml

# Compare environments
diff <(kubectl kustomize overlays/dev/) <(kubectl kustomize overlays/prod/)

# Validate with server-side dry run
kubectl kustomize overlays/prod/ | kubectl apply --server-dry-run -f -
```

## Kustomize vs Helm

| Feature | Kustomize | Helm |
|---------|-----------|------|
| Learning Curve | Lower | Higher |
| Templating | None | Go templates |
| Package Management | No | Yes |
| Version Management | Git-based | Chart versions |
| Complexity | Simple | More complex |
| GitOps Friendly | Excellent | Good |

## Performance Considerations

### Large Repositories

```bash
# Build specific overlay only
kubectl kustomize overlays/prod/

# Use .kustomizeignore
echo "*.md" >> .kustomizeignore
echo "docs/" >> .kustomizeignore
```

### Resource Limits

```yaml
# Set resource limits in overlays
patches:
- target:
    kind: Deployment
  patch: |-
    - op: add
      path: /spec/template/spec/containers/0/resources/limits
      value:
        memory: "1Gi"
        cpu: "500m"
```

## Clean Up

```bash
# Remove test deployments
kubectl delete namespace dev
kubectl delete namespace staging
kubectl delete namespace production
```

## Next Steps

Excellent! You now understand how to use Kustomize for configuration management. Next, let's explore Helm charts in [Part 7: Helm Charts](../07-helm/README.md).

## Additional Resources

- [Kustomize Documentation](https://kustomize.io/)
- [Kustomize GitHub](https://github.com/kubernetes-sigs/kustomize)
- [Kubectl Kustomize Reference](https://kubectl.docs.kubernetes.io/references/kustomize/)
- [Kustomize Best Practices](https://kubectl.docs.kubernetes.io/guides/config_management/)
