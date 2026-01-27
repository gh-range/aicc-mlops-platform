# ADR-001: Choose k3s over Full Kubernetes and RKE2

**Status**: Accepted  
**Date**: 2025-12-31  
**Updated**: 2026-01-22 (Added migration path analysis)  
**Deciders**: Infrastructure Lead, Platform Team  
**Technical Story**: Phased deployment from single-node MAV to 128-node SuperPod

---

## Context and Problem Statement

We are building a commercial AI Computing Center with a three-phase deployment strategy:
- **Phase 1 (MAV)**: 1-node validation platform
- **Phase 2 (HA)**: 3-node high-availability cluster
- **Phase 3 (SuperPod)**: 128-node NVIDIA B200 commercial infrastructure (1024+ GPUs)

The orchestration platform must:
- Support rapid prototyping at Phase 1 (zero licensing cost)
- Validate HA patterns at Phase 2 (minimal complexity)
- Provide clear migration path to production Kubernetes at Phase 3
- Support GPU scheduling, multi-tenancy, and commercial billing

**Key Constraint**: Phase 1 and 2 are validation phases, not production revenue-generating deployments. Risk mitigation requires deferring commercial platform costs until Phase 3 business case is proven.

---

## Decision Drivers

### Phase 1-2 Requirements (Validation)
- Zero software licensing costs
- Low operational overhead (1-3 person team)
- Fast iteration cycles (simple upgrades)
- GPU Operator compatibility
- Proven in production (reference deployments)

### Phase 3 Requirements (Commercial)
- 128-node scale (1024 GPUs)
- 99.99% SLA capability
- Commercial platform integration (Run:AI or custom)
- Clear migration path from Phase 2
- No vendor lock-in

---

## Considered Options

### Option 1: Full Kubernetes (kubeadm)

**Description**: Official Kubernetes using kubeadm for cluster bootstrapping

**Pros:**
- [o] Industry standard, widest ecosystem compatibility
- [o] Most comprehensive documentation
- [o] Direct upstream updates
- [o] Maximum flexibility at scale

**Cons:**
- [x] Requires external etcd for HA (overkill for single node)
- [x] Higher resource overhead (~1.5GB RAM for control plane)
- [x] More complex to set up and maintain
- [x] Slower release cycle means delayed features

**Cost Estimate** (Phase 1-2): 
- Hardware: $0 (can run on existing machine)
- Operations: 15-20 hours/month maintenance
- Learning curve: High for junior team members

**Migration Requirement**: None (used from start)

---

### Option 2: RKE2 (Rancher Kubernetes Engine 2)

**Description**: Rancher's security-focused Kubernetes distribution

**Pros:**
- [o] Enhanced security (FIPS 140-2, CIS hardening)
- [o] Embedded etcd support
- [o] Good for air-gapped environments
- [o] Rancher ecosystem integration

**Cons:**
- [x] Slightly higher resource usage than k3s (~800MB RAM)
- [x] More complex than k3s for single-node
- [x] Smaller community compared to k3s or full k8s
- [x] Requires understanding Rancher ecosystem

**Cost Estimate** (Phase 1-2):
- Hardware: $0
- Operations: 10-12 hours/month maintenance
- Learning curve: Medium (Rancher-specific concepts)

**Migration Requirement**: Potentially to standard k8s at Phase 3

---

### Option 3: k3s (Chosen for Phase 1-2)

**Description**: Lightweight Kubernetes distribution by Rancher (now SUSE)

**Pros:**
- [o] **Minimal resource overhead** (~500MB RAM for control plane)
- [o] **Single binary** - extremely easy to install/upgrade
- [o] **Embedded etcd** - true single-node HA without external dependencies
- [o] **Production-ready** - used by CNCF, edge computing, IoT
- [o] **Full Kubernetes API compatibility** - can run any k8s workload
- [o] **Active community** - 27k+ GitHub stars, frequent releases
- [o] **GPU Operator compatible** - same as full k8s
- [o] **Easy multi-node expansion** - simple to add nodes later

