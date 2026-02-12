# ADR-015: CAA Record Security Strategy

## Status
Accepted

## Date
2026-02-12

## Context

### Discovery
Through certificate inspection and CAA testing tools, we discovered that **Cloudflare Universal SSL uses multiple Certificate Authorities** for redundancy and load balancing.

**Evidence**:
```bash
# Cloudflare Proxied service (ollama.mlops.work)
openssl s_client -connect ollama.mlops.work:443 2>/dev/null | openssl x509 -noout -issuer
# Result: Google Trust Services (WE1)

# DNS Only service (jupyter.mlops.work)
openssl s_client -connect jupyter.mlops.work:443 2>/dev/null | openssl x509 -noout -issuer
# Result: Let's Encrypt (R13)
```

**Verification**: https://caatest.co.uk/ confirmed Cloudflare uses 4 backup CAs.

---

## Architecture

### Dual Certificate Model

```
┌─────────────────────────────────────────────────┐
│              External Traffic                   │
└──────────┬──────────────────┬───────────────────┘
           │                  │
    ┌──────▼────────┐    ┌─────▼──────────┐
    │  Proxied      │    │   DNS Only     │
    │ (Orange cloud)│    │ (Grey cloud)   │
    └──────┬────────┘    └─────┬──────────┘
           │                   │
    ┌──────▼───────────────────▼─────────┐
    │   Cloudflare Edge (4 CAs)          │
    │   - Google Trust Services (main)   │
    │   - DigiCert (backup)              │
    │   - Sectigo/Comodo (baccup)        │
    │   - SSL.com (backup)               │
    └──────┬─────────────────────────────┘
           │
    ┌──────▼─────────────────────────────┐
    │   Traefik Origin Server            │
    │   - Let's Encrypt (*.mlops.work)   │
    └────────────────────────────────────┘
```

---

## Decision

### Authorize 5 Certificate Authorities

**CAA Records Configured** (10 total):

| CA | Purpose | Records |
|----|---------|---------|
| **Let's Encrypt** | Origin Server (Traefik) | issue + issuewild |
| **Google Trust Services** | Cloudflare primary | issue + issuewild |
| **DigiCert** | Cloudflare backup | issue + issuewild |
| **Sectigo/Comodo** | Cloudflare backup | issue + issuewild |
| **SSL.com** | Cloudflare backup | issue + issuewild |

**DNS Configuration**:
```dns
mlops.work. CAA 0 issue "letsencrypt.org"
mlops.work. CAA 0 issuewild "letsencrypt.org"
mlops.work. CAA 0 issue "pki.goog"
mlops.work. CAA 0 issuewild "pki.goog"
mlops.work. CAA 0 issue "digicert.com"
mlops.work. CAA 0 issuewild "digicert.com"
mlops.work. CAA 0 issue "comodoca.com"
mlops.work. CAA 0 issuewild "comodoca.com"
mlops.work. CAA 0 issue "ssl.com"
mlops.work. CAA 0 issuewild "ssl.com"
```

---

## Rationale

### Why Multiple CAs?

1. **Cloudflare Redundancy**: Cloudflare rotates between CAs for:
   - Load balancing certificate issuance
   - Geographic optimization
   - Failover protection

2. **Dual Architecture**: Support both:
   - **Proxied services**: Use Cloudflare certificates
   - **DNS Only services**: Use Let's Encrypt directly

3. **Security**: CAA prevents unauthorized certificate issuance while maintaining operational flexibility.

---

## Consequences

### Positive

- [o] **Security**: Only authorized CAs can issue certificates for mlops.work
- [o] **Flexibility**: Supports Cloudflare CA rotation without manual intervention
- [o] **Compatibility**: Works with both Proxied and DNS Only services
- [o] **Compliance**: Aligns with CA/Browser Forum best practices

### Negative

- [!] **Maintenance**: Must update CAA records if:
  - Switching CDN providers
  - Cloudflare adds/removes CA partners
  - Changing Origin CA from Let's Encrypt

### Neutral

- <!> **HTTP Exchanges**: Some CAs include `cansignhttpexchanges=yes` (not needed for internal platform but harmless)

---

## Validation

### Pre-Deployment Check
```bash
# Verify no existing CAA conflicts
dig mlops.work CAA +short
```

### Post-Deployment Verification
```bash
# Confirm all CAs authorized
dig mlops.work CAA +short | grep -E "letsencrypt|pki.goog|digicert|comodo|ssl.com"

# Online validation
# https://caatest.co.uk/ → mlops.work
# https://letsdebug.net/ → mlops.work
```

### Ongoing Monitoring
```bash
# Quarterly review of Cloudflare CA list
# Check certificate issuer on proxied services
openssl s_client -connect ollama.mlops.work:443 2>/dev/null | openssl x509 -noout -issuer
```

---

## References

### Internal
- [dns-operations.md](../runbooks/dns-operations.md) - CAA record management
- [ADR-013: Automated TLS Governance](./ADR-013-automated-tls-governance-strategy.md)
- [TLS Security Baseline](../security/tls/tls-security-baseline.md)

### External
- [RFC 8659 - DNS CAA Resource Record](https://tools.ietf.org/html/rfc8659)
- [Cloudflare SSL/TLS Documentation](https://developers.cloudflare.com/ssl/)
- [Let's Encrypt CAA](https://letsencrypt.org/docs/caa/)

---

## Migration Path

If switching from Cloudflare in the future:

1. **Before migration**: Identify new CDN's required CAs
2. **Update CAA**: Add new CAs alongside existing
3. **Test**: Verify certificate issuance
4. **Remove old**: Delete unused CA records after 30-day buffer

**Example** (switching to AWS CloudFront):
```bash
# Add AWS CAs
dig mlops.work CAA +short
# Add: amazon.com, amazontrust.com

# Wait 30 days, then remove Cloudflare CAs
```

---

## Approval

**Decision Made**: 2026-02-12  
**Approved By**: Platform Engineering Team  
**Review Cycle**: Quarterly (or when Cloudflare updates CA list)

---

## Changelog

| Date | Version |  Author | Changes |
|------|---------|---------|---------|
| 2026-02-12 | 1.0 | Range | Initial CAA strategy for Cloudflare + Let's Encrypt |

