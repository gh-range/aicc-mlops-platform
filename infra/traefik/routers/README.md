# Router Layer (IngressRoute Definitions)

## Purpose
Centralized routing rules connecting external traffic to backend services.

## Structure
Each file defines ONE IngressRoute for a specific service:
- `traefik-dashboard.yaml`: Traefik Web UI
- `ollama.yaml`: Ollama LLM inference API
- `jupyter.yaml`: JupyterHub web interface
- `redis-ui.yaml`: Redis cluster management UI (future)

## Configuration Standard
All routers MUST:
1. Use `websecure` entrypoint (port 443)
2. Reference `mlops-work-wildcard-tls` secret (NO certResolver)
3. Apply global middlewares first, then service-specific ones
4. Use explicit namespace references for cross-namespace services

## Middleware Execution Order
Request → Global Middlewares → Service Middlewares → Backend
(security, rate-limit) (auth, redirect)

## TLS Policy
All routers inherit `enterprise-tls-policy` from global configuration.

## Deployed Routers

| Router Name | Host | Backend Service | Middleware Chain | Status |
|-------------|------|-----------------|------------------|--------|
| traefik-dashboard | traefik.mlops.work | api@internal | rate-limit → security-headers → dashboard-redirect → dashboard-auth | [O] Active |
| ollama-inference-api | ollama.mlops.work | ollama/ollama-service:11434 | security-headers → timeout-extended | [O] Active (Stub) |

## Cross-Namespace Service Reference
Enabled via Helm values:
```yaml
providers:
  kubernetesCRD:
    allowCrossNamespace: true
This allows IngressRoutes in traefik-system to reference Services in other namespaces (e.g., ollama, jupyterhub).

---

**Part of**: AI Computing Center MLOps Platform
**Managed by**: Range
**Last Updated**: 2026-02-04

