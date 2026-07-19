# Platform Component Upgrade Runbook (2026-07)

**Execution Date**: 2026-07-20
**Executor**: Range
**Status**: Completed
**Trigger**: Scheduled maintenance after multi-month project pause; pre-requisite for OS reinstall (Ubuntu 26.04 migration)
**Related ADR**: [ADR-017: Phased Component Upgrade Strategy](../design-decisions/ADR-017-phased-component-upgrade-strategy.md)

---

## Objective

Upgrade all core platform components to their latest supported versions prior to decommissioning the current OS image, ensuring the post-reinstall baseline (Ubuntu 26.04) starts from a known-good, up-to-date configuration state. All `values.yaml` files and Helm release states captured here are the source of truth for the subsequent OS migration.

---

## Pre-Upgrade State

| Component | Previous Version |
|---|---|
| Traefik | v3.6.15 (Helm chart older release) |
| cert-manager | pre-v1.21.0 |
| GPU Operator | v25.10.1 |
| JupyterHub | pre-4.4.0 |
| Calico | v3.31.3 (policy-only mode) |
| NVIDIA Driver | 590.44.01 |
| CUDA | 13.1 |

## Post-Upgrade Target State

| Component | Target Version |
|---|---|
| Traefik | v41.0.2 (Helm chart) |
| cert-manager | v1.21.0 |
| GPU Operator | v26.3.3 |
| JupyterHub | 4.4.0 |
| NVIDIA Driver | 610.43.02 |
| CUDA | 13.3 |
| k3s | v1.35.5 |

---

## Step 0: Pre-Upgrade etcd Backup

**Purpose**: Establish rollback point before touching any Helm release.

```bash
# Run as root
k3s etcd-snapshot save
k3s etcd-snapshot ls
```

**Checkpoint**: Confirm snapshot file exists and timestamp matches execution window.

---

## Step 1: Helm Repository Sync

```bash
helm repo add stable https://charts.helm.sh/stable
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo add traefik https://traefik.github.io/charts
helm repo add jetstack https://charts.jetstack.io
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/

helm repo update
```

---

## Step 2: cert-manager Upgrade -> v1.21.0

```bash
helm list -n cert-manager
helm search repo cert-manager --versions | head -10

helm upgrade cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.21.0

kubectl get pods -n cert-manager
helm list -n cert-manager
kubectl get certificate -A
kubectl get certificaterequest -A
```

**Verification**: All cert-manager pods `Running`; existing `Certificate` and `CertificateRequest` objects remain in `Ready=True` state (no re-issuance triggered by chart bump).

---

## Step 3: Traefik Upgrade -> v41.0.2 (Phased: 39.0.9 -> 40.3.0 -> 41.0.2)

**Working directory**: `~/aicc-mlops-platform/infra/traefik/base/helm`

### 3.1 Baseline check

```bash
helm list -n traefik-system
helm search repo traefik/traefik --versions | head -15
```

### 3.2 Phase A: Chart 39.0.9

```bash
helm upgrade traefik traefik/traefik -n traefik-system --version 39.0.9 -f values.yaml --dry-run
```

**Required `values.yaml` edits** (remove deprecated / conflicting keys):

```diff
 image:
-  tag: "v3.6.15"

 api:
-  enabled: true
```

```bash
helm upgrade traefik traefik/traefik -n traefik-system --version 39.0.9 --reset-values -f values.yaml

kubectl get pods -n traefik-system
kubectl delete pods <old-traefik-pod> -n traefik-system   # clears stuck Pending old ReplicaSet pod
kubectl get pods -n traefik-system -w
kubectl rollout status deploy/traefik -n traefik-system
```

### 3.3 Phase B: Chart 40.3.0

```bash
helm upgrade traefik traefik/traefik -n traefik-system --version 40.3.0 -f values.yaml

kubectl get pods -n traefik-system
kubectl delete pods <old-traefik-pod> -n traefik-system
kubectl get pods -n traefik-system -w
kubectl rollout status deploy/traefik -n traefik-system
```

