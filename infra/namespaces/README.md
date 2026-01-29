# Kubernetes Namespace Management

Centralized namespace definitions with ResourceQuotas and LimitRanges for all platform components.

## Purpose

This directory contains **foundational namespace configurations** that must be applied before deploying applications. Each namespace file defines:

1. **Namespace**: Logical isolation boundary
2. **ResourceQuota**: Hard limits on CPU/memory/GPU consumption
3. **LimitRange**: Default/min/max resource constraints per Pod/Container

## Design Principles

### 1. Namespace Isolation Strategy

| Namespace | Purpose | GPU Quota | CPU Quota | Memory Quota |
|-----------|---------|-----------|-----------|--------------|
| `traefik-system` | Ingress controller | 0 | 4-8 cores | 8-16 GB |
| `jupyterhub` | Multi-user notebook platform | 4 | 20-40 cores | 64-96 GB |
| `gpu-operator` | NVIDIA GPU management (system) | 0 | Variable | Variable |
| `monitoring` | Prometheus, Grafana (planned) | 0 | 8-16 cores | 32-64 GB |
| `argocd` | GitOps controller (planned) | 0 | 4-8 cores | 8-16 GB |

**GPU Priority**: User workloads (jupyterhub) > Infrastructure (0 GPU)

---

### 2. ResourceQuota Philosophy

**Hard Limits Prevent**:
- Runaway workloads consuming all cluster resources
- Single tenant monopolizing GPUs (multi-tenancy violation)
- Memory leaks crashing entire node

**Example** (from `jupyterhub/namespace.yaml`):
```yaml
spec:
  hard:
    requests.nvidia.com/gpu: "4"  # Max 4 concurrent GPU pods
    requests.cpu: "20"             # Guarantee 20 cores
    limits.cpu: "40"               # Hard cap at 40 cores (burst)
```

**Enforcement**: Kubernetes Admission Controller rejects pod creation if quota exceeded.

---

### 3. LimitRange Strategy

**Default Values**:
- Prevent pods without resource requests (unbounded growth)
- Ensure consistent QoS across namespaces

**Example** (from `jupyterhub/namespace.yaml`):
```yaml
spec:
  limits:
  - type: Container
    default:
      cpu: "1"       # If user doesn't specify, default to 1 core
      memory: 2G
    defaultRequest:
      cpu: 500m      # Minimum guaranteed
      memory: 1G
```

**Rationale**: Users often omit resource requests; LimitRange provides safe defaults.

---

## Deployment Order

**CRITICAL**: Namespaces must be created before applications.

```bash
# Step 1: Create all namespaces (with quotas)
kubectl apply -f infra/namespaces/traefik-system/
kubectl apply -f infra/namespaces/jupyterhub/

# or batch application
kubectl apply -R -f infra/namespaces/

# Step 2: Verify quotas active
kubectl get resourcequota -A

# Step 3: Deploy applications
kubectl apply -f infra/traefik/
kubectl apply -f apps/jupyterhub/
```

**Validation**:
```bash
# Check quota enforcement
kubectl describe resourcequota gpu-quota -n jupyterhub

# Expected output:
# Used: requests.nvidia.com/gpu: 2
# Hard: requests.nvidia.com/gpu: 4
```

---

## File Naming Convention

**Pattern**: `<namespace-name>.yaml`

Examples:
- `jupyterhub/namespace.yaml` (subdirectory for complex namespaces)

**Why subdirectories?**: Some namespaces (jupyterhub) require additional resources (NetworkPolicies, ConfigMaps).

---

## Phase-Specific Quotas

### Phase 1 (MAV - Current)

**Single Node**: RTX A4000 (1 physical GPU → 4 virtual)

| Namespace | GPU Quota | Rationale |
|-----------|-----------|-----------|
| jupyterhub | 4 | All available GPUs for user workloads |
| traefik-system | 0 | Infrastructure doesn't need GPU |

---

### Phase 2 (HA - Q3 2026)

**3 Nodes**: 12-16 GPUs total

| Namespace | GPU Quota | Rationale |
|-----------|-----------|-----------|
| jupyterhub | 12 | 75% of capacity for users |
| monitoring | 0 | Prometheus/Grafana on separate nodes |
| argocd | 0 | GitOps control plane |

**Adjustment Strategy**: As utilization grows, rebalance quotas without downtime.

---

### Phase 3 (SuperPod - 2027)

**128 Nodes**: 1024 B200 GPUs (with MIG: 7168 MIG instances)

| Namespace | MIG Quota | Rationale |
|-----------|-----------|-----------|
| tenant-* (per tenant) | 10-100 | Based on subscription tier |
| system | 64 | Reserved for platform operations |
| monitoring | 0 | CPU-only metrics collection |

**Multi-Tenancy**: Each customer gets dedicated namespace with quota.

---

## Quota Monitoring

### Real-Time Status

```bash
# Check quota usage across all namespaces
kubectl get resourcequota -A -o custom-columns=\
NAMESPACE:.metadata.namespace,\
GPU_USED:.status.used."requests\.nvidia\.com/gpu",\
GPU_HARD:.status.hard."requests\.nvidia\.com/gpu"
```

### Prometheus Alerts (Planned)

```yaml
- alert: NamespaceQuotaExhausted
  expr: |
    kube_resourcequota_used / kube_resourcequota_hard > 0.9
  for: 5m
  annotations:
    summary: "Namespace {{ $labels.namespace }} at 90% quota"
```

---

## Troubleshooting

**Issue**: Pod stuck in Pending with `FailedScheduling` error

```bash
# Check quota status
kubectl describe resourcequota -n <namespace>

# Expected error:
# Error: exceeded quota: gpu-quota, requested: nvidia.com/gpu=1, used: nvidia.com/gpu=4, limited: nvidia.com/gpu=4
```

**Solution**: Delete unused pods or request quota increase.

---

**Issue**: Pod rejected with "minimum cpu usage per Container is 100m"

```bash
# Check LimitRange
kubectl describe limitrange -n <namespace>
```

**Solution**: Add resource requests to Pod spec:
```yaml
resources:
  requests:
    cpu: 100m
    memory: 128M
```

---

## Files

```
infra/namespaces/
├── README.md          # This file
├── traefik/
│   └── namespace.yaml # Ingress controller namespace
└── jupyterhub/
    └── namespace.yaml # Multi-user notebook namespace
```

---

## References

- [Kubernetes ResourceQuotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
- [LimitRange Documentation](https://kubernetes.io/docs/concepts/policy/limit-range/)
- [NVIDIA GPU Time-Slicing](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-sharing.html)
- [Multi-Tenancy Best Practices](https://kubernetes.io/docs/concepts/security/multi-tenancy/)

---

**Status**: Production (Phase 1 MAV)  
**Next**: Add monitoring, argocd namespaces (Phase 2)  
**Owner**: Platform Engineering Team

---

**Part of**: AI Computing Center MLOps Platform
**Managed by**: Range
**Last Updated**: 2026-01-29

