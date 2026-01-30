# JupyterHub with GPU Time-Slicing

Multi-tenant JupyterHub deployment supporting concurrent GPU workloads via NVIDIA Time-Slicing.

## Architecture

- **Namespace**: `jupyterhub`
- **GPU Quota**: 4 virtual GPUs (from 1 physical RTX A4000)
- **Authentication**: Dummy (development only, replace with GitHub OAuth in production)
- **Storage**: Local-path dynamic PVCs (10GB per user)
- **Ingress**: NodePort 30080 (migrate to Traefik in production)

## Prerequisites

1. **GPU Operator** with Time-Slicing enabled (1 physical → 4 virtual)
2. **k3s** cluster operational
3. **Namespace and ResourceQuota** applied

```bash
kubectl apply -f infra/namespaces/jupyterhub/
```

## Installation

### Method 1: Helm (Recommended)

```bash
# Add JupyterHub Helm repository
helm repo add jupyterhub https://hub.jupyter.org/helm-chart/
helm repo update

# Install with custom values
helm upgrade --install jupyterhub jupyterhub/jupyterhub \
  --namespace jupyterhub \
  --create-namespace \
  --values apps/jupyterhub/values.yaml \
  --version 4.3.2
```

### Method 2: ArgoCD (GitOps)

Create ApplicationSet (coming soon):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: jupyterhub
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://hub.jupyter.org/helm-chart/
    chart: jupyterhub
    targetRevision: 4.3.2
    helm:
      valueFiles:
        - ../../apps/jupyterhub/values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: jupyterhub
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Access

**URL**: `http://<node-ip>:30080`

**Login**: Any username/password (dummy authenticator)

## GPU Validation

After login, create a notebook and run:

```python
import torch
print(f"CUDA Available: {torch.cuda.is_available()}")
print(f"GPU Count: {torch.cuda.device_count()}")
print(f"GPU Name: {torch.cuda.get_device_name(0)}")
```

Expected output:
```
CUDA Available: True
GPU Count: 1
GPU Name: NVIDIA RTX A4000
```

## Resource Limits

**Per User Pod**:
- GPU: 1 virtual GPU (guaranteed)
- CPU: 0.5-2 cores
- Memory: 1-4 GB
- Storage: 10 GB PVC

**Namespace Total**:
- Max 4 concurrent users (GPU quota)
- Max 40 CPU cores
- Max 96 GB memory

## Production Upgrade Path

### Phase 1: Security Hardening

Replace dummy authenticator with GitHub OAuth:

```yaml
hub:
  config:
    GitHubOAuthenticator:
      client_id: YOUR_CLIENT_ID
      client_secret: YOUR_CLIENT_SECRET
      oauth_callback_url: https://jupyter.mlops.work/hub/oauth_callback
    JupyterHub:
      authenticator_class: github
```

### Phase 2: Persistent Database

Replace sqlite-memory with PostgreSQL:

```yaml
hub:
  db:
    type: postgres
    url: postgresql://user:pass@postgres.default.svc:5432/jupyterhub
```

### Phase 3: Traefik Ingress

Remove NodePort, add IngressRoute:

```yaml
proxy:
  service:
    type: ClusterIP
***
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: jupyterhub
  namespace: jupyterhub
spec:
  entryPoints: [websecure]
  routes:
  - match: Host(`jupyter.mlops.work`)
    kind: Rule
    services:
    - name: proxy-public
      port: 80
  tls:
    certResolver: letsencrypt
```

## Monitoring

Check GPU utilization:

```bash
# DCGM metrics
kubectl port-forward -n gpu-operator svc/nvidia-dcgm-exporter 9400:9400
curl localhost:9400/metrics | grep DCGM_FI_DEV_GPU_UTIL

# User pod status
kubectl get pods -n jupyterhub -l component=singleuser-server
```

## Troubleshooting

**Issue**: User pod stuck in Pending

```bash
# Check GPU availability
kubectl describe node llm1.mlops.work | grep nvidia.com/gpu

# Check ResourceQuota
kubectl describe resourcequota gpu-quota -n jupyterhub
```

**Issue**: GPU not visible in notebook

```bash
# Verify GPU Operator
kubectl logs -n gpu-operator -l app=nvidia-device-plugin-daemonset

# Check user pod
kubectl describe pod jupyter-<username> -n jupyterhub
```

## Audit Baseline
- **Deployment Method**: Helm Chart
- **Namespace**: jupyterhub
- **Core Service**: proxy-public
- **Status**: Audit completed on $(date +'%Y-%m-%d'). Service is ready for TLS integration.

## TLS Validation Report (Step 4.4)
- **Status**: Verified Active
- **Issuer**: Let's Encrypt (R13/E6)
- **Protocol**: TLS 1.3 / HSTS Enabled (Global Policy)
- **Trust Chain**: Full chain provided by Traefik. Tested via OpenSSL.
- **Redirection**: Verified HTTP (301) to HTTPS (200).

## Files

```
apps/jupyterhub/
├── values.yaml              # Helm chart configuration
├── README.md                # This file
├── certificate.yaml         # 
├── middleware-redirect.yaml #  
├── ingressroute-http.yaml   #  
└── ingressroute.yaml        # 

infra/namespaces/jupyterhub/
└── namespace.yaml       # Namespace, ResourceQuota, LimitRange

```

## References

- [JupyterHub Helm Chart](https://z2jh.jupyter.org/)
- [NVIDIA Time-Slicing](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-sharing.html)
- [GPU Operator Guide](../../docs/runbooks/gpu-operator.md)

---

**Status**: Development (Dummy Auth)  
**Next**: Migrate to GitHub OAuth + Traefik Ingress  
**Phase 2 Target**: Support 12-16 concurrent users (3-node HA cluster)

---

**Part of**: AI Computing Center MLOps Platform
**Managed by**: Range
**Last Updated**: 2026-01-29

