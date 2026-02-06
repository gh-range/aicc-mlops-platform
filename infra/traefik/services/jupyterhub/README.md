# JupyterHub Middleware
This directory contains the JupyterHub-specific Traefik middleware configuration.

## Middleware List
| Middleware | Purpose | Corresponding Issues |
|------------|------|---------|
| `jupyterhub-websocket` | WebSocket header upgrade | Notebook kernel connection failure |
| `jupyterhub-buffering` | Large file/Token handling | OAuth token too large, Notebook upload failure |

## Router Configuration
The actual IngressRoute is defined in `routers/jupyter.yaml`, which references the middleware in this directory.

## Middleware Application Order
```yaml
middlewares:
1. jupyterhub-websocket # Ensure WebSocket headers are correct
2. jupyterhub-buffering # Handle large requests/responses
3. security-headers # Global security headers
4. rate-limit # Global rate limit
```

## Testing WebSocket
```bash
# 1. Deploy middleware
kubectl apply -f services/jupyterhub/
# 2. Check middleware
kubectl get middleware -n traefik-system | grep jupyterhub
# 3. Verify IngressRoute reference
kubectl describe ingressroute -n traefik-system jupyterhub-https
```

## Session Affinity
Session affinity (sticky session) is configured in the `service` section of `routers/jupyter.yaml` using the cookie `JUPYTERHUB_SESSION`.

## Troubleshooting

### WebSocket connection failed
```bash
# Check if middleware is applied correctly
kubectl get ingressroute -n traefik-system jupyterhub-https -o yaml | grep middlewares -A 10
```

### Large file upload failed (Error 413)
```bash
# Check buffering settings
kubectl describe middleware -n traefik-system jupyterhub-buffering
```

---

**Part of**: AI Computing Center MLOps Platform
**Managed by**: Range
**Last Updated**: 2026-02-06

