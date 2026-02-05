# Runbook: Adding New Service to Traefik

**Audience**: Platform Engineers  
**Estimated Time**: 15 minutes  
**Prerequisites**: Service deployed in Kubernetes with ClusterIP

---

## Step 1: Verify Service

```bash
# Check service exists
kubectl get svc <service-name> -n <namespace>

# Verify endpoints
kubectl get endpoints <service-name> -n <namespace>
```

**Expected**: Service has at least one endpoint IP.

---

## Step 2: Configure Cloudflare DNS

1. Login to Cloudflare Dashboard
2. Navigate to DNS → Records
3. Add A record:
   - **Name**: `<subdomain>`
   - **IPv4**: `<your-origin-ip>`
   - **Proxy**: Orange (Enabled) or Gray (Disabled - for WebSocket)
4. Save

**WebSocket services**: Use Gray cloud (DNS Only)

---

## Step 3: Create IngressRoute

```bash
cd ~/aicc-mlops-platform/infra/traefik

cat > routers/<service-name>.yaml << 'YAML'
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: <service-name>-https
  namespace: traefik-system
  labels:
    app.kubernetes.io/name: <service-name>
  annotations:
    service-namespace: "<namespace>"
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`<subdomain>.mlops.work`)
      kind: Rule
      services:
        - name: <service-name>
          namespace: <namespace>
          port: <port>
      middlewares:
        - name: security-headers
          namespace: traefik-system
  tls:
    secretName: mlops-work-wildcard-tls
    options:
      name: enterprise-tls-policy
      namespace: traefik-system
YAML
```

**Middleware selection**:
- All services: `security-headers`
- Public APIs: `rate-limit`
- Admin UIs: `dashboard-auth` (BasicAuth)
- Long operations: `timeout-extended`

---

## Step 4: Apply and Verify

```bash
# Apply IngressRoute
kubectl apply -f routers/<service-name>.yaml

# Check Traefik Dashboard
# https://traefik.mlops.work/dashboard/ → HTTP → Routers
# Look for <service-name>-https@kubernetescrd with Success status

# Test HTTPS
curl -I https://<subdomain>.mlops.work
```

---

## Step 5: Update Documentation

```bash
# Regenerate router inventory
cd ~/aicc-mlops-platform/infra/traefik
./tools/router-scanner.sh
cp reports/router-inventory.md ROUTER_INVENTORY.md

# Update certificates.md
# Add entry to "Services Using This Certificate" table

# Commit changes
git add routers/<service-name>.yaml ROUTER_INVENTORY.md base/tls/certificates.md
git commit -m "feat(traefik): add <service-name> routing"
git push origin develop
```

---

## Troubleshooting

### Router shows "Service Not Found"
```bash
# Verify service exists in target namespace
kubectl get svc <service-name> -n <namespace>

# Check cross-namespace permissions
helm get values traefik -n traefik-system | grep allowCrossNamespace
# Should show: allowCrossNamespace: true
```

### Certificate Warning in Browser
```bash
# Verify TLS secret reference
kubectl get ingressroute <name> -n traefik-system -o yaml | grep secretName
# Should show: secretName: mlops-work-wildcard-tls

# Check certificate validity
kubectl get certificate mlops-work-wildcard -n traefik-system
# Status should show Ready: True
```

### 502 Bad Gateway
```bash
# Check backend service endpoints
kubectl get endpoints <service-name> -n <namespace>
# Should show at least one IP address

# Check Pod status
kubectl get pods -n <namespace> -l app=<service-name>
```

---

**Last Updated**: 2026-02-05

