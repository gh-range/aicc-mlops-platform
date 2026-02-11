# HSTS Configuration Guide

## Document Information

**Component**: Traefik Middleware
**Purpose**: HTTP Strict Transport Security (HSTS) Implementation
**Compliance**: RFC 6797, PCI DSS 4.0
**Last Updated**: 2026-02-11

---

## Overview

HSTS (HTTP Strict Transport Security) is a web security policy mechanism that forces clients to use HTTPS connections only, preventing SSL stripping and protocol downgrade attacks.

### Benefits

| Feature | Protection |
|---------|------------|
| **Force HTTPS** | Prevents HTTP connections |
| **SSL Stripping** | Blocks MITM downgrade attacks |
| **Cookie Security** | Protects session tokens |
| **Browser Preload** | Pre-configured HTTPS in browsers |

### Requirements for SSL Labs A+

- `max-age` ≥ 31536000 (1 year)
- `includeSubDomains` recommended
- `preload` optional but recommended

---

## Implementation

### Method 1: Traefik Middleware (Recommended)

**File**: `infra/traefik/middlewares/security-headers.yaml`

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: security-headers
  namespace: traefik-system
spec:
  headers:
    forceSTSHeader: true
    stsIncludeSubdomains: true
    stsPreload: true
    stsSeconds: 31536000
```

### Method 2: Traefik Static Configuration

**File**: `infra/traefik/base/helm/values.yaml`

```yaml
additionalArguments:
  - "--entrypoints.websecure.http.middlewares=traefik-system-security-headers@kubernetescrd"
```

---

## Configuration Parameters

### max-age

**Syntax**: `max-age=<seconds>`

**Recommended Values**:
- **Development**: 300 (5 minutes) - for testing
- **Staging**: 86400 (1 day)
- **Production**: 31536000 (1 year) - SSL Labs A+ requirement

**Example**:
```
Strict-Transport-Security: max-age=31536000
```

### includeSubDomains

**Purpose**: Apply HSTS to all subdomains

**Use Cases**:
- [o] **Use** if all subdomains support HTTPS
- [x] **Avoid** if any subdomain lacks TLS

**Example**:
```
Strict-Transport-Security: max-age=31536000; includeSubDomains
```

### preload

**Purpose**: Eligible for browser HSTS preload list

**Requirements**:
1. `max-age` ≥ 31536000
2. `includeSubDomains` must be present
3. Valid certificate on base domain
4. Manual submission to https://hstspreload.org/

**Example**:
```
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
```

---

## Deployment Steps

### Step 1: Create Middleware

```bash
cd ~/aicc-mlops-platform

cat > infra/traefik/middlewares/security-headers.yaml << 'YAML'
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: security-headers
  namespace: traefik-system
  labels:
    app.kubernetes.io/name: traefik
    app.kubernetes.io/component: middleware
spec:
  headers:
    forceSTSHeader: true
    stsIncludeSubdomains: true
    stsPreload: true
    stsSeconds: 31536000
YAML
```

### Step 2: Apply Middleware to IngressRoutes

```yaml
# Example: infra/traefik/routers/jupyter.yaml
spec:
  routes:
    - match: Host(`jupyter.mlops.work`)
      kind: Rule
      middlewares:
        - name: security-headers
          namespace: traefik-system
      services:
        - name: proxy-public
          namespace: jupyterhub
          port: 80
  tls:
    secretName: mlops-work-wildcard-tls
    options:
      name: enterprise-tls-policy
      namespace: traefik-system
```

### Step 3: Deploy and Verify

```bash
# Deploy middleware
kubectl apply -f infra/traefik/middlewares/security-headers.yaml

# Verify middleware exists
kubectl get middleware -n traefik-system security-headers

# Test HSTS header
curl -I https://jupyter.mlops.work 2>&1 | grep -i strict
```

---

## Verification

### Manual Testing

```bash
# Test HSTS header presence
curl -I https://jupyter.mlops.work 2>&1 | grep -i strict

# Expected output:
strict-transport-security: max-age=31536000; includeSubDomains; preload
```

### Automated Testing

```bash
#!/bin/bash
# Test HSTS configuration

ENDPOINT="jupyter.mlops.work"

echo "Testing HSTS Configuration for $ENDPOINT"

HSTS_HEADER=$(curl -s -I "https://$ENDPOINT" | grep -i "strict-transport-security")

if [ -z "$HSTS_HEADER" ]; then
    echo "[o] FAIL: HSTS header not found"
    exit 1
fi

echo "[o] HSTS Header Found: $HSTS_HEADER"

# Check max-age
if echo "$HSTS_HEADER" | grep -q "max-age=31536000"; then
    echo "[o] max-age=31536000 (1 year) - SSL Labs A+ compliant"
