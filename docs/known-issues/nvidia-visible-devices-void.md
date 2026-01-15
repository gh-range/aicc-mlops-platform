# Known Issue: NVIDIA_VISIBLE_DEVICES=void

## Metadata
- **Date Identified**: 2026-01-15
- **Severity**: Low (Cosmetic)
- **Impact**: No functional impact on GPU allocation or Time-Slicing
- **Status**: Accepted

## Description
When deploying workloads requesting GPU resources (`nvidia.com/gpu`), the Device Plugin sets the environment variable `NVIDIA_VISIBLE_DEVICES=void` instead of the expected GPU index or UUID. However, GPU devices remain accessible and `nvidia-smi` functions correctly.

## Technical Background

### Root Cause
NVIDIA GPU Operator has transitioned from **Legacy Hook Mode** to **CDI (Container Device Interface) Mode**:

| Mechanism | NVIDIA_VISIBLE_DEVICES Behavior | Device Injection |
|-----------|--------------------------------|------------------|
| Legacy Hook | Set to GPU ID (e.g., `0` or `GPU-uuid`) | via NVIDIA Container Runtime Hook |
| CDI Mode | Set to `void` (explicit no-op) | via Container Device Interface |

In the current environment:
- Device Plugin operates in CDI mode (sets `NVIDIA_VISIBLE_DEVICES=void`)
- Legacy hook may still be partially active (allows GPU access)
- This mixed state is a known transition-period behavior

### References
- NVIDIA GPU Operator Issue #1994: https://github.com/NVIDIA/gpu-operator/issues/1994
- ClearML Issue #1508: https://github.com/clearml/clearml/issues/1508
- NVIDIA CDI Documentation: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/1.17.3/cdi-support.html

## Impact Assessment

### Functional Impact
- **GPU Allocation**: UNAFFECTED - Device Plugin correctly manages GPU resources
- **Time-Slicing**: UNAFFECTED - ConfigMap-based configuration works normally
- **CUDA Applications**: UNAFFECTED - nvidia-smi and CUDA toolkit function correctly
- **Workload Scheduling**: UNAFFECTED - Kubernetes resource requests/limits honored

### Monitoring Impact
- Tools relying on `NVIDIA_VISIBLE_DEVICES` for GPU detection may fail
- Examples: ClearML agent, some legacy monitoring scripts
- Workaround: Use `nvidia-smi` output or CDI device names

## Validation Results

```bash
# Test Pod Output (2026-01-15)
NVIDIA_VISIBLE_DEVICES=void
CUDA_VISIBLE_DEVICES=
# But nvidia-smi shows:
# GPU 0: NVIDIA RTX A4000 (UUID: GPU-xxxxx)
```

## Mitigation Strategy

### Current Approach
**Accept as known behavior** during CDI transition period.

Rationale:
1. No functional degradation
2. Avoids unnecessary system changes during Time-Slicing implementation
3. GPU Operator ecosystem still stabilizing CDI support

### Future Actions
- Monitor NVIDIA GPU Operator releases for CDI stabilization
- Plan full CDI migration post-Time-Slicing deployment
- Update monitoring tools to use CDI-compatible methods

## Testing Checklist
- [x] GPU visible in `nvidia-smi`
- [x] Device Plugin socket exists (`/var/lib/kubelet/device-plugins/nvidia-gpu.sock`)
- [x] Node reports GPU capacity (`nvidia.com/gpu: 1`)
- [x] Test workload can execute CUDA code
- [ ] Time-Slicing configuration
- [ ] JupyterHub GPU allocation

## Sign-off
- **Technical Lead**: Documented as non-blocking issue
- **Next Review**: After Time-Slicing validation (2026-01-16 estimated)

