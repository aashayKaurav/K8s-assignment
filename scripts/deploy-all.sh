#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
K8S_DIR="$(dirname "$SCRIPT_DIR")/k8s"
NAMESPACE="k8s-assignment"

echo "=== K8s Assignment: Deploy All ==="

# Step 1: Namespace
echo ""
echo "[1/8] Creating namespace..."
kubectl apply -f "$K8S_DIR/namespace.yaml"

# Step 2: ConfigMap + Secret
echo ""
echo "[2/8] Applying ConfigMap and Secret..."
kubectl apply -f "$K8S_DIR/config/configmap.yaml"
kubectl apply -f "$K8S_DIR/config/secret.yaml"

# Step 3: PV + PVC
echo ""
echo "[3/8] Creating PersistentVolume and PersistentVolumeClaim..."
kubectl apply -f "$K8S_DIR/database/pv.yaml"
kubectl apply -f "$K8S_DIR/database/pvc.yaml"

# Step 4: PostgreSQL
echo ""
echo "[4/8] Deploying PostgreSQL..."
kubectl apply -f "$K8S_DIR/database/deployment.yaml"
kubectl apply -f "$K8S_DIR/database/service.yaml"

echo "     Waiting for PostgreSQL to be ready..."
kubectl rollout status deployment/postgres -n "$NAMESPACE" --timeout=120s

# Step 5: Backend
echo ""
echo "[5/8] Deploying Backend..."
kubectl apply -f "$K8S_DIR/backend/deployment.yaml"
kubectl apply -f "$K8S_DIR/backend/service.yaml"

echo "     Waiting for Backend to be ready..."
kubectl rollout status deployment/backend -n "$NAMESPACE" --timeout=120s

# Step 6: Frontend
echo ""
echo "[6/8] Deploying Frontend..."
kubectl apply -f "$K8S_DIR/frontend/deployment.yaml"
kubectl apply -f "$K8S_DIR/frontend/service.yaml"

echo "     Waiting for Frontend to be ready..."
kubectl rollout status deployment/frontend -n "$NAMESPACE" --timeout=120s

# Step 7: HPA
echo ""
echo "[7/8] Creating HorizontalPodAutoscaler..."
kubectl apply -f "$K8S_DIR/backend/hpa.yaml"

# Step 8: Ingress
echo ""
echo "[8/8] Creating Ingress..."
kubectl apply -f "$K8S_DIR/ingress/ingress.yaml"

echo ""
echo "=== Deployment complete! ==="
echo ""
echo "--- Status ---"
kubectl get all -n "$NAMESPACE"
echo ""
echo "--- PVC ---"
kubectl get pvc -n "$NAMESPACE"
echo ""
echo "--- Ingress ---"
kubectl get ingress -n "$NAMESPACE"
echo ""
echo "--- HPA ---"
kubectl get hpa -n "$NAMESPACE"
echo ""
echo "=== Access the app ==="
echo "Run:  minikube tunnel -p k8s-assignment"
echo "Then: open http://localhost in your browser"
