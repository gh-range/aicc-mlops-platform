# ADR-004: GPU Operator Deployment Strategy

**Status**: Accepted  
**Date**: 2026-01-07  
**Deciders**: Infrastructure Lead  
**Technical Story**: Enable GPU workloads in Kubernetes with production-grade management

---

## Context and Problem Statement

We need to enable GPU access for ML workloads in our k3s cluster. The cluster will support:
- JupyterHub multi-user environment
- LLM inference (Ollama)
- Model training (LLaMA-Factory)
- Multiple concurrent users sharing single RTX A4000 GPU

**Key Requirements:**
- GPU accessible to Kubernetes pods
- Support for GPU time-slicing (multi-user)
- Production-grade monitoring (GPU metrics)
- Easy to maintain and upgrade
- Scalable to multi-node in future

---

## Decision Drivers

- **Operational Complexity**: Need simple installation and maintenance
- **Team Size**: Initially 1 engineer, growing to 3-5
- **Hardware**: Single RTX A4000 16GB, may add nodes later
- **Multi-user Support**: JupyterHub requires GPU sharing
- **Monitoring**: Need GPU metrics for Prometheus/Grafana
- **Future-proof**: Solution must work for 3-5 node expansion

---

## Considered Options

### Option 1: Manual NVIDIA Driver + Device Plugin

**Description**: Traditional approach

**Installation**:
```bash
# On host (manual)
sudo apt-get install nvidia-driver-580
sudo apt-get install nvidia-container-toolkit
sudo systemctl restart containerd

# Deploy device plugin
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/main/nvidia-device-plugin.yml
```

**Pros:**
- Direct control over driver version
- No additional operators running
- Simpler for single node

