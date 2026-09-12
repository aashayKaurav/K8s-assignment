# Troubleshooting Exercises

Practice debugging Kubernetes issues using these 5 failure scenarios. Each exercise includes a broken manifest, the symptom you'll observe, commands to investigate, and a hidden solution.

## How to Use

1. Apply the broken manifest from `broken-manifests/`
2. Observe the symptom
3. Use the debug commands to investigate
4. Try to fix the issue before reading the solution

---

## Exercise 1: Wrong Image Tag (ImagePullBackOff)

**Apply:**
```bash
kubectl apply -f troubleshooting/broken-manifests/01-wrong-image.yaml
```

**Symptom:** Pod stuck in `ImagePullBackOff` or `ErrImagePull` state.

**Debug Commands:**
```bash
kubectl get pods -n k8s-assignment
kubectl describe pod -l app=backend-broken-1 -n k8s-assignment
kubectl get events -n k8s-assignment --sort-by='.lastTimestamp'
```

**What to look for:** In `kubectl describe pod`, check the Events section for image pull errors. Look at the container spec to see the image name.

<details>
<summary>Solution (click to reveal)</summary>

**Root cause:** The image tag `k8s-backend:99.99` does not exist. Since `imagePullPolicy: Never` is set, Kubernetes can't pull it from anywhere.

**Fix:** Change the image tag from `k8s-backend:99.99` to `k8s-backend:1.0` (which was loaded into Minikube).

```yaml
# Change this:
image: k8s-backend:99.99
# To this:
image: k8s-backend:1.0
```

**Cleanup:**
```bash
kubectl delete -f troubleshooting/broken-manifests/01-wrong-image.yaml
```
</details>

---

## Exercise 2: Missing Secret Reference (CreateContainerConfigError)

**Apply:**
```bash
kubectl apply -f troubleshooting/broken-manifests/02-missing-secret.yaml
```

**Symptom:** Pod stuck in `CreateContainerConfigError` state.

**Debug Commands:**
```bash
kubectl get pods -n k8s-assignment
kubectl describe pod -l app=backend-broken-2 -n k8s-assignment
kubectl get secrets -n k8s-assignment
```

**What to look for:** In `kubectl describe pod`, check Events for messages about missing secrets or configmaps.

<details>
<summary>Solution (click to reveal)</summary>

**Root cause:** The deployment references a secret called `db-secret-typo` which doesn't exist. The correct secret name is `db-secret`.

**Fix:** Change the secretRef name:

```yaml
# Change this:
- secretRef:
    name: db-secret-typo
# To this:
- secretRef:
    name: db-secret
```

**Cleanup:**
```bash
kubectl delete -f troubleshooting/broken-manifests/02-missing-secret.yaml
```
</details>

---

## Exercise 3: Wrong targetPort in Service (502 Bad Gateway)

**Apply:**
```bash
kubectl apply -f troubleshooting/broken-manifests/03-wrong-port.yaml
```

**Symptom:** Service exists but returns 502 Bad Gateway, or connection refused when accessing the backend.

**Debug Commands:**
```bash
kubectl get svc -n k8s-assignment
kubectl get endpoints backend-broken-3 -n k8s-assignment
kubectl describe svc backend-broken-3 -n k8s-assignment
kubectl get pods -l app=backend-broken-3 -n k8s-assignment -o wide
# Test connectivity from inside the cluster:
kubectl run debug --image=busybox -n k8s-assignment --rm -it --restart=Never -- wget -qO- http://backend-broken-3/api/health
```

**What to look for:** Check the endpoints — if they show the wrong port, traffic won't reach the container. Compare the Service `targetPort` with the container's actual `containerPort`.

<details>
<summary>Solution (click to reveal)</summary>

**Root cause:** The Service targetPort is `8080`, but the backend container listens on port `5000`. Traffic is being sent to the wrong port.

**Fix:** Change targetPort to match the container port:

```yaml
# Change this:
ports:
  - port: 80
    targetPort: 8080
# To this:
ports:
  - port: 80
    targetPort: 5000
```

**Cleanup:**
```bash
kubectl delete -f troubleshooting/broken-manifests/03-wrong-port.yaml
```
</details>

---

## Exercise 4: Memory Limit Too Low (OOMKilled)

**Apply:**
```bash
kubectl apply -f troubleshooting/broken-manifests/04-oom-killed.yaml
```

**Symptom:** Pod keeps restarting. Status shows `OOMKilled` or `CrashLoopBackOff`.

**Debug Commands:**
```bash
kubectl get pods -n k8s-assignment -w
kubectl describe pod -l app=backend-broken-4 -n k8s-assignment
kubectl logs -l app=backend-broken-4 -n k8s-assignment --previous
```

**What to look for:** In `kubectl describe pod`, check the "Last State" section for `OOMKilled` reason. Check the container's resource limits.

<details>
<summary>Solution (click to reveal)</summary>

**Root cause:** The memory limit is set to `16Mi`, which is far too low for a Python/Flask application. The OS kills the container when it exceeds this limit.

**Fix:** Increase the memory limit to a reasonable value:

```yaml
# Change this:
resources:
  limits:
    memory: 16Mi
# To this:
resources:
  limits:
    memory: 256Mi
```

**Cleanup:**
```bash
kubectl delete -f troubleshooting/broken-manifests/04-oom-killed.yaml
```
</details>

---

## Exercise 5: Wrong Liveness Probe Path (Repeated Restarts)

**Apply:**
```bash
kubectl apply -f troubleshooting/broken-manifests/05-wrong-probe.yaml
```

**Symptom:** Pod starts, then gets killed and restarted repeatedly. Restart count increases.

**Debug Commands:**
```bash
kubectl get pods -n k8s-assignment -w
kubectl describe pod -l app=backend-broken-5 -n k8s-assignment
kubectl logs -l app=backend-broken-5 -n k8s-assignment
```

**What to look for:** In `kubectl describe pod`, check Events for liveness probe failures (e.g., "Liveness probe failed: HTTP probe failed with statuscode: 404"). The pod itself is healthy, but K8s thinks it's not because the probe path is wrong.

<details>
<summary>Solution (click to reveal)</summary>

**Root cause:** The liveness probe path is `/api/healthx` (typo), which returns 404. After 3 consecutive failures, Kubernetes kills the container.

**Fix:** Correct the probe path:

```yaml
# Change this:
livenessProbe:
  httpGet:
    path: /api/healthx
# To this:
livenessProbe:
  httpGet:
    path: /api/health
```

**Cleanup:**
```bash
kubectl delete -f troubleshooting/broken-manifests/05-wrong-probe.yaml
```
</details>

---

## Cleanup All Exercises

```bash
kubectl delete -f troubleshooting/broken-manifests/ -n k8s-assignment --ignore-not-found
```
