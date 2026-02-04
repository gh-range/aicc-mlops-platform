# Service-Specific Middleware Layer

## Purpose
Middleware that is ONLY applicable to a specific service.

## Directory Structure
services/
├── traefik-dashboard/ # Dashboard-only middleware
├── ollama/ # Ollama-specific timeouts
└── jupyterhub/ # OAuth forward auth

## Guidelines
- **DO**: Place authentication, custom timeouts, service-specific redirects here
- **DON'T**: Place global security policies (those belong in `/middlewares/`)

## Examples
- `traefik-dashboard/dashboard-auth.yaml`: BasicAuth for dashboard
- `ollama/timeout-extended.yaml`: 5-minute timeout for LLM inference
- `jupyterhub/oauth-forward-auth.yaml`: GitHub OAuth integration

---

**Part of**: AI Computing Center MLOps Platform
**Managed by**: Range
**Last Updated**: 2026-02-04

