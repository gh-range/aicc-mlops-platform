# GPU Time-Slicing Operational Validation

**Document Type**: Runbook  
**Last Updated**: 2026-01-21  
**Owner**: Infrastructure Team  
**Status**: Production Ready

---

## Configuration Snapshot

### GPU Operator

**Version**: v25.10.1  
**Namespace**: gpu-operator  
**Driver Mode**: Pre-installed (host driver 590.44.01)

### Time-Slicing Configuration

**ConfigMap**: `time-slicing-config`  
**Strategy**: envvar (UUID-based)  
**Replicas**: 4  
**Physical GPU**: 1x RTX A4000 16GB  
**Virtual GPUs**: 4

```yaml
version: v1
sharing:
  timeSlicing:
    renameByDefault: false
    failRequestsGreaterThanOne: false
    resources:
    - name: nvidia.com/gpu
      replicas: 4
```

---

## Validation Results

### Node Capacity

```bash
kubectl describe node llm1 | grep nvidia.com/gpu
# Expected: nvidia.com/gpu: 4
```

**Status**: ✓ PASS (2026-01-21)

### Concurrent Pod Scheduling

**Test**: Deploy 4 pods requesting 1 GPU each  
**Result**: All 4 pods running simultaneously  
**Resource Allocation**: 4/4 GPU utilized

**Status**: ✓ PASS (2026-01-21)

### ResourceQuota Enforcement

**Test**: Attempt 3rd pod deployment in 2-GPU quota namespace  
**Result**: Admission Controller rejected with "exceeded quota"

**Status**: ✓ PASS (2026-01-21)

### Resource Recovery

**Test**: Delete pods and verify GPU reclamation  
**Result**: Resources released within 5 seconds, reallocation successful

**Status**: ✓ PASS (2026-01-21)

---

## Known Issues

### CDI Void Behavior

**Symptom**: `NVIDIA_VISIBLE_DEVICES=void` in pod environment

**Root Cause**: GPU Operator transitioning to CDI mode, legacy hook still active

**Impact**: None - GPU access functional, container workloads unaffected

**Workaround**: Not required

**References**:
- [NVIDIA/gpu-operator#1994](https://github.com/NVIDIA/gpu-operator/issues/1994)
- ADR-004: GPU Operator Deployment

**Status**: Accepted as known behavior

---

## Troubleshooting

### Issue: GPU capacity shows 0

**Check 1**: Verify GPU Operator pods
```bash
kubectl get pods -n gpu-operator
```

**Check 2**: Verify device plugin logs
```bash
kubectl logs -n gpu-operator -l app=nvidia-device-plugin-daemonset
```

**Check 3**: Verify Time-Slicing ConfigMap
```bash
kubectl get configmap time-slicing-config -n gpu-operator -o yaml
```

---

### Issue: Pod pending with "Insufficient nvidia.com/gpu"

**Check 1**: Node GPU capacity
```bash
kubectl describe node llm1 | grep nvidia.com/gpu
```

**Check 2**: Current allocation
```bash
kubectl describe node llm1 | grep -A 10 "Allocated resources"
```

**Check 3**: Namespace ResourceQuota
```bash
kubectl describe resourcequota -n <namespace>
```

---

## Operational Commands

### Check GPU allocation
```bash
kubectl get nodes -o json | jq '.items[].status.allocatable."nvidia.com/gpu"'
```

### List all GPU pods
```bash
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.containers[].resources.limits."nvidia.com/gpu") | "\(.metadata.namespace)/\(.metadata.name)"'
```

### Force device plugin restart
```bash
kubectl delete pods -n gpu-operator -l app=nvidia-device-plugin-daemonset
```

---

## Migration Path

### Current: MAV Node
- **Platform**: RTX A4000 with Time-Slicing
- **Purpose**: Validate multi-tenancy patterns and orchestration logic

### Target: NVIDIA B200 SuperPod
- **Platform**: NVIDIA B200 Blackwell architecture
- **Strategy**: MIG (Multi-Instance GPU) for hardware-level isolation
- **Scale**: 128+ GPU deployment with InfiniBand fabric

**Transition Approach:**
- Time-Slicing validation proves quota enforcement mechanisms
- MIG profiles in B200 provide hardware-isolated compute instances
- ResourceQuota patterns remain consistent across both platforms
- Monitoring and observability stack unchanged

---

## Next Steps

- JupyterHub GPU integration
- DCGM metrics monitoring (Prometheus + Grafana)
- Phase 2: B200 SuperPod architecture finalization

---

## References

- ADR-004: GPU Operator Deployment Strategy
- ADR-008: GPU Resource Management Policy
- [NVIDIA Time-Slicing Guide](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-sharing.html)
- [NVIDIA B200 Platform](https://www.nvidia.com/en-us/data-center/dgx-b200/)

