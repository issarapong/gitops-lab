# Part 8: External Secrets Management

External Secrets Operator synchronizes secrets from external systems like AWS Secrets Manager, HashiCorp Vault, Azure Key Vault, and others into Kubernetes secrets.

## What is External Secrets Operator (ESO)?

External Secrets Operator provides:

- **Multi-provider Support**: AWS, Azure, GCP, Vault, and more
- **GitOps Compatible**: Declarative secret management
- **Automatic Refresh**: Periodic secret synchronization
- **Template Support**: Transform secrets before storing
- **Secure**: No secrets stored in Git repositories

## Architecture

```text
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  External       │    │   External      │    │   Kubernetes    │
│  Secret Store   │◄───│   Secrets       │───►│    Secret       │
│  (Vault, AWS,   │    │   Operator      │    │                 │
│  Azure, etc.)   │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Prerequisites

- Kubernetes cluster running (Docker Desktop, Minikube, or Kind)
- ArgoCD or Flux installed
- Access to an external secret store (we'll use local Vault for demo)

## Installation

### Step 1: Install External Secrets Operator

```bash
# Ensure you're using the GitOps lab kubeconfig
export KUBECONFIG="$HOME/.kube/config-gitops-lab"

# Or start a new terminal and run:
# cd /path/to/gitops/examples/lab
# ./scripts/lab-startup.sh status

# Add External Secrets Helm repository
helm repo add external-secrets https://charts.external-secrets.io

# Install External Secrets Operator
helm install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets-system \
  --create-namespace

# Verify installation
kubectl get pods -n external-secrets-system
```

### Step 2: Install HashiCorp Vault (for demo)

```bash
# Add HashiCorp Helm repository
helm repo add hashicorp https://helm.releases.hashicorp.com

# Install Vault in dev mode
helm install vault hashicorp/vault \
  --set "server.dev.enabled=true" \
  --set "server.dev.devRootToken=myroot" \
  --set "injector.enabled=false" \
  -n vault-system \
  --create-namespace

# Wait for Vault to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault -n vault-system --timeout=300s

# Port forward to access Vault UI
kubectl port-forward svc/vault -n vault-system 8200:8200 &
```

## Setting Up Secret Stores

### Step 1: Create SecretStore for Vault

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: default
spec:
  provider:
    vault:
      server: "http://vault.vault-system.svc.cluster.local:8200"
      path: "secret"
      version: "v2"
      auth:
        tokenSecretRef:
          name: "vault-token"
          key: "token"
```

Apply the SecretStore:

```bash
# Create Vault token secret
kubectl create secret generic vault-token \
  --from-literal=token=myroot \
  -n default

# Apply SecretStore
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: default
spec:
  provider:
    vault:
      server: "http://vault.vault-system.svc.cluster.local:8200"
      path: "secret"
      version: "v2"
      auth:
        tokenSecretRef:
          name: "vault-token"
          key: "token"
EOF
```

### Step 2: Store Secrets in Vault

```bash
# Access Vault pod
kubectl exec -it vault-0 -n vault-system -- /bin/sh

# Inside Vault pod, set secrets
vault kv put secret/myapp/db username="admin" password="supersecret"
vault kv put secret/myapp/api key="api-key-12345" secret="api-secret-67890"
vault kv put secret/myapp/config debug="true" log_level="info"

# Exit Vault pod
exit
```

## Creating External Secrets

### Step 1: Basic ExternalSecret

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-database-secret
  namespace: default
spec:
  refreshInterval: 15s
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: database-credentials
    creationPolicy: Owner
  data:
  - secretKey: username
    remoteRef:
      key: secret/data/myapp/db
      property: username
  - secretKey: password
    remoteRef:
      key: secret/data/myapp/db
      property: password
```

Apply the ExternalSecret:

```bash
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-database-secret
  namespace: default
spec:
  refreshInterval: 15s
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: database-credentials
    creationPolicy: Owner
  data:
  - secretKey: username
    remoteRef:
      key: secret/data/myapp/db
      property: username
  - secretKey: password
    remoteRef:
      key: secret/data/myapp/db
      property: password
EOF
```

### Step 2: Verify Secret Creation

```bash
# Check ExternalSecret status
kubectl get externalsecret

# Check created secret
kubectl get secret database-credentials -o yaml

