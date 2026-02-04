# Certificate Inventory

## Architecture Overview

### Cloudflare Proxy + Let's Encrypt Origin
External Users
↓ HTTPS (Cloudflare Universal SSL)
↓ Issuer: Google Trust Services (WE1)
Cloudflare Proxy (Orange Cloud)
↓ HTTPS (Origin Certificate)
↓ Issuer: Let's Encrypt (R13) [o]
mlops.work Origin Server
↓ Backend Services

**Key Points:**
- **External View**: Users see Cloudflare's Universal SSL (Google Trust Services)
- **Origin Server**: Uses Let's Encrypt wildcard certificate
- **Security**: End-to-end encryption maintained (Full/Strict SSL mode)

---

## Active Certificates

### mlops-work-wildcard-tls (Origin Certificate)
- **Type**: Wildcard TLS Certificate
- **Subject**: CN = *.mlops.work
- **SAN**: DNS:*.mlops.work, DNS:mlops.work
- **Issuer**: Let's Encrypt (R13)
- **Managed By**: cert-manager with Let's Encrypt ACME
- **Valid From**: 2026-01-30 18:41:41 GMT
- **Valid Until**: 2026-04-30 18:41:40 GMT (90 days)
- **Key Algorithm**: RSA 2048-bit
- **Namespace**: traefik-system
- **Secret Name**: mlops-work-wildcard-tls

### Cloudflare Universal SSL (Edge Certificate)
- **Issuer**: Google Trust Services (WE1)
- **Subject**: CN = mlops.work
- **Managed By**: Cloudflare (Automatic)
- **Purpose**: Client-to-Cloudflare encryption
- **Note**: Not stored in Kubernetes, managed by Cloudflare

## Certificate Renewal Strategy
- **Automation**: cert-manager with ACME DNS-01 challenge
- **Renewal Window**: 30 days before expiration
- **Alert Threshold**: 14 days before expiration (Zabbix monitoring)
- **Backup**: Automatic Secret backup via Velero

### Cloudflare Edge Certificate
- **Automation**: Managed by Cloudflare
- **Renewal**: Automatic, no action required
- **Validity**: Typically 1 year (auto-renewed)

## Verification Commands

### Check Origin Certificate (from server)
```bash
echo | openssl s_client -connect localhost:443 -servername traefik.mlops.work 2>/dev/null \
  | openssl x509 -noout -issuer -dates
```
# Expected: issuer=C = US, O = Let's Encrypt, CN = R13

### Check Edge Certificate (from external)

```bash
echo | openssl s_client -connect traefik.mlops.work:443 -servername traefik.mlops.work 2>/dev/null \
  | openssl x509 -noout -issuer -dates
```
# Expected: issuer=C = US, O = Google Trust Services, CN = WE1

## Security Notes
- Origin uses Let's Encrypt (Industry standard, automatic renewal)
- Cloudflare SSL Mode: Full (Strict) - validates origin certificate
- No self-signed certificates - all certificates are publicly trusted
- End-to-end encryption - TLS termination at origin, not at proxy
- NO Traefik certResolver (cert-manager handles all certificates)

## Usage Mapping
| Service | IngressRoute | Origin Certificate | Edge Certificate |
|---------|--------------|-------------------|------------------|
| Traefik Dashboard | traefik-dashboard | Let's Encrypt R13 | Google Trust Services |
| Ollama API | ollama-inference-api | Let's Encrypt R13 | Google Trust Services |
| JupyterHub | jupyterhub-https | Let's Encrypt R13 | Google Trust Services |

All services share the same wildcard certificate: mlops-work-wildcard-tls

---

**Part of**: AI Computing Center MLOps Platform
**Managed by**: Range
**Last Updated**: 2026-02-04

