# ADR-011: Traefik Network Ingress Strategy

**Status**: Accepted  
**Date**: 2026-01-22  
**Decision Makers**: Platform Engineering Team  
**Technical Story**: Select optimal network ingress mode for bare-metal single-node MAV and future SuperPod deployment

## Context

Kubernetes offers multiple service exposure methods:
1. **LoadBalancer**: Provisions external load balancer (cloud provider)
2. **NodePort**: Exposes service on node IP with high port (30000-32767)
3. **ClusterIP + HostPort**: Binds container port directly to host port
4. **hostNetwork: true**: Container uses host network namespace

Our requirements:
- **MAV Phase**: Bare-metal single node, no external LB
- **Standard Ports**: HTTP (80) and HTTPS (443) without port suffixes
- **Security**: Network namespace isolation
- **SuperPod Phase**: Multi-node with potential hardware LB integration

## Decision

Use **ClusterIP Service + HostPort binding** for Traefik ingress.

```yaml
service:
  type: ClusterIP

ports:
  web:
    hostPort: 80
  websecure:
    hostPort: 443

hostNetwork: false
```

## Rationale

### Service Type Comparison

| Mode | MAV Suitability | Port | Isolation | SuperPod Migration |
|------|-----------------|------|-----------|-------------------|
| **LoadBalancer** | [x] No (requires cloud LB) | 80/443 | [o] Yes | [!] Vendor lock-in |
| **NodePort** | [!] Possible | 30000+ | [o] Yes | [o] Works but non-standard |
| **ClusterIP + HostPort** | [o] **Optimal** | 80/443 | [o] Yes | [o] Transparent upgrade |
| **hostNetwork: true** | [!] Works | 80/443 | [x] No | [x] Security risk |

### Why Not LoadBalancer?

**Problem**: Requires external load balancer provisioning

```yaml
service:
  type: LoadBalancer
```

**Result on bare-metal**:
```
NAME      TYPE           EXTERNAL-IP   PORT(S)
traefik   LoadBalancer   <pending>     80:32145/TCP,443:31567/TCP
```

- EXTERNAL-IP stays `<pending>` forever
- Falls back to NodePort (random high ports)
- Requires MetalLB or similar (additional complexity)

### Why Not NodePort?

**Configuration**:
```yaml
service:
  type: NodePort
```

**Result**:
```
Access: http://192.168.1.100:31234
       https://192.168.1.100:32456
```

**Drawbacks**:
- Non-standard ports (31234, 32456)
- Requires firewall rules for random port range
- Poor user experience (URLs with ports)
- Certificate CN/SAN mismatch with ports

### Why Not hostNetwork?

**Configuration**:
```yaml
hostNetwork: true
```

**Benefits**:
- Direct host port binding (80/443)
- Minimal latency

**Critical Risks**:
[x] **No network namespace isolation** (security violation)  
[x] **Pod sees all host network traffic** (compliance issue)  
[x] **DNS resolution uses host /etc/resolv.conf** (breaks Kubernetes DNS)  
[x] **Port conflicts** with other host services  
[x] **Violates pod security standards**  

### HostPort Advantages

**Network Flow**:
```
External Client (Internet)
    ↓
Host NIC (eth0) :80/:443
    ↓ [iptables DNAT]
Pod Network :8000/:8443
    ↓ [Container Network]
Traefik Process
    ↓ [Service Discovery]
Backend Pods
```

**Security Boundaries**:
```
┌─────────────────────────────────────┐
│  Host Network Namespace             │
│  ├─ eth0: 192.168.1.100            │
│  ├─ iptables: 80→10.42.0.5:8000    │
│  └─ iptables: 443→10.42.0.5:8443   │
└───────────────┬─────────────────────┘
                │ (namespace boundary)
┌───────────────▼─────────────────────┐
│  Pod Network Namespace              │
│  ├─ eth0: 10.42.0.5                │
│  ├─ Traefik: 8000, 8443            │
│  └─ Isolated from host processes   │
└─────────────────────────────────────┘
```

## Configuration Details

### Service Definition

```yaml
service:
  enabled: true
  type: ClusterIP       # Internal cluster service only
  single: true          # Single Service for TCP (not UDP split)
```

**Result**:
```
NAME      TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)
traefik   ClusterIP   10.43.55.10   <none>        80/TCP,443/TCP
```

### Port Mapping

