$ErrorActionPreference = "Stop"
$K8S_DIR = Join-Path (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)) "k8s"
$NAMESPACE = "k8s-assignment"

Write-Host "=== K8s Assignment: Deploy All ===" -ForegroundColor Cyan

Write-Host "`n[1/8] Creating namespace..." -ForegroundColor Yellow
kubectl apply -f "$K8S_DIR\namespace.yaml"

Write-Host "`n[2/8] Applying ConfigMap and Secret..." -ForegroundColor Yellow
kubectl apply -f "$K8S_DIR\config\configmap.yaml"
kubectl apply -f "$K8S_DIR\config\secret.yaml"

Write-Host "`n[3/8] Creating PersistentVolume and PersistentVolumeClaim..." -ForegroundColor Yellow
Write-Host "     Creating hostPath directory on database node..."
minikube ssh -p k8s-assignment -n k8s-assignment-m03 "sudo mkdir -p /mnt/data/postgres"
kubectl apply -f "$K8S_DIR\database\pv.yaml"
kubectl apply -f "$K8S_DIR\database\pvc.yaml"

Write-Host "`n[4/8] Deploying PostgreSQL..." -ForegroundColor Yellow
kubectl apply -f "$K8S_DIR\database\deployment.yaml"
kubectl apply -f "$K8S_DIR\database\service.yaml"
Write-Host "     Waiting for PostgreSQL to be ready..."
kubectl rollout status deployment/postgres -n $NAMESPACE --timeout=120s

Write-Host "`n[5/8] Deploying Backend..." -ForegroundColor Yellow
kubectl apply -f "$K8S_DIR\backend\deployment.yaml"
kubectl apply -f "$K8S_DIR\backend\service.yaml"
Write-Host "     Waiting for Backend to be ready..."
kubectl rollout status deployment/backend -n $NAMESPACE --timeout=120s

Write-Host "`n[6/8] Deploying Frontend..." -ForegroundColor Yellow
kubectl apply -f "$K8S_DIR\frontend\deployment.yaml"
kubectl apply -f "$K8S_DIR\frontend\service.yaml"
Write-Host "     Waiting for Frontend to be ready..."
kubectl rollout status deployment/frontend -n $NAMESPACE --timeout=120s

Write-Host "`n[7/8] Creating HorizontalPodAutoscaler..." -ForegroundColor Yellow
kubectl apply -f "$K8S_DIR\backend\hpa.yaml"

Write-Host "`n[8/8] Creating Ingress..." -ForegroundColor Yellow
kubectl apply -f "$K8S_DIR\ingress\ingress.yaml"

Write-Host "`n=== Deployment complete! ===" -ForegroundColor Green
Write-Host "`n--- Status ---" -ForegroundColor Cyan
kubectl get all -n $NAMESPACE
Write-Host "`n--- PVC ---" -ForegroundColor Cyan
kubectl get pvc -n $NAMESPACE
Write-Host "`n--- Ingress ---" -ForegroundColor Cyan
kubectl get ingress -n $NAMESPACE
Write-Host "`n--- HPA ---" -ForegroundColor Cyan
kubectl get hpa -n $NAMESPACE
Write-Host "`n=== Access the app ===" -ForegroundColor Green
Write-Host "Run:  minikube tunnel -p k8s-assignment"
Write-Host "Then: open http://localhost in your browser"
