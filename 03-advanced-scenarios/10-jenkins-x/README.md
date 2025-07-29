# Part 10: Jenkins X CI/CD

Jenkins X is a cloud-native CI/CD solution for Kubernetes that provides automated CI/CD pipelines using GitOps principles.

## What is Jenkins X?

Jenkins X provides:

- **Cloud Native CI/CD**: Built specifically for Kubernetes
- **GitOps**: Git-based workflow automation
- **Preview Environments**: Automatic environment creation for PRs
- **Progressive Delivery**: Canary deployments and automated promotion
- **Developer Experience**: Simplified development workflow

## Architecture

```text
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Git Repo      │───▶│   Jenkins X     │───▶│   Kubernetes    │
│  (Source Code)  │    │   Pipeline      │    │  Environments   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                       │                       │
        ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Pull Request   │    │   Tekton        │    │   Preview Env   │
│   (Preview)     │    │   Pipelines     │    │   Staging Env   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Prerequisites

- Kubernetes cluster running (Docker Desktop, Minikube, or Kind)
- kubectl configured
- Git repository access
- Sufficient cluster resources (4GB+ RAM recommended)

## Installation

### Step 1: Install Jenkins X CLI

```bash
# Ensure you're using the GitOps lab kubeconfig
export KUBECONFIG="$HOME/.kube/config-gitops-lab"

# Install Jenkins X CLI
curl -L "https://github.com/jenkins-x/jx/releases/download/$(curl -s https://api.github.com/repos/jenkins-x/jx/releases/latest | jq -r '.tag_name')/jx-linux-amd64.tar.gz" | tar xzv
sudo mv jx /usr/local/bin

# Verify installation
jx version
```

### Step 2: Install Jenkins X

```bash
# Install Jenkins X using Terraform (simplified approach)
jx install --provider=kubernetes

# Or install with specific configuration
jx install \
  --provider=kubernetes \
  --git-kind=github \
  --git-username=$GITHUB_USERNAME \
  --git-token=$GITHUB_TOKEN \
  --default-admin-password=admin123 \
  --default-environment-prefix=jx
```

### Step 3: Verify Installation

```bash
# Check Jenkins X namespaces
kubectl get namespaces | grep jx

# Check pods
kubectl get pods -n jx

# Get Jenkins X status
jx status
```

## Setting Up Development Environment

### Step 1: Create Application

```bash
# Create a new Spring Boot application
jx create spring \
  --artifact-id=sample-spring-app \
  --group-id=com.example \
  --language=java \
  --spring-boot-version=2.7.0

# Or import existing application
jx import --url=https://github.com/your-username/sample-app
```

### Step 2: Configure Pipeline

```yaml
# jenkins-x.yml
buildPack: none
pipelineConfig:
  pipelines:
    pullRequest:
      pipeline:
        agent:
          image: gcr.io/jenkinsxio/builder-maven
        stages:
        - name: ci
          steps:
          - name: build
            command: mvn
            args:
            - clean
            - compile
          - name: test
            command: mvn
            args:
            - test
          - name: package
            command: mvn
            args:
            - package
          - name: build-container
            image: gcr.io/kaniko-project/executor:latest
            command: /kaniko/executor
            args:
            - --cache=true
            - --cache-dir=/workspace
            - --context=/workspace/source
            - --dockerfile=/workspace/source/Dockerfile
            - --destination=$DOCKER_REGISTRY/$ORG/$APP_NAME:$PREVIEW_VERSION
            - --cache-repo=$DOCKER_REGISTRY/$ORG/cache
        
    release:
      pipeline:
        agent:
          image: gcr.io/jenkinsxio/builder-maven
        environment:
        - name: _JAVA_OPTIONS
          value: -XX:+UnlockExperimentalVMOptions -Dsun.zip.disableMemoryMapping=true -XX:+UseParallelGC -XX:MinHeapFreeRatio=5 -XX:MaxHeapFreeRatio=10 -XX:GCTimeRatio=4 -XX:AdaptiveSizePolicyWeight=90 -Xms128m -Xmx512m
        stages:
        - name: release
          steps:
          - name: build
            command: mvn
            args:
            - clean
            - compile
          - name: test
            command: mvn
            args:
            - test
          - name: package
            command: mvn
            args:
            - package
          - name: build-container
            image: gcr.io/kaniko-project/executor:latest
            command: /kaniko/executor
            args:
            - --cache=true
            - --cache-dir=/workspace
            - --context=/workspace/source
            - --dockerfile=/workspace/source/Dockerfile
            - --destination=$DOCKER_REGISTRY/$ORG/$APP_NAME:$VERSION
            - --cache-repo=$DOCKER_REGISTRY/$ORG/cache
          - name: promote
            command: jx
            args:
            - step
            - promote
            - --version=$VERSION
            - --env=staging