```yaml
ports:
  web:
    port: 8000          # Container listening port
    hostPort: 80        # Host binding port
    exposedPort: 80     # Service exposed port
  websecure:
    port: 8443
    hostPort: 443
    exposedPort: 443
```

**Traffic Path**:
```
curl http://node-ip:80
  → Host :80 (iptables)
    → Pod IP:8000 (container)
      → Traefik process
```

## Security Analysis

### Network Isolation

[o] **Pod Network Namespace**: Separate from host  
[o] **Capability Drop**: ALL capabilities dropped except NET_BIND_SERVICE  
[o] **Read-only Filesystem**: Container filesystem is immutable  
[o] **Non-root User**: Runs as UID 65532  

### Attack Surface

| Mode | Exposed to Pod | Risk Level |
|------|---------------|------------|
| hostNetwork | All host traffic | [H] Critical |
| HostPort | Only forwarded traffic | [L] Low |

### PodSecurity Compliance

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: traefik-system
  labels:
    pod-security.kubernetes.io/enforce: restricted
```

**HostPort is allowed under `restricted` policy**  
**hostNetwork would require `privileged` policy** [x]

## SuperPod Migration Path

### Current (MAV): Single Node

```
Node: llm1
  ├─ Traefik Pod (DaemonSet)
  │   └─ HostPort 80/443
  └─ Access: http://llm1-ip:80
```

### Future (SuperPod): Multi-Node

**Option A: Continue HostPort (Recommended)**
```
Load Balancer (Hardware/HAProxy)
  ├─ Backend: node-1:80
  ├─ Backend: node-2:80
  └─ Backend: node-N:80

Each node has DaemonSet pod with HostPort
```

**Option B: Upgrade to LoadBalancer Service**
```
service:
  type: LoadBalancer

Deploy: MetalLB or cloud provider LB
```

**Decision**: Start with HostPort, migrate to LB only if needed.

## Port Conflict Prevention

### Pre-flight Check

```bash
# Verify ports 80/443 are available
sudo netstat -tulpn | grep -E ':80 |:443 '

# Expected: No output (ports free)
```

### Conflict Resolution

```bash
# If Apache/Nginx running on port 80
sudo systemctl stop apache2
sudo systemctl disable apache2

# If other service on port 443
sudo lsof -i :443
# Kill or reconfigure conflicting service
```

### k3s Built-in Traefik

Already disabled via `--disable traefik` (verified in Step 2.1).

## Validation Criteria

[o] External access: `curl http://<node-ip>:80` returns Traefik 404  
[o] HTTPS access: `curl -k https://<node-ip>:443` returns Traefik response  
[o] No hostNetwork: `kubectl get pod -n traefik-system -o yaml | grep hostNetwork` shows `false`  
[o] Namespace isolation: Traefik cannot access host /etc/hosts  
[o] Pod restart: Port rebinds automatically within 10 seconds  

## Alternatives Considered

### Alternative 1: MetalLB + LoadBalancer

**Pros**: Standard Kubernetes pattern  
**Cons**: Additional component, complexity, single-node doesn't benefit  
**Verdict**: Overkill for MAV, consider for SuperPod Phase 2

### Alternative 2: Ingress NodePort

**Pros**: No HostPort needed  
**Cons**: Non-standard ports (30000+), poor UX  
**Verdict**: Rejected due to usability issues

### Alternative 3: External HAProxy

**Pros**: Enterprise-grade LB, centralized config  
**Cons**: Additional infrastructure, external to k8s  
**Verdict**: Valid for SuperPod, not for MAV

## Implementation

### Current Configuration

```yaml
# infra/traefik/base/helm/values.yaml
service:
  type: ClusterIP
  
ports:
  web:
    hostPort: 80
  websecure:
    hostPort: 443
    
hostNetwork: false
```

### Verification Commands

```bash
# Check service type
kubectl get svc -n traefik-system traefik -o jsonpath='{.spec.type}'
# Expected: ClusterIP

# Check host port binding
sudo netstat -tulpn | grep traefik
# Expected: traefik listening on :80 and :443

# Test external access
curl -v http://$(hostname -I | awk '{print $1}'):80
# Expected: Traefik 404 page
```

## References

- Kubernetes Services: https://kubernetes.io/docs/concepts/services-networking/service/
- HostPort vs hostNetwork: https://kubernetes.io/docs/concepts/security/pod-security-standards/
- Traefik Ports Configuration: https://doc.traefik.io/traefik/routing/entrypoints/
- Related ADRs: ADR-009, ADR-010

## Supersedes

N/A

## Superseded By

N/A

