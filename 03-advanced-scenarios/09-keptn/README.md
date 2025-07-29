# Part 9: Keptn for Application Lifecycle Management

Keptn is a Cloud Native Computing Foundation (CNCF) project that provides a control plane for continuous delivery and automated operations for cloud-native applications.

## What is Keptn?

Keptn provides:

- **Event-driven Orchestration**: Automate delivery and operations workflows
- **Quality Gates**: Automated quality evaluation with SLI/SLO
- **Multi-stage Delivery**: Progressive deployment across environments
- **Auto-remediation**: Automated problem detection and resolution
- **Observability**: Built-in monitoring and evaluation

## Architecture

```text
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Git Repo      │───▶│  Keptn Control  │───▶│   Kubernetes    │
│   (Shipyard)    │    │     Plane       │    │   Workloads     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │   Integrations  │
                       │  (Prometheus,   │
                       │  Dynatrace,     │
                       │  ArgoCD, etc.)  │
                       └─────────────────┘
```

## Prerequisites

- Kubernetes cluster running (Docker Desktop, Minikube, or Kind)
- kubectl configured
- Helm installed
- Istio (for advanced features)

## Installation

### Step 1: Install Keptn

```bash
# Ensure you're using the GitOps lab kubeconfig
export KUBECONFIG="$HOME/.kube/config-gitops-lab"

# Download Keptn CLI
curl -sL https://get.keptn.sh | bash

# Add to PATH
export PATH=$PATH:/usr/local/bin

# Verify installation
keptn version

# Install Keptn on cluster
keptn install --endpoint-service-type=ClusterIP

# Wait for Keptn to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=keptn -n keptn --timeout=300s
```

### Step 2: Authenticate with Keptn

```bash
# Get Keptn API token
KEPTN_API_TOKEN=$(kubectl get secret keptn-api-token -n keptn -ojsonpath='{.data.keptn-api-token}' | base64 -d)

# Get Keptn endpoint (port forward for local access)
kubectl port-forward svc/api-gateway-nginx -n keptn 8080:80 &

# Authenticate
keptn auth --endpoint=http://localhost:8080/api --api-token=$KEPTN_API_TOKEN
```

### Step 3: Install Istio (Optional for advanced routing)

```bash
# Download Istio
curl -L https://istio.io/downloadIstio | sh -
export PATH=$PATH:$PWD/istio-*/bin

# Install Istio
istioctl install --set values.global.meshID=mesh1 --set values.global.network=network1 -y

# Enable Istio injection for Keptn
kubectl label namespace keptn istio-injection=enabled
```

## Creating Your First Keptn Project

### Step 1: Create Project Structure

```yaml
# shipyard.yaml
apiVersion: spec.keptn.sh/0.2.3
kind: Shipyard
metadata:
  name: sample-app
spec:
  stages:
  - name: dev
    sequences:
    - name: delivery
      tasks:
      - name: deployment
        properties:
          deploymentstrategy: direct
      - name: test
        properties:
          teststrategy: functional
      - name: evaluation
      - name: release
        
  - name: staging
    sequences:
    - name: delivery
      triggeredOn:
      - event: dev.delivery.finished
      tasks:
      - name: deployment
        properties:
          deploymentstrategy: blue_green_service
      - name: test
        properties:
          teststrategy: performance
      - name: evaluation
      - name: release
        
  - name: production
    sequences:
    - name: delivery
      triggeredOn:
      - event: staging.delivery.finished
        selector:
          match:
            result: pass
      tasks:
      - name: deployment
        properties:
          deploymentstrategy: blue_green_service
      - name: release

  - name: production
    sequences:
    - name: remediation
      triggeredOn:
      - event: production.remediation.triggered
      tasks:
      - name: get-action
      - name: action
      - name: evaluation
        triggeredAfter: "10m"
        properties:
          timeframe: "10m"
```

### Step 2: Create Keptn Project

