# GPU Operator Installation Report

**Installation Date**: 2026-01-08
**Operator Version**: v25.10.1  
**Status**: Success

---

## System Configuration

### Hardware
- GPU: NVIDIA RTX A4000 16GB
- CPU: Intel i9-10900F (10C/20T)
- RAM: 128GB DDR4
- OS: Ubuntu 24.04 LTS

### Software
- k3s: 1.34.3+k3s1
- Helm: 3.19.4
- NVIDIA Driver: 590.44.01
- CUDA: 13.1

---

## Installation Summary

### Helm Chart

```bash
Chart: nvidia/gpu-operator v25.10.1
Namespace: gpu-operator
Release: gpu-operator
```

### Configuration

```yaml
driver.enabled: false  # Use host driver 590.44.01
toolkit.enabled: true
dcgm.enabled: true
devicePlugin.enabled: true
dcgmExporter.enabled: true
gds.enabled: false
gfd.enabled: true
migManager.enabled: false
nfd.enabled: true
validator.enabled: false
sandboxWorkloads.enabled: false
```

---

## Verification Results

| Check | Status | Details |
|-------|--------|---------|
| All pods running | PASS | 6/6 pods Running |
| GPU resources advertised | PASS | nvidia.com/gpu: 1 |
| Node GPU labels | PASS | 15+ nvidia.com/* labels |
| DCGM service | PASS | Port 9400 active |
| GPU pod scheduling | PASS | Test pod accessed GPU |
| DCGM metrics | PASS | Metrics available |

**Overall**: 6 / 6 checks passed

---

---

## Verification Results

| Check | Status | Details |
|-------|--------|---------|
| All pods running | PASS | 10/11 pods Running |
| GPU resources advertised | PASS | nvidia.com/gpu: 1 |
| Node GPU labels | PASS | 15+ nvidia.com/* labels |
| DCGM service | PASS | Port 9400 active |
| GPU pod scheduling | PASS | Test pod accessed GPU |
| DCGM metrics | PASS | Metrics available |

**Overall**: 6 / 6 checks passed

### Pods

```
gpu-feature-discovery-5tscl                                   1/1     Running  
gpu-operator-7569f8b499-cdlc2                                 1/1     Running  
gpu-operator-node-feature-discovery-gc-55ffc49ccc-m5shl       1/1     Running  
gpu-operator-node-feature-discovery-master-6b5787f695-x2vkl   1/1     Running  
gpu-operator-node-feature-discovery-worker-j44rc              1/1     Running  
nvidia-container-toolkit-daemonset-4785n                      1/1     Running  
nvidia-cuda-validator-x2zm9                                   0/1     Completed
nvidia-dcgm-exporter-tsb5m                                    1/1     Running  
nvidia-dcgm-ncdch                                             1/1     Running  
nvidia-device-plugin-daemonset-mmnmg                          1/1     Running  
nvidia-operator-validator-k44n9                               1/1     Running
```

### Services

```
# kubectl get svc -n gpu-operator nvidia-dcgm-exporter
nvidia-dcgm-exporter   ClusterIP   10.43.34.174   9400/TCP
```

---

## GPU Resources

### Node Allocatable

```
  "nvidia.com/gpu": "1",
```

### Node Labels

```
nvidia.com/gpu.compute.major=8
nvidia.com/gpu.compute.minor=6
nvidia.com/gpu.count=1
nvidia.com/gpu.deploy.container-toolkit=true
nvidia.com/gpu.deploy.dcgm-exporter=true
nvidia.com/gpu.deploy.dcgm=true
nvidia.com/gpu.deploy.device-plugin=true
nvidia.com/gpu.deploy.driver=true
nvidia.com/gpu.deploy.gpu-feature-discovery=true
nvidia.com/gpu.deploy.node-status-exporter=true
nvidia.com/gpu.deploy.operator-validator=true
nvidia.com/gpu.family=ampere
nvidia.com/gpu.memory=16376
nvidia.com/gpu.mode=graphics
nvidia.com/gpu.present=true
nvidia.com/gpu.product=NVIDIA-RTX-A4000
nvidia.com/gpu.replicas=1
nvidia.com/gpu.sharing-strategy=none
```

---

## Test Results

### GPU Access Test

```bash
kubectl run test-gpu-verify --rm -i --restart=Never \
  --image=nvidia/cuda:13.1.0-base-ubuntu24.04 \
  --overrides='{"spec":{"runtimeClassName":"nvidia","containers":[{"name":"test-gpu-verify", \
  "image":"nvidia/cuda:13.1.0-base-ubuntu24.04","command":["nvidia-smi"], \
  "stdin":true,"tty":false,"resources":{"limits":{"nvidia.com/gpu":"1"}}}]}}'
```

**Result**: Success
- Driver detected: 590.44.01
- GPU detected: RTX A4000
- CUDA available: 13.1

### DCGM Metrics Sample

```
DCGM_FI_DEV_GPU_TEMP{gpu="0"} 29
DCGM_FI_DEV_GPU_UTIL{gpu="0"} 0
DCGM_FI_DEV_FB_USED{gpu="0"} 398
```

---


## Next Steps

1. Configure GPU time-slicing
   - Create time-slicing ConfigMap
   - Enable 4 virtual GPUs from 1 physical

2. Deploy test workloads
   - JupyterHub GPU notebook
   - Ollama LLM inference
   - Training job

3. Integrate monitoring
   - Prometheus scrape DCGM metrics
   - Grafana GPU dashboard

4. Document operational procedures
   - GPU upgrade process
   - Troubleshooting guide

---

## Troubleshooting Reference

### Common Issues

**Issue**: Pods stuck in Init
- Check: `kubectl describe pod -n gpu-operator <pod>`
- Solution: Verify network access to nvcr.io

**Issue**: GPU not advertised
- Check: `kubectl logs -n gpu-operator -l app=nvidia-device-plugin-daemonset`
- Solution: Verify host driver is working (`nvidia-smi`)

**Issue**: DCGM metrics not available
- Check: `kubectl logs -n gpu-operator -l app=nvidia-dcgm-exporter`
- Solution: Verify DCGM pod is Running

### Useful Commands
```bash
# Check all components
kubectl get all -n gpu-operator

# View operator logs
kubectl logs -n gpu-operator -l app=gpu-operator

# Restart device plugin
kubectl delete pod -n gpu-operator -l app=nvidia-device-plugin-daemonset

# Force operator to reconcile
kubectl delete pod -n gpu-operator -l app=gpu-operator
```

---

---

## Maintenance

### Upgrade GPU Operator

```bash
# Update repo
helm repo update

# Upgrade
helm upgrade gpu-operator nvidia/gpu-operator \
  -n gpu-operator \
  -f infra/k3s/gpu-operator/values.yaml
```

### Uninstall (if needed)

```bash
helm uninstall gpu-operator -n gpu-operator
kubectl delete namespace gpu-operator
```

---

## Sign-off

**Installed by**: Range  
**Verified by**: Range  
**Date**: 2026-01-08  
**Status**: Production Ready

