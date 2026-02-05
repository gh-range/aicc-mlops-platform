# Traefik IngressRoute Inventory

**Generated**: 2026-02-05

## Summary

- **Total Routers**: 3
- **Namespaces**: 1
- **TLS Certificate**: mlops-work-wildcard-tls (shared)

---

## Router Details

| Router Name | Host | Backend Service | Backend NS | Port | Status | Middlewares |
|-------------|------|-----------------|------------|------|--------|-------------|
| jupyterhub-https | jupyter.mlops.work | proxy-public | jupyterhub | 80 | Ready | security-headers |
| ollama-inference-api | ollama.mlops.work | ollama-service | ollama | 11434 | Ready |  |
| traefik-dashboard | traefik.mlops.work | api@internal | traefik-system |  | Internal | rate-limit,security-headers,dashboard-redirect,dashboard-auth |

---

## TLS Configuration

All routers use the same wildcard certificate:
- **Secret Name**: mlops-work-wildcard-tls
- **Secret Namespace**: traefik-system
- **TLS Options**: enterprise-tls-policy
- **Certificate Issuer**: Let's Encrypt R13
- **Valid For**: *.mlops.work

## Status Legend

- **Ready**: Service exists with active endpoints
- **NoEndpoints**: Service exists but no Pods available
- **ServiceNotFound**: Backend service does not exist
- **Internal**: Traefik internal service (api@internal)

---

**Report Location**: 
- JSON: `router-inventory.json`
- Markdown: `router-inventory.md`

**Regenerate**: 
```bash
./tools/router-scanner.sh
```
