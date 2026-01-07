# GPU Operator Detailed Architecture

## System Context

Our infrastructure runs on a single powerful workstation that will serve as the foundation for a production-grade MLOps platform.

**Current Environment**:
- Hardware: Intel i9-10900F, 128GB RAM, NVIDIA RTX A4000 16GB
- OS: Ubuntu 24.04 LTS
- Container Runtime: containerd (k3s embedded)
- Kubernetes: k3s 1.34.x
- NVIDIA Driver: 580.x (pre-installed)
- Helm: 3.19.x

---

## GPU Operator Component Architecture

### Component Interaction Flow
```
                    ┌─────────────────────────┐
                    │   GPU Operator Pod      │
                    │  (Namespace: gpu-operator)│
                    │  - Manages lifecycle    │
                    │  - Watches resources    │
                    └───────────┬─────────────┘
                                │
                ┌───────────────┼───────────────┐
                │               │               │
                ▼               ▼               ▼
     ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
     │   Driver     │  │   Toolkit    │  │Device Plugin │
     │  DaemonSet   │  │  DaemonSet   │  │  DaemonSet   │
     └──────┬───────┘  └──────┬───────┘  └──────┬───────┘
            │                  │                  │
            │                  │                  │
     ┌──────▼──────────────────▼──────────────────▼───────┐
     │              Kubernetes Node (Host)                 │
     │  ┌────────────────────────────────────────────┐   │
     │  │  Container Runtime (containerd)            │   │
     │  │  - nvidia-container-runtime-hook           │   │
     │  │  - Manages container GPU access            │   │
     │  └────────────────────────────────────────────┘   │
     │  ┌────────────────────────────────────────────┐   │
     │  │  Kernel Space                              │   │
     │  │  - NVIDIA kernel modules                   │   │
     │  │  - GPU memory management                   │   │
     │  └────────────────────────────────────────────┘   │
     │  ┌────────────────────────────────────────────┐   │
     │  │  Hardware Layer                            │   │
     │  │  NVIDIA RTX A4000 (16GB GDDR6)            │   │
     │  │  - 6144 CUDA cores                         │   │
     │  │  - Compute Capability: 8.6                 │   │
     │  └────────────────────────────────────────────┘   │
     └─────────────────────────────────────────────────────┘
```

---

## Component Details

### 1. GPU Operator Controller

**Namespace**: `gpu-operator`

**Responsibilities**:
- Orchestrate installation of all GPU components
- Monitor component health
- Handle upgrades and rollbacks
- Manage ClusterPolicy custom resource

**Pod Name Pattern**: `gpu-operator-*`

**Resources Created**:
- DaemonSets for driver, toolkit, device-plugin
- ConfigMaps for component configuration
- ServiceAccounts and RBAC permissions
- Services for metrics endpoints

---

### 2. NVIDIA Driver DaemonSet

**Why containerized driver?**

In traditional setup, NVIDIA drivers must be installed on host OS. GPU Operator runs drivers in containers for:
- Version consistency across nodes
- No host OS modification needed
- Easy driver upgrades via Helm
- Automatic recovery on failure

**Our Configuration**:
- Mode: Use pre-installed driver (580.x already on host)
- Reason: Ubuntu already has driver installed and working
- GPU Operator will validate and use existing driver

**DaemonSet**: `nvidia-driver-daemonset`

**Key Operations**:
1. Detect existing driver on host
2. Validate driver version compatibility
3. Load kernel modules if needed
4. Create device nodes in /dev

**Volume Mounts**:
```yaml
volumeMounts:
- /dev          # Device nodes
- /sys          # Sysfs for hardware info
- /lib/modules  # Kernel modules
```

---

### 3. NVIDIA Container Toolkit DaemonSet

**Purpose**: Bridge between container runtime and GPU hardware

**Components Installed**:
- `nvidia-container-runtime`: OCI-compliant runtime
- `nvidia-container-cli`: CLI tool for GPU container setup
- `libnvidia-container`: Library for GPU isolation

**DaemonSet**: `nvidia-container-toolkit-daemonset`

