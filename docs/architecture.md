# Architecture

## System Overview

This is a 3-tier application running on a 3-node Minikube Kubernetes cluster.

```
┌─── minikube (control-plane) ──────────────────────────────────────────────┐
│  K8s API Server, etcd, scheduler, controller-manager                      │
│  Also runs workload pods (no NoSchedule taint on control plane)          │
└──────────────────────────────────────────────────────────────────────────┘

┌─── minikube-m02 (worker) ────────────────────────────────────────────────┐
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ frontend-xxx │  │ frontend-yyy │  │ backend-xxx  │  │ backend-yyy  │ │
│  │  (nginx:80)  │  │  (nginx:80)  │  │ (flask:5000) │  │ (flask:5000) │ │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘ │
└──────────────────────────────────────────────────────────────────────────┘

┌─── minikube-m03 (worker, tainted: dedicated=database:NoSchedule) ────────┐
│  Label: node-role=database                                                │
│  ┌────────────────────────────────────────┐                              │
│  │  postgres-xxx                          │                              │
│  │  (postgres:16-alpine, port 5432)       │                              │
│  │  Volume: /mnt/data/postgres (hostPath) │                              │
│  └────────────────────────────────────────┘                              │
└──────────────────────────────────────────────────────────────────────────┘
```

## Networking Flow

```
User Browser
    │
    ▼
┌─────────────────────────────────────────────────┐
│  Ingress Controller (nginx)                      │
│  Rules:                                          │
│    /api/*  →  backend-service:80                 │
│    /*      →  frontend-service:80                │
└──────────┬─────────────────────┬────────────────┘
           │                     │
     ┌─────▼─────┐        ┌─────▼──────┐
     │ backend   │        │ frontend   │
     │ -service  │        │ -service   │
     │ :80→5000  │        │ :80→80     │
     └─────┬─────┘        └────────────┘
           │
     ┌─────▼─────┐
     │ postgres   │
     │ -service   │
     │ :5432      │
     └────────────┘
```

## Component Details

### Frontend (Nginx)
- **Image:** `k8s-frontend:1.0` (built locally, loaded into Minikube)
- **Replicas:** 2 (RollingUpdate)
- **Probes:** HTTP GET `/healthz` on port 80
- **Purpose:** Serves static HTML/JS/CSS. The JavaScript makes API calls to `/api/*` which the Ingress routes to the backend.

### Backend (Python Flask + Gunicorn)
- **Image:** `k8s-backend:1.0` (built locally, loaded into Minikube)
- **Replicas:** 2-5 (HPA, CPU target 50%)
- **Probes:**
  - Liveness: HTTP GET `/api/health` (checks DB connection)
  - Readiness: HTTP GET `/api/ready` (checks table exists)
- **Config:** Environment variables from ConfigMap (`DB_HOST`, `DB_PORT`, `DB_NAME`) and Secret (`DB_USER`, `DB_PASSWORD`)
- **Endpoints:** GET/POST/DELETE `/api/items`, GET `/api/health`, GET `/api/ready`

### PostgreSQL
- **Image:** `postgres:16-alpine` (from Docker Hub)
- **Replicas:** 1 (Recreate strategy — no dual-write risk)
- **Probes:** `pg_isready` exec command
- **Storage:** 1Gi PersistentVolume (hostPath on minikube-m03)
- **Scheduling:**
  - **Toleration:** Allows scheduling on tainted node (`dedicated=database:NoSchedule`)
  - **Node Affinity:** Required on nodes with `node-role=database` label
- **Config:** POSTGRES_DB from ConfigMap, POSTGRES_USER/POSTGRES_PASSWORD from Secret

### ConfigMap (`app-config`)
Stores non-sensitive database configuration:
- `DB_HOST=postgres-service`
- `DB_PORT=5432`
- `DB_NAME=appdb`

### Secret (`db-secret`)
Stores sensitive database credentials (base64 encoded):
- `DB_USER=appuser`
- `DB_PASSWORD=apppassword`

### HPA (`backend-hpa`)
- Target: backend Deployment
- Metric: CPU utilization at 50%
- Range: 2 (min) to 5 (max) replicas
- Requires `metrics-server` addon enabled

## Why These Design Choices?

| Decision | Reason |
|----------|--------|
| Recreate for PostgreSQL | Prevents two instances writing to the same volume simultaneously |
| RollingUpdate for FE/BE | Zero-downtime deployments for stateless services |
| ClusterIP for all Services | Internal-only; Ingress provides the single external entry point |
| Taint + Toleration for DB | Ensures only PostgreSQL runs on the database node |
| Node Affinity for DB | Pins PostgreSQL to the node with its hostPath volume |
| envFrom (ConfigMap + Secret) | Clean separation of config from code, sensitive vs non-sensitive |
| PV with nodeAffinity | Data persists on the specific node, survives pod restarts |
| HPA on backend only | Backend is the compute-heavy tier; frontend serves static files |
