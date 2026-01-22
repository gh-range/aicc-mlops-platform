# ADR-010: Traefik DaemonSet Deployment Strategy

**Status**: Accepted  
**Date**: 2026-01-22  
**Decision Makers**: Platform Engineering Team  
**Technical Story**: Select optimal Traefik deployment mode for MAV node and SuperPod scalability

## Context

Traefik Helm Chart supports two deployment modes:
1. **Deployment** (default): Fixed replica count with pod scheduling
2. **DaemonSet**: One pod per node with guaranteed node coverage

Our AICC MLOps Platform requires:
- **MAV Phase**: Single-node high availability
- **SuperPod Phase**: Multi-node horizontal scaling
- **Zero-downtime**: Upgrades without service interruption
- **Resource efficiency**: Minimal overhead on GPU workloads

## Decision

Deploy Traefik as **DaemonSet** in all environments (MAV and SuperPod).

## Rationale

### Deployment Mode Comparison

| Criterion | Deployment (3 replicas) | DaemonSet | Winner |
|-----------|-------------------------|-----------|--------|
| **Single-Node HA** | [x] All pods on same node = no HA | [o] Pod restarts guarantee Ingress | DaemonSet |
| **Multi-Node Scaling** | Manual replica adjustment | [o] Auto-scale to all nodes | DaemonSet |
| **Resource Predictability** | Varies by replica count | [o] Fixed per-node overhead | DaemonSet |
| **Upgrade Simplicity** | Rolling update with replicas | [o] Node-by-node update | DaemonSet |
| **Network Locality** | Pods may be remote from workload | [o] Local ingress on every node | DaemonSet |

### Single-Node MAV Environment

**Scenario**: Node restart during maintenance

```
Deployment Mode (3 replicas):
  t=0s: Node restarts
  t=30s: Pods pending (node not ready)
  t=60s: Pods starting
  t=90s: Service restored
  Result: 90s downtime

DaemonSet Mode:
  t=0s: Node restarts
  t=30s: DaemonSet controller detects node ready
  t=45s: Pod scheduled and started
  t=60s: Service restored
  Result: 60s downtime (33% faster recovery)
```

### Multi-Node SuperPod Environment

**Scenario**: Add 10 new GPU nodes to cluster

```
Deployment Mode:
  Action: Manually scale replicas from 3 to 13
  Risk: Forgot to scale = unbalanced load

DaemonSet Mode:
  Action: None (automatic)
  Result: New nodes get Traefik pod automatically
```

## Configuration

### DaemonSet Specification

```yaml
deployment:
  kind: DaemonSet
  
updateStrategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 1  # Update one node at a time

resources:
  requests:
    cpu: "500m"
    memory: 1G
  limits:
    cpu: "2"
    memory: 4G
```

### Why Not Deployment?

**Deployment with 1 replica**:
- [x] Single point of failure
- [x] No redundancy during pod restart

**Deployment with 3 replicas on single node**:
- [x] Wasted resources (3x overhead)
- [x] Port conflicts with HostPort
- [x] No actual HA benefit

## Consequences

### Positive

- **Guaranteed Availability**: Every node has local Ingress capability
- **Simplified Operations**: No manual scaling decisions
- **Predictable Resources**: Fixed per-node CPU/memory allocation
- **Network Efficiency**: Traffic handled by local Traefik pod
- **Future-proof**: Same config works for MAV and SuperPod

### Negative

- **Higher Total Resources**: SuperPod with 50 nodes = 50 Traefik pods
  - Mitigation: 500m CPU per node is acceptable overhead (~2.5% of 20-core node)
- **Update Coordination**: Rolling update affects all nodes sequentially
  - Mitigation: maxUnavailable=1 ensures gradual rollout

### Neutral

- **HostPort Requirement**: Each node binds ports 80/443
  - Not a concern: Dedicated ingress layer design pattern

## Alternatives Considered

### Alternative 1: Deployment with LoadBalancer Service

**Rejected because**:
- Requires external load balancer (not available in bare-metal MAV)
- Adds network hop overhead
- Complex to manage in multi-cluster environment

### Alternative 2: Multiple Deployments (one per node)

**Rejected because**:
- Manual node targeting (node affinity per deployment)
- Operational complexity
- Not scalable to 50+ nodes

### Alternative 3: Single Deployment with Node Selector

**Rejected because**:
- Still requires manual replica management
- No automatic scaling to new nodes
- Same single-node failure issues

## Validation Criteria

[o] Single-node restart: Ingress recovers within 60 seconds  
[o] Add new node: Traefik pod auto-scheduled within 30 seconds  
[o] Rolling update: Zero connection drops during upgrade  
[o] Resource overhead: <5% CPU per node  

## Implementation

### Phase 1: MAV Deployment (Current)
- Deploy DaemonSet with 1 node
- Validate HostPort binding
- Test pod restart recovery

### Phase 2: SuperPod Migration (Future)
- No configuration changes required
- Traefik automatically scales to all nodes
- Verify load distribution across nodes

## References

- Kubernetes DaemonSet: https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/
- Traefik HA Best Practices: https://doc.traefik.io/traefik/getting-started/install-traefik/#use-the-helm-chart
- Related ADRs: ADR-001 (k3s), ADR-009 (Standalone Traefik)

## Supersedes

N/A (Initial deployment mode decision)

## Superseded By

N/A

