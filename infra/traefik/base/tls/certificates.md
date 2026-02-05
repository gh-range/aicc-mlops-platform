# Certificate Inventory

## Architecture Overview

### Cloudflare Proxy + Let's Encrypt Origin
```
External Users
    ↓ HTTPS (TLS 1.3)
    ↓ Edge Certificate: Google Trust Services (WE1)
    ↓ Managed by: Cloudflare Universal SSL
[Cloudflare Proxy - Orange Cloud]
    ↓ HTTPS (Full/Strict Mode)
    ↓ Origin Certificate: Let's Encrypt (R13)
    ↓ Managed by: cert-manager (ACME DNS-01)
[mlops.work Origin Server - llm1]
    ↓ Traefik (Port 443, hostPort binding)
    ↓ IngressRoutes (traefik-system namespace)
[Backend Services]
    ↓ ollama (namespace: ollama)
    ↓ jupyterhub (namespace: jupyterhub)
    ↓ api@internal (Traefik Dashboard)
```

**Key Points:**
- **External Layer**: Cloudflare Universal SSL (automatic, free tier)
- **Origin Layer**: Let's Encrypt wildcard certificate (ACME, 90-day validity)
- **Security Model**: End-to-end encryption (Full/Strict SSL mode in Cloudflare)

**Special Configuration for JupyterHub:**
- Cloudflare Proxy **DISABLED** (Gray Cloud, DNS Only mode)
- Reason: WebSocket stability for long-running Notebook sessions
- Direct connection bypasses 100-second timeout on Cloudflare free tier

---

## Active Certificates

### mlops-work-wildcard-tls (Origin Certificate)
**Certificate Resource:**
- **Name**: `mlops-work-wildcard`
- **Namespace**: `traefik-system`
- **Type**: Wildcard TLS Certificate
- **Managed By**: cert-manager v1.19.2

**Generated Secret:**
- **Secret Name**: `mlops-work-wildcard-tls`
- **Secret Namespace**: `traefik-system`
- **Secret Type**: `kubernetes.io/tls`
- **Owner Reference**: Controlled by Certificate resource (auto-cleanup on deletion)

**Certificate Details:**
- **Subject**: `CN = *.mlops.work`
- **SAN (Subject Alternative Names)**: 
  - `DNS:*.mlops.work`
  - `DNS:mlops.work`
- **Issuer**: Let's Encrypt (R13 intermediate CA)
- **Key Algorithm**: RSA 2048-bit
- **Validity Period**: 90 days
- **Current Valid From**: 2026-01-30 18:41:41 GMT
- **Current Valid Until**: 2026-04-30 18:41:40 GMT

**ClusterIssuer:**
- **Name**: `letsencrypt-prod`
- **ACME Server**: https://acme-v02.api.letsencrypt.org/directory
- **Challenge Method**: DNS-01 (Cloudflare DNS provider)
- **Account Key Secret**: `letsencrypt-prod-account-key` (cert-manager namespace)

---

## Cross-Namespace Strategy

### Architecture Model: Centralized Secret with Cross-Namespace References

```
Certificate Resource              Secret Resource
(traefik-system)                 (traefik-system)
     ↓ manages                        ↓ referenced by
mlops-work-wildcard          mlops-work-wildcard-tls
                                      ↓
        ┌─────────────────────────────┼─────────────────────────────┐
        ↓                             ↓                             ↓
IngressRoute                  IngressRoute                  IngressRoute
traefik-dashboard            ollama-inference-api          jupyterhub-https
(traefik-system)             (traefik-system)              (traefik-system)
        ↓                             ↓                             ↓
    Service                       Service                       Service
api@internal                  ollama-service                proxy-public
(traefik-system)                  (ollama)                   (jupyterhub)
```

### Key Design Decisions

**1. Single Certificate, Single Secret**
- Only ONE Certificate resource: `mlops-work-wildcard`
- Only ONE Secret: `mlops-work-wildcard-tls`
- Located in: `traefik-system` namespace

