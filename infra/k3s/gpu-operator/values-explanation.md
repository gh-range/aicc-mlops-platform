# GPU Operator Helm Values Explanation

## Configuration Choices

### driver.enabled: false

**Reason**: We have NVIDIA driver 590.x pre-installed on Ubuntu host

**Alternative**: Set to `true` to use containerized driver
- Pros: Fully managed by operator
- Cons: 2GB+ download, more complex, redundant in our case

---

### toolkit.enabled: true

**Purpose**: Install NVIDIA Container Toolkit

**What it does**:
- Configures containerd to use nvidia-container-runtime
- Enables containers to access GPU devices
- Required for any GPU workload

---

### devicePlugin.enabled: true

**Purpose**: Advertise GPU resources to Kubernetes

**What it does**:
- Discovers GPUs via nvidia-smi
- Registers `nvidia.com/gpu` resource
- Handles GPU allocation to pods

**Time-slicing**: Will be configured separately via ConfigMap

---

### gfd.enabled: true

**Purpose**: GPU Feature Discovery

**What it does**:
- Labels nodes with GPU properties
- Example labels:
  - `nvidia.com/gpu.product=NVIDIA-RTX-A4000`
  - `nvidia.com/gpu.memory=16384`
  - `nvidia.com/cuda.driver.major=590`

**Use case**: Schedule pods to specific GPU types

---

### dcgmExporter.enabled: true

**Purpose**: Export GPU metrics to Prometheus

**Metrics exposed**:
- GPU utilization
- Memory usage
- Temperature
- Power consumption
- Clock speeds

**Endpoint**: Port 9400 on each node

---

### nfd.enabled: false

**Reason**: Node Feature Discovery not needed for single node

**When to enable**: Multi-node cluster with diverse hardware

---

### migManager.enabled: false

**Reason**: RTX A4000 does not support MIG (Multi-Instance GPU)

**MIG support**: Only on A100, A30, H100 GPUs

---

### validator.enabled: false

**Purpose**: Run validation tests after installation

**When to enable**: Troubleshooting or certification

**Why disabled**: We'll validate manually with test pods

---

## Version Selection

All component versions are matched to work together:
- Toolkit: v1.14.3
- Device Plugin: v0.14.3
- GFD: v0.8.2
- DCGM Exporter: 3.1.8

These are tested and compatible versions from NVIDIA.

---

## Runtime Configuration
```yaml
operator:
  defaultRuntime: containerd
```

**Reason**: k3s uses containerd (not docker)

**Effect**: Operator configures containerd to use nvidia-runtime

---

## Resource Requirements

GPU Operator components use minimal resources:
- Operator pod: ~100Mi memory
- Device plugin: ~50Mi per node
- DCGM exporter: ~100Mi per node
- Toolkit: ~50Mi per node

**Total overhead**: ~300Mi memory per node (negligible on 128GB system)

---

## Updates and Maintenance

To upgrade GPU Operator:
```bash
# Update Helm repo
helm repo update

# Check new versions
helm search repo nvidia/gpu-operator --versions

# Upgrade
helm upgrade gpu-operator nvidia/gpu-operator \
  -n gpu-operator \
  -f values.yaml
```

---

## Customization for Production

For production multi-node cluster, consider:
```yaml
# Enable ServiceMonitor for Prometheus Operator
dcgmExporter:
  serviceMonitor:
    enabled: true

# Node selectors for GPU nodes only
nodeSelector:
  node-role.kubernetes.io/gpu: "true"

# Tolerations for tainted GPU nodes
tolerations:
- key: nvidia.com/gpu
  operator: Exists
  effect: NoSchedule
```