# Decode secret values
kubectl get secret database-credentials -o jsonpath='{.data.username}' | base64 -d
kubectl get secret database-credentials -o jsonpath='{.data.password}' | base64 -d
```

### Step 3: Template-based ExternalSecret

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-config-secret
  namespace: default
spec:
  refreshInterval: 30s
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: app-config
    creationPolicy: Owner
    template:
      type: Opaque
      data:
        config.yaml: |
          database:
            host: "{{ .db_host | default "localhost" }}"
            username: "{{ .username }}"
            password: "{{ .password }}"
          api:
            key: "{{ .api_key }}"
            secret: "{{ .api_secret }}"
          app:
            debug: {{ .debug }}
            log_level: "{{ .log_level }}"
  dataFrom:
  - extract:
      key: secret/data/myapp/db
  - extract:
      key: secret/data/myapp/api
  - extract:
      key: secret/data/myapp/config
```

Apply the template-based ExternalSecret:

```bash
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-config-secret
  namespace: default
spec:
  refreshInterval: 30s
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: app-config
    creationPolicy: Owner
    template:
      type: Opaque
      data:
        config.yaml: |
          database:
            host: "{{ .db_host | default "localhost" }}"
            username: "{{ .username }}"
            password: "{{ .password }}"
          api:
            key: "{{ .key }}"
            secret: "{{ .secret }}"
          app:
            debug: {{ .debug }}
            log_level: "{{ .log_level }}"
  dataFrom:
  - extract:
      key: secret/data/myapp/db
  - extract:
      key: secret/data/myapp/api
  - extract:
      key: secret/data/myapp/config
EOF
```

## ClusterSecretStore

For cluster-wide secret management:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: vault-cluster-backend
spec:
  provider:
    vault:
      server: "http://vault.vault-system.svc.cluster.local:8200"
      path: "secret"
      version: "v2"
      auth:
        tokenSecretRef:
          name: "vault-token"
          key: "token"
          namespace: "vault-system"
```

## Multi-Provider Examples

### AWS Secrets Manager

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-manager
  namespace: default
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-west-2
      auth:
        secretRef:
          accessKeyID:
            name: awssm-secret
            key: access-key
          secretAccessKey:
            name: awssm-secret
            key: secret-access-key
```

### Azure Key Vault

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: azure-keyvault
  namespace: default
spec:
  provider:
    azurekv:
      vaultUrl: "https://my-vault.vault.azure.net/"
      authType: ServicePrincipal
      authSecretRef:
        clientId:
          name: azure-secret
          key: client-id
        clientSecret:
          name: azure-secret
          key: client-secret
      tenantId: "12345678-1234-1234-1234-123456789012"
```

### Google Secret Manager

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: gcpsm-secret-store
  namespace: default
spec:
  provider:
    gcpsm:
      projectId: "my-project"
      auth:
        secretRef:
          secretAccessKey:
            name: gcpsm-secret
            key: secret-access-credentials
```

## Using Secrets in Applications

### Step 1: Create Application with Secrets

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app-with-secrets
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sample-app-with-secrets
  template:
    metadata:
      labels:
        app: sample-app-with-secrets
    spec:
      containers:
      - name: app
        image: nginx:alpine
        env:
        - name: DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: password
        volumeMounts:
        - name: app-config
          mountPath: /etc/config
          readOnly: true
      volumes:
      - name: app-config
        secret:
          secretName: app-config
```

Apply the application:

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app-with-secrets
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sample-app-with-secrets
  template:
    metadata:
      labels:
        app: sample-app-with-secrets
    spec:
      containers:
      - name: app
        image: nginx:alpine
        env:
        - name: DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: password
        volumeMounts:
        - name: app-config
          mountPath: /etc/config
          readOnly: true
      volumes:
      - name: app-config
        secret:
          secretName: app-config
EOF
```

### Step 2: Verify Secret Usage

```bash
# Check pod environment variables
kubectl exec deployment/sample-app-with-secrets -- env | grep DB_

# Check mounted config file
kubectl exec deployment/sample-app-with-secrets -- cat /etc/config/config.yaml
```

## Secret Rotation and Refresh

### Automatic Refresh

External Secrets automatically refreshes secrets based on the `refreshInterval`:

```yaml
spec:
  refreshInterval: 15s  # Refresh every 15 seconds
```

