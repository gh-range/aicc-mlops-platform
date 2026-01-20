# ADR-008: GPU Resource Management Strategy

## Status
Accepted (2026-01-20)

## Context
GPUs are scarce resources requiring precise allocation control. Kubernetes LimitRange exhibits different behavior for extended resources (e.g., GPUs) compared to standard resources (CPU/memory). Setting `max` constraints for GPUs in LimitRange triggers automatic default value injection, causing unintended GPU allocation to non-GPU workloads.

## Problem Statement
Infrastructure components (Hub, Proxy) were automatically assigned 2 GPUs despite no explicit GPU requirements in their resource specifications. Investigation revealed that LimitRange with GPU `max` values caused Kubernetes to inject `default` GPU allocations.

## Decision

### 1. GPU Constraint Strategy
**DO NOT set GPU max/min in LimitRange**
- **Rationale**: Triggers automatic default value generation
- **Alternative**: Use ResourceQuota for namespace-level GPU limits

### 2. GPU Allocation Policy
**Explicit Declaration Principle**: All components must explicitly declare GPU requirements
- **GPU required**: `nvidia.com/gpu: "1"`
- **GPU not required**: `nvidia.com/gpu: "0"` (explicit zero prevents auto-injection)

### 3. Configuration Architecture
```yaml
# ResourceQuota (namespace-level hard limits)
apiVersion: v1
kind: ResourceQuota
metadata:
  name: gpu-quota
  namespace: jupyterhub
spec:
  hard:
    limits.nvidia.com/gpu: "4"
    requests.nvidia.com/gpu: "4"

# LimitRange (CPU/memory constraints only, NO GPU)
apiVersion: v1
kind: LimitRange
metadata:
  name: gpu-limitrange
  namespace: jupyterhub
spec:
  limits:
  - type: Container
    max:
      cpu: "8"
      memory: 32Gi
      # ❌ DO NOT include nvidia.com/gpu
    min:
      cpu: 100m
      memory: 128Mi
    default:
      cpu: "1"
      memory: 2Gi
    defaultRequest:
      cpu: 500m
      memory: 1Gi

# Helm values (application-level explicit declarations)
hub:
  resources:
    limits:
      cpu: "2"
      memory: 2Gi
      nvidia.com/gpu: "0"      # [o] Explicit zero
    requests:
      cpu: 200m
      memory: 512Mi
      nvidia.com/gpu: "0"

proxy:
  chp:
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
        nvidia.com/gpu: "0"
      requests:
        cpu: 100m
        memory: 256Mi
        nvidia.com/gpu: "0"

singleuser:
  extraResource:
    limits:
      nvidia.com/gpu: "1"      # [o] Explicit allocation
    guarantees:
      nvidia.com/gpu: "1"
```

## Consequences

### Positive
- Prevents unintended GPU allocation to infrastructure components
- ResourceQuota provides namespace-level protection against over-commitment
- Explicit declarations improve configuration transparency and auditability
- Aligns with Zero-Trust security model (deny-by-default)

### Negative
- Requires explicit GPU declaration for every component (increased maintenance overhead)
- Helm Chart updates may require GPU field verification

### Neutral
- GPU limits enforced at ResourceQuota level only
- Pod admission controller validates against ResourceQuota, not LimitRange

## Implementation Notes

### Migration Steps
1. Remove GPU constraints from LimitRange
2. Add explicit `nvidia.com/gpu: "0"` to all non-GPU workloads
3. Verify ResourceQuota enforcement
4. Document GPU request process for new services

### Validation Commands
```bash
# Verify LimitRange has no GPU configuration
kubectl get limitrange gpu-limitrange -n jupyterhub -o yaml | grep nvidia.com/gpu

# Verify Hub/Proxy have GPU explicitly set to zero
kubectl get pods -n jupyterhub -l component=hub -o jsonpath='{.spec.containers.resources}'
kubectl get pods -n jupyterhub -l component=proxy -o jsonpath='{.spec.containers.resources}'

# Verify ResourceQuota enforcement
kubectl get resourcequota gpu-quota -n jupyterhub -o yaml
```

## References
- Kubernetes Documentation: [Limit Ranges](https://kubernetes.io/docs/concepts/policy/limit-range/)
- Kubernetes Documentation: [Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
- NVIDIA GPU Operator: [Resource Management](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/)
- JupyterHub Helm Chart: [Resource Configuration](https://z2jh.jupyter.org/en/latest/resources/reference.html)
- Incident Report: Hub/Proxy auto-injected with 2 GPUs (2026-01-20)

## Compliance Mapping
- **ISO 27001**: A.12.1.3 (Capacity Management)
- **TCO Optimization**: Prevents GPU waste on non-compute workloads
- **SuperPod Readiness**: Resource pattern scalable to H200/B200 clusters

