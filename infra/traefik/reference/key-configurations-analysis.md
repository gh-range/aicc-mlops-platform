# Traefik 38.0.2 Key Configuration Analysis

**Analysis Date**: 2026-01-22  
**File**: values-default-38.0.2.yaml  
**Total Lines**: 1300+

## Category 1: Deployment Architecture

### Default Configuration
```yaml
deployment:
  enabled: true
  kind: Deployment      # ← Change to DaemonSet
  replicas: 1           # ← Not applicable for DaemonSet
```

### Production Requirements
| Aspect | Default | MAV Node | SuperPod (Future) |
|--------|---------|----------|-------------------|
| Deployment Type | Deployment | **DaemonSet** | DaemonSet |
| Replicas | 1 | N/A (per node) | N/A (per node) |
| High Availability | [x] No | [o] Yes (node-level) | [o] Yes (multi-node) |

**Decision**: Use **DaemonSet** to ensure Ingress capability on every node.

**Rationale**:
- Single-node MAV: Ensure Ingress survives node restarts
- Future SuperPod: Ingress on all worker nodes for traffic distribution
- Eliminates single point of failure

---

## Category 2: Network Exposure

### Default Configuration
```yaml
service:
  enabled: true
  type: LoadBalancer    # ← Change to ClusterIP
  single: true          # ← Keep true for simplicity

hostNetwork: false      # ← Change to false (use HostPort instead)

ports:
  web:
    port: 8000          # Container internal port
    exposedPort: 80     # External port
    hostPort: null      # <- Set to 80
  websecure:
    port: 8443
    exposedPort: 443
    hostPort: null      # <- Set to 443
```

### Production Requirements

#### Service Type Decision Matrix

| Service Type | Use Case | MAV Suitability | Complexity |
|--------------|----------|-----------------|------------|
| LoadBalancer | Cloud environments with LB support | [x] No (single-node, no external LB) | Low |
| NodePort | External access via node IP:port | [!] Possible (but port range 30000-32767) | Medium |
| ClusterIP + HostPort | Direct host binding (80/443) | [o] **Optimal** | Low |
| hostNetwork: true | Full host network namespace | [!] Risky (port conflicts) | High |

**Decision**: **ClusterIP + HostPort** mode

**Configuration**:
```yaml
service:
  type: ClusterIP

ports:
  web:
    hostPort: 80
  websecure:
    hostPort: 443

hostNetwork: false  # Keep false for namespace isolation
```

---

## Category 3: Resource Management

### Default Configuration
```yaml
resources: {}  # <- Must set explicit limits
```

### Production Requirements

**Single-Node MAV Node**:
```yaml
resources:
  requests:
    cpu: "500m"
    memory: 1G
  limits:
    cpu: "2"
    memory: 4G
```

**Rationale**:
- CPU: 500m baseline, burst to 2 cores for traffic spikes
- Memory: 1G steady state, 4G limit for connection pools
- Prevents resource starvation of GPU workloads

**SuperPod Scaling** (Future):
- requests.cpu: 1 core per node (higher baseline)
- limits.memory: 8G for 10Gbps+ traffic

---

## Category 4: TLS & Certificate Management

### Default Configuration
```yaml
ports:
  websecure:
    tls:
      enabled: true     # <- Keep enabled
      options: ""       # <- Leave empty for cert-manager

additionalArguments: []
```

### Production Requirements

**TLS Mode**: **Passthrough** (delegate to cert-manager)

**Configuration**:
```yaml
ports:
  websecure:
    tls:
      enabled: true
      # No certificate defined here - handled by cert-manager

additionalArguments:
  - "--providers.kubernetesingress.allowEmptyServices=true"
  - "--serversTransport.insecureSkipVerify=false"
```

**Rationale**:
- cert-manager handles certificate lifecycle (ACME)
- Traefik only routes TLS traffic to backend services
- Simplifies certificate rotation

---

## Category 5: Observability & Monitoring

### Default Configuration
```yaml
metrics:
  prometheus:
    enabled: false      # <- Enable for Zabbix integration

logs:
  general:
    level: INFO         # <- Keep INFO
  access:
    enabled: false      # <- Enable for audit

experimental:
  plugins: {}
  kubernetesGateway:
    enabled: false      # <- Keep false for now
```