### Manual Refresh

```bash
# Force refresh an ExternalSecret
kubectl annotate externalsecret app-database-secret \
  force-sync=$(date +%s) --overwrite
```

### Monitoring Refresh

```bash
# Watch ExternalSecret status
kubectl get externalsecret -w

# Check events
kubectl describe externalsecret app-database-secret
```

## Security Best Practices

### 1. Namespace Isolation

```yaml
# Use SecretStore per namespace
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: production-vault
  namespace: production
spec:
  provider:
    vault:
      server: "https://production-vault.company.com"
      # ... vault config
```

### 2. Least Privilege Access

```yaml
# Vault policy example
path "secret/data/production/*" {
  capabilities = ["read"]
}

path "secret/data/staging/*" {
  capabilities = ["read"]
}
```

### 3. Secret Naming Conventions

```yaml
spec:
  target:
    name: "{{ .Release.Name }}-database-credentials"
    labels:
      app.kubernetes.io/name: "{{ .Release.Name }}"
      app.kubernetes.io/component: database
```

## GitOps Integration

### ArgoCD with External Secrets

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-with-secrets
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/your-org/k8s-manifests
    targetRevision: HEAD
    path: apps/sample-app
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
  # Ensure External Secrets are created first
  syncWaves:
  - resources:
    - group: external-secrets.io
      kind: ExternalSecret
    wave: 0
  - resources:
    - group: apps
      kind: Deployment
    wave: 1
```

### Flux with External Secrets

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: app-secrets
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: app-repo
  path: "./manifests/secrets"
  prune: true
  targetNamespace: default

---
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: app-deployment
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: app-repo
  path: "./manifests/app"
  prune: true
  targetNamespace: default
  dependsOn:
  - name: app-secrets
```

## Troubleshooting

### Common Issues

#### ExternalSecret Not Syncing

```bash
# Check ExternalSecret status
kubectl describe externalsecret app-database-secret

# Check operator logs
kubectl logs -n external-secrets-system deployment/external-secrets -f

# Check SecretStore connectivity
kubectl get secretstore vault-backend -o yaml
```

#### Secret Not Updated

```bash
# Force refresh
kubectl annotate externalsecret app-database-secret \
  force-sync=$(date +%s) --overwrite

# Check refresh interval
kubectl get externalsecret app-database-secret -o jsonpath='{.spec.refreshInterval}'
```

#### Authentication Issues

```bash
# Check auth secret
kubectl get secret vault-token -o yaml

# Test Vault connectivity
kubectl exec -it vault-0 -n vault-system -- vault status
```

## Monitoring and Alerting

### Metrics

External Secrets Operator exposes Prometheus metrics:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: external-secrets-operator
  namespace: external-secrets-system
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: external-secrets
  endpoints:
  - port: metrics
```

### Alerts

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: external-secrets-alerts
  namespace: external-secrets-system
spec:
  groups:
  - name: external-secrets
    rules:
    - alert: ExternalSecretSyncError
      expr: increase(externalsecret_sync_calls_error_total[5m]) > 0
      labels:
        severity: warning
      annotations:
        summary: "ExternalSecret sync failed"
        description: "ExternalSecret {{ $labels.name }} in namespace {{ $labels.namespace }} failed to sync"
```

## Clean Up

```bash
# Delete test application
kubectl delete deployment sample-app-with-secrets

# Delete External Secrets
kubectl delete externalsecret app-database-secret app-config-secret

# Delete SecretStore
kubectl delete secretstore vault-backend

# Uninstall Vault
helm uninstall vault -n vault-system

# Uninstall External Secrets Operator
helm uninstall external-secrets -n external-secrets-system

# Delete namespaces
kubectl delete namespace vault-system external-secrets-system
```

## Next Steps

Excellent! You now understand how to manage secrets securely with External Secrets Operator. Next, let's explore application lifecycle management with [Part 9: Keptn](../09-keptn/README.md).

## Additional Resources

- [External Secrets Operator Documentation](https://external-secrets.io/)
- [External Secrets GitHub](https://github.com/external-secrets/external-secrets)
- [Provider Guides](https://external-secrets.io/latest/provider/aws-secrets-manager/)
- [Security Best Practices](https://external-secrets.io/latest/guides/security-best-practices/)