```bash
# Create project with shipyard
keptn create project sample-app --shipyard=shipyard.yaml

# Create service
keptn create service sample-service --project=sample-app
```

### Step 3: Configure SLI/SLO

```yaml
# sli.yaml - Service Level Indicators
spec_version: "1.0"
indicators:
  response_time_p50: histogram_quantile(0.50, sum(rate(http_request_duration_seconds_bucket[3m])) by (le))
  response_time_p90: histogram_quantile(0.90, sum(rate(http_request_duration_seconds_bucket[3m])) by (le))
  response_time_p95: histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[3m])) by (le))
  throughput: sum(rate(http_requests_total[3m]))
  error_rate: sum(rate(http_requests_total{status!~"2.."}[3m]))/sum(rate(http_requests_total[3m]))
```

```yaml
# slo.yaml - Service Level Objectives
spec_version: "0.1.1"
comparison:
  aggregate_function: "avg"
  compare_with: "single_result"
  include_result_with_score: "pass"
  number_of_comparison_results: 1
filter:
objectives:
  - sli: "response_time_p95"
    key_sli: false
    pass:             # pass if (relative change <= 10% AND absolute value is < 600ms)
      - criteria:
          - "<=+10%"    # relative values require a prefixed sign (plus or minus)
          - "<600"      # absolute values only require a logical operator
    warning:          # if the response time is below 800ms, the result should be a warning
      - criteria:
          - "<=800"
    weight: 1
  - sli: "error_rate"
    key_sli: false
    pass:
      - criteria:
          - "<=+5%"
          - "<0.05"
    warning:
      - criteria:
          - "<=0.1"
    weight: 1
  - sli: "throughput"
    key_sli: false
    pass:
      - criteria:
          - ">=-10%"
    warning:
      - criteria:
          - ">=-20%"
    weight: 1
total_score:
  pass: "90%"
  warning: "75%"
```

## Deployment with Keptn

### Step 1: Prepare Application Manifests

```yaml
# helm/values.yaml
replicaCount: 1
image:
  repository: nginx
  tag: 1.21
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: false

resources:
  limits:
    cpu: 500m
    memory: 128Mi
  requests:
    cpu: 250m
    memory: 64Mi
```

```yaml
# helm/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "sample-service.fullname" . }}
  labels:
    {{- include "sample-service.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "sample-service.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "sample-service.selectorLabels" . | nindent 8 }}
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - name: http
          containerPort: 80
          protocol: TCP
        livenessProbe:
          httpGet:
            path: /
            port: http
        readinessProbe:
          httpGet:
            path: /
            port: http
        resources:
          {{- toYaml .Values.resources | nindent 12 }}
```

### Step 2: Add Configuration Resources

```bash
# Add SLI configuration
keptn add-resource --project=sample-app --service=sample-service --stage=staging --resource=sli.yaml --resourceUri=prometheus/sli.yaml

# Add SLO configuration
keptn add-resource --project=sample-app --service=sample-service --stage=staging --resource=slo.yaml --resourceUri=slo.yaml

# Add Helm chart
tar -czf sample-service.tgz helm/
keptn add-resource --project=sample-app --service=sample-service --stage=dev --resource=sample-service.tgz --resourceUri=helm/sample-service.tgz
```

### Step 3: Configure Prometheus Integration

```bash
# Install Prometheus (if not already installed)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace

# Install Keptn Prometheus Service
helm repo add keptn https://charts.keptn.sh
helm install prometheus-service keptn/prometheus-service \
  --namespace keptn \
  --set prometheus.endpoint=http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090
```

## Triggering Deployments

### Step 1: Trigger Deployment

```bash
# Trigger deployment to dev
keptn trigger delivery \
  --project=sample-app \
  --service=sample-service \
  --image=nginx:1.21 \
  --tag=1.21

# Monitor deployment
keptn get event delivery.triggered --project=sample-app
```

### Step 2: Watch Keptn Bridge

