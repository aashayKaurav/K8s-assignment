# K8s Assignment - 3-Tier Application on Kubernetes

A complete 3-tier application (Frontend + Backend + PostgreSQL) deployed on a local Kubernetes cluster (Minikube) to learn core K8s concepts.

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

**Nodes:**
- `minikube` — Control plane + workloads
- `minikube-m02` — Worker (Frontend + Backend pods)
- `minikube-m03` — Worker (PostgreSQL only, tainted)

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Minikube](https://minikube.sigs.k8s.io/) — `winget install Kubernetes.minikube`
- [kubectl](https://kubernetes.io/docs/tasks/tools/) — comes with Docker Desktop

## Quick Start

```bash
# 1. Setup the 3-node cluster
./scripts/setup-cluster.sh

# 2. Build and load Docker images
./scripts/build-images.sh

# 3. Deploy everything
./scripts/deploy-all.sh

# 4. Access the app
minikube tunnel -p k8s-assignment
# Open http://localhost in your browser
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
├── scripts/             # Setup, build, deploy, teardown
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
kubectl describe node minikube-m03 | grep Taint

# Check PVC status
kubectl get pvc -n k8s-assignment

# Port-forward to a specific service (alternative to Ingress)
kubectl port-forward svc/backend-service 5000:80 -n k8s-assignment

# Shell into a pod
kubectl exec -it deploy/backend -n k8s-assignment -- /bin/sh
```

## Troubleshooting Exercises

See [troubleshooting/exercises.md](troubleshooting/exercises.md) for 5 hands-on debugging scenarios:

1. Wrong image tag (ImagePullBackOff)
2. Missing Secret reference (CreateContainerConfigError)
3. Wrong targetPort in Service (502 Bad Gateway)
4. Memory limit too low (OOMKilled)
5. Wrong liveness probe path (repeated restarts)

## Teardown

```bash
./scripts/teardown.sh
```
