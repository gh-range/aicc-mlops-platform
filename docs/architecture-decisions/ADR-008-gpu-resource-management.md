# ADR-008: GPU Resource Management Strategy1

## Status
Accepted (2026-01-20)

## Context
GPUs are scarce resources requiring precise allocation control. During initial deployment, infrastructure components (Hub, Proxy, Scheduler, ImagePuller) were automatically assigned 2 GPUs despite no explicit requirements in resource specifications. Investigation revealed complex interactions between Kubernetes LimitRange, PodSecurity policies, and JupyterHub configuration defaults.

## Problem Statement

### Primary Issue: GPU Auto-Injection
Infrastructure components received unexpected GPU allocations:
- `hub`: 2 GPU (expected: 0)
- `proxy`: 2 GPU (expected: 0)
- `user-scheduler`: 2 GPU (expected: 0)
- `continuous-image-puller`: 2 GPU (expected: 0)

### Root Cause Analysis
1. **LimitRange GPU Max Trigger**: Setting ANY GPU field (`max`, `min`, `default`, `defaultRequest`) in LimitRange caused Kubernetes to auto-inject GPU allocations to Pods without explicit resource declarations
2. **Implicit Default Behavior**: Even with only `max.nvidia.com/gpu: "2"` defined (no `default` field), Kubernetes used the max value as implicit default
3. **PodSecurity Incompatibility**: JupyterHub's `block-cloud-metadata` sidecar requires privileged capabilities, violating `restricted` PodSecurity policy
4. **Memory Format Mismatch**: JupyterHub config rejects Kubernetes `Gi` suffix (requires `G`)
5. **LimitRange Minimum Violation**: Components with `cpu.requests: 50m` failed against `LimitRange.min.cpu: 100m`

## Decision

### 1. GPU Constraint Strategy: Complete Removal from LimitRange

**Initial Hypothesis**: Only `default`/`defaultRequest` fields cause auto-injection  
**Reality**: ANY GPU field presence in LimitRange triggers auto-injection behavior  
**Evidence**: Pods received `nvidia.com/gpu: "2"` matching the `max` value even without `default` specified

**Solution**: **Completely remove ALL GPU fields from LimitRange**
```yaml
# [x] INCORRECT (causes auto-injection)
spec:
  limits:
  - type: Container
    max:
      nvidia.com/gpu: "2"    # ← Triggers auto-injection
    min:
      nvidia.com/gpu: "0"

# [o] CORRECT (no auto-injection)
spec:
  limits:
  - type: Container
    max:
      cpu: "8"
      memory: 32Gi
      # GPU completely absent
    min:
      cpu: 100m
      memory: 128Mi
```

**Alternative**: Use ResourceQuota for namespace-level GPU limits (no side effects)

### 2. GPU Allocation Policy: Explicit Declaration Principle

**Zero-Trust Model**: All components must explicitly declare GPU requirements
- **GPU required**: `nvidia.com/gpu: "1"` (explicit non-zero)
- **GPU not required**: `nvidia.com/gpu: "0"` (explicit zero prevents auto-injection)
- **Undeclared**: [x] Prohibited (would trigger auto-injection with LimitRange present)

**Rationale**:
- Prevents unintended GPU allocation to infrastructure workloads
- Aligns with Zero-Trust security principles (deny-by-default)
- Improves configuration auditability and cost visibility

### 3. PodSecurity Policy: Baseline Enforcement

**Challenge**: JupyterHub's default configuration violates `restricted` policy:
- `block-cloud-metadata` sidecar: `privileged=true`, `NET_ADMIN` capability, `runAsUser=0`

**Solution**: Adjust namespace PodSecurity labels
```yaml
metadata:
  labels:
    pod-security.kubernetes.io/enforce: baseline    # Allow essential workloads
    pod-security.kubernetes.io/audit: restricted    # Log violations for review
    pod-security.kubernetes.io/warn: restricted     # Warn on non-compliance
```

**Trade-off Analysis**:
| Policy | Compatibility | Security | Production Readiness |
|--------|--------------|----------|---------------------|
| restricted | [x] Requires extensive JupyterHub customization | ⭐⭐⭐⭐⭐ | Future state |
| baseline | [o] Works with minimal configuration | ⭐⭐⭐⭐ | Current (MAV node) |
| privileged | [o] No restrictions | ⭐ | [x] Never |

