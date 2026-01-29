# JupyterHub Custom Services

Custom authentication, spawner configurations, and extensions for JupyterHub deployment.

## Purpose

This directory is reserved for **custom JupyterHub components** that extend the official Helm chart. For standard deployment configuration, see [`apps/jupyterhub/`](../../apps/jupyterhub/).

## Directory Structure

```
services/jupyterhub/
├── README.md                    # This file
├── authenticators/              # Custom OAuth/LDAP authenticators (future)
├── spawners/                    # Custom KubeSpawner configurations (future)
├── docker/                      # Custom JupyterHub hub/user images (future)
└── hooks/                       # Lifecycle hooks (pre-spawn, post-spawn) (future)
```

## Current Status

**Phase 1 (MAV)**: Using official JupyterHub Helm chart with minimal customization.

- Authentication: Dummy authenticator (development only)
- User Image: `quay.io/jupyter/minimal-notebook:ubuntu-24.04`
- Spawner: Default KubeSpawner with GPU resource limits

**No custom code required at this stage.**

---

## Planned Customizations (Phase 2-3)

### 1. GitHub OAuth Authenticator

```python
# authenticators/github_oauth.py
from oauthenticator.github import GitHubOAuthenticator

class CustomGitHubAuthenticator(GitHubOAuthenticator):
    """
    Custom authenticator with:
    - Organization membership validation
    - Team-based ResourceQuota mapping
    - Audit logging
    """
    async def pre_spawn_start(self, user, spawner):
        # Map GitHub team to Kubernetes namespace
        pass
```

**Implementation Timeline**: Q3 2026 (Phase 2)

---

### 2. Custom KubeSpawner (GPU Allocation)

```python
# spawners/gpu_spawner.py
from kubespawner import KubeSpawner

class GPUAwareSpawner(KubeSpawner):
    """
    Enhanced spawner with:
    - Dynamic GPU allocation based on user tier
    - MIG instance selection (Phase 3)
    - Cost estimation display in launcher UI
    """
    pass
```

**Implementation Timeline**: Q1 2027 (Phase 3 commercial launch)

---

### 3. Custom User Images

**Current**: Official `jupyter/minimal-notebook`

**Planned** (Phase 2-3):
```dockerfile
# docker/user-image/Dockerfile
FROM quay.io/jupyter/pytorch-notebook:ubuntu-24.04

# Add enterprise tooling
RUN pip install \
    llama-factory \
    ktransformers \
    company-internal-ml-sdk

# NVIDIA optimizations
ENV CUDA_LAUNCH_BLOCKING=0
ENV TORCH_CUDA_ARCH_LIST="8.0;8.6;9.0"  # A100, A4000, B200
```

**Build Automation**: ArgoCD Image Updater + Harbor registry

---

## Integration with apps/jupyterhub/

Custom components are referenced in `apps/jupyterhub/values.yaml`:

```yaml
hub:
  image:
    name: harbor.mlops.work/services/jupyterhub-hub  # Custom hub image
    tag: 1.0.0
  
  extraConfig:
    custom_auth.py: |
      from services.authenticators.github_oauth import CustomGitHubAuthenticator
      c.JupyterHub.authenticator_class = CustomGitHubAuthenticator

singleuser:
  image:
    name: harbor.mlops.work/services/jupyterhub-user  # Custom user image
    tag: 2.0.0
```

---

## Development Workflow

### Adding a Custom Authenticator

1. Create `authenticators/my_auth.py`
2. Build hub image: `docker build -t jupyterhub-hub:custom -f docker/hub/Dockerfile .`
3. Push to registry: `docker push harbor.mlops.work/services/jupyterhub-hub:custom`
4. Update `apps/jupyterhub/values.yaml` to reference new image
5. ArgoCD auto-syncs deployment

### Testing Locally

```bash
# Launch local JupyterHub with custom components
cd services/jupyterhub
docker-compose up

# Access: http://localhost:8000
```

---

## Decision Rationale

**Why defer customizations to Phase 2-3?**

Per [ADR-001](../../docs/design-decisions/01-why-k3s.md) and [Operating Plan](../../docs/operating-plan.md):

1. **Phase 1 (MAV)**: Validate orchestration patterns with minimal complexity
2. **Phase 2 (HA)**: Add authentication and multi-tenancy customizations
3. **Phase 3 (Commercial)**: Implement billing-aware spawners and enterprise SSO

**Early customization would**:
- Increase maintenance burden during architecture validation
- Distract from core objective (proving GPU Time-Slicing + ResourceQuotas work)
- Risk technical debt if commercial requirements pivot

---

## References

- [JupyterHub Authenticators](https://jupyterhub.readthedocs.io/en/stable/reference/authenticators.html)
- [KubeSpawner Documentation](https://jupyterhub-kubespawner.readthedocs.io/)
- [Custom Docker Images Guide](https://z2jh.jupyter.org/en/stable/jupyterhub/customizing/user-environment.html)
- [Deployment Config](../../apps/jupyterhub/values.yaml)

---

**Status**: Placeholder (no custom code yet)  
**Implementation Start**: Q3 2026 (Phase 2)  
**Owner**: Platform Engineering Team

**For deployment instructions, see**: [apps/jupyterhub/README.md](../../apps/jupyterhub/README.md)

---

**Part of**: AI Computing Center MLOps Platform  
**Managed by**: Range  
**Last Updated**: 2026-01-29

