# Traefik Pre-Deployment Checklist

**Date**: 2026/01/23  
**Node**: llm1

## Resource Verification

### 1. Namespace
```bash
kubectl get namespace traefik-system
```
Expected: Active status

### 2. ResourceQuota
```bash
kubectl get resourcequota -n traefik-system
```
Expected: 
- CPU requests: 4 cores
- Memory requests: 8G

### 3. LimitRange
```bash
kubectl get limitrange -n traefik-system
```
Expected: Container default limits defined

### 4. PriorityClass
```bash
kubectl get priorityclass system-cluster-critical
```
Expected: Value 2000000000

### 5. Dashboard Auth Secret
```bash
kubectl get secret traefik-dashboard-auth -n traefik-system
```
Expected: Opaque type with 'users' data key

## Port Availability

```bash
sudo netstat -tulpn | grep -E ':80 |:443 '
```
Expected: No output (ports free)

## Helm Repository

```bash
helm search repo traefik/traefik --version 38.0.2
```
Expected: Chart found

## Pre-flight Status

- [ ] Namespace created with ResourceQuota and LimitRange
- [ ] PriorityClass exists
- [ ] Dashboard Secret created
- [ ] Ports 80/443 available
- [ ] Helm repository accessible
- [ ] values.yaml validated

## Ready for Deployment

If all checks pass, proceed with:
```bash
helm install traefik traefik/traefik \
  --namespace traefik-system \
  --version 38.0.2 \
  -f ~/aicc-mlops-platform/infra/traefik/base/helm/values.yaml \
  --wait --timeout 5m
```