**2. Centralized IngressRoute Management**
- All IngressRoutes deployed in `traefik-system` namespace
- Enables centralized visibility and management
- Requires `allowCrossNamespace: true` in Traefik Helm values

**3. Cross-Namespace Service References**
- IngressRoutes in `traefik-system` can reference Services in other namespaces
- Example:
  ```yaml
  services:
    - name: proxy-public
      namespace: jupyterhub  # Cross-namespace reference
      port: 80
  ```

### Benefits of This Model

| Benefit | Description |
|---------|-------------|
| **Single Renewal Point** | cert-manager renews one Certificate, all services get new cert |
| **Atomic Updates** | Secret updated in-place, no partial state during renewal |
| **Zero Downtime** | Traefik hot-reloads TLS config without Pod restart |
| **Simplified Monitoring** | One Certificate to monitor for expiry |
| **No Duplication** | No Secret copying or synchronization needed |
| **Centralized Visibility** | All routing config in one namespace |

### Limitations

| Limitation | Mitigation |
|------------|------------|
| **Cross-Namespace Permission Required** | Traefik requires `allowCrossNamespace: true` (security consideration) |
| **Namespace Coupling** | All IngressRoutes must be in `traefik-system` |
| **Multi-Cluster Not Supported** | Secrets cannot cross cluster boundaries (requires alternative strategy) |
| **RBAC Complexity** | Traefik ServiceAccount needs permission to read Secrets in traefik-system |

---

## Services Using This Certificate

| Service | IngressRoute Name | IngressRoute NS | Backend Service | Backend NS | Host | Cloudflare Proxy |
|---------|-------------------|-----------------|-----------------|------------|------|------------------|
| Traefik Dashboard | traefik-dashboard | traefik-system | api@internal | traefik-system | traefik.mlops.work | ✅ Enabled |
| Ollama API | ollama-inference-api | traefik-system | ollama-service | ollama | ollama.mlops.work | ✅ Enabled |
| JupyterHub | jupyterhub-https | traefik-system | proxy-public | jupyterhub | jupyter.mlops.work | ❌ Disabled (WebSocket) |

**Note:** All IngressRoutes reference the same TLS Secret:
```yaml
spec:
  tls:
    secretName: mlops-work-wildcard-tls
    options:
      name: enterprise-tls-policy
      namespace: traefik-system
```

---

## Certificate Renewal Strategy

### Automatic Renewal Process

**Trigger Conditions:**
- cert-manager checks certificate expiry every hour
- Renewal initiated when **< 30 days remaining** (configurable via `renewBefore`)
- Default: 720h (30 days) before expiry

**Renewal Workflow:**
1. cert-manager detects certificate nearing expiry
2. Initiates ACME DNS-01 challenge with Cloudflare
3. Let's Encrypt validates DNS TXT record
4. New certificate issued (90-day validity)
5. Secret `mlops-work-wildcard-tls` updated in-place (atomic operation)
6. Traefik automatically detects Secret change and reloads TLS config
7. All IngressRoutes immediately use new certificate (no configuration change needed)

**Timeline Example:**
```
Day 0:  Certificate issued (valid for 90 days)
Day 60: cert-manager triggers renewal (30 days before expiry)
Day 60: New certificate obtained and Secret updated
Day 90: Old certificate would have expired (already replaced)
```

### Impact on Services During Renewal

- [o] **Zero Downtime**: Secret update is atomic, no service interruption
- [o] **Hot Reload**: Traefik reloads TLS config without Pod restart
- [o] **Simultaneous Propagation**: All IngressRoutes get new cert at the same time
- [!] **Brief Coexistence**: Old and new cert may coexist in Traefik memory for ~1 second during reload

### Monitoring Renewal

**Watch Certificate Status:**
```bash
kubectl get certificate mlops-work-wildcard -n traefik-system -w
```

