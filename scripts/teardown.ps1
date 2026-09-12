$PROFILE_NAME = "k8s-assignment"
$NAMESPACE = "k8s-assignment"

Write-Host "=== K8s Assignment: Teardown ===" -ForegroundColor Cyan

$confirm = Read-Host "This will delete all resources. Continue? (y/N)"
if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "Aborted."
    exit 0
}

Write-Host "`n[1/3] Deleting namespace and all resources within it..." -ForegroundColor Yellow
kubectl delete namespace $NAMESPACE --ignore-not-found

Write-Host "`n[2/3] Deleting PersistentVolume (cluster-scoped)..." -ForegroundColor Yellow
kubectl delete pv postgres-pv --ignore-not-found

$deleteCluster = Read-Host "`n[3/3] Also delete the Minikube cluster? (y/N)"
if ($deleteCluster -eq "y" -or $deleteCluster -eq "Y") {
    minikube delete -p $PROFILE_NAME
    Write-Host "Minikube cluster deleted." -ForegroundColor Green
} else {
    Write-Host "Minikube cluster kept. Delete manually with: minikube delete -p $PROFILE_NAME" -ForegroundColor Gray
}

Write-Host "`n=== Teardown complete! ===" -ForegroundColor Green