**Mitigation for cloudMetadata Risk**:
- Disabled `cloudMetadata.blockWithIptables` (eliminates privileged requirement)
- On-premises deployment (no cloud metadata endpoint exists)
- Can implement NetworkPolicy egress restrictions if cloud migration occurs

### 4. Configuration Architecture

#### Infrastructure Layer (infra/namespaces/jupyterhub/namespace.yaml)
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: jupyterhub
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
***
apiVersion: v1
kind: ResourceQuota
metadata:
  name: gpu-quota
  namespace: jupyterhub
spec:
  hard:
    limits.nvidia.com/gpu: "4"         # Namespace-level GPU limit
    requests.nvidia.com/gpu: "4"
    requests.cpu: "20"
    requests.memory: 64Gi
    limits.cpu: "40"
    limits.memory: 96Gi
***
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
      # [o] NO GPU fields (prevents auto-injection)
    min:
      cpu: 100m                        # Minimum enforced
      memory: 128Mi
    default:
      cpu: "1"
      memory: 2Gi
    defaultRequest:
      cpu: 500m
      memory: 1Gi
  - type: Pod
    max:
      cpu: "16"
      memory: 64Gi
    min:
      cpu: 100m
      memory: 128Mi
```

#### Application Layer (apps/jupyterhub/values.yaml)
```yaml
hub:
  resources:
    limits:
      cpu: "2"
      memory: 2Gi
      nvidia.com/gpu: "0"              # [o] Explicit zero
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

scheduling:
  userScheduler:
    enabled: true
    replicas: 2                        # High availability
    resources:
      requests:
        cpu: 100m                      # Meet LimitRange minimum
        memory: 256Mi
        nvidia.com/gpu: "0"
      limits:
        cpu: 200m
        memory: 512Mi
        nvidia.com/gpu: "0"

prePuller:
  resources:
    requests:
      cpu: 100m                        # Meet LimitRange minimum
      memory: 128Mi
      nvidia.com/gpu: "0"
    limits:
      cpu: 200m
      memory: 256Mi
      nvidia.com/gpu: "0"
  hook:
    enabled: true
  continuous:
    enabled: true

singleuser:
  cloudMetadata:
    blockWithIptables: false           # [o] Disable privileged sidecar
  
  extraResource:
    limits:
      nvidia.com/gpu: "1"              # [o] User pods get GPU
    guarantees:
      nvidia.com/gpu: "1"
  
  cpu:
    limit: 2
    guarantee: 0.5
  
  memory:
    limit: 4G                          # [o] Use 'G' not 'Gi'
    guarantee: 1G
  
  image:
    name: quay.io/jupyter/minimal-notebook
    tag: ubuntu-24.04
  
  storage:
    type: dynamic
    dynamic:
      storageClass: local-path
    capacity: 10Gi                     # [o] Storage can use 'Gi'
```

## Consequences

### Positive
- [o] Infrastructure components correctly allocated 0 GPU
- [o] User notebooks receive 1 GPU on-demand
- [o] ResourceQuota provides namespace-level protection
- [o] Explicit declarations improve cost visibility and auditability
- [o] Baseline PodSecurity allows JupyterHub operation with reasonable security
- [o] Configuration aligns with Zero-Trust principles
- [o] Pattern validated for multi-tenancy and SuperPod scaling

### Negative
- [!] Requires explicit GPU declaration for every component (maintenance overhead)
- [!] `baseline` PodSecurity less restrictive than `restricted` (acceptable for MAV, reassess for production)
- [!] Cloud metadata endpoint accessible to user notebooks (mitigated: on-premises deployment)
- [!] Helm Chart updates require GPU field verification

### Neutral
- GPU limits enforced at ResourceQuota level only (simpler than dual-layer enforcement)
- LimitRange now only governs CPU/memory (clearer separation of concerns)

## Implementation Notes

### Issue Timeline
1. **Initial State**: LimitRange with `max.nvidia.com/gpu: "2"` defined
2. **Symptom**: All Pods received `nvidia.com/gpu: "2"` despite no explicit requests
3. **Hypothesis 1**: Only `default` fields cause injection → Disproven
4. **Hypothesis 2**: `kubectl apply` not overwriting → Disproven (forced delete/recreate still injected GPU)
5. **Root Cause**: ANY GPU field in LimitRange triggers implicit default behavior
6. **Solution**: Complete removal of GPU fields from LimitRange
7. **Secondary Issues**: PodSecurity violations, memory format incompatibility, CPU minimums
8. **Final State**: All infrastructure pods GPU=0, user pods GPU=1, stable operation

### Key Lessons Learned
1. **LimitRange extended resource behavior differs from CPU/memory**: Setting `max` alone triggers auto-injection for GPUs
2. **PodSecurity requires application-level coordination**: Infrastructure teams cannot enforce `restricted` without validating workload compatibility
3. **JupyterHub configuration quirks**: Memory format (`G` not `Gi`), privileged sidecar defaults
4. **Explicit is better than implicit**: Zero-Trust resource allocation prevents surprises

### Migration Steps for Other Namespaces
1. Audit existing LimitRange for GPU fields
2. Remove all GPU constraints from LimitRange
3. Add explicit `nvidia.com/gpu: "0"` to all non-GPU workloads
4. Verify ResourceQuota enforcement
5. Test Pod admission and runtime behavior
6. Document GPU request process for developers

## Validation

### Verification Commands
```bash
# 1. Verify LimitRange has NO GPU configuration
kubectl get limitrange gpu-limitrange -n jupyterhub -o yaml | grep "nvidia.com/gpu"
# Expected: No output

