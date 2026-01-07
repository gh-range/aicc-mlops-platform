# NVIDIA GPU Operator Overview

## What is GPU Operator?

The NVIDIA GPU Operator is a Kubernetes operator that automates the management of all NVIDIA software components needed to run GPU-accelerated workloads.

### Core Purpose

**Problem it solves:**
- Traditional approach requires manual installation of drivers, CUDA toolkit, container runtime on each node
- Version mismatches between components
- Complex upgrade procedures
- Difficult to manage across multiple nodes

**GPU Operator solution:**
- Automated deployment of all GPU software stack
- Consistent configuration across cluster
- Simplified upgrades
- Cloud-native management

---

## Why NOT Manually Install device-plugin?

### Manual Approach (Old Way)
```
On each node:
1. Install NVIDIA Driver
2. Install NVIDIA Container Toolkit
3. Install nvidia-docker2
4. Configure containerd/docker
5. Deploy k8s-device-plugin as DaemonSet
6. Configure runtime class
```

**Problems:**
- Time-consuming for multi-node clusters
- Version conflicts
- Manual driver updates
- No automatic recovery
- Difficult to troubleshoot

### GPU Operator Approach (Modern Way)
```
Single helm install command:
  helm install gpu-operator ...

GPU Operator handles:
- Driver installation (as container!)
- Container toolkit installation
- Device plugin deployment
- DCGM exporter for metrics
- GFD (GPU Feature Discovery)
- Automatic updates and recovery
```

**Benefits:**
- Declarative configuration
- Automatic driver installation
- Self-healing
- Easy upgrades
- Consistent across nodes

---

## GPU Operator Components

The GPU Operator deploys several components as DaemonSets:

### 1. NVIDIA Driver Container

**Purpose**: Provides GPU driver to host kernel

**How it works**:
- Runs as privileged container
- Mounts kernel modules into host
- Survives container restarts
- Automatic version management

**Pods**: `nvidia-driver-daemonset-*`

**Why containerized?**
- No need to install drivers on host OS
- Easy version switching
- Consistent across different OS versions
- Can be upgraded without node reboot (in some cases)

---

### 2. NVIDIA Container Toolkit

**Purpose**: Enables containers to access GPUs

**Components**:
- `nvidia-container-runtime`
- `nvidia-container-cli`
- Hooks into container runtime (containerd/docker)

**Pods**: `nvidia-container-toolkit-daemonset-*`

**What it does**:
- Injects GPU devices into containers
- Sets up device permissions
- Configures cgroups for GPU isolation

---

### 3. NVIDIA Device Plugin

**Purpose**: Advertises GPUs to Kubernetes scheduler

**Functionality**:
- Discovers GPUs on node
- Reports GPU count to kubelet
- Handles GPU allocation to pods
- Supports GPU sharing strategies

**Pods**: `nvidia-device-plugin-daemonset-*`

**Resource management**:
```yaml
resources:
  limits:
    nvidia.com/gpu: 1  # Request 1 GPU
```

---

### 4. GPU Feature Discovery (GFD)

**Purpose**: Labels nodes with GPU properties

**Discovered features**:
- GPU model
- CUDA version
- Driver version
- Compute capability
- Memory size

**Example labels**:
```
nvidia.com/gpu.product=NVIDIA-RTX-A4000
nvidia.com/gpu.memory=16384
nvidia.com/cuda.driver.major=580
```

**Use case**: Schedule pods to nodes with specific GPU types

---

### 5. DCGM Exporter

**Purpose**: Export GPU metrics to Prometheus

**Metrics provided**:
- GPU utilization
- Memory usage
- Temperature
- Power consumption
- SM clock
- PCIe bandwidth

**Endpoint**: `http://node:9400/metrics`

**Integration**: Prometheus scrapes these metrics for Grafana dashboards

---

### 6. Node Feature Discovery (NFD) - Optional

**Purpose**: Discover hardware features beyond GPU

**Features**:
- CPU capabilities
- Network devices
- Storage controllers