```

### Step 3: Create Dockerfile

```dockerfile
# Dockerfile
FROM openjdk:11-jre-slim

COPY target/*.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app.jar"]
```

## Environment Management

### Step 1: Understanding Environments

Jenkins X creates several environments by default:

- **Development**: Local development
- **Staging**: Integration testing
- **Production**: Live applications

```bash
# List environments
jx get environments

# Get environment details
jx get env staging
```

### Step 2: Create Custom Environment

```bash
# Create new environment
jx create env \
  --name=qa \
  --label=QA \
  --namespace=jx-qa \
  --promotion=Manual \
  --order=150

# Configure environment
jx edit env qa --promotion=Auto
```

### Step 3: Environment Configuration

```yaml
# environments/qa/env.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: env
  labels:
    env: "qa"
    team: $TEAM
data:
  namespace: "jx-qa"
  promotion: "Auto"
  order: "150"
  
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: qa-env
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/$ORG/environment-$TEAM-qa
    targetRevision: HEAD
    path: .
  destination:
    server: https://kubernetes.default.svc
    namespace: jx-qa
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Preview Environments

### Step 1: Automatic Preview Creation

When you create a Pull Request, Jenkins X automatically:

1. Builds your application
2. Creates a preview environment
3. Deploys your changes
4. Provides a preview URL

```bash
# Create feature branch
git checkout -b feature/new-functionality
git push origin feature/new-functionality

# Create pull request (triggers preview environment)
# Preview environment will be available at: https://sample-app-pr-123.jx.example.com
```

### Step 2: Preview Environment Configuration

```yaml
# preview/values.yaml
expose:
  Annotations:
    helm.sh/hook: post-install,post-upgrade
    helm.sh/hook-delete-policy: hook-succeeded
  config:
    exposer: Ingress
    http: "true"
    tlsacme: "false"

cleanup:
  Args:
    - --cleanup
  Annotations:
    helm.sh/hook: pre-delete
    helm.sh/hook-delete-policy: hook-succeeded

app:
  name: sample-app
  externalURL: http://sample-app.jx.example.com

preview:
  image:
    repository: gcr.io/my-project/sample-app
    tag: SNAPSHOT-PR-123-1
```

### Step 3: Preview Environment Testing

```bash
# Get preview environments
jx get preview

# Access preview environment
jx preview --app=sample-app --pr=123

# Delete preview environment
jx delete preview --app=sample-app --pr=123
```

## Application Promotion

### Step 1: Automatic Promotion

```bash
# Merge PR triggers promotion to staging
git checkout main
git merge feature/new-functionality
git push origin main

# Check promotion status
jx get activities

# Monitor promotion
jx get activities -w
```

### Step 2: Manual Promotion

```bash
# Promote to production manually
jx promote \
  --app=sample-app \
  --version=1.0.1 \
  --env=production

# Promote with specific values
jx promote \
  --app=sample-app \
  --version=1.0.1 \
  --env=production \
  --timeout=30m
```

### Step 3: Promotion Pipeline

```yaml
# .lighthouse/jenkins-x/promote.yaml
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: promote
spec:
  pipelineSpec:
    tasks:
    - name: promote-app
      taskSpec:
        steps:
        - name: promote
          image: gcr.io/jenkinsxio/jx-cli:latest
          script: |
            #!/usr/bin/env bash
            set -e
            jx step promote \
              --app=$APP_NAME \
              --version=$VERSION \
              --env=$TARGET_ENV
```

## Pipeline Configuration

### Step 1: Custom Pipeline Steps

```yaml
# .lighthouse/jenkins-x/pullrequest.yaml
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: pullrequest
spec:
  pipelineSpec:
    tasks:
    - name: from-build-pack
      taskSpec:
        stepTemplate:
          name: ""
          resources:
            requests:
              cpu: 400m
              memory: 600Mi
          workingDir: /workspace/source
        steps:
        - image: gcr.io/jenkinsxio/jx-cli:latest
          name: jx-variables
          script: |
            #!/usr/bin/env bash
            jx gitops variables
        - image: gcr.io/jenkinsxio/builder-maven:latest
          name: build-mvn-compile
          script: |
            #!/usr/bin/env bash
            mvn clean compile
        - image: gcr.io/jenkinsxio/builder-maven:latest
          name: build-mvn-test
          script: |
            #!/usr/bin/env bash
            mvn test
        - image: gcr.io/jenkinsxio/builder-maven:latest
          name: build-mvn-package
          script: |
            #!/usr/bin/env bash
            mvn package -DskipTests
        - image: gcr.io/kaniko-project/executor:debug-v1.3.0
          name: build-container-build
          script: |
            #!/busybox/sh
            /kaniko/executor $KANIKO_FLAGS \
              --context=/workspace/source \
              --dockerfile=/workspace/source/Dockerfile \
              --destination=$PUSH_CONTAINER_REGISTRY/$DOCKER_REGISTRY_ORG/$APP_NAME:$VERSION
```

### Step 2: Quality Gates

```yaml
# Add quality gate step
- name: quality-gate
  image: sonarqube-scanner:latest
  script: |
    #!/usr/bin/env bash
    sonar-scanner \
      -Dsonar.projectKey=$APP_NAME \
      -Dsonar.sources=src/main \
      -Dsonar.host.url=$SONAR_URL \
      -Dsonar.login=$SONAR_TOKEN
    
    # Wait for quality gate result
    curl -u $SONAR_TOKEN: \
      "$SONAR_URL/api/qualitygates/project_status?projectKey=$APP_NAME" \
      | jq -e '.projectStatus.status == "OK"'
```

### Step 3: Security Scanning

```yaml
# Add security scanning
- name: security-scan
  image: aquasec/trivy:latest
  script: |
    #!/usr/bin/env bash
    trivy image \
      --exit-code 1 \
      --severity HIGH,CRITICAL \
      $PUSH_CONTAINER_REGISTRY/$DOCKER_REGISTRY_ORG/$APP_NAME:$VERSION
```

## Integration with GitOps Tools

### Step 1: ArgoCD Integration

```yaml
# Environment repository with ArgoCD Application
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sample-app-staging
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/environment-staging
    targetRevision: HEAD
    path: apps/sample-app
  destination:
    server: https://kubernetes.default.svc
    namespace: jx-staging
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Step 2: Flux Integration

```bash
# Configure Jenkins X with Flux
jx install \
  --provider=kubernetes \
  --gitops \
  --gitops-flux
```

### Step 3: External Secrets Integration

```yaml
# Add External Secret to environment
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
  namespace: jx-staging
spec:
  refreshInterval: 15s
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: sample-app-secrets
    creationPolicy: Owner
  data:
  - secretKey: database-url
    remoteRef:
      key: secret/staging/sample-app
      property: database-url
```

## Monitoring and Observability

### Step 1: Pipeline Monitoring

```bash
# Watch pipeline execution
jx get activities -w

# Get pipeline logs
jx logs -f

# Get build logs for specific pipeline
jx logs $OWNER/$REPO/$BRANCH --build=$BUILD_NUMBER
```

### Step 2: Application Monitoring

```yaml
# Add Prometheus monitoring to application
apiVersion: v1
kind: Service
metadata:
  name: sample-app-metrics
  labels:
    app: sample-app
    prometheus: monitoring
spec:
  ports:
  - name: metrics
    port: 8080
    targetPort: 8080
  selector:
    app: sample-app

---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: sample-app
spec:
  selector:
    matchLabels:
      app: sample-app
      prometheus: monitoring
  endpoints:
  - port: metrics
    path: /actuator/prometheus
```

### Step 3: Alert Configuration

```yaml
# Prometheus alerts for applications
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: sample-app-alerts
spec:
  groups:
  - name: sample-app
    rules:
    - alert: ApplicationDown
      expr: up{job="sample-app"} == 0
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "Application {{ $labels.instance }} down"
    - alert: HighErrorRate
      expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: "High error rate on {{ $labels.instance }}"
```

## Best Practices

### 1. Repository Structure

```text
sample-app/
├── src/                    # Application source
├── Dockerfile             # Container definition
├── charts/                # Helm charts
│   ├── sample-app/
│   └── preview/
├── .lighthouse/           # Pipeline definitions
│   └── jenkins-x/
├── jenkins-x.yml          # Jenkins X configuration
└── skaffold.yaml         # Local development
```

### 2. Pipeline Optimization

- Use parallel steps where possible
- Cache dependencies (Maven, npm, etc.)
- Optimize Docker builds with multi-stage
- Use resource limits for steps

### 3. Environment Strategy

- **Dev**: Fastest feedback, basic tests
- **Staging**: Production-like, full test suite
- **Production**: Manual approval, monitoring

### 4. Security Practices

- Scan container images
- Use least privilege service accounts
- Rotate secrets regularly
- Implement policy enforcement

## Troubleshooting

### Common Issues

#### Pipeline Failures

```bash
# Check pipeline status
jx get activities

# Get detailed logs
jx logs $OWNER/$REPO/$BRANCH --build=$BUILD_NUMBER

# Check pod logs
kubectl logs -n jx -l app=jenkins-x-webhook
```

#### Environment Issues

```bash
# Check environment health
jx get env

# Verify environment repository
git clone https://github.com/$ORG/environment-$TEAM-staging
cd environment-$TEAM-staging
git log --oneline -10

# Check ArgoCD sync status
kubectl get applications -n argocd
```

#### Resource Constraints

```bash
# Check cluster resources
kubectl top nodes
kubectl top pods -n jx

# Increase resource limits
jx edit requirements
```

## Performance Optimization

### Build Optimization

```yaml
# Use build cache
- name: build-mvn-package
  image: gcr.io/jenkinsxio/builder-maven:latest
  script: |
    #!/usr/bin/env bash
    mvn package -DskipTests \
      -Dmaven.repo.local=/workspace/.m2/repository
  volumeMounts:
  - name: maven-cache
    mountPath: /workspace/.m2/repository
```

### Resource Management

```yaml
# Set appropriate resource limits
stepTemplate:
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 1000m
      memory: 1Gi
```

## Clean Up

```bash
# Delete applications
jx delete app sample-app

# Delete environments
jx delete env qa

# Uninstall Jenkins X
jx uninstall --context=$(kubectl config current-context)

# Clean up namespaces
kubectl delete namespace jx jx-staging jx-production
```

## Next Steps

Excellent! You now understand cloud-native CI/CD with Jenkins X. Next, let's explore advanced configuration patterns in [Part 11: Overlay Patterns](../11-overlays/README.md).

## Additional Resources

- [Jenkins X Documentation](https://jenkins-x.io/docs/)
- [Jenkins X Examples](https://github.com/jenkins-x/jx3-examples)
- [Tekton Documentation](https://tekton.dev/docs/)
- [Jenkins X Best Practices](https://jenkins-x.io/docs/resources/guides/)