### 3.4 Phase C: Chart 41.0.2 (target)

```bash
# Pre-flight schema validation
helm template traefik traefik/traefik --version 41.0.2 -f values.yaml --dry-run 2>&1 |\
  grep -i "error\|not allowed\|additional properties"
```

**Required `values.yaml` edits** (new schema for logging/access-log):

```diff
+log:
+  level: INFO
+  format: json
+
+accessLog:
+  enabled: true
+  format: json
+  fields:
+    defaultMode: keep
+    names: {}
+    headers:
+      defaultMode: drop
```

```bash
helm upgrade traefik traefik/traefik -n traefik-system --version 41.0.2 -f values.yaml

kubectl get pods -n traefik-system
kubectl delete pods <old-traefik-pod> -n traefik-system
kubectl get pods -n traefik-system -w
helm list -n traefik-system
kubectl rollout status deploy/traefik -n traefik-system

kubectl get ingressroute -A
```

**Verification**: `helm list -n traefik-system` shows chart `41.0.2`; all `IngressRoute` objects still resolve; dashboard and existing routers (`jupyter.mlops.work`, `ollama.mlops.work`) return expected status codes.

**Reference**: https://artifacthub.io/packages/helm/traefik/traefik

---

## Step 4: GPU Operator Upgrade -> v26.3.3

**Working directory**: `~/aicc-mlops-platform/infra/gpu-operator/time-slicing`

```bash
helm list -n gpu-operator
helm search repo nvidia/gpu-operator --versions | head -15
```

**Required `gpu-operator-timeslicing-values.yaml` edits**:

```diff
 devicePlugin:
   enabled: true
-  version:

   env:
   - name: PASS_DEVICE_SPECS
     value: "true"
-  - name: FAIL_ON_INIT_ERROR
-    value: "true"
-  - name: DEVICE_LIST_STRATEGY
-    value: "volume-mounts"
-  - name: DEVICE_ID_STRATEGY
-    value: "uuid"

 dcgm:
   enabled: true
   image: dcgm
   repository: nvcr.io/nvidia/cloud-native
   version: "4.6.0-1-ubuntu24.04"
```

```bash
helm upgrade gpu-operator nvidia/gpu-operator \
  -n gpu-operator --version v26.3.3 \
  -f gpu-operator-timeslicing-values.yaml --dry-run

helm upgrade gpu-operator nvidia/gpu-operator \
  -n gpu-operator --version v26.3.3 \
  -f gpu-operator-timeslicing-values.yaml --wait

kubectl apply -f device-plugin-config.yaml
kubectl get pods -n gpu-operator -w
helm list -n gpu-operator
kubectl rollout status daemonset nvidia-device-plugin-daemonset -n gpu-operator
```

**Verification**: All GPU Operator pods `Running`/`Completed` (validator jobs); `nvidia-device-plugin-daemonset` rollout succeeds; `kubectl describe node` still reports `nvidia.com/gpu` allocatable resources with time-slicing replica count intact.

**Reference**: https://catalog.ngc.nvidia.com/orgs/nvidia/teams/cloud-native/containers/dcgm/

---

## Step 5: JupyterHub Upgrade -> 4.4.0

**Working directory**: `~/aicc-mlops-platform/apps/jupyterhub`

```bash
helm list -n jupyterhub
helm search repo jupyter --versions | head -10
```

**Required `values.yaml` edits**:

```diff
 hub:
+   image:
+     name: quay.io/jupyterhub/k8s-hub
+     pullPolicy: IfNotPresent
```

