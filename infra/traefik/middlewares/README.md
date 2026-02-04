# Global Middleware Layer

## Purpose
Platform-wide middleware applied to all or most services.

## Components

### security-headers.yaml
HTTP security headers enforcement:
- X-Frame-Options: SAMEORIGIN
- X-Content-Type-Options: nosniff
- Strict-Transport-Security (HSTS): 1 year
- X-XSS-Protection: enabled

**Applied to**: All public-facing services

### rate-limit.yaml
DDoS protection and abuse prevention:
- Average: 100 requests/second
- Burst: 200 requests
- Period: 1 minute

**Applied to**: Dashboard, public APIs

### compression.yaml (TODO)
Response compression for bandwidth optimization:
- Gzip compression
- Minimum response size: 1KB
- Excluded MIME types: images, videos

## Usage
Referenced in IngressRoute specs:
```yaml
middlewares:
  - name: security-headers
    namespace: traefik-system
  - name: rate-limit
    namespace: traefik-system
```

---

**Part of**: AI Computing Center MLOps Platform
**Managed by**: Range
**Last Updated**: 2026-02-04