**Why needed**: GPU Operator can use NFD labels for advanced scheduling

---

## Deployment Architecture
```
┌─────────────────────────────────────────────────────┐
│                  Kubernetes Cluster                  │
│                                                      │
│  ┌────────────────────────────────────────────┐    │
│  │         GPU Operator Pod                    │    │
│  │  (Controls lifecycle of all components)    │    │
│  └────────────────────────────────────────────┘    │
│                         │                            │
│        ┌────────────────┼────────────────┐          │
│        ▼                ▼                ▼          │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐     │
│  │ Driver   │    │ Toolkit  │    │ Device   │     │
│  │DaemonSet │    │DaemonSet │    │ Plugin   │     │
│  └──────────┘    └──────────┘    └──────────┘     │
│        │                │                │          │
│        ▼                ▼                ▼          │
│  ┌──────────────────────────────────────────┐     │
│  │           Worker Node (Host)             │     │
│  │  ┌────────────────────────────────┐     │     │
│  │  │  Kernel Modules (from driver)  │     │     │
│  │  └────────────────────────────────┘     │     │
│  │  ┌────────────────────────────────┐     │     │
│  │  │    NVIDIA GPU Hardware         │     │     │
│  │  │    (RTX A4000 16GB)           │     │     │
│  │  └────────────────────────────────┘     │     │
│  └──────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────┘
```

---

## GPU Operator vs Manual Installation

| Aspect | Manual Installation | GPU Operator |
|--------|---------------------|--------------|
| **Installation Time** | 30-60 min per node | 5-10 min for cluster |
| **Driver Updates** | Manual on each node | `helm upgrade` |
| **Configuration** | Multiple config files | Single Helm values.yaml |
| **Multi-node** | Repeat on each node | Automatic DaemonSet |
| **Recovery** | Manual intervention | Self-healing |
| **Monitoring** | Manual setup | DCGM exporter included |
| **Kubernetes-native** | No | Yes |

---

## When to Use GPU Operator

### Use GPU Operator when:
- [ ] Running Kubernetes (k3s, k8s, OpenShift)
- [ ] Need to manage multiple GPU nodes
- [ ] Want declarative GPU configuration
- [ ] Require automatic driver management
- [ ] Need GPU monitoring out-of-box

### Consider manual installation when:
- [ ] Single bare-metal server (no K8s)
- [ ] Custom driver requirements
- [ ] Air-gapped environment without container registry access
- [ ] Very old GPU hardware not supported by recent drivers

---

## Our Use Case

**Decision**: Use GPU Operator

**Reasons**:
1. Running k3s (Kubernetes)
2. Single node now, but may expand to 3-5 nodes
3. Want automatic driver management
4. Need DCGM metrics for monitoring
5. Demonstrates production best practices for interviews

**Alternative considered**: Manual driver + device-plugin
- Rejected: Not scalable, harder to maintain

---

## Pre-requisites for GPU Operator

### Node Requirements
- [ ] NVIDIA GPU present
- [ ] Linux kernel headers installed
- [ ] No existing NVIDIA drivers (or use pre-installed driver mode)
- [ ] Container runtime: containerd or docker

### Kubernetes Requirements
- [ ] Kubernetes 1.20+
- [ ] Helm 3.x
- [ ] Node has internet access (or private registry)

### Our Setup
- [x] GPU: RTX A4000 16GB
- [x] Driver: 580.x
- [x] k3s: 1.34.x with containerd
- [x] Helm: 3.19.x installed

---

## Next Steps

After understanding GPU Operator architecture:
1. Review Helm chart values and customization options
2. Deploy GPU Operator with appropriate settings
3. Configure GPU time-slicing for multi-user access
4. Deploy DCGM exporter for monitoring
5. Validate GPU scheduling

---

## References

- [NVIDIA GPU Operator Documentation](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/)
- [GPU Operator Architecture](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/overview.html)
- [Kubernetes Device Plugins](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/device-plugins/)

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2026-01-07 | Range | Initial architecture documentation |

