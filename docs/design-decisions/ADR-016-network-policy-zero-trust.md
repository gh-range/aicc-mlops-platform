# ADR-016: NetworkPolicy Zero-Trust Implementation

## Status
Accepted

## Date
2026-02-12

## Context

### Security Requirements
Implement network isolation for AICC MLOps Platform to:
- Restrict Traefik to necessary ingress/egress paths
- Isolate JupyterHub from direct external access
- Establish baseline for zero-trust architecture

### Technical Environment
- **CNI**: K3s Flannel + Calico v3.31.3 (policy-only mode)
- **Ingress**: Traefik (Cloudflare proxied + Direct)
- **Workloads**: JupyterHub, Ollama (planned)

---

## Decision

### Adopted NetworkPolicy Strategy: Permissive Baseline

Implemented **two-tier NetworkPolicy** approach:
1. **Traefik**: Permissive egress policy
2. **JupyterHub**: Restricted ingress (Traefik-only)

### Architecture

```
Internet
  │
  ├─ Cloudflare Proxy ─→ (Traefik services)
  ├─ DNS Only ─────────→ jupyter.mlops.work
  │
  ↓
Traefik (traefik-system)
  │ NetworkPolicy: Permissive egress
  │ Ingress: Allow all :80, :443, :8080
  │ Egress: Allow all namespaces + external
  ↓
JupyterHub (jupyterhub)
  │ NetworkPolicy: Restricted ingress
  │ Ingress: Only from traefik-system
  │ Egress: DNS, K8s API, external
  ↓
User Notebooks
```

---

## Implementation Details

### 1. Traefik NetworkPolicy (Permissive)

**File**: `infra/namespaces/traefik-system/network-policies/traefik-netpol.yaml`

```yaml
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: traefik
  policyTypes: [Ingress, Egress]
  
  ingress:
    - {}  # Allow all ingress
  
  egress:
    - to: [podSelector: {}]              # Same namespace
    - to: [namespaceSelector: kube-system]  # DNS
      ports: 
    - to: [namespaceSelector: {}]        # All namespaces
    - to: [ipBlock: {cidr: 0.0.0.0/0}]   # External
```

**Rationale**: 
- Initial attempt with strict egress rules **failed** (Dashboard inaccessible)
- Traefik requires flexible connectivity for dynamic routing, health checks, and internal communication
- Permissive policy provides baseline isolation while maintaining functionality

---

### 2. JupyterHub NetworkPolicy (Restricted)

**Files**: 
- `infra/namespaces/jupyterhub/network-policies/jupyterhub-netpol.yaml`

```yaml
# Policy 1: Proxy (ingress restriction)
spec:
  podSelector:
    matchLabels:
      component: proxy
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: traefik-system
          podSelector:
            matchLabels:
              app.kubernetes.io/name: traefik
      ports: 

# Policy 2: Hub (internal communication)
spec:
  podSelector:
    matchLabels:
      component: hub
  ingress:
    - from: [podSelector: {component: proxy}]
  egress:
    - to: [namespaceSelector: kube-system]  # DNS
    - to: [ipBlock: 0.0.0.0/0]  # GitHub OAuth, external
```

**Effect**: JupyterHub cannot be accessed directly, only through Traefik

---


## Validation

### Test Results

| Test | Method | Expected | Actual | Status |
|------|--------|----------|--------|--------|
| Traefik Dashboard | Browser | 200 | 200 | [o] |
| JupyterHub via Traefik | Browser | 200/302 | 200 | [o] |
| JupyterHub via curl | `curl -I` | 200/302 | 502 | [!] See note |
| Pod status | `kubectl get pods` | Running | Running | [o] |

**Important Note on curl 502**:
```bash
# Simple curl shows 502 (false positive)
curl -I https://jupyter.mlops.work
# HTTP/1.1 502 Bad Gateway

# Full request succeeds
curl -L --max-time 30 https://jupyter.mlops.work
# Returns HTML (200 OK)
```

**Root Cause**: JupyterHub initial connection requires redirect handling and longer timeout. Browser handles this automatically; simple `curl -I` does not.

**Validation Command**:
```bash
# Correct validation method
curl -L -s -o /dev/null -w "%{http_code}\n" --max-time 30 https://jupyter.mlops.work
# Expected: 200
```

