# GPU Operator Helm Values Explanation

**Environment**: k3s v1.34.3 + NVIDIA Driver 590.44.01 + CUDA 13.1 + RTX A4000  
**GPU Operator Version**: v25.10.1

---

## Design Decisions

### 1. driver.enabled: false

**Decision**: Use pre-installed host driver from NVIDIA (590.44.01)

**Reasoning**:
- Newest NVIDIA driver already installed on Ubuntu 24.04 host
- Avoids 2GB+ containerized driver download
- More reliable for single-node development setup

**Trade-offs**:
- [o] Faster deployment, no driver container overhead
- [x] Must manually upgrade driver when needed
- [x] Less portable across heterogeneous clusters

---

### 2. Component Versions: Auto-managed

**Decision**: Let GPU Operator Chart manage all component versions

**Reasoning**:
- NVIDIA tests component compatibility for each Chart release
- Avoids version mismatch issues
- Simplifies upgrades - only change Chart version
- Reduces maintenance overhead

**What Chart v25.10.1 includes**:
- NVIDIA Container Toolkit (compatible with CUDA 11.0-13.x)
- Device Plugin (supports time-slicing and MIG)
- GPU Feature Discovery (node labeling)
- DCGM + DCGM Exporter (metrics collection)
- Node Feature Discovery (hardware detection)

---

### 3. toolkit.enabled: true with k3s-specific paths

**Purpose**: Install NVIDIA Container Toolkit for GPU access in containers

**k3s-specific configuration**:
```yaml
env:
  - name: CONTAINERD_CONFIG
    value: /var/lib/rancher/k3s/agent/etc/containerd/config.toml
  - name: CONTAINERD_SOCKET
    value: /run/k3s/containerd/containerd.sock
  - name: CONTAINERD_RUNTIME_CLASS
    value: nvidia
  - name: CONTAINERD_SET_AS_DEFAULT
    value: "true"
```

**Critical**: k3s uses different paths than standard Kubernetes

**What it does**:

1. Modifies containerd config to add nvidia runtime
2. Creates RuntimeClass 'nvidia' for GPU pods
3. Enables containers to access GPU devices via /dev/nvidia*

---

### 4. devicePlugin.enabled: true

**Purpose**: Advertise GPU resources to Kubernetes scheduler

**What it provides**:

- Discovers GPUs via nvidia-smi
- Registers `nvidia.com/gpu: 1` in node allocatable resources
- Handles GPU allocation to pods
- Supports time-slicing (configured separately)

**Verification**:

```bash
kubectl get nodes -o json | jq '.items[].status.allocatable'
# Should show: "nvidia.com/gpu": "1"
```

---

### 5. gfd.enabled: true

**Purpose**: GPU Feature Discovery - automatic node labeling

**Labels applied to node**:

```yaml
nvidia.com/gpu.present: "true"
nvidia.com/gpu.product: NVIDIA-RTX-A4000
nvidia.com/gpu.memory: 16384
nvidia.com/gpu.count: "1"
nvidia.com/cuda.driver.major: "590"
nvidia.com/cuda.driver.minor: "44"
nvidia.com/cuda.runtime.major: "13"
nvidia.com/cuda.runtime.minor: "1"
```

**Use case**: Schedule workloads to specific GPU types

```yaml
nodeSelector:
  nvidia.com/gpu.product: NVIDIA-RTX-A4000
```

---

### 6. dcgm + dcgmExporter.enabled: true

**Purpose**: GPU monitoring and metrics export to Prometheus

**Architecture**:

- DCGM: Collects GPU telemetry (utilization, memory, temp, power)
- DCGM Exporter: Exposes metrics on port 9400 in Prometheus format

**Resource limits set**:

```yaml
dcgmExporter:
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
```

**Key metrics exposed**:

- `DCGM_FI_DEV_GPU_UTIL` - GPU utilization %
- `DCGM_FI_DEV_FB_USED` - Memory used (MB)
- `DCGM_FI_DEV_GPU_TEMP` - Temperature (C)
- `DCGM_FI_DEV_POWER_USAGE` - Power (W)

**Access metrics**:

```bash
POD=$(kubectl get pod -n gpu-operator -l app=nvidia-dcgm-exporter -o name | head -1)
kubectl port-forward -n gpu-operator $POD 9400:9400
curl localhost:9400/metrics | grep DCGM
```

---

### 7. nfd.enabled: true

**Decision**: Enable Node Feature Discovery

**What it does**:

- Detects CPU, kernel, PCI, USB features
- Labels nodes with hardware capabilities
- Required dependency for GPU Operator to function

**Note**: pod gpu-feature-discovery will be pending if nfd.enabled: false

---

### 8. migManager.enabled: false

**Decision**: RTX A4000 does not support MIG

**MIG compatibility**:

- [o] Supported: A100, A30, H100, H200
- [x] Not supported: RTX series (A4000/A5000/A6000), V100, T4

**What is MIG**: Multi-Instance GPU - partitions single GPU into up to 7 isolated instances with dedicated memory/compute.

**Our case**: Single RTX A4000 for development/research, MIG not applicable.

---

### 9. validator.enabled: false

**Decision**: Manual validation via post-install script

**Why disabled**:

- Validator pods consume resources and stay as Completed
- We perform comprehensive verification in `post-install-verify.sh`
- Can enable temporarily for troubleshooting

**Enable for debugging**:

```yaml
validator:
  enabled: true
```


---

## Resource Overhead

GPU Operator components on single node:


| Component | CPU | Memory | Purpose |
| :-- | :-- | :-- | :-- |
| gpu-operator | 100m | 100Mi | Operator controller |
| nvidia-container-toolkit | 50m | 50Mi | Runtime configuration |
| nvidia-device-plugin | 50m | 50Mi | Resource advertising |
| nvidia-dcgm | 100m | 100Mi | GPU monitoring |
| nvidia-dcgm-exporter | 100m | 128Mi | Metrics export |
| gpu-feature-discovery | 50m | 50Mi | Node labeling |
| nfd-master | 50m | 50Mi | NFD controller |
| nfd-worker | 50m | 50Mi | NFD worker |

**Total**: ~550m CPU, ~578Mi memory (negligible on 10900F + 128GB)

---

## Upgrade Process

### Check for updates:

```bash
helm repo update
helm search repo nvidia/gpu-operator
```


### Upgrade to newer version:

```bash
helm upgrade gpu-operator nvidia/gpu-operator \
  --namespace gpu-operator \
  --values infra/k3s/gpu-operator/values.yaml \
  --wait
```

### Rollback if needed:

```bash
helm rollback gpu-operator -n gpu-operator
```

---

## Production Scaling Considerations

When scaling to multi-node cluster:

### 1. Node selectors for GPU nodes

```yaml
nodeSelector:
  node-role.kubernetes.io/gpu: "true"
```

### 2. Tolerations for tainted GPU nodes

```yaml
tolerations:
- key: nvidia.com/gpu
  operator: Exists
  effect: NoSchedule
```

### 3. Enable Prometheus ServiceMonitor

```yaml
dcgmExporter:
  serviceMonitor:
    enabled: true
    interval: 30s
```

### 4. Namespace-level GPU quotas

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: gpu-quota
spec:
  hard:
    requests.nvidia.com/gpu: "2"
```

---

## Troubleshooting

### GPU not advertised

```bash
kubectl logs -n gpu-operator -l app=nvidia-device-plugin-daemonset
kubectl describe node | grep nvidia.com/gpu
```


### DCGM metrics unavailable

```bash
kubectl get pods -n gpu-operator | grep dcgm
POD=$(kubectl get pod -n gpu-operator -l app=nvidia-dcgm-exporter -o jsonpath='{.items.metadata.name}')
POD_IP=$(kubectl get pod -n gpu-operator $POD -o jsonpath='{.status.podIP}')
curl http://$POD_IP:9400/metrics | head
```

### Containerd not configured

```bash
cat /var/lib/rancher/k3s/agent/etc/containerd/config.toml | grep nvidia
systemctl restart k3s
```

---

## Summary

**Configuration philosophy**: Minimal overrides, leverage Chart defaults
**Target environment**: Single-node k3s development cluster with RTX A4000
**Production-ready**: Full monitoring, resource limits, and upgrade path included
**Next steps**: GPU time-slicing configuration, Prometheus integration
