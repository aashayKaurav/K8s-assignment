# Complete Guide: K8s Assignment on Ubuntu

This guide walks you through **everything** — from installing prerequisites to running every Kubernetes experiment and troubleshooting exercise.

---

## Part 1: Prerequisites (One-time Setup)

You need **3 things** installed: Docker, Minikube, and kubectl.

### 1.1 Install Docker

```bash
# Remove old versions (safe to run even if Docker isn't installed)
sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null

# Install dependencies
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key and repo
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin

# Allow running Docker without sudo
sudo usermod -aG docker $USER
newgrp docker

# Verify
docker --version
docker run hello-world
```

If `docker run hello-world` prints "Hello from Docker!" — Docker is ready.

### 1.2 Install Minikube

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64

# Verify
minikube version
```

### 1.3 Install kubectl

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin/kubectl
rm kubectl

# Verify
kubectl version --client
```

### 1.4 Verify All Tools

```bash
docker --version      # Should show Docker version 24+ or 27+
minikube version      # Should show minikube v1.30+
kubectl version --client  # Should show Client Version v1.28+
```

All 3 working? Move to Part 2.

---

## Part 2: Clone and Setup the Cluster

### 2.1 Clone the Repo

```bash
git clone https://github.com/aashayKaurav/K8s-assignment.git
cd K8s-assignment
```

### 2.2 Create the 3-Node Kubernetes Cluster

This creates 3 Docker containers that act as Kubernetes "servers" (nodes):

```bash
bash scripts/setup-cluster.sh
```

This takes **3-5 minutes**. It will:
- Create 3 nodes: `k8s-assignment` (control-plane), `k8s-assignment-m02` (worker), `k8s-assignment-m03` (worker)
- Label `k8s-assignment-m03` as `node-role=database`
- Taint `k8s-assignment-m03` so ONLY the database pod can run there
- Enable the Ingress controller and metrics-server addons

**Verify all 3 nodes are Ready:**
```bash
kubectl get nodes
```

Expected output:
```
NAME                 STATUS   ROLES           AGE   VERSION
k8s-assignment       Ready    control-plane   3m    v1.37.0
k8s-assignment-m02   Ready    <none>          2m    v1.37.0
k8s-assignment-m03   Ready    <none>          1m    v1.37.0
```

If all show `Ready` — move on. If any show `NotReady`, wait a minute and check again.

### 2.3 Build Docker Images

This builds the frontend (Nginx) and backend (Python Flask) images and loads them into Minikube:

```bash
bash scripts/build-images.sh
```

**Verify images are loaded:**
```bash
minikube image ls -p k8s-assignment | grep k8s-
```

You should see `k8s-frontend:1.0` and `k8s-backend:1.0`.

### 2.4 Deploy Everything to Kubernetes

```bash
bash scripts/deploy-all.sh
```

This deploys in order: Namespace → ConfigMap + Secret → PV/PVC → PostgreSQL → Backend → Frontend → HPA → Ingress.

**Verify everything is running:**
```bash
kubectl get all -n k8s-assignment
```

Wait until ALL pods show `Running` and `1/1` under READY. The backend pods may restart a few times while waiting for PostgreSQL — that's normal, they'll stabilize.

### 2.5 Access the Application

Open a **new terminal** and run (keep it open):

```bash
minikube tunnel -p k8s-assignment
```

It may ask for your sudo password. This creates a network tunnel from your machine to the cluster.

Now open your browser and go to: **http://localhost**

You should see the **Item Manager** UI. Try:
- Type a name and description, click "Add Item"
- Add 3-4 items
- Delete one item
- The health badge (top-right) should show "Healthy"

---

## Part 3: Explore Kubernetes Concepts

Now the fun part. Each experiment below demonstrates a core K8s concept.

### 3.1 See Pod Placement (Taints & Node Affinity)

```bash
kubectl get pods -n k8s-assignment -o wide
```

Look at the `NODE` column:

| Pod | Node | Why |
|-----|------|-----|
| frontend pods | `k8s-assignment` or `m02` | Regular worker nodes |
| backend pods | `k8s-assignment` or `m02` | Regular worker nodes |
| postgres pod | `k8s-assignment-m03` ONLY | Taint + Node Affinity |

