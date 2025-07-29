# Part 2: Kubernetes Basics

Now that you have Kubernetes running (from Part 1), let's explore the fundamental concepts and operations. This section works with any Kubernetes setup - Docker Desktop, Minikube, or Kind.

## What You'll Learn

In this section, you'll learn:
- Core Kubernetes concepts (Pods, Deployments, Services)
- Essential kubectl commands
- How to manage applications declaratively
- Persistent storage basics
- Troubleshooting common issues

## Prerequisites

- Kubernetes cluster running (from Part 1)
- kubectl configured and working
- At least 2GB RAM available for your cluster
- Internet connection for pulling container images

## Verify Your Setup

Before we start, let's make sure your Kubernetes cluster is ready:

```bash
# Check cluster status
kubectl cluster-info

# Check nodes are ready
kubectl get nodes

# Check system pods are running
kubectl get pods -n kube-system

# Check your current context
kubectl config current-context
```

You should see output similar to:
- **Docker Desktop**: Context shows `docker-desktop`
- **Minikube**: Context shows `minikube`
- **Kind**: Context shows `kind-gitops-lab`

If any commands fail, return to [Part 1: Kubernetes Setup](../01-kubernetes-setup/README.md) to fix your setup.

## Basic Kubernetes Concepts

### Pods

The smallest deployable unit in Kubernetes.

```yaml
# Create a simple pod
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
spec:
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
```

```bash
# Apply the pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
spec:
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
EOF

# Check pod status
kubectl get pods
kubectl describe pod nginx-pod
```

### Deployments

Manage replica sets and pods declaratively.

```yaml
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
        image: nginx:latest
        ports:
        - containerPort: 80
```

```bash
# Create deployment
kubectl apply -f - <<EOF
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
        image: nginx:latest
        ports:
        - containerPort: 80
EOF

# Check deployment
kubectl get deployments
kubectl get pods -l app=nginx
```

### Services

Expose applications running on pods.

```yaml
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
```

```bash
# Create service
kubectl apply -f - <<EOF
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

# Check service
kubectl get services
```

## Essential kubectl Commands

```bash
# Cluster information
kubectl cluster-info
kubectl get nodes
kubectl get namespaces

# Pod management
kubectl get pods
kubectl get pods -A  # all namespaces
kubectl describe pod <pod-name>
kubectl logs <pod-name>
kubectl exec -it <pod-name> -- bash

# Deployment management
kubectl get deployments
kubectl scale deployment nginx-deployment --replicas=5
kubectl rollout status deployment nginx-deployment
kubectl rollout history deployment nginx-deployment

# Service management
kubectl get services
kubectl describe service <service-name>

# Resource management
kubectl get all
kubectl delete pod <pod-name>
kubectl delete deployment <deployment-name>
kubectl delete service <service-name>

# Yaml output
kubectl get pod <pod-name> -o yaml
kubectl get deployment <deployment-name> -o yaml
```

## Namespaces

Organize resources in logical groups.

```bash
# Create namespace
kubectl create namespace gitops-lab

# List namespaces
kubectl get namespaces

# Deploy to specific namespace
kubectl apply -f deployment.yaml -n gitops-lab

# Set default namespace
kubectl config set-context --current --namespace=gitops-lab
```

## ConfigMaps and Secrets

### ConfigMaps

Store configuration data.

```bash
# Create configmap from literal
kubectl create configmap app-config \
  --from-literal=database_url=postgresql://localhost:5432/mydb \
  --from-literal=debug=true

# Create configmap from file
echo "app.name=MyApp" > app.properties
kubectl create configmap app-config-file --from-file=app.properties

# View configmap
kubectl get configmaps
kubectl describe configmap app-config
```

### Secrets

Store sensitive data.

```bash
# Create secret
kubectl create secret generic app-secret \
  --from-literal=username=admin \
  --from-literal=password=secret123

# View secret
kubectl get secrets
kubectl describe secret app-secret

# Decode secret
kubectl get secret app-secret -o jsonpath='{.data.username}' | base64 -d
```