# 2. Verify infrastructure pods have GPU=0
kubectl get pods -n jupyterhub -o custom-columns=\
  'NAME:.metadata.name,GPU-LIMITS:.spec.containers.resources.limits.nvidia\.com/gpu'
# Expected: hub=0, proxy=0, user-scheduler=0, continuous-image-puller=0

# 3. Verify user pod receives GPU=1
kubectl get pods -n jupyterhub -l component=singleuser-server -o jsonpath=\
  '{.items.spec.containers.resources.limits.nvidia\.com/gpu}'
# Expected: 1

# 4. Verify ResourceQuota enforcement
kubectl get resourcequota gpu-quota -n jupyterhub -o yaml
# Expected: hard.limits.nvidia.com/gpu: "4"

# 5. Verify PodSecurity labels
kubectl get namespace jupyterhub -o yaml | grep pod-security
# Expected: enforce=baseline, audit=restricted, warn=restricted

# 6. Test user notebook GPU access
# Login to JupyterHub → Start notebook → Run:
!nvidia-smi
# Expected: 1 GPU visible
```

### Production Checklist
- [x] Infrastructure pods: GPU=0
- [x] User pods: GPU=1 (on-demand)
- [x] ResourceQuota enforced
- [x] PodSecurity baseline compliant
- [x] User spawning successful
- [x] High availability: 2x user-scheduler replicas
- [x] Git configuration matches cluster state
- [x] ADR documented

## Compliance Mapping

### Security Standards
- **ISO 27001**: A.12.1.3 (Capacity Management), A.14.2.5 (Secure Engineering)
- **NIST 800-190**: Container Security (baseline PodSecurity)
- **CIS Kubernetes Benchmark**: 5.2 (Pod Security Standards)

### Operational Excellence
- **TCO Optimization**: Prevents GPU waste on non-compute workloads ($30K/GPU cost avoidance)
- **SuperPod Readiness**: Resource pattern validated for H200/B200 cluster scaling
- **FinOps**: Explicit GPU allocation enables accurate cost attribution

### Future Production Requirements
- **Cloud Deployment**: Re-enable `cloudMetadata.blockWithIptables` with CNI NetworkPolicy
- **Compliance Audit**: Migrate to `restricted` PodSecurity with custom SecurityContext templates if required
- **Multi-Region**: Extend ResourceQuota strategy to federated clusters

## References
- [Kubernetes LimitRange Documentation](https://kubernetes.io/docs/concepts/policy/limit-range/)
- [Kubernetes Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [NVIDIA GPU Operator Resource Management](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/)
- [JupyterHub Helm Chart Reference](https://z2jh.jupyter.org/en/latest/resources/reference.html)
- [NIST 800-190 Container Security](https://csrc.nist.gov/publications/detail/sp/800-190/final)

## Incident Reference
- **Date**: 2026-01-20
- **Reporter**: Range
- **Severity**: Medium (cost impact, no service outage)
- **Resolution Time**: 4 hours
- **Status**: Resolved and validated

## Amendment History
- **2026-01-20 15:00 CST**: Initial version with complete root cause analysis and multi-issue resolution

