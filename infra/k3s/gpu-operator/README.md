# NVIDIA GPU Operator Deployment

Production-ready GPU Operator deployment for k3s with pre-installed NVIDIA driver.

## Environment

- **OS**: Ubuntu 24.04 LTS
- **k3s**: v1.34.3
- **NVIDIA Driver**: 590.44.01
- **CUDA**: 13.1
- **GPU**: NVIDIA RTX A4000 (16GB)
- **GPU Operator**: v25.10.1

## Quick Start

### 1. Pre-installation Check
```bash
sudo ./infra/k3s/gpu-operator/pre-install-check.sh
```

### 2. Install GPU Operator
```bash
sudo ./infra/k3s/gpu-operator/install-gpu-operator.sh
```

### 3. Verify Installation
```bash
sudo ./infra/k3s/gpu-operator/post-install-verify.sh
```

## Files

| File | Purpose |
|------|---------|
| `pre-install-check.sh` | Pre-installation system checks and conflict cleanup |
| `values.yaml` | Helm values for GPU Operator (k3s-optimized) |
| `values-explanation.md` | Detailed configuration rationale and design decisions |
| `install-gpu-operator.sh` | GPU Operator installation script |
| `post-install-verify.sh` | 8-step post-installation verification |

## Verification Checklist

- [x] All pods Running or Completed
- [x] GPU resources advertised (nvidia.com/gpu: 1)
- [x] Node GPU labels applied
- [x] RuntimeClass 'nvidia' created
- [x] DCGM Exporter service running
- [x] Test pod can access GPU
- [x] DCGM metrics available
- [x] Containerd configured with nvidia runtime

## Testing GPU Access

```bash
kubectl run cuda-test --rm -it --restart=Never \
  --image=nvidia/cuda:13.1.0-base-ubuntu24.04 \
  --overrides='{"spec":{"runtimeClassName":"nvidia","containers":[{"name":"cuda","image":"nvidia/cuda:13.1.0-base-ubuntu24.04","command":["nvidia-smi"],"resources":{"limits":{"nvidia.com/gpu":"1"}}}]}}'
```

## Monitoring

### View GPU Metrics
```bash
POD=$(kubectl get pod -n gpu-operator -l app=nvidia-dcgm-exporter -o name | head -1)
kubectl port-forward -n gpu-operator $POD 9400:9400 &
curl localhost:9400/metrics | grep DCGM_FI_DEV
```

## Uninstall

```bash
helm uninstall gpu-operator -n gpu-operator
kubectl delete namespace gpu-operator
```

## Next Steps

1. Configure GPU time-slicing for multi-tenant workloads
2. Integrate DCGM Exporter with Prometheus/Grafana
3. Deploy JupyterHub with GPU support
4. Set up LLaMA-Factory fine-tuning pipeline

## References

- [NVIDIA GPU Operator Documentation](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/)
- [k3s GPU Support](https://docs.k3s.io/advanced#nvidia-container-runtime-support)