```bash
helm upgrade jupyterhub jupyterhub/jupyterhub -n jupyterhub --version 4.4.0 -f values.yaml --dry-run
helm upgrade jupyterhub jupyterhub/jupyterhub -n jupyterhub --version 4.4.0 -f values.yaml --wait

kubectl get pods -n jupyterhub
kubectl delete pod <ContainerStatusUnknown-pod> -n jupyterhub   # not auto-cleaned by k3s
helm list -n jupyterhub
kubectl rollout status deploy/hub -n jupyterhub
kubectl rollout status deploy/proxy -n jupyterhub
kubectl rollout status deploy/user-scheduler -n jupyterhub
```

**Known Issue**: Pods in `ContainerStatusUnknown/Unknown` state are not automatically garbage-collected by k3s and must be deleted manually.

**Verification**: `hub`, `proxy`, and `user-scheduler` deployments all report successful rollout; GitHub OAuth login flow still functions end-to-end.

---

## Step 6: Calico CNI Compatibility Audit (No Upgrade Performed)

**Purpose**: Confirm Calico policy-only layer remains compatible with the updated stack before deciding on an upgrade cadence.

```bash
helm list -A
kubectl get pods -A | grep -i calico
kubectl get ds,deploy -A | grep -i calico
kubectl get crd | grep -i calico
ls -l /etc/cni/net.d/
kubectl get ds calico-node -n kube-system \
  -o jsonpath='{.spec.template.spec.containers[*].image}{"\n"}'
# Result: Calico node v3.31.3

cat /etc/cni/net.d/10-calico.conflist
cat /etc/cni/net.d/10-canal.conflist
ip link show | grep -E 'cali|tunl|vxlan|flannel'
kubectl get ippool.crd.projectcalico.org -o yaml | grep -E "vxlanMode|ipipMode"
kubectl get felixconfiguration default -o yaml
kubectl get ippool -o yaml

crictl info | grep confDir
find /var/lib/rancher/k3s/agent/etc/cni -maxdepth 2 -type f -print
# Active CNI config: /var/lib/rancher/k3s/agent/etc/cni/net.d/10-flannel.conflist

kubectl get events -A --sort-by='.lastTimestamp'
```

**Decision**: No Calico upgrade performed in this cycle. Version v3.31.3 confirmed compatible with k3s v1.35.5 and current NetworkPolicy baseline (ADR-016). Re-evaluate after.

---

## Step 7: Image Cleanup

```bash
# List all local images
k3s crictl images

# Prune unused/dangling images
k3s crictl rmi --prune
```

**Purpose**: Reclaim disk space on the M.2 SSD boot volume before OS image capture.

---

## Step 8: Post-Upgrade etcd Backup

```bash
# Run as root
k3s etcd-snapshot save
k3s etcd-snapshot ls
```

**Purpose**: Capture final cluster state as the last checkpoint before OS reinstall. This snapshot, combined with the `values.yaml` files under version control, constitutes the full restoration baseline for the Ubuntu 26.04 target environment.

---

## Summary of Component State After Upgrade

| Component | Chart / Version | Namespace | Rollout Status |
|---|---|---|---|
| cert-manager | v1.21.0 | cert-manager | OK |
| Traefik | 41.0.2 | traefik-system | OK |
| GPU Operator | v26.3.3 | gpu-operator | OK |
| JupyterHub | 4.4.0 | jupyterhub | OK |
| Calico | v3.31.3 (unchanged) | kube-system | Compatibility confirmed |

---

## Next Steps

1. Export full `values.yaml` set for all releases (`helm get values <release> -n <ns> -a`) and commit to `/infra` for disaster-recovery parity.
2. Proceed with Velero backup of PVC-backed workloads prior to OS reinstall.
3. Execute Ubuntu 26.04 clean install on M.2 boot volume.
4. Re-bootstrap cluster from `infra/k3s/bootstrap/install-k3s.sh` and restore etcd snapshot captured in Step 8.
5. Re-validate GPU Operator, Traefik routing, and JupyterHub OAuth against the new OS baseline.

---

## Sign-off

**Executed by**: Range
**Verified by**: Range
**Date**: 2026-07-20
**Status**: Upgrade Complete, Ready for OS Migration Phase