```bash
# Port forward to Keptn Bridge
kubectl port-forward svc/bridge -n keptn 9000:8080 &

# Access Keptn Bridge at http://localhost:9000
echo "Access Keptn Bridge at http://localhost:9000"
```

### Step 3: Manual Quality Gate Evaluation

```bash
# Trigger evaluation manually
keptn trigger evaluation \
  --project=sample-app \
  --service=sample-service \
  --stage=staging \
  --timeframe=5m

# Get evaluation result
keptn get event evaluation.finished --project=sample-app --limit=1
```

## Quality Gates and SLO Evaluation

### Step 1: Configure Quality Gates

```yaml
# remediation.yaml
apiVersion: spec.keptn.sh/0.1.4
kind: Remediation
metadata:
  name: remediation-sample-service
spec:
  remediations:
  - problemType: "Response time degradation"
    actionsOnOpen:
    - action: scaling
      name: "Scaling action"
      description: "Scale up when response time degrades"
      value:
        replicas: "+1"
  - problemType: "response_time_p90"
    actionsOnOpen:
    - action: scaling
      name: "Scale up replicas"
      value:
        replicas: "+2"
```

### Step 2: Performance Testing Integration

```yaml
# jmeter/load.jmx (JMeter test plan)
<?xml version="1.0" encoding="UTF-8"?>
<jmeterTestPlan version="1.2">
  <hashTree>
    <TestPlan guiclass="TestPlanGui" testclass="TestPlan" testname="Load Test">
      <elementProp name="TestPlan.arguments" elementType="Arguments" guiclass="ArgumentsPanel">
        <collectionProp name="Arguments.arguments"/>
      </elementProp>
      <stringProp name="TestPlan.user_define_classpath"></stringProp>
      <boolProp name="TestPlan.functional_mode">false</boolProp>
      <boolProp name="TestPlan.serialize_threadgroups">false</boolProp>
    </TestPlan>
    <hashTree>
      <ThreadGroup guiclass="ThreadGroupGui" testclass="ThreadGroup" testname="Thread Group">
        <stringProp name="ThreadGroup.on_sample_error">continue</stringProp>
        <elementProp name="ThreadGroup.main_controller" elementType="LoopController">
          <boolProp name="LoopController.continue_forever">false</boolProp>
          <stringProp name="LoopController.loops">100</stringProp>
        </elementProp>
        <stringProp name="ThreadGroup.num_threads">10</stringProp>
        <stringProp name="ThreadGroup.ramp_time">60</stringProp>
      </ThreadGroup>
    </hashTree>
  </hashTree>
</jmeterTestPlan>
```

## Auto-remediation

### Step 1: Configure Auto-remediation

```bash
# Add remediation configuration
keptn add-resource --project=sample-app --service=sample-service --stage=production --resource=remediation.yaml
```

### Step 2: Simulate Problem

```bash
# Trigger a problem event
keptn send event \
  --file=problem.json \
  --project=sample-app

# problem.json content:
cat > problem.json <<EOF
{
  "type": "sh.keptn.event.problem.open",
  "specversion": "1.0",
  "source": "keptn/monitoring",
  "id": "problem-12345",
  "time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "contenttype": "application/json",
  "data": {
    "project": "sample-app",
    "service": "sample-service",
    "stage": "production",
    "problemTitle": "Response time degradation",
    "problemType": "response_time_p90",
    "state": "OPEN"
  }
}
EOF
```

## Multi-stage Delivery

### Step 1: Configure Progressive Delivery

```yaml
# Update shipyard.yaml for canary deployment
spec:
  stages:
  - name: production
    sequences:
    - name: delivery
      tasks:
      - name: deployment
        properties:
          deploymentstrategy: canary
          canary:
            weight: 10
            maxWeight: 50
            stepWeight: 10
            stepDuration: "5m"
      - name: test
        properties:
          teststrategy: functional
      - name: evaluation
        properties:
          timeframe: "5m"
      - name: release
```

### Step 2: Blue-Green Deployment

