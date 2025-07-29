#!/bin/bash

# Kubernetes Basics - Run Examples Script
# Runs through all the examples in the README automatically

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

NAMESPACE="kubernetes-basics-demo"

echo -e "${CYAN}Kubernetes Basics - Running Examples${NC}"
echo "===================================="
echo

# Verify cluster is accessible
if ! kubectl cluster-info &>/dev/null; then
    log_error "Cannot connect to Kubernetes cluster"
    echo "Please run './verify-setup.sh' first"
    exit 1
fi

# Create demo namespace
log_step "Creating demo namespace..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
log_success "Namespace '$NAMESPACE' ready"

echo

# Example 1: Simple Pod
log_step "Example 1: Creating a simple pod..."
kubectl apply -n "$NAMESPACE" -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx-pod
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
EOF

log_info "Waiting for pod to be ready..."
kubectl wait --for=condition=Ready pod/nginx-pod -n "$NAMESPACE" --timeout=60s

log_success "Pod created and ready"
kubectl get pod nginx-pod -n "$NAMESPACE"

echo

# Example 2: Deployment
log_step "Example 2: Creating a deployment..."
kubectl apply -n "$NAMESPACE" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
EOF

log_info "Waiting for deployment to be ready..."
kubectl wait --for=condition=Available deployment/nginx-deployment -n "$NAMESPACE" --timeout=120s

log_success "Deployment created and ready"
kubectl get deployment nginx-deployment -n "$NAMESPACE"
kubectl get pods -l app=nginx -n "$NAMESPACE"

echo

# Example 3: Service
log_step "Example 3: Creating a service..."
kubectl apply -n "$NAMESPACE" -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

log_success "Service created"
kubectl get service nginx-service -n "$NAMESPACE"

echo

# Example 4: ConfigMap
log_step "Example 4: Creating a ConfigMap..."
kubectl create configmap app-config -n "$NAMESPACE" \
  --from-literal=database_url=postgresql://localhost:5432/mydb \
  --from-literal=debug=true \
  --dry-run=client -o yaml | kubectl apply -f -

log_success "ConfigMap created"
kubectl get configmap app-config -n "$NAMESPACE"

echo

# Example 5: Secret
log_step "Example 5: Creating a Secret..."
kubectl create secret generic app-secret -n "$NAMESPACE" \
  --from-literal=username=admin \
  --from-literal=password=secret123 \
  --dry-run=client -o yaml | kubectl apply -f -

log_success "Secret created"
kubectl get secret app-secret -n "$NAMESPACE"

echo

# Example 6: PVC
log_step "Example 6: Creating a PersistentVolumeClaim..."
kubectl apply -n "$NAMESPACE" -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: demo-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

log_info "Waiting for PVC to be bound..."
sleep 5

PVC_STATUS=$(kubectl get pvc demo-pvc -n "$NAMESPACE" -o jsonpath='{.status.phase}')
if [ "$PVC_STATUS" = "Bound" ]; then
    log_success "PVC created and bound"
else
    log_warning "PVC status: $PVC_STATUS (may need more time)"
fi

kubectl get pvc demo-pvc -n "$NAMESPACE"

echo

# Example 7: Complete application with service
log_step "Example 7: Deploying complete test application..."
kubectl apply -n "$NAMESPACE" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: test-app
        image: nginxdemos/hello:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: test-app-service
spec:
  selector:
    app: test-app
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

log_info "Waiting for test application to be ready..."
kubectl wait --for=condition=Available deployment/test-app -n "$NAMESPACE" --timeout=120s

log_success "Test application deployed and ready"
kubectl get all -l app=test-app -n "$NAMESPACE"

echo

# Test the application
log_step "Testing the application..."
echo "Starting port-forward to test the application..."
kubectl port-forward service/test-app-service 8080:80 -n "$NAMESPACE" &
PORT_FORWARD_PID=$!

# Wait a moment for port-forward to start
sleep 3

# Test the service
if curl -s http://localhost:8080 > /dev/null; then
    log_success "Application is responding on http://localhost:8080"
    echo "You can test it with: curl http://localhost:8080"
else
    log_warning "Could not reach application (port-forward may need more time)"
fi

# Stop port-forward
kill $PORT_FORWARD_PID 2>/dev/null || true

echo

# Show all resources
log_step "Summary of all created resources:"
kubectl get all -n "$NAMESPACE"

echo

# Scaling example
log_step "Bonus: Scaling deployment..."
kubectl scale deployment nginx-deployment --replicas=5 -n "$NAMESPACE"
log_info "Scaled nginx-deployment to 5 replicas"

kubectl wait --for=condition=Available deployment/nginx-deployment -n "$NAMESPACE" --timeout=60s
kubectl get deployment nginx-deployment -n "$NAMESPACE"

echo

# Cleanup prompt
echo -e "${CYAN}Examples completed successfully!${NC}"
echo
echo "Resources created in namespace '$NAMESPACE':"
echo "- nginx-pod (single pod)"
echo "- nginx-deployment (5 replicas)"
echo "- nginx-service (ClusterIP service)"
echo "- test-app deployment and service"
echo "- app-config (ConfigMap)"
echo "- app-secret (Secret)"
echo "- demo-pvc (PersistentVolumeClaim)"
echo

read -p "Do you want to clean up all demo resources? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Cleaning up demo resources..."
    kubectl delete namespace "$NAMESPACE"
    log_success "Demo namespace and all resources deleted"
else
    log_info "Demo resources preserved in namespace '$NAMESPACE'"
    echo "To clean up later, run: kubectl delete namespace $NAMESPACE"
fi

echo
echo -e "${GREEN}Kubernetes basics examples completed!${NC}"
echo "Next: Continue to Part 3 - GitOps Introduction"