**Integration with containerd**:

The toolkit configures containerd to use NVIDIA runtime:
```toml
# /etc/containerd/config.toml (modified by toolkit)
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
  runtime_type = "io.containerd.runc.v2"
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
    BinaryName = "/usr/bin/nvidia-container-runtime"
```

**What happens when pod requests GPU**:
1. Kubernetes schedules pod to node with GPU
2. containerd uses nvidia-container-runtime
3. Runtime calls nvidia-container-cli
4. CLI configures cgroups for GPU access
5. CLI mounts GPU devices into container
6. Container can now access GPU via CUDA

---

### 4. NVIDIA Device Plugin DaemonSet

**Purpose**: Advertise GPU resources to Kubernetes

**How it works**:
```
┌──────────────────────────────────────────┐
│  kubelet (on each node)                  │
│  - Discovers available resources         │
│  - Allocates resources to pods           │
└─────────────┬────────────────────────────┘
              │ gRPC (Device Plugin API)
              ▼
┌──────────────────────────────────────────┐
│  NVIDIA Device Plugin                    │
│  1. Discovers GPUs using nvidia-smi      │
│  2. Reports GPU count to kubelet         │
│  3. Handles allocation requests          │
│  4. Supports time-slicing (virtual GPUs) │
└──────────────────────────────────────────┘
```

**DaemonSet**: `nvidia-device-plugin-daemonset`

**Resource Exposure**:

Without time-slicing:
```yaml
Allocatable Resources:
  nvidia.com/gpu: 1  # One physical GPU
```

With time-slicing (4 replicas):
```yaml
Allocatable Resources:
  nvidia.com/gpu: 4  # Four virtual GPUs
```

**Pod GPU Request Example**:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
spec:
  containers:
  - name: cuda-app
    image: nvidia/cuda:12.0-base
    resources:
      limits:
        nvidia.com/gpu: 1  # Request 1 GPU (physical or virtual)
```

---

### 5. GPU Feature Discovery (GFD)

**Purpose**: Label nodes with GPU properties for scheduling

**DaemonSet**: `gpu-feature-discovery`

**Labels Added to Node**:
```bash
kubectl get nodes --show-labels | grep nvidia

# Example labels:
nvidia.com/gpu.present=true
nvidia.com/gpu.product=NVIDIA-RTX-A4000
nvidia.com/gpu.memory=16384
nvidia.com/cuda.driver.major=580
nvidia.com/cuda.driver.minor=xx
nvidia.com/cuda.driver.rev=xx
nvidia.com/cuda.runtime.major=12
nvidia.com/gpu.compute.major=8
nvidia.com/gpu.compute.minor=6
nvidia.com/gpu.family=ampere
```

**Use Case - Schedule pods to specific GPU**:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ampere-only-pod
spec:
  nodeSelector:
    nvidia.com/gpu.family: ampere
    nvidia.com/gpu.memory: "16384"
  containers:
  - name: workload
    image: my-app
    resources:
      limits:
        nvidia.com/gpu: 1
```

---

### 6. DCGM Exporter

**Purpose**: Export GPU metrics to Prometheus

