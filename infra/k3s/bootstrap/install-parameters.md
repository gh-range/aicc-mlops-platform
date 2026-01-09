# k3s Installation Parameters Explained

## Core Installation Command
```bash
curl -sfL https://get.k3s.io | sh -s - server \
  --cluster-init \
  --disable traefik \
  --disable servicelb \
  --write-kubeconfig-mode 644
```

---

## Parameter Breakdown

### `--cluster-init`

**Purpose**: Initialize embedded etcd for high availability

**What it does**:
- Creates an embedded etcd cluster (no external etcd needed)
- Enables multi-master capability (can add more control plane nodes later)
- Stores cluster state in `/var/lib/rancher/k3s/server/db/etcd`

**Why we use it**:
- True HA on single node (survives k3s restart)
- Future-proof: easy to add nodes without data migration
- Industry best practice for production

**Alternative**: Without this flag, k3s uses SQLite (not recommended for production)

---

### `--disable traefik`

**Purpose**: Disable bundled Traefik ingress controller

**Why we disable it**:
- We will install Traefik manually via Helm for:
  - Better version control
  - Custom configuration (middlewares, TLS settings)
  - Integration with cert-manager
  - Path-based routing for our use case

**Note**: k3s includes Traefik v2 by default, but manual installation gives more flexibility

---

### `--disable servicelb`

**Purpose**: Disable bundled ServiceLB (klipper-lb)

**Why we disable it**:
- ServiceLB creates `hostPort` bindings (not suitable for production)
- We will use Traefik as LoadBalancer instead
- Cleaner architecture: single ingress point

**What is ServiceLB?**
- Simple load balancer for k3s
- Works by creating DaemonSet with host network
- Good for dev, but limited for production

---

### `--write-kubeconfig-mode 644`

**Purpose**: Make kubeconfig readable by non-root users

**Default behavior**: k3s creates `/etc/rancher/k3s/k3s.yaml` with mode 600 (root only)

**With this flag**: Mode 644 allows your user to run kubectl without sudo

**Security note**: 
- In production with multiple users, use RBAC instead
- For single-user dev/staging, this is convenient

---

## Additional Useful Parameters (Not Used Now)

### Storage
```bash
--default-local-storage-path /mnt/k3s-storage
```
Change local-path-provisioner default location

### Networking
```bash
--flannel-backend vxlan  # Default, can also use: wireguard, host-gw
--cluster-cidr 10.42.0.0/16  # Pod network CIDR
--service-cidr 10.43.0.0/16  # Service network CIDR
```

### Node Configuration
```bash
--node-name my-custom-name  # Override hostname
--node-label gpu=true  # Add custom labels
--node-taint gpu=true:NoSchedule  # Add taints
```

### TLS & Security
```bash
--tls-san additional-domain.com  # Add TLS SAN for API server
--secrets-encryption  # Enable encryption at rest for secrets
```

---

## Installation Script Location

The official k3s install script does the following:

1. Download k3s binary to `/usr/local/bin/k3s`
2. Create systemd service at `/etc/systemd/system/k3s.service`
3. Configure environment in `/etc/systemd/system/k3s.service.env`
4. Generate kubeconfig at `/etc/rancher/k3s/k3s.yaml`
5. Start and enable k3s service

---

## Post-Installation Files

| File | Purpose |
|------|---------|
| `/usr/local/bin/k3s` | k3s binary |
| `/etc/rancher/k3s/k3s.yaml` | kubeconfig |
| `/var/lib/rancher/k3s/` | Data directory (etcd, manifests, etc) |
| `/usr/local/bin/k3s-uninstall.sh` | Uninstall script |
| `/usr/local/bin/kubectl` | Symlink to k3s |

---

## Environment Variables (Alternative to Flags)

Instead of command-line flags, you can use env vars:
```bash
export K3S_CLUSTER_INIT=true
export K3S_DISABLE_TRAEFIK=true
curl -sfL https://get.k3s.io | sh -
```

Stored in: `/etc/systemd/system/k3s.service.env`

---

## References

- [k3s Documentation](https://docs.k3s.io/)
- [k3s Server Configuration](https://docs.k3s.io/cli/server)
- [k3s Networking](https://docs.k3s.io/networking)
