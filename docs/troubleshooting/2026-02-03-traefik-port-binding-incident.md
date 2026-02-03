# Traefik Port Binding Incident Report

## Executive Summary
**Incident ID**: AICC-2026-0203-001  
**Severity**: P1 (Critical - Service Outage)  
**Impact**: Complete loss of HTTPS (443) access to all MLOps services  
**Root Cause**: Helm values misconfiguration during function added.  
**Resolution**: Rollback to DaemonSet + hostPort configuration  

---

## Timeline of Events

| Event | Action Taken |
|-------|--------------|
| Attempted to enable cross-namespace routing via `helm upgrade` | Modified service type parameters |
| Observed Dashboard (traefik.mlops.work) returning 443 connection refused | Investigated Service configuration |
| Discovered Traefik Service type changed from `LoadBalancer` to `NodePort` | Ports reassigned: 443→32647, 80→30504 |
| Confirmed k3s ServiceLB not running (`svclb-*` Pods absent in kube-system) | Identified infrastructure gap |
| Container runtime errors detected (`c5b5d524f2bb` not found) | Cleared stale containerd references |
| Attempted `helm upgrade` with ClusterIP + hostPort | Failed: hostPort not applied in Deployment mode |
| Identified root cause: Deployment mode incompatible with hostPort | Confirmed DaemonSet requirement |
| Applied corrected `values.yaml` with DaemonSet + hostPort | Service restored |

---

## Root Cause Analysis

### Primary Cause
**Helm Chart Parameter Conflict**: The `--reuse-values` flag during `helm upgrade` preserved conflicting settings from previous iterations, specifically:
- `deployment.kind: Deployment` (old value)
- `ports.web.hostPort: 80` (new value)

**Technical Detail**: Kubernetes Deployment objects do NOT support `hostPort` binding. Only DaemonSet and Pod-level specs allow direct host network port allocation.

### Contributing Factors
1. **Missing k3s ServiceLB**: The default k3s LoadBalancer controller was not operational, causing `type: LoadBalancer` to fall back to NodePort allocation.
2. **Schema Validation Errors**: Helm Chart v38.0.2 rejected `ports.web.redirections` and `ports.websecure.tls.options` parameters, masking the underlying configuration drift.
3. **Lack of Pre-Change Validation**: No dry-run or diff analysis performed before applying changes to production routing infrastructure.

---

## Impact Assessment

### Affected Services
- [o] **Traefik Dashboard**: Inaccessible via standard HTTPS (443)
- [o] **JupyterHub**: Complete service outage (`jupyter.mlops.work` unreachable)
- [!] **cert-manager**: Certificate renewals deferred (no immediate impact)
- [o] **Ollama (planned)**: Deployment blocked due to routing unavailability

### Impact
- **Development Velocity**: Service halt in AI model training workflows
- **Security Posture**: Forced use of non-standard ports (32647) exposed NodePort range
- **Compliance Risk**: Temporary violation of "standard ports only" policy (ADR-02)

---

## Resolution Steps

### Immediate Actions (Mitigation)
```bash
# 1. Confirmed Service status
kubectl get svc -n traefik-system traefik -o yaml

# 2. Verified Pod port bindings
kubectl get pod -n traefik-system -o jsonpath='{.items.spec.containers.ports}'

# 3. Tested local connectivity
curl -k https://localhost:443
```

### Corrective Actions (Permanent Fix)
```bash
# 1. Corrected values.yaml structure
# - Changed deployment.kind to DaemonSet
# - Fixed ports.expose from boolean to object format
# - Removed unsupported parameters (redirections, tls.options in ports)

# 2. Applied declarative configuration
helm upgrade traefik traefik/traefik -n traefik-system \
  -f infra/traefik/base/helm/values.yaml

# 3. Validated restoration
sudo ss -tlnp | grep :443
curl -I https://traefik.mlops.work/dashboard/
```

---

## Preventive Measures

### Technical Controls
1. **Implement CI/CD Validation Pipeline**
   - Add `helm lint` and `helm diff` to Git pre-commit hooks
   - Require dry-run validation before any infrastructure changes
   
2. **Enforce Configuration Management**
   - Migrate to GitOps (ArgoCD) for immutable infrastructure definitions
   - Eliminate manual `helm upgrade` commands in production

3. **Add Monitoring Alerts**
   - Zabbix trigger: Alert when Traefik Service type != ClusterIP
   - Prometheus rule: Alert when hostPort 443 binding disappears

### Operational Controls
1. **Mandatory Change Review**
   - All Traefik configuration changes require peer review via Pull Request
   - Implement 4-eyes principle for production routing modifications

2. **Runbook Documentation**
   - Create `docs/runbooks/traefik-deployment-modes.md`
   - Document DaemonSet vs Deployment trade-offs

3. **Testing Protocol**
   - Before merging: Test configuration in isolated namespace
   - After merging: Validate external HTTPS access from remote client

---

## Lessons Learned

### What Went Well [o]
- Systematic troubleshooting methodology identified root cause
- No data loss or certificate revocation occurred
- Documentation of troubleshooting steps enabled knowledge capture

### What Needs Improvement [!]
- Insufficient understanding of Kubernetes networking primitives (hostPort vs NodePort vs LoadBalancer)
- Lack of automated testing for infrastructure changes
- Missing baseline health checks before applying changes

### Action Items
| Action | Owner | Status |
|--------|-------|--------|
| Create Traefik deployment mode runbook | MLOps Engineer | Pending |
| Implement helm diff in CI pipeline | DevOps Lead | Pending |
| Add Zabbix monitoring for port bindings | SRE Team | Pending |
| Conduct team training on K8s networking | Tech Lead | Pending |

---

## References
- **ADR-014**: Infrastructure Service Exposure Standards
- **Helm Chart**: traefik/traefik v38.0.2 (App: v3.6.7)
- **K8s Documentation**: [hostPort vs NodePort](https://kubernetes.io/docs/concepts/services-networking/)
- **Git Commit**: [To be added after final resolution]

---

## Approval
**Prepared By**: MLOps Platform Team  
**Reviewed By**: 
**Approved By**: 
**Date**: 2026-02-03

