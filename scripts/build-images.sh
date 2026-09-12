#!/bin/bash
set -euo pipefail

PROFILE="k8s-assignment"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== K8s Assignment: Build & Load Images ==="

# Build frontend image
echo ""
echo "[1/4] Building frontend image..."
docker build -t k8s-frontend:1.0 "$PROJECT_DIR/apps/frontend/"

# Build backend image
echo ""
echo "[2/4] Building backend image..."
docker build -t k8s-backend:1.0 "$PROJECT_DIR/apps/backend/"

# Load images into Minikube
echo ""
echo "[3/4] Loading frontend image into Minikube..."
minikube image load k8s-frontend:1.0 -p "$PROFILE"

echo ""
echo "[4/4] Loading backend image into Minikube..."
minikube image load k8s-backend:1.0 -p "$PROFILE"

echo ""
echo "=== Images built and loaded! ==="
echo ""
echo "Verify with: minikube image ls -p $PROFILE | grep k8s-"
echo ""
echo "Next step: Run ./scripts/deploy-all.sh"