**Cons:**
- [x] Some components replaced (e.g., sqlite instead of etcd by default)
- [x] Not every Kubernetes feature flag available
- [x] Slightly less enterprise "credibility" vs full k8s (perception issue)
- [x] **128-node scale untested** (migration to k8s recommended at Phase 3)

**Cost Estimate** (Phase 1-2):
- Hardware: $0
- Operations: 5-8 hours/month maintenance (simple upgrades)
- Learning curve: Low (standard kubectl knowledge applies)

**Migration Requirement**: Yes, to standard k8s at Phase 3 (see migration analysis below)

---

## Decision Outcome

**Chosen option**: **k3s for Phase 1-2, migrate to standard Kubernetes for Phase 3**

### Rationale by Phase

**Phase 1 (MAV - 1 node)**:
1. **Zero Risk Validation**: Test orchestration patterns without commercial licensing commitment
2. **Resource Efficiency**: Saves ~1GB RAM vs full k8s (critical for maximizing ML workload capacity)
3. **Learning Depth**: Team gains deep Kubernetes GPU scheduling knowledge
4. **Rapid Iteration**: Simple upgrades enable fast experimentation

**Phase 2 (HA - 3 nodes)**:
1. **HA Validation**: k3s embedded etcd proves HA patterns work
2. **Cost Deferral**: Continue zero licensing costs while validating architecture
3. **Operational Simplicity**: k3s handles 3-node scale effortlessly (proven to 100+ nodes)
4. **Migration Readiness**: All Phase 2 workloads will run identically on Phase 3 k8s

**Phase 3 (SuperPod - 128 nodes)**:
1. **Production Grade**: Migrate to standard k8s for enterprise credibility
2. **Scale Confidence**: k3s documentation recommends k8s for >100 nodes
3. **Commercial Platform Support**: Run:AI and similar platforms officially support standard k8s
4. **Vendor Flexibility**: Standard k8s maximizes choice of commercial add-ons

**Expected Benefits**:
- Phase 1-2: 50% reduction in platform maintenance time vs full k8s
- Phase 1-2: Zero software licensing costs ($0 vs $3.8M for Run:AI)
- Phase 3: Validated architecture reduces migration risk to near-zero

**Accepted Trade-offs**:
- One-time migration effort at Phase 2 → Phase 3 transition (~4 weeks, see below)
- Team learns k3s-specific patterns first, then standard k8s (educational benefit)

---

## Migration Path: k3s → Standard Kubernetes

### Compatibility Analysis

**API Compatibility**: ✓ 100%
- k3s is CNCF-certified Kubernetes conformant
- All Kubernetes APIs function identically
- kubectl commands work without modification
- Helm charts, Operators, CRDs: zero changes required

**Component Differences**:
| Component | k3s | Standard k8s | Impact |
|-----------|-----|--------------|--------|
| **etcd** | Embedded (optional) | External cluster | k3s can use external etcd (same as k8s) |
| **Datastore** | sqlite (default) or etcd | etcd only | Phase 2 uses embedded etcd (same data model) |
| **Ingress** | Traefik (default) | None (manual install) | Traefik works identically on k8s |
| **Storage** | local-path | None (manual install) | Phase 3 uses Longhorn/Ceph (k8s-native) |
| **CNI** | Flannel (default) | None (manual install) | Phase 3 uses Calico (k8s-native) |

**Workload Compatibility**: ✓ 100%
- All Phase 1-2 workloads (Pods, Deployments, Services) run unchanged on k8s
- GPU Operator deployment identical (same Helm chart)
- ArgoCD, Prometheus, Grafana: zero modifications

---

### Migration Strategy

**Approach**: Parallel deployment (zero downtime)

**Timeline**: 4 weeks

#### Week 1: Build Parallel k8s Cluster