**Key learning:** No frontend or backend pod is on `m03` because it has a **taint** (`dedicated=database:NoSchedule`). Only PostgreSQL has a **toleration** for that taint.

Verify the taint:
```bash
kubectl describe node k8s-assignment-m03 | grep Taint
```

### 3.2 Data Persistence (PersistentVolumes)

This proves that data survives pod deletion.

**Step 1:** Make sure you have items in the browser (add some if needed).

**Step 2:** Delete the database pod (simulates a crash):
```bash
kubectl delete pod -l app=postgres -n k8s-assignment
```

**Step 3:** Watch K8s automatically create a new pod:
```bash
kubectl get pods -n k8s-assignment -w
```

Wait until the new postgres pod shows `1/1 Running`, then press `Ctrl+C`.

**Step 4:** Refresh the browser — **your items are still there!**

**Why it works:** The data is stored on a **PersistentVolume** (a directory on the node's disk), not inside the container. When the new pod starts, it mounts the same volume and gets the same data.

Check the PVC status:
```bash
kubectl get pvc -n k8s-assignment
```

It should show `Bound` — meaning the storage is allocated and connected.

### 3.3 Auto-Scaling (HPA)

This demonstrates Kubernetes automatically adding pods when CPU usage is high.

**Terminal 1** — Watch the HPA:
```bash
kubectl get hpa -n k8s-assignment -w
```

**Terminal 2** — Generate load (flood the backend with requests):
```bash
kubectl run load-gen --image=busybox -n k8s-assignment --rm -it --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://backend-service/api/items; done"
```

**Watch Terminal 1.** Over 1-2 minutes you'll see:
1. CPU% climbs above 50%
2. REPLICAS increases from 2 → 3 → 4 → 5

**Stop the load:** Press `Ctrl+C` in Terminal 2.

**Watch scale-down:** After ~5 minutes of low CPU, replicas will decrease back to 2.

Verify with:
```bash
kubectl get pods -n k8s-assignment | grep backend
```

### 3.4 Check Logs

```bash
# Backend logs (see HTTP requests)
kubectl logs -l app=backend -n k8s-assignment --tail=20

# PostgreSQL logs
kubectl logs -l app=postgres -n k8s-assignment --tail=20
```

### 3.5 Shell into a Pod

```bash
kubectl exec -it deploy/backend -n k8s-assignment -- /bin/sh
```

Inside the pod:
```bash
# See how ConfigMap and Secret values become environment variables
env | grep DB

# You'll see:
# DB_HOST=postgres-service
# DB_PORT=5432
# DB_NAME=appdb
# DB_USER=appuser
# DB_PASSWORD=apppassword

# Exit the pod
exit
```

**Key learning:** Pods don't hardcode database credentials. They read them from **ConfigMap** (non-sensitive) and **Secret** (sensitive) resources injected as environment variables.

### 3.6 Rolling Update (Zero-Downtime Deployment)

```bash
# In one terminal, watch pods
kubectl get pods -n k8s-assignment -w

# In another terminal, trigger a restart
kubectl rollout restart deployment/backend -n k8s-assignment
```

Watch the first terminal — you'll see:
1. New pods created (`ContainerCreating`)
2. New pods become `Running`
3. ONLY THEN old pods `Terminate`

This is **RollingUpdate** strategy — new pods come up before old ones go down, so there's zero downtime.

### 3.7 Understand Services and Endpoints

```bash
# See all services
kubectl get svc -n k8s-assignment

# See which pod IPs each service routes to
kubectl get endpoints -n k8s-assignment
```

**Key learning:** A Service is a stable internal DNS name (like `backend-service`) that routes traffic to the pod IPs behind it. Pod IPs change when pods restart, but the service name never changes.

---

## Part 4: Troubleshooting Exercises

These are **intentionally broken** Kubernetes manifests. Your job is to **find and understand the bug** using `kubectl` commands.

For each exercise:
1. Apply the broken manifest
2. Observe the symptom
3. Investigate using the debug commands
4. Try to figure out the fix
5. Check the solution (hidden in `troubleshooting/exercises.md`)
6. Clean up before moving to the next exercise

---

### Exercise 1: Wrong Image Tag

**What's broken:** The deployment references an image tag that doesn't exist.

**Apply:**
```bash
kubectl apply -f troubleshooting/broken-manifests/01-wrong-image.yaml
```

**Observe the symptom:**
```bash
kubectl get pods -n k8s-assignment
```

You'll see a pod stuck in `ErrImagePull` or `ImagePullBackOff`.

**Investigate:**
```bash
kubectl describe pod -l app=backend-broken-1 -n k8s-assignment
```

Scroll to the **Events** section at the bottom. Look for the error message — it tells you exactly what's wrong.

**Question to answer:** What image tag is it trying to use? What should it be?

<details>
<summary>Click for the answer</summary>

The image is `k8s-backend:99.99` — that tag doesn't exist. It should be `k8s-backend:1.0` (what we loaded into Minikube).

Since `imagePullPolicy: Never` is set, Kubernetes won't try to pull from Docker Hub — it only looks locally, and `99.99` isn't there.

</details>

**Clean up:**
```bash
kubectl delete -f troubleshooting/broken-manifests/01-wrong-image.yaml
```

---

### Exercise 2: Missing Secret Reference

**What's broken:** The deployment references a Secret that doesn't exist.

**Apply:**
```bash
kubectl apply -f troubleshooting/broken-manifests/02-missing-secret.yaml
```

**Observe the symptom:**
```bash
kubectl get pods -n k8s-assignment
```

You'll see a pod stuck in `CreateContainerConfigError`.

**Investigate:**
```bash
kubectl describe pod -l app=backend-broken-2 -n k8s-assignment
```

Look at the Events section. Then check what secrets actually exist:
```bash
kubectl get secrets -n k8s-assignment
```

**Question to answer:** What secret name is the pod looking for? What's the actual secret name?

<details>
<summary>Click for the answer</summary>

The deployment references `db-secret-typo` but the actual secret is named `db-secret`. A simple typo prevents the container from starting because Kubernetes can't inject the required environment variables.

</details>

**Clean up:**
```bash
kubectl delete -f troubleshooting/broken-manifests/02-missing-secret.yaml
```

---

### Exercise 3: Wrong Service Port

**What's broken:** The Service sends traffic to the wrong port on the container.

**Apply:**
```bash
kubectl apply -f troubleshooting/broken-manifests/03-wrong-port.yaml
```

**Observe the symptom:**
```bash
kubectl get pods -n k8s-assignment
```

The pod is `Running` and looks healthy! But try hitting it through the service:
```bash
kubectl run debug --image=busybox -n k8s-assignment --rm -it --restart=Never -- wget -qO- --timeout=5 http://backend-broken-3/api/health
```

It times out or fails with connection refused.

**Investigate:**
```bash
# Check the service details
kubectl describe svc backend-broken-3 -n k8s-assignment

# Check the endpoints
kubectl get endpoints backend-broken-3 -n k8s-assignment
```

**Question to answer:** What port is the service targeting? What port does the backend actually listen on?

<details>
<summary>Click for the answer</summary>

The Service has `targetPort: 8080` but the backend container listens on port `5000`. So traffic from the service goes to port 8080, where nothing is listening. Fix: change `targetPort` to `5000`.

</details>

**Clean up:**
```bash
kubectl delete -f troubleshooting/broken-manifests/03-wrong-port.yaml
```

---

### Exercise 4: Out of Memory (OOMKilled)

**What's broken:** The memory limit is set way too low for a Python application.

**Apply:**
```bash
kubectl apply -f troubleshooting/broken-manifests/04-oom-killed.yaml
```

**Observe the symptom:**
```bash
kubectl get pods -n k8s-assignment -w
```

Watch for 30 seconds. The pod starts, gets killed, restarts, gets killed again — `CrashLoopBackOff`.

Press `Ctrl+C` to stop watching, then investigate.

**Investigate:**
```bash
kubectl describe pod -l app=backend-broken-4 -n k8s-assignment
```

Look for the **Last State** section — it shows the termination reason. Also check the container's **resource limits**.

```bash
# Check previous logs (before crash)
kubectl logs -l app=backend-broken-4 -n k8s-assignment --previous
```

**Question to answer:** What's the memory limit? Why is it too low?

<details>
<summary>Click for the answer</summary>

The memory limit is `16Mi` (16 megabytes). A Python/Flask application needs at least 128-256Mi to start. The Linux OOM killer terminates the process when it exceeds 16Mi, causing the `OOMKilled` status.

Fix: increase the memory limit to `256Mi`.

</details>

**Clean up:**
```bash
kubectl delete -f troubleshooting/broken-manifests/04-oom-killed.yaml
```

---

### Exercise 5: Wrong Liveness Probe Path

**What's broken:** The liveness probe checks a URL that doesn't exist.

**Apply:**
```bash
kubectl apply -f troubleshooting/broken-manifests/05-wrong-probe.yaml
```

**Observe the symptom:**
```bash
kubectl get pods -n k8s-assignment -w
```

Watch for 30-60 seconds. The pod starts, runs for a bit, then gets killed and restarted. The restart count keeps climbing.

Press `Ctrl+C`, then investigate.

**Investigate:**
```bash
kubectl describe pod -l app=backend-broken-5 -n k8s-assignment
```

Look at the Events section for **liveness probe** failures. Check the HTTP status code.

**Question to answer:** What URL path is the liveness probe checking? What should it be?

<details>
<summary>Click for the answer</summary>

The liveness probe checks `/api/healthx` (typo — extra `x`). That returns 404. After 3 consecutive failures, Kubernetes assumes the container is dead and restarts it.

Fix: change the probe path to `/api/health`.

The tricky part: the application itself is fine! It's just Kubernetes's health check that's misconfigured.

</details>

**Clean up:**
```bash
kubectl delete -f troubleshooting/broken-manifests/05-wrong-probe.yaml
```

---

### Clean Up All Exercises

If you want to clean up all broken manifests at once:
```bash
kubectl delete -f troubleshooting/broken-manifests/ -n k8s-assignment --ignore-not-found
```

---

## Part 5: Teardown (When You're Done)

### Option A: Delete just the K8s resources (keep the cluster for later)

```bash
kubectl delete namespace k8s-assignment
kubectl delete pv postgres-pv
```

### Option B: Delete everything including the Minikube cluster

```bash
bash scripts/teardown.sh
```

### Option C: Nuclear — delete everything manually

```bash
minikube delete -p k8s-assignment
docker system prune -f
```

---

## Quick Reference: Common Commands

| What | Command |
|------|---------|
| See all resources | `kubectl get all -n k8s-assignment` |
| See pods with node info | `kubectl get pods -n k8s-assignment -o wide` |
| Pod logs | `kubectl logs -l app=backend -n k8s-assignment` |
| Previous crash logs | `kubectl logs -l app=backend -n k8s-assignment --previous` |
| Describe a pod | `kubectl describe pod <pod-name> -n k8s-assignment` |
| Shell into a pod | `kubectl exec -it deploy/backend -n k8s-assignment -- /bin/sh` |
| Watch pods live | `kubectl get pods -n k8s-assignment -w` |
| Check HPA | `kubectl get hpa -n k8s-assignment` |
| Check PVC | `kubectl get pvc -n k8s-assignment` |
| Check endpoints | `kubectl get endpoints -n k8s-assignment` |
| Check events | `kubectl get events -n k8s-assignment --sort-by='.lastTimestamp'` |
| Check node taints | `kubectl describe node k8s-assignment-m03 \| grep Taint` |

---

## Troubleshooting Setup Issues

**"minikube: command not found"** — Run the install step again (1.2).

**"docker: permission denied"** — Run `sudo usermod -aG docker $USER` then log out and back in.

**Nodes stuck in NotReady** — Wait 1-2 minutes. If still not ready:
```bash
minikube delete -p k8s-assignment
bash scripts/setup-cluster.sh
```

**Pods stuck in ImagePullBackOff** — The custom images weren't loaded. Run:
```bash
bash scripts/build-images.sh
kubectl rollout restart deployment/frontend deployment/backend -n k8s-assignment
```

**PostgreSQL stuck in CreateContainerConfigError** — The hostPath directory doesn't exist. Run:
```bash
minikube ssh -p k8s-assignment -n k8s-assignment-m03 "sudo mkdir -p /mnt/data/postgres"
kubectl rollout restart deployment/postgres -n k8s-assignment
```

**Can't access http://localhost** — Make sure `minikube tunnel` is running in a separate terminal.

**kubectl connects to wrong cluster** — Set the context:
```bash
minikube update-context -p k8s-assignment
```
