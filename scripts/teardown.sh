#!/bin/bash
set -euo pipefail

PROFILE="k8s-assignment"
NAMESPACE="k8s-assignment"

echo "=== K8s Assignment: Teardown ==="

read -p "This will delete all resources. Continue? (y/N) " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "[1/3] Deleting namespace and all resources within it..."
kubectl delete namespace "$NAMESPACE" --ignore-not-found

echo ""
echo "[2/3] Deleting PersistentVolume (cluster-scoped)..."
kubectl delete pv postgres-pv --ignore-not-found

echo ""
echo "[3/3] Stopping and deleting Minikube cluster..."
read -p "Also delete the Minikube cluster? (y/N) " delete_cluster
if [[ "$delete_cluster" == "y" || "$delete_cluster" == "Y" ]]; then
    minikube delete -p "$PROFILE"
    echo "Minikube cluster deleted."
else
    echo "Minikube cluster kept. Delete manually with: minikube delete -p $PROFILE"
fi

echo ""
echo "=== Teardown complete! ==="
