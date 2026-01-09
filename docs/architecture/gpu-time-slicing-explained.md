# GPU Time-Slicing Explained

## What is GPU Time-Slicing?

GPU time-slicing allows multiple processes to share a single physical GPU by time-multiplexing GPU access.

### Without Time-Slicing
```
Physical GPU (RTX A4000 16GB)
         │
         │ Only 1 pod at a time
         ▼
     [Pod A]
```

**Limitation**: Only 1 pod can use GPU, even if GPU is idle most of the time.

---

### With Time-Slicing (4 replicas)
```
Physical GPU (RTX A4000 16GB)
         │
         │ Divided into 4 virtual GPUs
         ├─────┬─────┬─────┬─────┐
         ▼     ▼     ▼     ▼     ▼
      GPU:0  GPU:1  GPU:2  GPU:3
         │     │     │     │
         ▼     ▼     ▼     ▼
      Pod A  Pod B  Pod C  Pod D
```

**Benefit**: 4 pods can run simultaneously, sharing GPU compute time.

---

## How Time-Slicing Works

### CUDA MPS (Multi-Process Service)

NVIDIA uses CUDA MPS to enable time-sharing:

1. **Scheduler**: Switches between processes every few milliseconds
2. **Context Switching**: Saves/restores GPU state for each process
3. **Time Slices**: Each process gets turns to use GPU compute

**Analogy**: Like CPU multitasking, but for GPU.

---

## Configuration

### Device Plugin ConfigMap
```yaml
version: v1
sharing:
  timeSlicing:
    resources:
    - name: nvidia.com/gpu
      replicas: 4  # Create 4 virtual GPUs
```

### Effect on Kubernetes

**Before time-slicing**:
```
Node allocatable resources:
  nvidia.com/gpu: "1"
```

**After time-slicing**:
```
Node allocatable resources:
  nvidia.com/gpu: "4"
```

Kubernetes scheduler now sees 4 GPUs available.

---

## Resource Allocation

### Pod Request
```yaml
resources:
  limits:
    nvidia.com/gpu: 1  # Request 1 virtual GPU
```

### Actual Hardware

All pods share the same physical RTX A4000:
- Same 16GB VRAM (shared, not partitioned)
- Same 6144 CUDA cores (time-multiplexed)
- Same memory bandwidth (shared)

---

## Limitations and Considerations

### 1. No Memory Isolation

**Problem**: All pods share 16GB VRAM

**Impact**:
- One pod using 10GB leaves only 6GB for others
- OOM (Out of Memory) affects all pods
- No per-pod memory limits enforced

**Mitigation**:
- User education: limit memory usage
- Monitor VRAM usage per pod (DCGM)
- Use ResourceQuotas for namespace limits

---

### 2. No QoS Guarantees

**Problem**: No guaranteed compute time per pod

**Impact**:
- One GPU-intensive pod can starve others
- Unpredictable performance
- Noisy neighbor problem

**Mitigation**:
- Best for interactive workloads (JupyterHub)
- Not ideal for long training jobs
- Use PriorityClass for critical workloads

---

### 3. Scheduler Limitations

**Kubernetes Issue**: Scheduler doesn't know actual GPU load

**Impact**:
- May schedule 4 pods even if GPU is 100% utilized
- No automatic load balancing
- Can't prevent over-subscription

**Mitigation**:
- Monitor GPU utilization (DCGM)
- Manual intervention if needed
- Consider MIG for true isolation (not available on A4000)

---

## Use Cases

### Good Use Cases

- JupyterHub multi-user environment
- Interactive development/debugging
- Short inference requests
- Model serving (low QPS)
- Educational environments

### Poor Use Cases

- Long training jobs (hours/days)
- High-throughput inference
- Real-time applications with strict SLA
- Workloads requiring guaranteed resources

---

## Our Configuration: 4 Replicas

### Why 4?

**Reasoning**:
- Supports 4 concurrent JupyterHub users
- Balances utilization vs performance
- Leaves headroom (16GB / 4 = 4GB per user)

**Alternatives**:
- 2 replicas: Less contention, better performance
- 8 replicas: More users, higher contention

**Decision**: 4 is sweet spot for our use case

---

## Monitoring Time-Sliced GPUs

### DCGM Metrics
```bash
# GPU utilization (shared across all pods)
DCGM_FI_DEV_GPU_UTIL{gpu="0"}

# Memory used (total across all pods)
DCGM_FI_DEV_FB_USED{gpu="0"}

# Per-process metrics (if available)
DCGM_FI_PROF_PIPE_TENSOR_ACTIVE{gpu="0",pid="1234"}
```

### Limitation

DCGM reports aggregate GPU metrics, not per-pod breakdown.

**Workaround**: Use pod labels + time-series correlation

---

## Future: MIG for True Isolation

### What is MIG?

Multi-Instance GPU: Hardware partitioning of GPU

**Advantages**:
- True memory isolation (e.g., 4x 4GB slices)
- QoS guarantees
- Fault isolation

**Limitation**: Only on A100, A30, H100 GPUs

### Migration Path

If we upgrade to A100:
1. Enable MIG in BIOS
2. Create MIG instances (e.g., 1g.5gb profile)
3. Update GPU Operator config
4. Pods request `nvidia.com/mig-1g.5gb`

---

## Troubleshooting

### Issue: Only 1 GPU shown after time-slicing

**Check**: Device plugin config
```bash
kubectl get configmap -n gpu-operator time-slicing-config -o yaml
```

**Solution**: Verify `replicas: 4` is set correctly

---

### Issue: Pods fail with CUDA_ERROR_OUT_OF_MEMORY

**Cause**: Total VRAM exceeded 16GB

**Check**: Memory usage
```bash
nvidia-smi dmon -s mu -c 1
```

**Solution**: Limit users or reduce per-pod memory usage

---

### Issue: Poor performance with 4 concurrent pods

**Cause**: GPU compute saturation

**Check**: GPU utilization
```bash
nvidia-smi dmon -s u -c 5
```

**Solution**: Reduce replicas to 2 or add more GPUs

---

## References

- [NVIDIA Time-Slicing Documentation](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-sharing.html)
- [Device Plugin Time-Slicing](https://github.com/NVIDIA/k8s-device-plugin#shared-access-to-gpus-with-cuda-time-slicing)
