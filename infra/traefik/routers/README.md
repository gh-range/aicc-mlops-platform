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
| jupyterhub-https | jupyter.mlops.work | jupyterhub/proxy-public:80 | security-headers | **No rate-limit** (WebSocket), **Cloudflare Proxy disabled** | [o] Active |

### JupyterHub Special Routing Configuration

**Why no rate-limit?**
- Notebook users may frequently execute code cells
- Rate limiting causes 429 errors, interrupting kernel connections

**Why no Cloudflare Proxy?**
- Requires persistent WebSocket connections (free tier has 100-second timeout)
- Large file uploads (Free tier 100MB limit)
- Direct Origin connection provides more stable experience

**Why only security headers?**
- HSTS: Enforces HTTPS
- X-Frame-Options: Prevents Clickjacking
- Does not impact WebSocket Upgrade

### Testing Notes
```bash
# [x] Incorrect testing method
curl -I https://jupyter.mlops.work  # Returns 405 (expected behavior)

# [o] Correct testing methods
curl https://jupyter.mlops.work/  # Returns HTML
curl https://jupyter.mlops.work/hub/api  # Returns JSON

Translated with DeepL.com (free version)

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
**Last Updated**: 2026-02-05