**DCGM**: Data Center GPU Manager (NVIDIA's monitoring tool)

**DaemonSet**: `nvidia-dcgm-exporter`

**Metrics Exposed** (via port 9400):
```
# GPU Utilization
DCGM_FI_DEV_GPU_UTIL

# Memory Usage
DCGM_FI_DEV_FB_USED
DCGM_FI_DEV_FB_FREE

# Temperature
DCGM_FI_DEV_GPU_TEMP

# Power
DCGM_FI_DEV_POWER_USAGE

# Clock Speeds
DCGM_FI_DEV_SM_CLOCK
DCGM_FI_DEV_MEM_CLOCK

# PCIe Throughput
DCGM_FI_PROF_PCIE_TX_BYTES
DCGM_FI_PROF_PCIE_RX_BYTES
```

**Prometheus Integration**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nvidia-dcgm-exporter
  namespace: gpu-operator
  labels:
    app: nvidia-dcgm-exporter
spec:
  ports:
  - name: metrics
    port: 9400
    targetPort: 9400
  selector:
    app: nvidia-dcgm-exporter
```

Prometheus will scrape this service and store GPU metrics for Grafana dashboards.

---

## Deployment Sequence

When GPU Operator is installed, components are deployed in order:
```
1. GPU Operator Pod starts
   └─> Reads ClusterPolicy configuration
   └─> Creates DaemonSets

2. Driver DaemonSet (if not pre-installed)
   └─> Installs NVIDIA kernel modules
   └─> Creates /dev/nvidia* devices
   └─> Marks nodes as GPU-capable

3. NVIDIA Container Toolkit DaemonSet
   └─> Installs nvidia-container-runtime
   └─> Configures containerd runtime
   └─> Restarts containerd (if needed)

4. Device Plugin DaemonSet
   └─> Discovers GPUs via nvidia-smi
   └─> Registers with kubelet
   └─> Exposes nvidia.com/gpu resource

5. GPU Feature Discovery
   └─> Queries GPU properties
   └─> Adds labels to node

6. DCGM Exporter
   └─> Starts metrics collection
   └─> Exposes metrics endpoint
```

**Timeline**: ~2-5 minutes for all components to be Running

---

## Integration with k3s

### k3s Specifics

k3s uses **containerd** as container runtime (not Docker). GPU Operator fully supports this.

**Differences from standard Kubernetes**:
- k3s uses `/var/lib/rancher/k3s` instead of `/var/lib/kubelet`
- containerd config at `/var/lib/rancher/k3s/agent/etc/containerd/config.toml`
- No separate container runtime installation needed

**GPU Operator Adaptation**:
- Automatically detects k3s environment
- Uses correct paths for k3s
- Configures k3s's embedded containerd

---

## Pre-installed Driver Mode

Since we already have NVIDIA driver 580.x installed on host:

**Configuration**:
```yaml
driver:
  enabled: false  # Don't install driver via operator
```

**Benefits**:
- Faster deployment (skip driver container)
- Use system-tested driver
- No risk of driver version conflicts

**Requirements**:
- Driver must be compatible with CUDA version in workload containers
- Driver 580.x supports CUDA 12.x (we're good)

**Validation**:
```bash
# Check host driver
nvidia-smi

# After GPU Operator deployed, check in container
kubectl run test --rm -it --restart=Never \
  --image=nvidia/cuda:12.0-base \
  --limits=nvidia.com/gpu=1 \
  -- nvidia-smi
```

Should show same driver version in both places.

---

## GPU Time-Slicing Architecture

**Problem**: We have 1 physical GPU, but want to support multiple users simultaneously.

**Solution**: GPU time-slicing (share GPU among multiple pods)

**How it works**:
```
Physical GPU (RTX A4000 16GB)
         │
         │ Divided into replicas
         ▼
┌────────┬────────┬────────┬────────┐
│ GPU:0  │ GPU:1  │ GPU:2  │ GPU:3  │  Virtual GPUs
└────────┴────────┴────────┴────────┘
    │        │        │        │
    ▼        ▼        ▼        ▼
 Pod A    Pod B    Pod C    Pod D    Running concurrently
```

**Configuration** (in Device Plugin):
```yaml
sharing:
  timeSlicing:
    replicas: 4  # Create 4 virtual GPUs from 1 physical
```

**Scheduling**:
- CUDA MPS (Multi-Process Service) handles time-sharing
- Each pod gets time slices of GPU compute
- Memory is still shared (not isolated)

**Limitations**:
- No memory isolation between pods
- One pod can starve others (no QoS)
- Best for interactive workloads, not long training jobs

**Our Use Case**: Perfect for JupyterHub multi-user environment

---

## Resource Flow Diagram
```
User submits pod with GPU request
         │
         ▼
Kubernetes Scheduler
  - Checks node labels (via GFD)
  - Finds node with nvidia.com/gpu available
         │
         ▼
kubelet calls Device Plugin
  - Allocate 1 GPU replica
  - Returns device ID
         │
         ▼
containerd starts container
  - Uses nvidia-container-runtime
  - Mounts /dev/nvidia0, /dev/nvidiactl
  - Sets up cgroups
         │
         ▼
Container runs with GPU access
  - CUDA libraries communicate with driver
  - GPU executes workload
         │
         ▼
DCGM Exporter monitors
  - Collects GPU metrics
  - Exposes to Prometheus
```

---

## Monitoring and Observability

### Logs
```bash
# GPU Operator controller
kubectl logs -n gpu-operator -l app=gpu-operator

# Driver (if containerized)
kubectl logs -n gpu-operator -l app=nvidia-driver-daemonset

# Device Plugin
kubectl logs -n gpu-operator -l app=nvidia-device-plugin-daemonset

# DCGM Exporter
kubectl logs -n gpu-operator -l app=nvidia-dcgm-exporter
```

### Metrics
```bash
# Check DCGM metrics endpoint
kubectl port-forward -n gpu-operator svc/nvidia-dcgm-exporter 9400:9400

# Access metrics
curl http://localhost:9400/metrics | grep DCGM_FI_DEV_GPU_UTIL
```

### Node Labels
```bash
# View all GPU-related labels
kubectl get nodes -o json | jq '.items[].metadata.labels' | grep nvidia
```

---

## Failure Recovery

GPU Operator components are DaemonSets with automatic recovery:

**Scenario 1: Device Plugin crash**
1. DaemonSet detects pod crash
2. Restarts device plugin pod
3. Plugin re-registers with kubelet
4. GPU resources available again

**Scenario 2: Driver issue**
1. If using containerized driver, pod restarts
2. Re-loads kernel modules
3. If pre-installed driver, check host system

**Scenario 3: Node reboot**
1. All DaemonSet pods recreate
2. Driver loads on boot (host driver)
3. Components initialize in sequence
4. GPU becomes schedulable again

---

## Security Considerations

### Privileged Containers

Driver and toolkit DaemonSets run as **privileged** containers because they need:
- Access to `/dev`
- Kernel module loading
- Host filesystem modification

**Mitigation**:
- Restricted to `gpu-operator` namespace
- Uses specific ServiceAccounts with minimal RBAC
- Only runs on nodes with GPUs (via nodeSelector)

### Device Access

Containers with GPU access get:
- `/dev/nvidia*` device nodes
- `/dev/nvidiactl` control device
- `/dev/nvidia-uvm` unified memory

**Isolation**:
- cgroups limit which processes access which GPUs
- No cross-container GPU access
- Memory not isolated in time-slicing mode (limitation)

---

## Comparison with Alternatives

### GPU Operator vs Standalone Device Plugin

| Feature | GPU Operator | Device Plugin Only |
|---------|--------------|-------------------|
| Driver Management | Yes | No (manual install) |
| Monitoring | DCGM included | Manual setup |
| Time-slicing | Built-in | Manual config |
| Multi-node | Automatic | Manual per node |
| Upgrades | `helm upgrade` | Restart manually |
| Feature Discovery | Included | Optional add-on |

### GPU Operator vs Cloud Provider Solutions

| Feature | GPU Operator | AWS EKS | GKE |
|---------|--------------|---------|-----|
| Vendor Lock-in | None | AWS only | GCP only |
| On-premise | Yes | No | No |
| Cost | Free | Per-node fee | Per-node fee |
| Customization | Full | Limited | Limited |
| Driver version | Your choice | Provider choice | Provider choice |

---

## Next Steps

Now that we understand GPU Operator architecture:
1. Prepare Helm values for our configuration
2. Deploy GPU Operator
3. Validate all components are running
4. Configure time-slicing
5. Test GPU scheduling

---

## References

- [GPU Operator Components](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/overview.html)
- [Device Plugin Spec](https://github.com/NVIDIA/k8s-device-plugin)
- [DCGM Metrics](https://docs.nvidia.com/datacenter/dcgm/latest/dcgm-api/dcgm-api-field-ids.html)
- [Time-Slicing Guide](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-sharing.html)

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2026-01-07 | Range | Detailed architecture for our setup |

