# Part 7: Helm Charts

Helm is the package manager for Kubernetes. It helps you manage Kubernetes applications through Helm Charts, which are collections of files that describe a related set of Kubernetes resources.

## What is Helm?

Helm provides:

- **Package Management**: Install, upgrade, and manage applications
- **Templating**: Use Go templates for dynamic configurations
- **Release Management**: Track deployment history and rollbacks
- **Dependency Management**: Manage chart dependencies
- **Repository System**: Share and discover charts

## Helm Architecture

```text
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Helm CLI  │───▶│  Kubernetes │───▶│    Pods     │
│             │    │   Cluster   │    │  Services   │
│  (Client)   │    │             │    │   etc.      │
└─────────────┘    └─────────────┘    └─────────────┘
       │
       ▼
┌─────────────┐
│  Chart Repo │
│             │
│  (Storage)  │
└─────────────┘
```

## Prerequisites

- Kubernetes cluster running (Docker Desktop, Minikube, or Kind)
- kubectl configured

## Installation

### Step 1: Install Helm

```bash
# Ensure you're using the GitOps lab kubeconfig
export KUBECONFIG="$HOME/.kube/config-gitops-lab"

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
helm version
```

### Step 2: Add Chart Repositories

```bash
# Add popular repositories
helm repo add stable https://charts.helm.sh/stable
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Update repositories
helm repo update

# List repositories
helm repo list

# Search for charts
helm search repo nginx
helm search repo postgresql
```

## Basic Helm Commands

```bash
# Install a chart
helm install my-nginx bitnami/nginx

# List releases
helm list

# Get release status
helm status my-nginx

# Upgrade release
helm upgrade my-nginx bitnami/nginx --set replicaCount=2

# Rollback release
helm rollback my-nginx 1

# Uninstall release
helm uninstall my-nginx

# Get release history
helm history my-nginx
```

## Working with the Example Chart

Navigate to the examples directory:

```bash
cd /Volumes/Server/git-remote/github-issarapong/gitops/examples/lab/02-core-tools/07-helm/examples
```

### Step 1: Examine Chart Structure

```bash
# View chart structure
tree sample-app/

# Validate chart
helm lint sample-app/

# Template and view output
helm template my-sample-app sample-app/
```

### Step 2: Install Chart

```bash
# Install with default values
helm install sample-app-dev sample-app/ --namespace dev --create-namespace

# Install with custom values
helm install sample-app-staging sample-app/ \
  --namespace staging \
  --create-namespace \
  --set replicaCount=2 \
  --set config.environment=staging \
  --set config.logLevel=debug

# Install with values file
helm install sample-app-prod sample-app/ \
  --namespace production \
  --create-namespace \
  --values sample-app/values-prod.yaml
```

### Step 3: Manage Releases

```bash
# List all releases
helm list --all-namespaces

# Check status
helm status sample-app-dev -n dev

# Upgrade release
helm upgrade sample-app-dev sample-app/ \
  --namespace dev \
  --set image.tag=1.22

# View history
helm history sample-app-dev -n dev

# Rollback if needed
helm rollback sample-app-dev 1 -n dev
```

## Helm Templates

### Template Functions

```yaml
# String functions
name: {{ .Values.name | upper }}
version: {{ .Chart.Version | quote }}

# Default values
port: {{ .Values.port | default 8080 }}

# Conditionals
{{- if .Values.ingress.enabled }}
# Ingress configuration
{{- end }}

# Loops
{{- range .Values.environments }}
- name: {{ . }}
{{- end }}

# Include templates
{{- include "myapp.labels" . | nindent 4 }}
```

### Helper Templates

```yaml
# templates/_helpers.tpl
{{/*
Expand the name of the chart.
*/}}
{{- define "sample-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "sample-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "sample-app.labels" -}}
helm.sh/chart: {{ include "sample-app.chart" . }}
{{ include "sample-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
```

## Environment-specific Values

### Development Values

```yaml
# values-dev.yaml
replicaCount: 1

image:
  tag: "latest"

config:
  environment: development
  logLevel: debug
  features:
    caching: false
    monitoring: false

resources:
  limits:
    cpu: 200m
    memory: 64Mi
  requests:
    cpu: 100m
    memory: 32Mi

ingress:
  enabled: true
  hosts:
  - host: sample-app-dev.local
    paths:
    - path: /
      pathType: Prefix
```

