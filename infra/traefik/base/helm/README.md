# Traefik Production Helm Values

## Configuration Summary

| Category | Value | Rationale |
|----------|-------|-----------|
| **Deployment** | DaemonSet | HA guarantee on single/multi-node |
| **Service Type** | ClusterIP | No external LoadBalancer needed |
| **Network Mode** | HostPort 80/443 | Direct host binding |
| **Resources** | 500m CPU / 1G RAM | Baseline with burst capacity |
| **TLS** | Passthrough | Delegated to cert-manager |
| **Metrics** | Prometheus enabled | Zabbix integration |
| **Logs** | JSON format | Structured logging for audit |
| **Security** | BasicAuth dashboard | Protected management interface |

## Files Structure

```
base/helm/
├── values.yaml              # Production configuration (150 lines)
├── validate-values.sh       # Pre-deployment validation script
└── README.md               # This file
```

## Deployment Command

```bash
helm install traefik traefik/traefik \
  --namespace traefik-system \
  --version 38.0.2 \
  -f values.yaml \
  --wait
```

## Validation Workflow

```bash
# 1. Validate YAML syntax
./validate-values.sh

# 2. Dry-run deployment
helm install traefik traefik/traefik \
  --namespace traefik-system \
  --version 38.0.2 \
  -f values.yaml \
  --dry-run --debug

# 3. Apply configuration
helm install traefik traefik/traefik \
  --namespace traefik-system \
  --version 38.0.2 \
  -f values.yaml
```

## Configuration Overrides

To override specific values for different environments:

```bash
# Development
helm install traefik traefik/traefik \
  -f values.yaml \
  -f ../overlays/dev/values-override.yaml

# Production
helm install traefik traefik/traefik \
  -f values.yaml \
  -f ../overlays/production/values-override.yaml
```

## Dashboard Access

After deployment, access dashboard at:
- URL: `https://traefik.<domain>/dashboard/`
- Username: `admin`
- Password: (defined in dashboard-auth-secret.yaml)

**Note**: Update DNS or /etc/hosts to resolve `traefik.<domain>` to node IP.

## Monitoring Integration

Prometheus metrics available at:
- Endpoint: `http://<node-ip>:9100/metrics`
- Scrape interval: 30s (recommended)

## Troubleshooting

### Check Traefik Logs
```bash
kubectl logs -n traefik-system -l app.kubernetes.io/name=traefik -f
```

### Verify Port Binding
```bash
sudo netstat -tunlp | grep -E ':80|:443'
```

### Test Dashboard Access
```bash
curl -k -u admin:<password> https://traefik.<domain>/dashboard/
```

