$ErrorActionPreference = "Stop"
$PROFILE_NAME = "k8s-assignment"
$DB_NODE = "$PROFILE_NAME-m03"

Write-Host "=== K8s Assignment: Cluster Setup ===" -ForegroundColor Cyan

Write-Host "`n[1/4] Starting 3-node Minikube cluster..." -ForegroundColor Yellow
minikube start --nodes=3 --driver=docker --cpus=2 --memory=4096 --profile=$PROFILE_NAME
if ($LASTEXITCODE -ne 0) { throw "Minikube start failed" }

Write-Host "`n[2/4] Labeling database node ($DB_NODE)..." -ForegroundColor Yellow
kubectl label nodes $DB_NODE node-role=database --overwrite

Write-Host "`n[3/4] Tainting database node ($DB_NODE)..." -ForegroundColor Yellow
kubectl taint nodes $DB_NODE dedicated=database:NoSchedule --overwrite 2>$null
if ($LASTEXITCODE -ne 0) {
    # Taint may already exist, that's fine
    Write-Host "  (taint already exists or applied)" -ForegroundColor Gray
}

Write-Host "`n[4/4] Enabling addons (ingress, metrics-server)..." -ForegroundColor Yellow
minikube addons enable ingress -p $PROFILE_NAME
minikube addons enable metrics-server -p $PROFILE_NAME

Write-Host "`n=== Cluster setup complete! ===" -ForegroundColor Green
Write-Host "`nNodes:"
kubectl get nodes -o wide
Write-Host "`nNext step: Run .\scripts\build-images.ps1"