### Production Values

```yaml
# values-prod.yaml
replicaCount: 5

image:
  tag: "1.21"

config:
  environment: production
  logLevel: error
  features:
    caching: true
    monitoring: true

resources:
  limits:
    cpu: 1000m
    memory: 256Mi
  requests:
    cpu: 500m
    memory: 128Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
  - host: sample-app.production.com
    paths:
    - path: /
      pathType: Prefix
  tls:
  - secretName: sample-app-tls
    hosts:
    - sample-app.production.com
```

## Chart Dependencies

### Adding Dependencies

```yaml
# Chart.yaml
dependencies:
- name: postgresql
  version: "11.6.12"
  repository: https://charts.bitnami.com/bitnami
  condition: postgresql.enabled
- name: redis
  version: "16.13.2"
  repository: https://charts.bitnami.com/bitnami
  condition: redis.enabled
```

```bash
# Download dependencies
helm dependency update sample-app/

# Build dependencies
helm dependency build sample-app/
```

### Managing Dependencies

```yaml
# values.yaml
postgresql:
  enabled: true
  auth:
    postgresPassword: secretpassword
    database: myapp
  primary:
    persistence:
      enabled: true
      size: 8Gi

redis:
  enabled: true
  auth:
    enabled: true
    password: redispassword
```

## Chart Testing

### Unit Tests

```yaml
# templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "sample-app.fullname" . }}-test"
  labels:
    {{- include "sample-app.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": test
spec:
  restartPolicy: Never
  containers:
  - name: wget
    image: busybox
    command: ['wget']
    args: ['{{ include "sample-app.fullname" . }}:{{ .Values.service.port }}']
```

```bash
# Run tests
helm test sample-app-dev -n dev
```

### Linting and Validation

```bash
# Lint chart
helm lint sample-app/

# Template with validation
helm template sample-app-test sample-app/ --debug

# Install with dry-run
helm install sample-app-test sample-app/ --dry-run --debug
```

## GitOps Integration

### With ArgoCD

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sample-app-helm
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/helm-charts
    chart: sample-app
    targetRevision: 0.1.0
    helm:
      valueFiles:
      - values-prod.yaml
      parameters:
      - name: replicaCount
        value: "3"
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

### With Flux

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: sample-app-repo
  namespace: flux-system
spec:
  interval: 1m
  url: https://your-org.github.io/helm-charts

---
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: sample-app
  namespace: flux-system
spec:
  interval: 15m
  chart:
    spec:
      chart: sample-app
      version: "0.1.0"
      sourceRef:
        kind: HelmRepository
        name: sample-app-repo
  values:
    replicaCount: 3
    config:
      environment: production
  targetNamespace: production
  install:
    createNamespace: true
```

## Chart Repository

### Creating a Chart Repository

```bash
# Package chart
helm package sample-app/

# Create repository index
helm repo index . --url https://your-org.github.io/helm-charts

# Upload to GitHub Pages or similar
git add .
git commit -m "Add sample-app chart"
git push origin gh-pages
```

### Using Private Repositories

```bash
# Add private repository with authentication
helm repo add private-repo https://charts.example.com \
  --username myuser \
  --password mypassword

# Or use token
helm repo add private-repo https://charts.example.com \
  --username myuser \
  --password-stdin < token.txt
```

## Advanced Helm Features

### Hooks

```yaml
# Pre-install hook
apiVersion: batch/v1
kind: Job
metadata:
  name: "{{ include "sample-app.fullname" . }}-pre-install"
  annotations:
    "helm.sh/hook": pre-install
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: pre-install-job
        image: busybox
        command: ['sh', '-c', 'echo Pre-install hook']
