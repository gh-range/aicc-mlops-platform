# ADR-009: Standalone Traefik Deployment Strategy

**Status**: Accepted  
**Date**: 2026-01-22  
**Decision Makers**: Platform Engineering Team  
**Technical Story**: Deploy production-grade Traefik independently from k3s built-in controller

## Context

k3s defaults to deploying Traefik v2.x as a built-in Ingress Controller. However, for enterprise MLOps platforms targeting SuperPod scalability, independent lifecycle management is critical.

## Decision

Deploy Traefik as a standalone Helm-managed application with k3s built-in Traefik permanently disabled via `--disable traefik` flag.

## Rationale

### Why Disable k3s Built-in Traefik?

| Criterion | Built-in Traefik | Standalone Traefik |
|-----------|------------------|-------------------|
| Version Control | Coupled with k3s release cycle | Independent versioning (Helm chart) |
| Configuration Management | Limited customization via HelmChartConfig | Full Helm values.yaml control |
| Upgrade Risk | k3s upgrade may force Traefik changes | Decoupled upgrade windows |
| GitOps Compatibility | Requires special CRD handling | Native ArgoCD/Flux support |
| Multi-Cluster Consistency | Different Traefik versions per k3s version | Uniform Traefik version across clusters |

### Enterprise Requirements

1. **Compliance Auditability**: All infrastructure changes must be Git-tracked
2. **Disaster Recovery**: Helm-based deployments simplify backup/restore procedures
3. **SuperPod Migration Path**: Identical Traefik configuration across MAV and production clusters

## Consequences

### Positive

- Full control over Traefik lifecycle (install/upgrade/rollback)
- Explicit configuration versioning in Git
- Consistent deployment patterns with other infrastructure components
- Easier integration with cert-manager and external DNS providers

### Negative

- Requires manual Traefik installation (mitigated by automation scripts)
- Additional operational overhead for upgrades (acceptable trade-off)

## Implementation

### Current Status (2026-01-22)

```bash
# k3s service configuration excerpt
ExecStart=/usr/local/bin/k3s server \
  --disable traefik \
  --disable servicelb \
  --write-kubeconfig-mode 644
```

### Verification

```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
# Output: No resources found in kube-system namespace
```

## References

- k3s Advanced Options: https://docs.k3s.io/installation/configuration
- Traefik Kubernetes Ingress: https://doc.traefik.io/traefik/providers/kubernetes-ingress/
- Related ADR: ADR-001 (k3s as Kubernetes Distribution)

## Supersedes

N/A (Initial decision for Ingress layer)

## Superseded By

N/A

