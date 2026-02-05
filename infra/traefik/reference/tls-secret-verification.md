# TLS Secret Cross-Namespace Verification Report

## Test Date
2026-02-05

## Architecture Model
IngressRoute (traefik-system) ─┐
IngressRoute (traefik-system) ─┼─> Secret: mlops-work-wildcard-tls (traefik-system)
IngressRoute (traefik-system) ─┘
↓ ↓
Backend Services cert-manager manages
(multiple namespaces) (ACME renewal)

## Verification Results

### Secret Location Check

# traefik-system namespace
mlops-work-wildcard-tls   kubernetes.io/tls   2026-01-30T19:40:12Z

# jupyterhub namespace
Error from server (NotFound): secrets "mlops-work-wildcard-tls" not found

### Services Using This Secret
| Service | IngressRoute Namespace | Backend Namespace | Host |
|---------|----------------------|-------------------|------|
| Traefik Dashboard | traefik-system | traefik-system (api@internal) | traefik.mlops.work |
| Ollama API | traefik-system | ollama | ollama.mlops.work |
| JupyterHub | traefik-system | jupyterhub | jupyter.mlops.work |

### Certificate Details
subject=CN = *.mlops.work
issuer=C = US, O = Let's Encrypt, CN = R13
notBefore=Jan 30 18:41:41 2026 GMT
notAfter=Apr 30 18:41:40 2026 GMT

## Conclusion
- [o] Single Secret in traefik-system namespace
- [o] All IngressRoutes reference the same Secret (no duplication)
- [o] Cross-namespace service references working
- [o] Certificate valid for *.mlops.work (wildcard)
- [o] Managed by cert-manager (automatic renewal)

## Benefits of This Model
1. **Single Source of Truth**: One Secret, managed by one Certificate resource
2. **Simplified Renewal**: cert-manager renews once, all services get new cert
3. **No Secret Synchronization**: No need for Reflector or manual copying
4. **Centralized Visibility**: All TLS config in traefik-system namespace

## Limitations
1. **Namespace Coupling**: All IngressRoutes must be in traefik-system OR allowCrossNamespace must be enabled
2. **RBAC Consideration**: Traefik needs permission to read Secrets in traefik-system
3. **Multi-cluster**: Does not work across Kubernetes clusters (requires alternative strategy)

