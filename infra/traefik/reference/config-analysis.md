# Traefik Helm Chart 38.0.2 Configuration Analysis

**Chart Version**: 38.0.2  
**App Version**: v3.6.6  
**Analysis Date**: 2026-01-22

## Key Configuration Sections

### 1. Deployment Mode
```yaml
# Default: Deployment with 1 replica
deployment:
  enabled: true
  kind: Deployment
  replicas: 1
```

**Decision Point**: Should we use DaemonSet for HA?

### 2. Service Type
```yaml
# Default: LoadBalancer (not suitable for single-node)
service:
  enabled: true
  type: LoadBalancer
```

**Decision Point**: Change to ClusterIP + HostPort for direct host access

### 3. Ports Configuration
```yaml
ports:
  web:
    port: 8000          # Internal container port
    expose:
      default: true
    exposedPort: 80     # External port
  websecure:
    port: 8443
    expose:
      default: true
    exposedPort: 443
  traefik:
    port: 9000          # Dashboard
    expose:
      default: false
```

**Decision Point**: Enable dashboard with authentication

### 4. TLS Configuration
```yaml
# Default: TLS disabled
ports:
  websecure:
    tls:
      enabled: true
      options: ""
```

**Decision Point**: Delegate TLS to cert-manager (Passthrough mode)

### 5. Resource Limits
```yaml
# Default: No limits set
resources: {}
```

**Decision Point**: Must set explicit limits for production

### 6. Metrics & Monitoring
```yaml
metrics:
  prometheus:
    enabled: false
```

**Decision Point**: Enable for Zabbix integration

### 7. Access Logs
```yaml
logs:
  access:
    enabled: false
```

**Decision Point**: Enable for security audit

## Critical Customizations Required

| Category | Default | Production Requirement |
|----------|---------|------------------------|
| Deployment Kind | Deployment | DaemonSet (HA) |
| Service Type | LoadBalancer | ClusterIP + HostPort |
| Resource Limits | Unset | CPU: 2, Memory: 4G |
| Prometheus Metrics | Disabled | Enabled |
| TLS Mode | Terminated | Passthrough (cert-manager) |
| Dashboard Auth | None | BasicAuth + NetworkPolicy |
| Access Logs | Disabled | Enabled (JSON format) |

## Version-Specific Notes

### Changes in v3.6.6
- Enhanced HTTP/3 support
- Improved middleware performance
- Security patches for CVE-2024-XXXX

### Chart 38.0.2 Updates
- Updated CRD versions
- Support for Kubernetes 1.34+
- Helm 3.19+ compatibility

## References

- Default Values: `reference/values-default-38.0.2.yaml`
- Upstream Changelog: https://github.com/traefik/traefik-helm-chart/releases/tag/v38.0.2
- Traefik v3 Migration: https://doc.traefik.io/traefik/migration/v2-to-v3/

## Next Steps

Design production-grade values.yaml based on this analysis.
