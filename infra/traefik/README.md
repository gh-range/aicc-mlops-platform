# Traefik Ingress Controller Infrastructure

**Chart Version**: 38.0.2  
**App Version**: v3.6.7
**Deployment Mode**: DaemonSet with HostPort  
**Namespace**: traefik-system

## Directory Structure

```
traefik/
├── base/                          # Base Helm deployment
│   ├── helm/
│   │   ├── values.yaml           # Production values
│   │   └── values-override.yaml  # Environment-specific overrides
│   └── manifests/                # Additional K8s resources
│       ├── priority-class.yaml
│       └── pod-disruption-budget.yaml
├── overlays/                      # Environment-specific patches
│   ├── dev/
│   ├── staging/
│   └── production/
├── configs/                       # Traefik CRD configurations
│   ├── middlewares/              # Middleware definitions
│   │   ├── security-headers.yaml
│   │   ├── rate-limit.yaml
│   │   └── basic-auth.yaml
│   └── tls-options/              # TLS configuration
│       └── modern-tls.yaml
└── certs/                         # Certificate management
    └── cluster-issuers/
        ├── letsencrypt-staging.yaml
        └── letsencrypt-prod.yaml
```

## Deployment Workflow

### Initial Installation
```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update

helm install traefik traefik/traefik \
  --namespace traefik-system \
  --version 38.0.2 \
  -f base/helm/values.yaml
```

### Upgrade
```bash
helm upgrade traefik traefik/traefik \
  --namespace traefik-system \
  --version 38.0.2 \
  -f base/helm/values.yaml \
  --reuse-values
```

## Key Design Decisions

| Decision | Rationale | ADR Reference |
|----------|-----------|---------------|
| DaemonSet deployment | Ensure ingress on every node for HA | ADR-009 |
| HostPort 80/443 | Direct host network access without LoadBalancer | ADR-009 |
| Dedicated namespace | Isolation and RBAC granularity | ADR-001 |
| Helm management | Lifecycle automation and version control | ADR-009 |

## Integration Points

- **cert-manager**: Automatic TLS certificate provisioning
- **Prometheus**: Metrics export on port 9100
- **ArgoCD**: GitOps-based deployment automation
- **NetworkPolicy**: Zero-trust ingress traffic control

## Maintenance

- **Certificate Rotation**: Automated via cert-manager
- **Version Upgrades**: Quarterly review cycle
- **Backup**: Helm values stored in Git
- **Disaster Recovery**: Velero namespace backup

## References

- Traefik Documentation: https://doc.traefik.io/traefik/
- Helm Chart: https://github.com/traefik/traefik-helm-chart
- Related ADRs: ADR-001, ADR-009

---

**Part of**: AI Computing Center MLOps Platform  
**Managed by**: Range  
**Last Updated**: 2026-01-28
