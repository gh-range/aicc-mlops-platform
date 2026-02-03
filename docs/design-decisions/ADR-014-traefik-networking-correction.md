# ADR-014 Amendment: Traefik Networking Architecture Correction

## Status
**AMENDED** (Original: 2026-01-20 | Amendment: 2026-02-03)

## Context
The original ADR-02 specified Traefik deployment using `LoadBalancer` service type, assuming k3s ServiceLB would be available. Post-incident analysis revealed:

1. **k3s ServiceLB Not Active**: No `svclb-*` Pods observed in `kube-system` namespace
2. **NodePort Fallback Risk**: LoadBalancer without LB controller degrades to NodePort (random high ports)
3. **Single-Node Constraint**: MAV environment does not require external load balancing

## Decision
**Updated Architecture**: DaemonSet + hostPort + ClusterIP

### Configuration Matrix
| Component | Previous | Corrected | Rationale |
|-----------|----------|-----------|-----------|
| deployment.kind | Deployment | **DaemonSet** | Enables hostPort support |
| service.type | LoadBalancer | **ClusterIP** | No external LB needed in MAV |
| ports.web.hostPort | (unset) | **80** | Direct host binding |
| ports.websecure.hostPort | (unset) | **443** | Direct host binding |

## Consequences

### Positive [o]
- **Zero external dependencies**: No reliance on k3s ServiceLB or MetalLB
- **Predictable port allocation**: Always 80/443, never random NodePort range
- **Lowest latency**: No kube-proxy iptables overhead for ingress traffic
- **SuperPod ready**: DaemonSet automatically scales to all worker nodes

### Negative [!]
- **Single point of failure**: In MAV (single-node), if node fails, ingress unavailable
  - *Mitigation*: Acceptable for development phase; multi-node HA planned for Phase 3
- **Port conflict risk**: hostPort requires exclusive access to 80/443 on host
  - *Mitigation*: Documented in installation prerequisites

## Implementation Checklist
- [o] Update `values.yaml` with corrected structure
- [o] Validate hostPort binding with `ss -tlnp | grep :443`
- [o] Test external HTTPS access from remote client
- [ ] Update README.md with networking prerequisites
- [ ] Add Zabbix monitoring for port binding status
- [o] Document rollback procedure in runbooks

## Migration Path (Future)
When transitioning from MAV to multi-node SuperPod:

```yaml
# Phase 3: Production SuperPod Configuration
service:
  type: LoadBalancer  # MetalLB or cloud provider LB
  annotations:
    metallb.universe.tf/address-pool: ingress-pool

deployment:
  kind: DaemonSet  # Keep DaemonSet for node-level HA
  
ports:
  web:
    hostPort: null   # Remove hostPort when using external LB
  websecure:
    hostPort: null
```

## References
- Incident Report: `AICC-2026-0203-001`
- Kubernetes Documentation: [hostPort Networking](https://kubernetes.io/docs/concepts/configuration/overview/#services)
- Original ADR-014: `docs/design-decisions/ADR-014-traefik-networking-correction.md`