```bash
# Deploy new 128-node k8s cluster (Phase 3 hardware)
# Keep Phase 2 k3s cluster running

# 1. Bootstrap k8s control plane (5 master nodes)
kubeadm init --control-plane-endpoint=k8s-api.example.com

# 2. Join worker nodes (128 GPU nodes)
kubeadm join k8s-api.example.com:6443 --token <token>

# 3. Install GPU Operator (identical config to Phase 2)
helm install gpu-operator nvidia/gpu-operator \
  --namespace gpu-operator \
  --create-namespace \
  -f phase2/gpu-operator-values.yaml  # Same values file

# 4. Verify GPU capacity
kubectl get nodes -o json | jq '.items[].status.allocatable."nvidia.com/mig-1g.10gb"'
```

#### Week 2: Infrastructure Validation

```bash
# Deploy core platform services
kubectl apply -k infra/monitoring/  # Prometheus, Grafana
kubectl apply -k infra/storage/     # Longhorn
kubectl apply -k infra/networking/  # Calico, MetalLB

# Test GPU scheduling
kubectl run test-gpu --rm -it --image=nvidia/cuda:13.1.0-base \
  --limits=nvidia.com/mig-1g.10gb=1 \
  -- nvidia-smi

# Verify identical behavior to Phase 2
```

#### Week 3: Workload Migration

```bash
# Option A: GitOps (recommended)
# Point ArgoCD to new cluster, reapply all ApplicationSets
kubectl config use-context phase3-k8s
argocd cluster add phase3-k8s
argocd app sync --all

# Option B: Velero backup/restore
velero backup create phase2-full --include-namespaces='*'
velero restore create --from-backup phase2-full --context=phase3-k8s

# Option C: Manual migration (per namespace)
for ns in $(kubectl get ns -o name --context=phase2-k3s); do
  kubectl get all,pvc,configmap,secret -n $ns -o yaml --context=phase2-k3s | \
    kubectl apply -f - --context=phase3-k8s
done
```

**Gradual Customer Cutover**:
- Week 3 Day 1-2: Internal testing (10% traffic)
- Week 3 Day 3-4: Beta customers (30% traffic)
- Week 3 Day 5-7: All customers (100% traffic)

#### Week 4: Decommission Phase 2

```bash
# DNS cutover
# OLD: api.example.com → phase2-k3s VIP (10.0.1.100)
# NEW: api.example.com → phase3-k8s VIP (10.0.2.100)

# Keep Phase 2 k3s read-only for 30 days (rollback safety)
kubectl scale deployment --all --replicas=0 --context=phase2-k3s

# After 30 days: Full decommission
kubectl delete all --all-namespaces --context=phase2-k3s
k3s-uninstall.sh
```

---

### Migration Risk Mitigation

**Rollback Plan**:
- Phase 2 k3s cluster retained for 90 days post-migration
- DNS can be reverted in <5 minutes
- No data loss (Velero backups of both clusters)

**Testing Checklist**:
- [ ] GPU Operator all pods Running on k8s
- [ ] All Phase 2 workloads deployed on k8s
- [ ] GPU allocation identical (MIG instances)
- [ ] Monitoring metrics flowing to Prometheus
- [ ] Customer API endpoints responding
- [ ] Billing system calculating usage correctly
- [ ] 48-hour burn-in test (zero incidents)

**Estimated Downtime**: <5 minutes (DNS cutover window)

---

### Migration Effort Estimate

| Task | Hours | Owner |
|------|-------|-------|
| k8s cluster deployment | 40 | Platform Engineers (2) |
| Infrastructure validation | 16 | SRE Lead |
| Workload migration scripting | 24 | DevOps Engineer |
| Customer communication | 8 | Customer Success |
| Monitoring cutover | 16 | Platform Engineers |
| Documentation updates | 16 | Technical Writer |
| Post-migration support | 40 | On-call team (1 week) |
| **Total** | **160 hours** | **~1 FTE-month** |

**Cost**: ~$20K labor (at $125/hour blended rate)

---

## Phase 3: Why Not Continue with k3s?

### Technical Considerations

**k3s Scale Testing**:
- Officially tested: Up to 100 nodes (SUSE documentation)
- Community reports: Successful deployments at 150-200 nodes
- Our requirement: 128 nodes (within tested range)

**Decision Factors for Migration**:

1. **Enterprise Credibility** (High Priority)
   - Fortune 500 customers expect "Kubernetes" not "k3s"
   - Procurement teams may flag k3s as "non-standard"
   - Standard k8s reduces customer concerns

2. **Commercial Platform Support** (High Priority)
   - Run:AI documentation: Kubernetes 1.28+, no k3s mention
   - Vendor support contracts: May exclude k3s
   - Reduces integration risk

3. **Operational Best Practices** (Medium Priority)
   - Separate control plane (5 masters) from GPU nodes (128 workers)
   - Easier to scale control plane independently
   - Standard k8s architecture more familiar to new hires

4. **Risk Mitigation** (Medium Priority)
   - k3s at 128-node scale less battle-tested than k8s
   - Commercial deployment justifies "safe" choice
   - Lower insurance/audit risk

**Technical Verdict**: k3s could likely handle 128 nodes, but business case favors standard k8s.

---

### Alternative: Hybrid Architecture (Rejected)

**Concept**: Use k3s for edge clusters, k8s for core SuperPod

**Pros**:
- Leverage k3s simplicity for remote deployments
- Standard k8s for main commercial cluster

**Cons**:
- Two platform skillsets required
- Increased operational complexity
- Customer confusion (which cluster for which workload?)

**Verdict**: Rejected (unnecessary complexity for Phase 3)

---

## Success Metrics

### Phase 1 (MAV) - Q1-Q2 2026
- [o] k3s cluster operational
- [o] GPU utilization >60%
- [ ] Platform uptime >99%
- [ ] Zero licensing cost validated

### Phase 2 (HA) - Q3-Q4 2026
- [ ] 3-node k3s HA cluster operational
- [ ] Control plane failover <30 seconds
- [ ] GPU utilization >75%
- [ ] Migration plan documented (this ADR section)

### Phase 3 (Commercial) - 2027+
- [ ] Standard k8s cluster deployed (128 nodes)
- [ ] Migration from k3s completed (<5 min downtime)
- [ ] GPU utilization >80%
- [ ] Commercial billing system integrated
- [ ] 99.99% SLA achieved for 90 consecutive days

---

## Lessons Learned (Post-Migration - TBD)

**To be documented after Phase 3 migration**:
- Actual migration time vs estimate
- Unexpected issues encountered
- Customer feedback on cutover
- Recommendations for future migrations

---

## Alternatives Considered

### Continue k3s to Phase 3

**Argument**: k3s can technically handle 128 nodes

**Counter-Argument**:
- Enterprise customers expect standard k8s
- Commercial platform vendors officially support k8s only
- Risk of unknown issues at 128-node scale
- Migration effort (160 hours) justified by risk reduction

**Final Decision**: Migrate to standard k8s at Phase 3

---

### Use RKE2 Instead of Standard k8s

**Argument**: RKE2 provides enhanced security, simpler than k8s

**Counter-Argument**:
- RKE2 less common than kubeadm/standard k8s (hiring impact)
- Smaller ecosystem than standard k8s
- SUSE-specific features not required

**Final Decision**: Standard k8s (kubeadm or kops) for maximum compatibility

---

## References

- [k3s Official Docs](https://docs.k3s.io/)
- [CNCF k3s Conformance](https://www.cncf.io/certification/software-conformance/)
- [k3s vs k8s Resource Comparison](https://www.suse.com/c/rancher_blog/k3s-vs-k8s/)
- [k3s Production Deployments](https://docs.k3s.io/architecture)
- [Kubernetes kubeadm Setup](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [NVIDIA GPU Operator on Kubernetes](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/platform-support.html)

---

## Revision History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2025-12-31 | 0.1 | Range | Initial k3s selection rationale |
| 2026-01-22 | 0.2 | Range | Added Phase 3 migration analysis, 128-node strategy |

---

<div align="center">

**Current Phase**: 1 (k3s MAV)  
**Migration Decision Gate**: Q4 2026 (Post-Phase 2 validation)  
**Target Migration Date**: Q1 2027 (Phase 3 deployment)

**Related ADRs**: ADR-005 (Platform Comparison), ADR-004 (GPU Operator)

</div>