**Cons:**
- Manual setup on each node
- No automatic driver management
- Time-slicing requires manual ConfigMap
- No built-in monitoring (DCGM)
- Harder to upgrade
- Not declarative (can't GitOps it)

**Cost Estimate**: 
- Initial setup: 2-4 hours
- Maintenance: 3-5 hours/month (updates, troubleshooting)
- Multi-node expansion: +2 hours per node

---

### Option 2: GPU Operator (Containerized Driver)

**Description**: Full GPU Operator with containerized driver

**Installation**:
```bash
helm install gpu-operator nvidia/gpu-operator \
  --namespace gpu-operator \
  --create-namespace
```

**Pros:**
- Fully automated driver installation
- Declarative configuration
- Easy multi-node expansion
- Built-in DCGM monitoring
- Self-healing components

**Cons:**
- Requires pulling large driver container (~2GB)
- Driver runs as privileged container
- More components to understand
- Our driver already installed (redundant)

**Cost Estimate**:
- Initial setup: 30 minutes
- Maintenance: 1 hour/month
- Multi-node expansion: 5 minutes per node

---

### Option 3: GPU Operator (Use Pre-installed Driver)

**Description**: GPU Operator using existing host driver

**Installation**:
```bash
helm install gpu-operator nvidia/gpu-operator \
  --namespace gpu-operator \
  --create-namespace \
  --set driver.enabled=false
```

**Pros:**
- All GPU Operator benefits (monitoring, device plugin, time-slicing)
- Uses existing stable driver (580.x)
- Faster deployment (no driver download)
- Less disk space used
- Fully declarative and GitOps-friendly

**Cons:**
- Must maintain host driver separately
- Can't easily change driver version via Helm
- Team must understand both host driver and operator

**Cost Estimate**:
- Initial setup: 20 minutes
- Maintenance: 2 hours/month (operator + host driver)
- Multi-node expansion: 10 minutes per node (install driver + operator)

---

## Decision Outcome

**Chosen option**: Option 3 - GPU Operator with pre-installed driver

**Rationale:**

1. **Best of Both Worlds**
   - Keep stable host driver (580.x) already installed and tested
   - Gain all GPU Operator automation (device plugin, monitoring, time-slicing)
   - Reduce deployment time (no 2GB driver container download)

2. **Operational Simplicity**
   - One `helm install` command
   - Declarative configuration in Git
   - Automatic DCGM exporter for monitoring
   - Built-in time-slicing support

3. **Team Efficiency**
   - Junior engineers can manage via Helm
   - Clear component boundaries (host driver vs operator)
   - Easy to demonstrate in interviews

4. **Cost-Benefit**
   - Saves 2-3 hours/month vs manual installation
   - Reduces multi-node expansion time by 80%
   - Estimated labor cost savings at typical engineering rates

5. **Future-Proof**
   - Easy to add nodes (DaemonSets automatically deploy)
   - Supports GPU time-slicing out-of-box
   - DCGM metrics ready for Prometheus integration

**Expected Benefits:**
- 70% reduction in GPU infrastructure maintenance time
- Zero-downtime GPU driver updates (host side)
- Production-grade monitoring from day 1

**Accepted Trade-offs:**
- Must maintain host driver separately (apt upgrade)
- Slightly more complex than pure manual approach
- Team must understand operator concepts

---

## Implementation Details

### Helm Values Configuration
```yaml
# File: infra/k3s/gpu-operator/values.yaml

driver:
  enabled: false  # Use pre-installed host driver

toolkit:
  enabled: true   # Enable container toolkit

devicePlugin:
  enabled: true
  config:
    name: time-slicing-config
    create: true
    default: any  # Apply time-slicing to all GPUs

gfd:
  enabled: true   # GPU Feature Discovery

dcgmExporter:
  enabled: true   # Metrics for Prometheus
  serviceMonitor:
    enabled: false  # Enable later with Prometheus Operator

operator:
  defaultRuntime: containerd
```

### Time-Slicing Configuration
```yaml
# ConfigMap: time-slicing-config
version: v1
sharing:
  timeSlicing:
    resources:
    - name: nvidia.com/gpu
      replicas: 4  # Create 4 virtual GPUs from 1 physical
```

This allows 4 users to share the RTX A4000 simultaneously.

---

## Deployment Architecture
```
┌─────────────────────────────────────────────────────┐
│                    k3s Cluster                      │
│                                                     │
│  ┌────────────────────────────────────────────┐   │
│  │         GPU Operator (Helm Chart)          │   │
│  │  - Manages DaemonSets                      │   │
│  │  - Configures time-slicing                 │   │
│  └──────────────────┬─────────────────────────┘   │
│                     │                               │
│     ┌───────────────┼───────────────┐              │
│     ▼               ▼               ▼              │
│  ┌──────┐      ┌──────┐      ┌──────────┐         │
│  │Device│      │ GFD  │      │   DCGM   │         │
│  │Plugin│      │      │      │ Exporter │         │
│  └──┬───┘      └──┬───┘      └────┬─────┘         │
│     │             │                │               │
│     └─────────────┴────────────────┘               │
│                   │                                 │
│     ┌─────────────▼─────────────────────┐         │
│     │     Host OS (Ubuntu 24.04)        │         │
│     │  - NVIDIA Driver 580.x            │         │
│     │  - RTX A4000 16GB                 │         │
│     └───────────────────────────────────┘         │
└─────────────────────────────────────────────────────┘
```

---

## Validation Plan

### Step 1: Verify Component Health
```bash
kubectl get pods -n gpu-operator
# All pods should be Running
```

### Step 2: Check GPU Discovery
```bash
kubectl get nodes -o json | jq '.items[].status.allocatable'
# Should show: "nvidia.com/gpu": "4"
```

### Step 3: Test GPU Scheduling
```bash
kubectl run test-gpu --rm -it --restart=Never \
  --image=nvidia/cuda:13.1-base-ubuntu24.04 \
  --limits=nvidia.com/gpu=1 \
  -- nvidia-smi
```

### Step 4: Verify Time-Slicing
```bash
# Deploy 4 pods requesting GPU simultaneously
# All should get scheduled and run
```

### Step 5: Check Metrics
```bash
kubectl port-forward -n gpu-operator svc/nvidia-dcgm-exporter 9400:9400
curl localhost:9400/metrics | grep DCGM_FI_DEV_GPU_UTIL
```

---

## Rollback Plan

If GPU Operator deployment fails:
```bash
# 1. Uninstall Helm release
helm uninstall gpu-operator -n gpu-operator

# 2. Clean up namespace
kubectl delete namespace gpu-operator

# 3. Verify host driver still works
nvidia-smi

# 4. Fall back to Option 1 (manual device plugin) if needed
```

---

## Migration Path to Production SuperPod

### Phase 1 (Current): MAV Node Validation
- **Hardware**: RTX A4000 (Ampere/Ada architecture)
- **Strategy**: Time-Slicing with 4 replicas
- **Purpose**: Validate orchestration logic and multi-tenancy patterns

### Phase 2 (Target): NVIDIA B200 SuperPod
- **Hardware**: NVIDIA B200 Blackwell GPUs
- **Strategy**: MIG (Multi-Instance GPU) for hardware-level isolation
- **Networking**: InfiniBand fabric with RDMA
- **Scaling**: Proven architecture from MAV validates at SuperPod scale

**Migration Approach:**
- MAV node serves as reference implementation
- Time-Slicing patterns translate to MIG instance allocation
- GPU Operator configuration remains consistent across both phases
- Monitoring and quota mechanisms identical at both scales

---

## Monitoring Integration

### Prometheus ServiceMonitor

Once Prometheus Operator is deployed:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: nvidia-dcgm-exporter
  namespace: gpu-operator
spec:
  selector:
    matchLabels:
      app: nvidia-dcgm-exporter
  endpoints:
  - port: metrics
    interval: 15s
```

### Grafana Dashboard

Use official NVIDIA DCGM dashboard:
- Dashboard ID: 12239
- Metrics: GPU utilization, memory, temperature, power

---

## Security Considerations

### Privileged Containers

GPU Operator components run privileged to access GPU hardware:
- **Mitigation**: Restricted to `gpu-operator` namespace
- **RBAC**: Minimal permissions via ServiceAccounts
- **Network**: No external network access needed

### Device Access

Pods with GPU get direct hardware access:
- **Isolation**: Via cgroups (device plugin manages)
- **Limitation**: No memory isolation in time-slicing mode
- **Acceptable**: For trusted internal users (JupyterHub)

---

## Cost Analysis

### Initial Investment

| Item | Manual | GPU Operator |
|------|--------|--------------|
| Setup Time | 4 hours | 0.5 hours |
| Labor Cost | Estimated | Estimated |
| **Total** | **Higher** | **Lower** |

### Ongoing Maintenance (per month)

| Task | Manual | GPU Operator |
|------|--------|--------------|
| Driver updates | 2 hours | 1 hour |
| Troubleshooting | 2 hours | 0.5 hours |
| Config changes | 1 hour | 0.25 hours |
| **Total** | **5 hours** | **1.75 hours** |

**Monthly Savings**: ~3.25 hours of engineering time

---

## Team Impact

### Skills Required

**Before (Manual)**:
- NVIDIA driver installation
- Container runtime configuration
- Manual YAML deployment
- Device plugin troubleshooting

**After (GPU Operator)**:
- Helm chart management
- Kubernetes operator concepts
- Basic GPU operator troubleshooting

**Training Time**: 2 hours (read docs, deploy, test)

---

## Success Metrics

- [ ] All GPU Operator pods Running
- [ ] Node shows 4 allocatable GPUs (time-slicing)
- [ ] Test pod can access GPU and run nvidia-smi
- [ ] DCGM metrics available on port 9400
- [ ] Node labeled with GPU properties (GFD)
- [ ] Time to add 2nd node: <30 minutes

---

## References

- [GPU Operator Documentation](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/)
- [Pre-installed Driver Mode](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/install-gpu-operator-vgpu.html#using-pre-installed-drivers)
- [Time-Slicing Guide](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-sharing.html)

---

## Revision History

| Date | Author | Changes |
|------|---------|---------|
| 2026-01-07 | Range | Initial decision record |
| 2026-01-21 | Range | Update SuperPod migration path to B200 |

