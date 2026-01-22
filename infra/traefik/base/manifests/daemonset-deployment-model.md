# Traefik DaemonSet Deployment Model

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    External Traffic                         │
│              HTTP (80) / HTTPS (443)                        │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                   Node: llm1 (MAV)                          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Host Network Interface                              │  │
│  │  Port 80  ──────┐    Port 443  ──────┐              │  │
│  └─────────────────┼───────────────────┼───────────────┘  │
│                    │                   │                   │
│                    ▼                   ▼                   │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  Traefik DaemonSet Pod                              │  │
│  │  ┌──────────────────────────────────────────────┐   │  │
│  │  │  Container: traefik                          │   │  │
│  │  │  ├─ Port 8000 (web) ← HostPort 80           │   │  │
│  │  │  ├─ Port 8443 (websecure) ← HostPort 443    │   │  │
│  │  │  ├─ Port 9000 (dashboard)                   │   │  │
│  │  │  └─ Port 9100 (metrics)                     │   │  │
│  │  └──────────────────────────────────────────────┘   │  │
│  └─────────────────────────────────────────────────────┘  │
│                    │                   │                   │
│                    ▼                   ▼                   │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  Kubernetes Service Discovery                       │  │
│  │  ├─ JupyterHub (jupyterhub namespace)              │  │
│  │  ├─ OpenWebUI (ai-services namespace)              │  │
│  │  └─ ArgoCD (argocd namespace)                      │  │
│  └─────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Resource Allocation Model

### Single-Node (MAV) Configuration

```
Node Resources: 10 cores / 128G RAM / RTX A4000
├─ System Reserved: 1 core / 4G RAM
├─ Kubernetes: 1 core / 4G RAM
├─ Traefik DaemonSet: 0.5 core / 1G RAM (requests)
│   └─ Burst Capacity: 2 cores / 4G RAM (limits)
└─ Available for Workloads: 7.5 cores / 119G RAM
```

**Traefik Overhead**: 5% CPU baseline, 0.8% memory

### Multi-Node (SuperPod) Projection

```
50 Nodes × (0.5 core + 1G RAM) = 25 cores + 50G RAM total
Percentage per 20-core node: 2.5% CPU + 0.8% memory
Acceptable for enterprise infrastructure layer
```

## Pod Lifecycle Management

### Startup Sequence

```
1. DaemonSet Controller detects node ready
   └─ Scheduling Decision: <5 seconds

2. kubelet pulls image (if not cached)
   └─ Image Pull: 10-30 seconds (first time)
   └─ Cached: <2 seconds

3. Container starts
   └─ Traefik binary initialization: 5-10 seconds
   └─ Service discovery sync: 2-5 seconds

4. Readiness probe succeeds
   └─ Health check: /ping endpoint
   └─ Status: Ready for traffic

Total: 15-45 seconds (first deployment)
        5-15 seconds (restart)
```

### Update Strategy

```yaml
updateStrategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 1
```

**Update Flow** (50-node SuperPod):
```
Node 1: Update pod → Wait ready → Next
Node 2: Update pod → Wait ready → Next
...
Node 50: Update pod → Wait ready → Done

Total Time: 50 nodes × 15s = 12.5 minutes
No traffic interruption (other nodes handle traffic)
```

## Failure Scenarios & Recovery

### Scenario 1: Pod Crash

```
Event: Traefik process crashes (OOM, bug, etc.)
Detection: Liveness probe fails after 3 attempts
Action: kubelet restarts container
Recovery Time: 10-15 seconds
Impact: Minimal (HostPort rebinds automatically)
```

### Scenario 2: Node Failure

```
MAV (Single Node):
  Event: Node crashes/restarts
  Impact: Full ingress outage
  Recovery: Node boot + pod start = 2-3 minutes
  Mitigation: Fast node restart, no data loss

SuperPod (Multi Node):
  Event: One node fails
  Impact: Traffic redistributes to other 49 nodes
  Recovery: Automatic (no manual intervention)
  Client Impact: Zero (DNS round-robin or LB)
```

### Scenario 3: Network Port Conflict

```
Problem: Another process binds port 80/443
Detection: Pod CrashLoopBackOff (bind error)
Resolution: 
  1. Check: sudo netstat -tulpn | grep :80
  2. Kill conflicting process or change its port
  3. Pod auto-restarts and succeeds
```

## Scaling Behavior

### Horizontal Scaling (Add Nodes)

```
Action: kubectl label node worker-51 node-role.kubernetes.io/worker=true
Result: DaemonSet automatically schedules pod on worker-51
Time: 30-45 seconds
Config Change: None required
```

### Vertical Scaling (Change Resources)

```yaml
# Edit values.yaml
resources:
  requests:
    cpu: "1"      # Increased from 500m
    memory: 2G    # Increased from 1G
```

```
Action: helm upgrade traefik ...
Result: Rolling update with new resource requests
Impact: Pods rescheduled with new allocations
```

## Performance Characteristics

### Latency Profile

```
P50 (median): 2-5ms (routing decision)
P95: 10-15ms (includes backend lookup)
P99: 50ms (cold cache or slow backend)
```

### Throughput Capacity

```
Single Pod (500m CPU):
  HTTP/1.1: ~5,000 req/s
  HTTP/2: ~8,000 req/s (multiplexing)
  
Burst (2 CPU limit):
  HTTP/1.1: ~15,000 req/s
  HTTP/2: ~25,000 req/s
```

### Connection Limits

```
Max Concurrent Connections: ~10,000 per pod
Memory per Connection: ~100KB
Max Memory (4G limit): 40,000 connections
```

## Monitoring Metrics

### Key Indicators

```
traefik_entrypoint_requests_total
traefik_entrypoint_request_duration_seconds
traefik_entrypoint_open_connections
traefik_backend_requests_total
```

### Alert Thresholds

```
Critical: Pod restart > 3 times/hour
Warning: P95 latency > 100ms
Warning: Memory usage > 80% limit
Info: Request rate > 10,000 req/s
```

## Best Practices

[o] Always set resource requests = production baseline  
[o] Set limits = 2-4x requests for burst capacity  
[o] Enable PodDisruptionBudget for controlled updates  
[o] Monitor metrics for capacity planning  
[o] Test pod restart recovery regularly  

[x] Don't set limits too close to requests (no burst room)  
[x] Don't disable readiness probes (causes traffic loss)  
[x] Don't use hostNetwork (security risk)  
[x] Don't skip update strategy configuration  

## References

- Kubernetes DaemonSet: https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/
- Traefik Performance: https://doc.traefik.io/traefik/operations/performance/
- ADR-010: Traefik DaemonSet Strategy

