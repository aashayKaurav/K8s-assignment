#!/bin/bash
set -euo pipefail

PROFILE="k8s-assignment"
DB_NODE="${PROFILE}-m03"

echo "=== K8s Assignment: Cluster Setup ==="

# Step 1: Start a 3-node Minikube cluster
echo ""
echo "[1/4] Starting 3-node Minikube cluster..."
minikube start \
    --nodes=3 \
    --driver=docker \
    --cpus=2 \
    --memory=4096 \
    --profile="$PROFILE"

echo ""
echo "[2/4] Labeling database node (${DB_NODE})..."
kubectl label nodes ${DB_NODE} node-role=database --overwrite

echo ""
echo "[3/4] Tainting database node (${DB_NODE})..."
kubectl taint nodes ${DB_NODE} dedicated=database:NoSchedule --overwrite 2>/dev/null || true

echo ""
echo "[4/4] Enabling addons (ingress, metrics-server)..."
minikube addons enable ingress -p "$PROFILE"
minikube addons enable metrics-server -p "$PROFILE"

echo ""
echo "=== Cluster setup complete! ==="
echo ""
echo "Nodes:"
kubectl get nodes -o wide
echo ""
echo "Next step: Run ./scripts/build-images.sh"
