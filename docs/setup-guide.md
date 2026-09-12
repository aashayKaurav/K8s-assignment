# Setup Guide

A step-by-step walkthrough for deploying the 3-tier application on Kubernetes.

## 1. Prerequisites

### Install Minikube
```bash
winget install Kubernetes.minikube
```

### Verify tools
```bash
minikube version
kubectl version --client
docker --version
```

## 2. Create the Cluster

We create a 3-node cluster to simulate a real multi-node environment:

```bash
minikube start --nodes=3 --driver=docker --cpus=2 --memory=4096 --profile=k8s-assignment
```

**What this does:**
- Creates 3 Docker containers acting as K8s nodes
- `k8s-assignment` — control-plane node (also runs workloads by default)
- `k8s-assignment-m02` — worker node for FE/BE pods
- `k8s-assignment-m03` — worker node (will be dedicated to database)

Verify:
```bash
kubectl get nodes
```

## 3. Label and Taint the Database Node

### Labels
Labels are key-value metadata on nodes. We use them with Node Affinity to control pod scheduling.

```bash
kubectl label nodes k8s-assignment-m03 node-role=database
```

### Taints
Taints prevent pods from scheduling on a node unless they have a matching toleration.

```bash
kubectl taint nodes k8s-assignment-m03 dedicated=database:NoSchedule
```

This means: "Only pods that tolerate `dedicated=database:NoSchedule` can run here."

Verify:
```bash
kubectl describe node k8s-assignment-m03 | grep -A5 "Taints\|Labels"
```

## 4. Enable Addons

```bash
minikube addons enable ingress -p k8s-assignment
minikube addons enable metrics-server -p k8s-assignment
```

- **ingress** — Deploys an Nginx Ingress Controller for path-based routing
- **metrics-server** — Collects CPU/memory metrics for HPA to work

## 5. Build Docker Images

```bash
docker build -t k8s-frontend:1.0 ./apps/frontend/
docker build -t k8s-backend:1.0 ./apps/backend/
```

Load them into Minikube (since we're not using a registry):
```bash
minikube image load k8s-frontend:1.0 -p k8s-assignment
minikube image load k8s-backend:1.0 -p k8s-assignment
```

All deployments use `imagePullPolicy: Never` so K8s uses these pre-loaded images.

## 6. Deploy — Step by Step

### 6.1 Namespace
```bash
kubectl apply -f k8s/namespace.yaml
```
**Concept:** Namespaces provide isolation. All our resources live in `k8s-assignment`.

### 6.2 ConfigMap and Secret
```bash
kubectl apply -f k8s/config/configmap.yaml
kubectl apply -f k8s/config/secret.yaml
```
**Concept:**
- **ConfigMap** — stores non-sensitive config as key-value pairs
- **Secret** — stores sensitive data (base64 encoded). In production, use external secret managers.

Verify:
```bash
kubectl get configmap,secret -n k8s-assignment
kubectl describe configmap app-config -n k8s-assignment
```

### 6.3 PersistentVolume and PVC
```bash
kubectl apply -f k8s/database/pv.yaml
kubectl apply -f k8s/database/pvc.yaml
```
**Concept:**
- **PV** — a piece of storage in the cluster (here, a directory on the DB node)
- **PVC** — a request for storage by a pod. The PVC binds to a matching PV.

Verify:
```bash
kubectl get pv,pvc -n k8s-assignment
```
PVC should show `Bound` status.

### 6.4 PostgreSQL
```bash
kubectl apply -f k8s/database/deployment.yaml
kubectl apply -f k8s/database/service.yaml
kubectl rollout status deployment/postgres -n k8s-assignment
```
**Concepts demonstrated:**
- **Tolerations** — allows this pod to run on the tainted node
- **Node Affinity** — ensures this pod ONLY runs on the labeled node
- **Recreate strategy** — kills old pod before creating new one (safe for DBs)
- **PVC mount** — persistent storage

Verify:
```bash
kubectl get pods -n k8s-assignment -o wide   # Should be on k8s-assignment-m03
```

### 6.5 Backend
```bash
kubectl apply -f k8s/backend/deployment.yaml
kubectl apply -f k8s/backend/service.yaml
kubectl rollout status deployment/backend -n k8s-assignment
```
**Concepts:**
- **RollingUpdate** — maxSurge:1, maxUnavailable:0 (zero-downtime)
- **envFrom** — injects all ConfigMap + Secret keys as environment variables
- **Liveness probe** — checks `/api/health` (DB connection alive)
- **Readiness probe** — checks `/api/ready` (DB table exists)

### 6.6 Frontend
```bash
kubectl apply -f k8s/frontend/deployment.yaml
kubectl apply -f k8s/frontend/service.yaml
kubectl rollout status deployment/frontend -n k8s-assignment
```

### 6.7 HPA
```bash
kubectl apply -f k8s/backend/hpa.yaml
```
**Concept:** HPA watches CPU metrics and scales the backend between 2-5 replicas.

Verify:
```bash
kubectl get hpa -n k8s-assignment
```
Note: CPU metrics may show `<unknown>` for 1-2 minutes until metrics-server collects data.

### 6.8 Ingress
```bash
kubectl apply -f k8s/ingress/ingress.yaml
```
**Concept:** Ingress provides a single entry point with path-based routing:
- `/api/*` → backend-service
- `/*` → frontend-service

## 7. Access the Application

```bash
minikube tunnel -p k8s-assignment
```

Open http://localhost in your browser. You should see the Item Manager UI.

## 8. Verify Everything

```bash
# All pods running
kubectl get all -n k8s-assignment

# PVC bound
kubectl get pvc -n k8s-assignment

# HPA has metrics
kubectl get hpa -n k8s-assignment

# Ingress has address
kubectl get ingress -n k8s-assignment

# Postgres is on the right node
kubectl get pods -n k8s-assignment -o wide | grep postgres

# Node taint is present
kubectl describe node k8s-assignment-m03 | grep Taint
```

## 9. Test HPA Scaling

Generate load on the backend to trigger auto-scaling:

```bash
# In one terminal, watch the HPA
kubectl get hpa -n k8s-assignment --watch

# In another terminal, generate load
kubectl run load-gen --image=busybox -n k8s-assignment --rm -it --restart=Never -- \
  /bin/sh -c "while true; do wget -q -O- http://backend-service/api/items; done"
```

You should see replicas increase from 2 towards 5.

## 10. Teardown

```bash
# Delete all K8s resources
kubectl delete namespace k8s-assignment
kubectl delete pv postgres-pv

# Or delete the entire cluster
minikube delete -p k8s-assignment
```
