# JupyterHub Routing Validation Report

**Date**: 2026-02-05

**Phase**: JupyterHub Integration

## Configuration

### DNS Mode
- **Cloudflare Proxy**: Disabled (Gray Cloud)
- **Direct Connection**: Yes
- **Reason**: WebSocket stability for long-running Notebooks

### IngressRoute
- **Namespace**: traefik-system (Centralized management)
- **Host**: jupyter.mlops.work
- **Backend Service**: jupyterhub/proxy-public:80
- **TLS Secret**: mlops-work-wildcard-tls
- **Middleware**: security-headers only (no rate-limit)

## Test Results

### TLS Certificate
```
issuer=C = US, O = Let's Encrypt, CN = R13
notBefore=Jan 30 18:41:41 2026 GMT
notAfter=Apr 30 18:41:40 2026 GMT
```

### HTTP Response
```
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0  6040    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
HTTP/2 405
access-control-allow-headers: accept, content-type, authorization
content-security-policy: frame-ancestors 'none'; report-uri /hub/security/csp-report
content-type: text/html
date: Thu, 05 Feb 2026 06:47:46 GMT
server: TornadoServer/6.5.3
set-cookie: _xsrf=MnwxOjB8MTA6MTc3MDI3NDA2Nnw1Ol94c3JmfDY4OlRtOXVaVHBtVldSRlEweFJjM051UnpsdWMyWnNWRFJmWDB0eWJGTm1kbmd5Y3pRMU5FRlhlakZtVTFJeVFqWk5QUT09fDczMGU5MzIzZmRhYzU1ZGY1OGMxODdlMDE2OWMxOWY5MzVhMzBkNGFlYTY3ZTgyYzhmN2Q4NWRlMTBmNjgyODE; Max-Age=3600; Path=/hub/
```

### IngressRoute Status
```
spec:
  entryPoints:
  - websecure
  routes:
  - kind: Rule
    match: Host(`jupyter.mlops.work`)
    middlewares:
    - name: security-headers
      namespace: traefik-system
    services:
    - name: proxy-public
      namespace: jupyterhub
      port: 80
  tls:
    options:
      name: enterprise-tls-policy
```