### Production Requirements

```yaml
metrics:
  prometheus:
    enabled: true
    entryPoint: metrics
    addEntryPointsLabels: true
    addRoutersLabels: true
    addServicesLabels: true

logs:
  general:
    level: INFO
    format: json        # Structured logging
  access:
    enabled: true
    format: json
    fields:
      defaultMode: keep
      headers:
        defaultMode: drop  # Privacy compliance
```

**Integration Points**:
- Prometheus endpoint: `http://traefik:9100/metrics`
- Zabbix NVIDIA sensors: Co-locate metrics collection
- Access logs: Export to centralized logging (future ELK stack)

---

## Category 6: Security Hardening

### Default Configuration
```yaml
securityContext:
  capabilities:
    drop: [ALL]
    add: [NET_BIND_SERVICE]  # Required for port 80/443
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 65532

podSecurityContext:
  fsGroup: 65532

ingressRoute:
  dashboard:
    enabled: false      # <- Enable with auth
```

### Production Requirements

**Keep default security context** (already hardened)

**Dashboard Access Control**:
```yaml
ingressRoute:
  dashboard:
    enabled: true
    matchRule: "Host(`traefik.aicc.yourdomain.com`) && (PathPrefix(`/dashboard`) || PathPrefix(`/api`))"
    entryPoints: ["websecure"]
    middlewares:
      - name: dashboard-auth
        namespace: traefik-system
    tls: {}  # cert-manager will provide certificate
```

**Create BasicAuth Middleware** (separate manifest):
```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: dashboard-auth
  namespace: traefik-system
spec:
  basicAuth:
    secret: traefik-dashboard-auth
```

---

## Category 7: High Availability Features

### Default Configuration
```yaml
podDisruptionBudget:
  enabled: false        # ← Enable for production

affinity: {}            # ← Not needed for single-node

tolerations: []         # ← Add GPU node tolerations if needed

priorityClassName: ""   # ← Set to system-cluster-critical
```

### Production Requirements

**Single-Node MAV**:
```yaml
podDisruptionBudget:
  enabled: true
  minAvailable: 1       # Ensure at least 1 pod always running

priorityClassName: "system-cluster-critical"

tolerations:
  - effect: NoSchedule
    key: node-role.kubernetes.io/control-plane
    operator: Exists
```

**SuperPod (Future)**:
```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          topologyKey: kubernetes.io/hostname
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: traefik
```

---

## Configuration Decision Summary

| Category | Default | MAV Production | Priority |
|----------|---------|----------------|----------|
| Deployment Kind | Deployment | **DaemonSet** | [H] Critical |
| Service Type | LoadBalancer | **ClusterIP + HostPort** | [H] Critical |
| Resource Limits | Unset | **cpu:2, mem:4G** | [H] Critical |
| HostPort 80/443 | null | **Enabled** | [H] Critical |
| Prometheus Metrics | Disabled | **Enabled** | [M] High |
| Access Logs | Disabled | **Enabled (JSON)** | [M] High |
| Dashboard Auth | None | **BasicAuth** | [M] High |
| TLS Mode | Terminated | **Passthrough** | [L] Medium |
| PodDisruptionBudget | Disabled | **Enabled** | [L] Medium |
| PriorityClass | None | **system-cluster-critical** | [L] Medium |

---

## Lines of Code Reduction

| Component | Default Lines | Production Lines | Reduction |
|-----------|---------------|------------------|-----------|
| Full values.yaml | 1300+ | ~150 | 88% |
| Core deployment | - | ~60 | - |
| Security & observability | - | ~40 | - |
| Network & TLS | - | ~30 | - |
| Metadata & labels | - | ~20 | - |

**Approach**: Only override necessary values, inherit sensible defaults.

---

## Next Steps

Design production-grade values.yaml based on this analysis.

Key files to create:
1. `base/helm/values.yaml` - Core production configuration
2. `configs/middlewares/dashboard-auth.yaml` - Dashboard security
3. `base/manifests/priority-class.yaml` - Critical workload designation