**Check Days Until Expiry:**
```bash
kubectl get secret mlops-work-wildcard-tls -n traefik-system -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | openssl x509 -noout -enddate
```

**View cert-manager Logs:**
```bash
kubectl logs -n cert-manager -l app=cert-manager -f
```

**Alert Thresholds (Zabbix Integration):**
- **Warning**: < 14 days remaining
- **Critical**: < 7 days remaining
- **Emergency**: < 3 days remaining (manual intervention required)

---

## Cloudflare Configuration

### Edge Certificate (Cloudflare Universal SSL)

**Managed By:** Cloudflare (automatic, no action required)
- **Issuer**: Google Trust Services (WE1)
- **Subject**: `CN = mlops.work`
- **Validity**: Typically 1 year (auto-renewed by Cloudflare)
- **Purpose**: Encryption between client and Cloudflare edge

### SSL/TLS Mode: Full (Strict)

**Configuration:**
- Cloudflare Dashboard → SSL/TLS → Overview → Full (strict)
- **Validates**: Cloudflare verifies origin certificate against trusted CA
- **Requires**: Valid certificate on origin (Let's Encrypt qualifies)

**Why Full (Strict) vs Other Modes:**
- [x] **Flexible**: Cloudflare to origin can be unencrypted (insecure)
- [!] **Full**: Accepts self-signed certs (less secure)
- [o] **Full (Strict)**: Requires valid CA-signed cert (recommended)
- [!] **Strict (SSL-Only Origin Pull)**: Requires Cloudflare Origin CA cert (unnecessary with Let's Encrypt)

---

## Adding New Services

### Standard Procedure for Onboarding New Service

**Prerequisites:**
- Service deployed in Kubernetes with a ClusterIP Service
- DNS A record created in Cloudflare (pointing to origin server IP)
- Decide on Cloudflare Proxy mode (Orange = Enabled, Gray = DNS Only)

**Step 1: Create IngressRoute**
```bash
cd ~/aicc-mlops-platform/infra/traefik

cat > routers/<service-name>.yaml << 'YAML_EOF'
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: <service-name>-https
  namespace: traefik-system
  labels:
    app.kubernetes.io/name: <service-name>
    app.kubernetes.io/component: web-ui
  annotations:
    traefik.io/description: "<Service Description>"
    service-namespace: "<backend-namespace>"
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`<subdomain>.mlops.work`)
      kind: Rule
      services:
        - name: <service-name>-service
          namespace: <backend-namespace>
          port: <service-port>
      middlewares:
        - name: security-headers
          namespace: traefik-system
  tls:
    secretName: mlops-work-wildcard-tls
    options:
      name: enterprise-tls-policy
      namespace: traefik-system
YAML_EOF
```

**Step 2: Apply IngressRoute**
```bash
kubectl apply -f routers/<service-name>.yaml
```

**Step 3: Verify in Traefik Dashboard**
1. Access https://traefik.mlops.work/dashboard/
2. Navigate to HTTP → Routers
3. Confirm `<service-name>-https@kubernetescrd` appears with status **Success**

**Step 4: Test HTTPS Access**
```bash
# Test from origin server (should show Let's Encrypt R13)
echo | openssl s_client -connect localhost:443 -servername <subdomain>.mlops.work 2>/dev/null | \
  openssl x509 -noout -issuer

# Test from external (may show Google Trust Services if Cloudflare Proxy enabled)
curl -I https://<subdomain>.mlops.work
```

**Step 5: Update Documentation**
Add entry to this file under "Services Using This Certificate" section.

### Special Considerations

**WebSocket Services (e.g., JupyterHub, VSCode Server):**
- Disable Cloudflare Proxy (Gray Cloud in DNS settings)
- Do NOT add `rate-limit` middleware
- Consider adding custom timeout middleware if needed

**API Services (e.g., Ollama, FastAPI):**
- Cloudflare Proxy can be enabled (benefits from DDoS protection)
- Add `timeout-extended` middleware for long-running operations
- Consider `rate-limit` for public-facing APIs

**Static Content / Dashboards:**
- Cloudflare Proxy recommended (benefits from CDN caching)
- Add `security-headers` middleware
- Consider `rate-limit` for login endpoints

---

## Troubleshooting

### Certificate Not Renewing

**Symptoms:**
- Certificate < 7 days from expiry
- cert-manager logs show ACME challenge failures

**Diagnosis:**
```bash
# Check Certificate status
kubectl describe certificate mlops-work-wildcard -n traefik-system

# Check CertificateRequest
kubectl get certificaterequest -n traefik-system | grep mlops-work

# Check Challenge status
kubectl get challenge -n traefik-system
```

**Common Causes:**
1. **Cloudflare API token expired**: Update Secret in cert-manager namespace
2. **DNS propagation delay**: ACME challenge timed out before DNS updated
3. **Let's Encrypt rate limit**: Too many renewals (5 per week for same domain)

**Resolution:**
```bash
# Force renewal (delete and recreate CertificateRequest)
kubectl delete certificaterequest -n traefik-system <request-name>

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager --tail=100
```

### IngressRoute Not Using Certificate

**Symptoms:**
- Browser shows certificate warning
- `openssl s_client` shows different certificate

**Diagnosis:**
```bash
# Verify IngressRoute references correct Secret
kubectl get ingressroute <name> -n traefik-system -o yaml | grep -A 5 "tls:"

# Verify Secret exists
kubectl get secret mlops-work-wildcard-tls -n traefik-system

# Check Traefik logs
kubectl logs -n traefik-system -l app.kubernetes.io/name=traefik | grep -i tls
```

**Resolution:**
- Ensure `secretName: mlops-work-wildcard-tls` in IngressRoute spec
- Restart Traefik Pod if Secret was recently created:
  ```bash
  kubectl delete pod -n traefik-system -l app.kubernetes.io/name=traefik
  ```

### Cross-Namespace Service Not Found

**Symptoms:**
- Traefik Dashboard shows Router in error state
- Logs: "service not in the parent resource namespace"

**Diagnosis:**
```bash
# Check if allowCrossNamespace is enabled
helm get values traefik -n traefik-system | grep allowCrossNamespace
```

**Resolution:**
```bash
# Enable cross-namespace references
helm upgrade traefik traefik/traefik -n traefik-system \
  --set providers.kubernetesCRD.allowCrossNamespace=true \
  --reuse-values
```

---

## Security Notes

- [o] **Origin Certificate**: Let's Encrypt (publicly trusted, industry standard)
- [o]**ACME Challenge**: DNS-01 (works behind firewall, no port 80 requirement)
- [o]**Certificate Storage**: Kubernetes Secret (encrypted at rest if etcd encryption enabled)
- [o] **Automatic Rotation**: cert-manager ensures certificates never expire
- [o] **TLS 1.2+ Only**: Enforced by enterprise-tls-policy (no weak protocols)
- [o] **Perfect Forward Secrecy**: ECDHE cipher suites configured
- [!] **Single Point of Failure**: All services depend on one Secret (mitigated by automatic renewal)
- [!] **Namespace Permission**: Traefik can read all Secrets in traefik-system (minimize Secret count)

---

## References

- **cert-manager Documentation**: https://cert-manager.io/docs/
- **Let's Encrypt Rate Limits**: https://letsencrypt.org/docs/rate-limits/
- **Traefik TLS Documentation**: https://doc.traefik.io/traefik/https/tls/
- **Cloudflare SSL Modes**: https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/
- **ADR-014**: Traefik Networking Correction (internal doc)
- **Incident Report**: 2026-02-04 Port Binding Issue (reference/)

---

**Part of**: AI Computing Center MLOps Platform
**Managed by**: Range
**Last Updated**: 2026-02-05
**Review Cycle**: Quarterly or when new services are added