```yaml
# Blue-green configuration in shipyard
- name: deployment
  properties:
    deploymentstrategy: blue_green_service
- name: test
  properties:
    teststrategy: functional
- name: evaluation
  properties:
    timeframe: "10m"
- name: release
  properties:
    strategy: blue_green_service
```

## Monitoring and Observability

### Step 1: Keptn Metrics

```bash
# View Keptn metrics
kubectl get --raw /metrics | grep keptn

# Keptn Bridge shows:
# - Deployment timeline
# - Quality gate results  
# - Performance trends
# - Problem notifications
```

### Step 2: Custom Metrics Integration

```yaml
# Custom SLI provider
apiVersion: v1
kind: ConfigMap
metadata:
  name: custom-sli-provider
  namespace: keptn
data:
  custom-queries: |
    spec_version: '1.0'
    indicators:
      custom_metric: 'custom_query{service="$SERVICE",stage="$STAGE"}'
      business_metric: 'business_kpi{project="$PROJECT"}'
```

## GitOps Integration with Keptn

### ArgoCD Integration

```yaml
# ArgoCD Application for Keptn-managed service
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: keptn-managed-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/keptn/keptn
    targetRevision: HEAD
    path: "installer/manifests/keptn"
  destination:
    server: https://kubernetes.default.svc
    namespace: keptn-managed
  syncPolicy:
    automated:
      prune: false  # Let Keptn manage lifecycle
      selfHeal: false
```

### Flux Integration

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: keptn-integration
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: keptn-repo
  path: "./keptn-resources"
  prune: true
  targetNamespace: keptn
```

## Best Practices

### 1. Project Structure

```text
keptn-project/
├── shipyard.yaml
├── sli.yaml
├── slo.yaml
├── remediation.yaml
├── helm/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
└── jmeter/
    └── load.jmx
```

### 2. Quality Gate Configuration

- Start with loose SLOs and tighten over time
- Use key SLIs that matter to business
- Implement gradual rollback strategies
- Monitor long-term trends

### 3. Multi-stage Strategy

- Dev: Fast feedback, loose quality gates
- Staging: Production-like testing
- Production: Strict quality gates, auto-remediation

### 4. Monitoring Integration

- Use existing monitoring tools (Prometheus, Dynatrace)
- Configure meaningful SLIs
- Set up alerting for quality gate failures

## Troubleshooting

### Common Issues

#### Keptn Not Receiving Events

```bash
# Check Keptn services
kubectl get pods -n keptn

# Check event flow
keptn get event --project=sample-app --limit=10

# Check logs
kubectl logs -n keptn deployment/shipyard-controller -f
```

#### Quality Gate Evaluation Fails

```bash
# Check SLI configuration
keptn get sli --project=sample-app --service=sample-service --stage=staging

# Test Prometheus connectivity
kubectl exec -n keptn deployment/prometheus-service -- curl prometheus-endpoint/api/v1/query?query=up
```

#### Deployment Stuck

```bash
# Check deployment logs
kubectl logs -n sample-app-dev deployment/sample-service

# Force trigger next sequence
keptn trigger delivery --project=sample-app --service=sample-service --image=nginx:1.22
```

## Clean Up

```bash
# Delete Keptn project
keptn delete project sample-app

# Uninstall Keptn
keptn uninstall

# Clean up monitoring
helm uninstall prometheus -n monitoring
kubectl delete namespace monitoring

# Clean up Istio (if installed)
istioctl x uninstall --purge
```

## Next Steps

Excellent! You now understand application lifecycle management with Keptn. Next, let's explore cloud-native CI/CD with [Part 10: Jenkins X](../10-jenkins-x/README.md).

## Additional Resources

- [Keptn Documentation](https://keptn.sh/docs/)
- [Keptn Tutorials](https://tutorials.keptn.sh/)
- [Keptn Examples](https://github.com/keptn/examples)
- [Quality Gates Guide](https://keptn.sh/docs/concepts/quality_gates/)
