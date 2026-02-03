# Traefik Deployment Recovery Runbook

## Purpose
Restore Traefik ingress functionality when standard ports (80/443) become unavailable.

## Symptoms
- `curl https://traefik.mlops.work` returns "Connection refused"
- Dashboard inaccessible via browser
- `kubectl get svc -n traefik-system` shows NodePort with high port numbers (30000+)

## Diagnosis Steps

### Step 1: Verify Service Configuration
```bash
kubectl get svc -n traefik-system traefik -o yaml | grep -E "type:|nodePort:"
```
**Expected Output**:
```yaml
type: ClusterIP
```
**Problem Indicator**:
```yaml
type: NodePort
nodePort: 32647  # Random high port
```

### Step 2: Check Pod Port Bindings
```bash
kubectl get pod -n traefik-system -o jsonpath='{.items.spec.containers.ports}' | jq
```
**Expected Output**:
```json
[
  {"containerPort": 8443, "hostPort": 443, "name": "websecure", "protocol": "TCP"}
]
```
**Problem Indicator**: Missing `hostPort` field

### Step 3: Verify DaemonSet vs Deployment
```bash
kubectl get daemonset,deployment -n traefik-system
```
**Expected Output**: DaemonSet present, NO Deployment

## Recovery Procedure

### Quick Rollback (5 minutes)
```bash
# 1. Check Helm history
helm history traefik -n traefik-system

# 2. Rollback to last known good version
helm rollback traefik [REVISION] -n traefik-system

# 3. Wait for rollout
kubectl rollout status daemonset traefik -n traefik-system

# 4. Validate
curl -I https://traefik.mlops.work/dashboard/
```

### Full Redeployment (10 minutes)
```bash
# 1. Backup current configuration
helm get values traefik -n traefik-system > /tmp/traefik-backup.yaml

# 2. Uninstall (preserves PVCs and Secrets)
helm uninstall traefik -n traefik-system

# 3. Reinstall with correct values
helm install traefik traefik/traefik -n traefik-system \
  -f infra/traefik/base/helm/values.yaml

# 4. Verify hostPort binding
sudo ss -tlnp | grep :443
```

## Validation Checklist
- [ ] `kubectl get daemonset -n traefik-system` shows 1/1 ready
- [ ] `sudo ss -tlnp | grep :443` shows process listening
- [ ] `curl -k https://localhost:443` returns HTTP response
- [ ] Remote browser can access `https://traefik.mlops.work/dashboard/`
- [ ] Jupyter and other services accessible via HTTPS

## Escalation
If recovery fails after 30 minutes:
1. Check k3s cluster health: `kubectl get nodes`
2. Review containerd status: `sudo systemctl status k3s`
3. Check firewall rules: `sudo iptables -L -n | grep 443`
4. Consult incident report: `docs/troubleshooting/2026-02-03-traefik-port-binding-incident.md`