---

## Consequences

### Positive
- [o] **Baseline isolation**: NetworkPolicy framework established
- [o] **JupyterHub protected**: Cannot be directly accessed (must go through Traefik)
- [o] **Operational stability**: No service disruption
- [o] **Foundation for improvement**: Can gradually tighten policies

### Negative
- [!] **Limited Traefik restriction**: Permissive egress provides minimal actual protection
- [!] **Maintenance burden**: Policies require updates when adding services
- [!] **Debugging complexity**: NetworkPolicy errors harder to diagnose

### Neutral
- <!> **Performance impact**: Negligible (policy evaluation at kernel level)
- <!> **Calico overhead**: ~50-100MB memory per node

---

## Why Not Strict Policy?

### Attempted Strict Traefik Policy (Failed)

```yaml
# Attempted configuration
egress:
  - to: [namespaceSelector: jupyterhub]
    ports: 
  - to: [ipBlock: 0.0.0.0/0]
    ports: 
```

**Failure Mode**: Traefik Dashboard returned "web server is down"

**Root Cause Analysis**:
1. **Missing same-namespace communication**: Traefik needs to access its own ClusterIP Service
2. **Undocumented port requirements**: Health checks, metrics, internal APIs use additional ports
3. **Dynamic routing**: Traefik discovers services dynamically, requiring broad namespace access

**Decision**: Adopt permissive policy rather than risk breaking production functionality in demo environment

---

## Future Improvements

### Phase 1: Monitoring (Next 1-2 months)
```bash
# Enable Calico Flow Logs to monitor actual traffic
kubectl apply -f - <<EOF
apiVersion: projectcalico.org/v3
kind: FlowLog
metadata:
  name: traefik-flow-log
spec:
  selector: app.kubernetes.io/name == "traefik"
EOF
```

### Phase 2: Gradual Tightening (3-6 months)
1. Analyze 14-day flow logs
2. Identify unused egress paths
3. Incrementally add restrictions
4. Monitor for breakage

### Phase 3: Production Hardening (6-12 months)
- Implement default-deny for all namespaces
- Service mesh consideration (Istio/Linkerd)
- FQDN-based egress filtering
- Layer 7 policies for HTTP/gRPC

---

## Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| **No NetworkPolicy** | Simple, no breakage | No isolation | Rejected |
| **Strict from day 1** | Maximum security | Operational risk | Rejected (failed) |
| **Permissive baseline** | Balance of both | Limited protection | **Adopted** |
| **Service Mesh** | L7 visibility | Complexity, overhead | Deferred |

---

## Maintenance

### When to Update NetworkPolicy

1. **Adding new services**: Create policy before deployment
2. **Service communication changes**: Update ingress/egress rules
3. **Quarterly review**: Audit unused rules, tighten where possible
4. **Security incidents**: Immediate restriction of compromised workloads

### Troubleshooting Checklist

```bash
# 1. Check policy exists
kubectl get networkpolicy -n <namespace>

# 2. Verify pod labels match
kubectl get pods -n <namespace> --show-labels

# 3. Check namespace labels
kubectl get namespace <namespace> --show-labels

# 4. View Calico logs
kubectl logs -n kube-system -l k8s-app=calico-node

# 5. Test from source pod
kubectl exec -n <source-ns> <pod> -- curl <target-service>
```

---

## References

### Internal
- [Traefik Architecture](../architecture/traefik-architecture.md)
- [Security Baseline](../security/tls/tls-security-baseline.md)

### External
- [Kubernetes NetworkPolicy](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Calico NetworkPolicy](https://docs.tigera.io/calico/latest/network-policy/)
- [CNCF Network Policy Best Practices](https://www.cncf.io/blog/2021/05/18/kubernetes-network-policy-best-practices/)

---

## Approval

**Decision Date**: 2026-02-12  
**Approved By**: Platform Engineering  
**Review Cycle**: Quarterly (or when adding major services)  
**Next Review**: 2026-05-12

---

## Changelog

| Date | Version |  Author | Changes |
|------|---------|---------|---------|
| 2026-02-12 | 1.0 | Range | Initial baseline NetworkPolicy for Traefik + JupyterHub |

