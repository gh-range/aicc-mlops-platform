# ADR-001: Choose k3s over Full Kubernetes and RKE2

**Status**: Accepted  
**Date**: 2025-12-31  
**Deciders**: Infrastructure Lead, Platform Team  
**Technical Story**: Single-node MLOps platform for AI workloads

---

## Context and Problem Statement

We need a Kubernetes distribution for running AI/ML workloads on a single powerful workstation (i9-10900F, 128GB RAM, RTX A4000 16GB). The platform must support GPU scheduling, GitOps workflows, and serve as a blueprint for future multi-node expansion.

**Key Requirements:**
- Single-node deployment with HA capability (no external etcd)
- Native GPU support via NVIDIA GPU Operator
- Low resource overhead (maximize resources for ML workloads)
- Production-grade features (RBAC, NetworkPolicy, PodSecurityStandards)
- Easy to upgrade and maintain by a small team (1-3 people)
- Can scale to 3-5 nodes in the future

---

## Decision Drivers

- **Cost**: Limited hardware budget, single-node deployment
- **Team Size**: 1 engineer initially, max 3-5 in 12 months
- **Timeline**: Need functional platform in 3 weeks
- **Scalability**: Start with 1 node, grow to 3-5 nodes within a year
- **Compliance**: Must support enterprise security standards
- **Technical Debt**: Easy upgrades, active community support

---

## Considered Options

### Option 1: Full Kubernetes (kubeadm)

**Description**: Official Kubernetes using kubeadm for cluster bootstrapping

**Pros:**
- o Industry standard, widest ecosystem compatibility
- o Most comprehensive documentation
- o Direct upstream updates
- o Maximum flexibility

**Cons:**
- x Requires external etcd for HA (overkill for single node)
- x Higher resource overhead (~1.5GB RAM for control plane)
- x More complex to set up and maintain
- x Slower release cycle means delayed features

**Cost Estimate**: 
- Hardware: $0 (can run on existing machine)
- Operations: 15-20 hours/month maintenance (complex upgrades)
- Learning curve: High for junior team members

---

### Option 2: RKE2 (Rancher Kubernetes Engine 2)

**Description**: Rancher's security-focused Kubernetes distribution

**Pros:**
- o Enhanced security (FIPS 140-2, CIS hardening)
- o Embedded etcd support
- o Good for air-gapped environments
- o Rancher ecosystem integration

**Cons:**
- x Slightly higher resource usage than k3s (~800MB RAM)
- x More complex than k3s for single-node
- x Smaller community compared to k3s or full k8s
- x Requires understanding Rancher ecosystem

**Cost Estimate**:
- Hardware: $0
- Operations: 10-12 hours/month maintenance
- Learning curve: Medium (Rancher-specific concepts)

---

### Option 3: k3s

**Description**: Lightweight Kubernetes distribution by Rancher (now SUSE)

**Pros:**
- o **Minimal resource overhead** (~500MB RAM for control plane)
- o **Single binary** - extremely easy to install/upgrade
- o **Embedded etcd** - true single-node HA without external dependencies
- o **Production-ready** - used by CNCF, edge computing, IoT
- o **Full Kubernetes API compatibility** - can run any k8s workload
- o **Active community** - 27k+ GitHub stars, frequent releases
- o **GPU Operator compatible** - same as full k8s
- o **Easy multi-node expansion** - simple to add nodes later

**Cons:**
- x Some components replaced (e.g., sqlite instead of etcd by default)
- x Not every Kubernetes feature flag available
- x Slightly less enterprise "credibility" vs full k8s (perception issue)

**Cost Estimate**:
- Hardware: $0
- Operations: 5-8 hours/month maintenance (simple upgrades)
- Learning curve: Low (standard kubectl knowledge applies)

---

## Decision Outcome

**Chosen option**: Option 3 - k3s

**Rationale:**

1. **Resource Efficiency**
   - Saves ~1GB RAM vs full k8s, critical for maximizing ML workload capacity
   - On our 128GB machine, this translates to ~8% more memory for training

2. **Operational Simplicity**
   - Single binary installation: `curl -sfL https://get.k3s.io | sh -`
   - Upgrades: `k3s-upgrade` or simple systemd service restart
   - Reduces maintenance burden from 20h/month to 5-8h/month

3. **Team Scalability**
   - Junior engineers can manage it with minimal training
   - Standard kubectl commands work identically
   - Reduces onboarding time from 2 weeks to 3 days

4. **Future-Proof**
   - Proven in production (Cloudflare, Siemens use k3s at scale)
   - Can seamlessly add nodes: `k3s agent --server https://...`
   - Full Kubernetes API means no vendor lock-in

5. **Cost-Benefit Analysis**
   - Saves 10-15 hours/month vs full k8s = $5,000-$7,500/year (at $50/hour)
   - Zero licensing cost (unlike some commercial k8s distributions)

**Expected Benefits:**
- 50% reduction in platform maintenance time
- 30% faster onboarding for new team members
- Same production capabilities as full k8s

**Accepted Trade-offs:**
- Slightly less "enterprise" brand recognition (mitigated by production deployments)
- Some advanced k8s features not available (none needed for our use case)

---

## Consequences

### Positive
- Team can focus on ML platform features instead of k8s operations
- Lower barrier to entry for GPU-enabled Kubernetes
- Faster iteration cycles due to simple upgrades
- Easy to demonstrate in interviews/demos

### Negative
- Some recruiters may not recognize k3s as "real Kubernetes"  
  → **Mitigation**: Emphasize k3s is CNCF-certified, API-compatible, used by Fortune 500
- May need to justify choice in interviews  
  → **Mitigation**: This ADR document itself serves as justification

### Neutral
- Need to use `k3s kubectl` instead of `kubectl` (unless aliased)
- Default ingress is Traefik instead of nginx (actually a positive for our use case)

---

## Implementation Plan

1. **Phase 1** (Week 1): Install k3s with embedded etcd
```bash
   curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --cluster-init" sh -
```

2. **Phase 2** (Week 1): Install NVIDIA GPU Operator
   - Verify GPU detection
   - Configure time-slicing for multi-user access

3. **Phase 3** (Week 2): Deploy core platform services
   - ArgoCD for GitOps
   - Prometheus/Grafana for monitoring
   - Traefik ingress with Let's Encrypt

4. **Phase 4** (Week 3): Deploy ML services
   - JupyterHub, Ollama, training pipelines

**Success Metrics:**
- Cluster uptime > 99.5% (max 3.6 hours downtime/month)
- Platform maintenance < 8 hours/month
- GPU utilization > 70% during work hours
- New engineer can deploy a workload in < 30 minutes

---

## References

- [k3s Official Docs](https://docs.k3s.io/)
- [CNCF k3s Conformance](https://www.cncf.io/certification/software-conformance/)
- [k3s vs k8s Resource Comparison](https://www.suse.com/c/rancher_blog/k3s-vs-k8s/)
- [NVIDIA GPU Operator on k3s](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/platform-support.html)

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2025-12-31 | Range | 0.1.0 |