```

### Notes

```yaml
# templates/NOTES.txt
1. Get the application URL by running these commands:
{{- if .Values.ingress.enabled }}
{{- range $host := .Values.ingress.hosts }}
  {{- range .paths }}
  http{{ if $.Values.ingress.tls }}s{{ end }}://{{ $host.host }}{{ .path }}
  {{- end }}
{{- end }}
{{- else if contains "NodePort" .Values.service.type }}
  export NODE_PORT=$(kubectl get --namespace {{ .Release.Namespace }} -o jsonpath="{.spec.ports[0].nodePort}" services {{ include "sample-app.fullname" . }})
  export NODE_IP=$(kubectl get nodes --namespace {{ .Release.Namespace }} -o jsonpath="{.items[0].status.addresses[0].address}")
  echo http://$NODE_IP:$NODE_PORT
{{- else if contains "LoadBalancer" .Values.service.type }}
     NOTE: It may take a few minutes for the LoadBalancer IP to be available.
           You can watch the status of by running 'kubectl get --namespace {{ .Release.Namespace }} svc -w {{ include "sample-app.fullname" . }}'
  export SERVICE_IP=$(kubectl get svc --namespace {{ .Release.Namespace }} {{ include "sample-app.fullname" . }} --template "{{"{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}"}}")
  echo http://$SERVICE_IP:{{ .Values.service.port }}
{{- else if contains "ClusterIP" .Values.service.type }}
  export POD_NAME=$(kubectl get pods --namespace {{ .Release.Namespace }} -l "app.kubernetes.io/name={{ include "sample-app.name" . }},app.kubernetes.io/instance={{ .Release.Name }}" -o jsonpath="{.items[0].metadata.name}")
  export CONTAINER_PORT=$(kubectl get pod --namespace {{ .Release.Namespace }} $POD_NAME -o jsonpath="{.spec.containers[0].ports[0].containerPort}")
  echo "Visit http://127.0.0.1:8080 to use your application"
  kubectl --namespace {{ .Release.Namespace }} port-forward $POD_NAME 8080:$CONTAINER_PORT
{{- end }}
```

## Best Practices

### 1. Chart Structure

- Keep charts focused and reusable
- Use semantic versioning
- Document all values in comments
- Use meaningful default values

### 2. Values Organization

```yaml
# Group related values
database:
  enabled: true
  host: localhost
  port: 5432
  
monitoring:
  enabled: false
  prometheus:
    enabled: true
  grafana:
    enabled: true
```

### 3. Resource Management

```yaml
# Always set resource limits
resources:
  limits:
    cpu: 500m
    memory: 128Mi
  requests:
    cpu: 250m
    memory: 64Mi
```

### 4. Security

```yaml
# Use security contexts
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 2000

# Set pod security context
podSecurityContext:
  seccompProfile:
    type: RuntimeDefault
```

## Troubleshooting

### Common Issues

#### Template Rendering Errors

```bash
# Debug template rendering
helm template sample-app-test sample-app/ --debug

# Check specific template
helm template sample-app-test sample-app/ -s templates/deployment.yaml
```

#### Release Stuck

```bash
# Check release status
helm status my-release -n namespace

# Force delete stuck release
helm delete my-release -n namespace --no-hooks
```

#### Values Not Applied

```bash
# Check effective values
helm get values my-release -n namespace

# Show all values (including defaults)
helm get values my-release -n namespace --all
```

## Performance Optimization

### Chart Size

```bash
# Use .helmignore to exclude unnecessary files
echo "*.md" >> .helmignore
echo "docs/" >> .helmignore
echo ".git/" >> .helmignore
```

### Resource Optimization

```yaml
# Use resource quotas per environment
resources:
  {{- if eq .Values.environment "production" }}
  limits:
    cpu: 1000m
    memory: 256Mi
  requests:
    cpu: 500m
    memory: 128Mi
  {{- else }}
  limits:
    cpu: 200m
    memory: 64Mi
  requests:
    cpu: 100m
    memory: 32Mi
  {{- end }}
```

## Clean Up

```bash
# Uninstall releases
helm uninstall sample-app-dev -n dev
helm uninstall sample-app-staging -n staging
helm uninstall sample-app-prod -n production

# Delete namespaces
kubectl delete namespace dev staging production
```

## Helm vs Kustomize

| Feature | Helm | Kustomize |
|---------|------|-----------|
| Learning Curve | Higher | Lower |
| Templating | Go templates | Patches |
| Package Management | Yes | No |
| Dependencies | Built-in | Manual |
| Reusability | Excellent | Good |
| GitOps Integration | Good | Excellent |

## Next Steps

Great! You now understand both Kustomize and Helm for configuration management. Next, let's explore advanced topics starting with [Part 8: External Secrets](../../03-advanced/08-external-secrets/README.md).

## Additional Resources

- [Helm Documentation](https://helm.sh/docs/)
- [Helm Chart Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Artifact Hub](https://artifacthub.io/) - Discover charts
- [Chart Testing](https://github.com/helm/chart-testing)