else
    echo "[!] max-age not set to 1 year"
fi

# Check includeSubDomains
if echo "$HSTS_HEADER" | grep -qi "includeSubDomains"; then
    echo "[o] includeSubDomains enabled"
else
    echo "[!] includeSubDomains not enabled"
fi

# Check preload
if echo "$HSTS_HEADER" | grep -qi "preload"; then
    echo "[o] preload directive present"
else
    echo "<!> preload not enabled (optional)"
fi
```

### SSL Labs Validation

1. Visit https://www.ssllabs.com/ssltest/
2. Enter domain: `jupyter.mlops.work`
3. Check "HSTS" section in results
4. Verify grade is **A+**

---

## Browser Preload Submission

### Prerequisites

1. [o] `max-age` ≥ 31536000
2. [o] `includeSubDomains` present
3. [o] Valid HTTPS on base domain (mlops.work)
4. [o] Valid HTTPS on www subdomain (if exists)
5. [o] All HTTP traffic redirects to HTTPS

### Submission Process

1. Test compliance: https://hstspreload.org/
2. Submit domain: mlops.work
3. Wait for inclusion (weeks to months)
4. Monitor status on preload list

### Considerations

[!] **Warning**: Preload is **permanent and difficult to undo**

- Browsers cache HSTS for years
- Removal from list takes months
- Only submit if 100% confident in HTTPS coverage

---

## Troubleshooting

### Issue: HSTS Header Not Appearing

**Symptom**: `curl -I` doesn't show HSTS header

**Solutions**:

1. **Check Middleware Applied**:
```bash
kubectl get middleware -n traefik-system security-headers
kubectl describe middleware -n traefik-system security-headers
```

2. **Check IngressRoute References Middleware**:
```bash
kubectl get ingressroute jupyterhub-https -n traefik-system -o yaml | grep -A 5 middlewares
```

3. **Check Traefik Logs**:
```bash
kubectl logs -n traefik-system -l app.kubernetes.io/name=traefik | grep -i middleware
```

### Issue: Browser Still Allows HTTP

**Symptom**: Browser connects via HTTP despite HSTS

**Cause**: First visit OR max-age expired

**Solution**:
1. Clear browser HSTS cache
   - Chrome: `chrome://net-internals/#hsts`
   - Firefox: `about:config` → `security.cert_pinning.enforcement_level`
2. Visit HTTPS URL first
3. Verify HSTS header present

### Issue: SubDomain HTTP Works

**Symptom**: `includeSubDomains` not protecting subdomains

**Cause**: Browser didn't receive HSTS on parent domain

**Solution**:
1. Visit parent domain via HTTPS first
2. Verify `includeSubDomains` in header
3. Clear browser cache and retry

---

## Rollback Procedure

### Emergency Rollback

If HSTS causes service disruption:

```bash
# Remove HSTS from middleware
kubectl edit middleware security-headers -n traefik-system

# Remove the Strict-Transport-Security line
# OR set max-age=0 (disable HSTS)

# Apply changes
kubectl apply -f infra/traefik/middlewares/security-headers.yaml
```

### Gradual Rollback

```yaml
# Set max-age to 0 to disable HSTS
customResponseHeaders:
  Strict-Transport-Security: "max-age=0"
```

**Note**: Browsers will respect existing cached HSTS until original max-age expires.

---

## Security Considerations

### HSTS Stripping Protection

HSTS prevents:
- [o] SSL Stripping (Moxie Marlinspike attack)
- [o] Protocol downgrade to HTTP
- [o] Man-in-the-Middle via HTTP

### Limitations

HSTS does NOT protect:
- [x] First visit (before HSTS cached) - use preload for this
- [x] Certificate validation (use HPKP for this, if needed)
- [x] DNS hijacking (use DNSSEC)

---

## References

### Standards
- [RFC 6797 - HTTP Strict Transport Security (HSTS)](https://tools.ietf.org/html/rfc6797)
- [OWASP HSTS Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Strict_Transport_Security_Cheat_Sheet.html)

### Tools
- [HSTS Preload List](https://hstspreload.org/)
- [SSL Labs](https://www.ssllabs.com/ssltest/)
- [Security Headers Scanner](https://securityheaders.com/)

### Best Practices
- [Mozilla Web Security Guidelines](https://infosec.mozilla.org/guidelines/web_security)
- [Google Web Fundamentals - HSTS](https://developers.google.com/web/fundamentals/security/encrypt-in-transit/enable-https)

---

## Changelog

| Date | Version | Changes |
|------|---------|---------|
| 2026-02-11 | 1.0 | Initial HSTS configuration guide |

