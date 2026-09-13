# K8s Assignment - 3-Tier Application on Kubernetes

A complete 3-tier application (Frontend + Backend + PostgreSQL) deployed on a local Kubernetes cluster (Minikube) to learn core K8s concepts.

> **New to this?** See the [Complete Ubuntu Guide](docs/ubuntu-complete-guide.md) for a step-by-step walkthrough covering installation, setup, all K8s experiments, and troubleshooting exercises.

## K8s Concepts Covered

| Concept | Where Used |
|---------|-----------|
| **Namespaces** | All resources in `k8s-assignment` namespace |
| **Deployments** | Frontend, Backend, PostgreSQL |
| **Services (ClusterIP)** | Internal networking between all tiers |
| **Ingress** | Single entry point with path-based routing |
| **ConfigMaps** | Database connection config (host, port, name) |
| **Secrets** | Database credentials (user, password) |
| **PersistentVolume/PVC** | PostgreSQL data persistence |
| **HPA** | Backend auto-scaling (CPU-based, 2-5 replicas) |
| **Taints & Tolerations** | Dedicated database node |
| **Node Affinity** | PostgreSQL pinned to labeled node |
| **Liveness/Readiness Probes** | Health checks on all deployments |
| **Rolling Updates** | Zero-downtime deploys for FE/BE |
| **Recreate Strategy** | PostgreSQL (avoid dual-write) |

## Architecture

```
                    ┌─────────────┐
                    │   Ingress   │
                    │  (nginx)    │
                    └──────┬──────┘
                    /              \
              /api/*            /*
                  │                │
         ┌────────▼──────┐  ┌─────▼──────────┐
         │  Backend Svc  │  │  Frontend Svc  │
         │  (ClusterIP)  │  │  (ClusterIP)   │
         └────────┬──────┘  └────────────────┘
                  │
         ┌────────▼──────┐
         │  PostgreSQL   │
         │  Svc+PV/PVC  │
         └───────────────┘
```

**Nodes** (named `<profile>`, `<profile>-m02`, `<profile>-m03`):
- `k8s-assignment` — Control plane + workloads
- `k8s-assignment-m02` — Worker (Frontend + Backend pods)
- `k8s-assignment-m03` — Worker (PostgreSQL only, tainted)

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Minikube](https://minikube.sigs.k8s.io/) — `winget install Kubernetes.minikube` (Windows) or `brew install minikube` (Mac) or [install guide](https://minikube.sigs.k8s.io/docs/start/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) — comes with Docker Desktop

## Quick Start

### Windows (PowerShell)
```powershell
.\scripts\setup-cluster.ps1
.\scripts\build-images.ps1
.\scripts\deploy-all.ps1
minikube tunnel -p k8s-assignment
# Open http://localhost
```

### Linux / Mac (Bash)
```bash
bash scripts/setup-cluster.sh
bash scripts/build-images.sh
bash scripts/deploy-all.sh
minikube tunnel -p k8s-assignment
# Open http://localhost
```

## Project Structure

```
k8s-assignment/
├── apps/
│   ├── frontend/        # Nginx + HTML/JS/CSS
│   └── backend/         # Python Flask REST API
├── k8s/
│   ├── namespace.yaml
│   ├── config/          # ConfigMap + Secret
│   ├── database/        # PostgreSQL (Deploy, Svc, PV, PVC)
│   ├── backend/         # Backend (Deploy, Svc, HPA)
│   ├── frontend/        # Frontend (Deploy, Svc)
│   └── ingress/         # Ingress rules
├── scripts/             # Setup, build, deploy, teardown (.ps1 + .sh)
├── troubleshooting/     # 5 debugging exercises
└── docs/                # Architecture + setup guide
```

## Useful Commands

```bash
# View all resources
kubectl get all -n k8s-assignment

# Check pod logs
kubectl logs -l app=backend -n k8s-assignment

# Watch HPA scaling
kubectl get hpa -n k8s-assignment --watch

# Check which node a pod is on
kubectl get pods -n k8s-assignment -o wide

# Verify DB node taint
kubectl describe node k8s-assignment-m03 | grep Taint

# Check PVC status
kubectl get pvc -n k8s-assignment

# Port-forward to a specific service (alternative to Ingress)
kubectl port-forward svc/backend-service 5000:80 -n k8s-assignment

# Shell into a pod
kubectl exec -it deploy/backend -n k8s-assignment -- /bin/sh
```

> **Note:** If your `kubectl` doesn't connect, use `minikube kubectl -p k8s-assignment --` as a prefix instead.

## Troubleshooting Exercises

See [troubleshooting/exercises.md](troubleshooting/exercises.md) for 5 hands-on debugging scenarios:

1. Wrong image tag (ImagePullBackOff)
2. Missing Secret reference (CreateContainerConfigError)
3. Wrong targetPort in Service (502 Bad Gateway)
4. Memory limit too low (OOMKilled)
5. Wrong liveness probe path (repeated restarts)

## Teardown

### Windows
```powershell
.\scripts\teardown.ps1
```

### Linux / Mac
```bash
bash scripts/teardown.sh
```
