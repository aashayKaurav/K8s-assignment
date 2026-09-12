$ErrorActionPreference = "Stop"
$PROFILE_NAME = "k8s-assignment"
$PROJECT_DIR = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

Write-Host "=== K8s Assignment: Build & Load Images ===" -ForegroundColor Cyan

Write-Host "`n[1/4] Building frontend image..." -ForegroundColor Yellow
docker build -t k8s-frontend:1.0 "$PROJECT_DIR\apps\frontend\"
if ($LASTEXITCODE -ne 0) { throw "Frontend build failed" }

Write-Host "`n[2/4] Building backend image..." -ForegroundColor Yellow
docker build -t k8s-backend:1.0 "$PROJECT_DIR\apps\backend\"
if ($LASTEXITCODE -ne 0) { throw "Backend build failed" }

Write-Host "`n[3/4] Loading frontend image into Minikube..." -ForegroundColor Yellow
minikube image load k8s-frontend:1.0 -p $PROFILE_NAME
if ($LASTEXITCODE -ne 0) { throw "Frontend image load failed" }

Write-Host "`n[4/4] Loading backend image into Minikube..." -ForegroundColor Yellow
minikube image load k8s-backend:1.0 -p $PROFILE_NAME
if ($LASTEXITCODE -ne 0) { throw "Backend image load failed" }

Write-Host "`n=== Images built and loaded! ===" -ForegroundColor Green
Write-Host "`nVerify with: minikube image ls -p $PROFILE_NAME | Select-String 'k8s-'"
Write-Host "Next step: Run .\scripts\deploy-all.ps1"