### Persistent Volumes

Most Kubernetes distributions come with storage provisioners:

- **Docker Desktop**: Uses `hostpath` provisioner
- **Minikube**: Uses `standard` storage class  
- **Kind**: Uses `standard` storage class

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

```bash
# Create PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# Check PVC
kubectl get pvc

# Check available storage classes
kubectl get storageclass
```

## Testing Your Setup

Create a simple test application:

```bash
# Create a test deployment with service
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  namespace: default
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
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: test-app-service
  namespace: default
spec:
  selector:
    app: test-app
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

# Test the application
kubectl get all

# Access the application (method depends on your setup)
# For Docker Desktop or Kind:
kubectl port-forward service/test-app-service 8080:80

# For Minikube:
# minikube service test-app-service --url

# In another terminal (or background the previous command with &)
curl http://localhost:8080
```

## Troubleshooting

### Issue: kubectl connection refused

```bash
# Check cluster status
kubectl cluster-info

# For Docker Desktop: ensure Kubernetes is enabled in settings
# For Minikube: check if cluster is running
minikube status

# For Kind: check if cluster exists
kind get clusters
```

### Issue: Pods stuck in pending

```bash
# Check pod events
kubectl describe pod <pod-name>

# Check node resources
kubectl describe nodes

# Check if nodes have sufficient resources
kubectl top nodes  # requires metrics-server
```

### Issue: ImagePullBackOff

```bash
# Check pod events
kubectl describe pod <pod-name>

# Check if image name is correct
# Check internet connectivity
# For private images, check if pull secrets are configured
```

### Common Solutions by Platform

**Docker Desktop:**
```bash
# Restart Docker Desktop if issues persist
# Go to Docker Desktop → Troubleshoot → Restart
```

**Minikube:**
```bash
# Restart minikube
minikube stop
minikube start

# Check logs
minikube logs
```

**Kind:**
```bash
# Recreate cluster if needed
kind delete cluster --name gitops-lab
kind create cluster --name gitops-lab
```

## Clean Up

```bash
# Remove test resources
kubectl delete deployment test-app
kubectl delete service test-app-service
kubectl delete deployment nginx-deployment
kubectl delete service nginx-service
kubectl delete pod nginx-pod
```

## Next Steps

Great! You now have a working Kubernetes cluster. Next, we'll explore GitOps principles and patterns in [Part 3: GitOps Introduction](../03-gitops-intro/README.md).

## Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Docker Desktop Kubernetes](https://docs.docker.com/desktop/kubernetes/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)
- [Kind Documentation](https://kind.sigs.k8s.io/)

## What You've Learned

In this section, you've learned:

- ✅ Core Kubernetes concepts (Pods, Deployments, Services)
- ✅ Essential kubectl commands for daily operations
- ✅ How to work with ConfigMaps and Secrets
- ✅ Persistent storage in Kubernetes
- ✅ Basic troubleshooting techniques
- ✅ Platform-specific considerations

## Hands-On Exercises

Try these exercises to reinforce your learning:

1. **Create a multi-container pod** with nginx and a sidecar container
2. **Deploy a database** (PostgreSQL) with persistent storage
3. **Create a namespace** and deploy applications in it
4. **Practice scaling** deployments up and down
5. **Expose a service** using different service types

### Exercise: Deploy a Complete Application Stack

```bash
# Create a namespace for the exercise
kubectl create namespace exercise

# Deploy a web application with database
kubectl apply -n exercise -f - <<EOF
# PostgreSQL Database
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:13
        env:
        - name: POSTGRES_DB
          value: myapp
        - name: POSTGRES_USER
          value: user
        - name: POSTGRES_PASSWORD
          value: password
        ports:
        - containerPort: 5432
---
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
---
# Web Application
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: webapp
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
spec:
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
  type: NodePort
EOF

# Check the deployment
kubectl get all -n exercise

# Test the webapp
kubectl port-forward -n exercise service/webapp-service 8080:80
```
