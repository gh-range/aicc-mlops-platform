# ADR-005: GPU Orchestration Platform Selection Strategy

**Status**: Accepted  
**Date**: 2026-01-22  
**Deciders**: Infrastructure Lead, Platform Architecture Team  
**Technical Story**: Platform selection for 1024+ GPU commercial data center

---

## Context and Problem Statement

We are building a commercial-grade AI Computing Center with a phased deployment strategy:
- **Phase 1**: 1-node MAV (Micro-Architecture Validation)
- **Phase 2**: 3-node HA validation cluster
- **Phase 3**: 128-node B200 SuperPod (1024+ GPUs)

The platform will provide GPU-as-a-Service for external customers or serve as an enterprise private cloud. We must select an orchestration strategy that:
- Validates architectural patterns at small scale (MAV)
- Scales economically to 1024+ GPUs
- Provides commercial-grade multi-tenancy and billing
- Minimizes vendor lock-in risk
- Balances capex/opex for ROI optimization

---

## Decision Drivers

### Technical Requirements
- Multi-tenant GPU isolation (namespace, MIG, time-slicing)
- Dynamic resource allocation and fair-share scheduling
- GPU utilization tracking and chargeback metrics
- High availability (99.99% SLA target)
- Zero-downtime upgrades

### Business Requirements
- Total Cost of Ownership (TCO) optimization
- Vendor independence (avoid platform lock-in)
- Flexibility to pivot between rental vs private cloud models
- Competitive pricing vs hyperscalers (AWS, Azure, GCP)

### Operational Requirements
- Team size: 1 engineer (MAV) → 3-5 engineers (HA) → 10-15 engineers (SuperPod)
- Learning curve for new hires
- Community support and documentation quality
- Integration with existing CNCF ecosystem

---

## Considered Options

### Option 1: Native k3s + NVIDIA GPU Operator

**Architecture**:
```
k3s Cluster
├── NVIDIA GPU Operator (device plugin, DCGM, MIG)
├── Kubernetes ResourceQuotas
├── Custom scheduling policies (taints/tolerations)
└── Prometheus + Grafana (cost tracking)
```

**Pros**:
- [o] Zero software licensing costs
- [o] Full control over scheduling logic
- [o] Direct NVIDIA support (GPU Operator is official)
- [o] Proven at scale (Cloudflare, Siemens production deployments)
- [o] Easy MAV validation (simple setup)
- [o] k3s → k8s migration path well-documented

**Cons**:
- [x] Requires custom development for advanced scheduling
- [x] No built-in GPU pooling across namespaces
- [x] Manual integration of chargeback systems
- [x] Team must build fair-share algorithms

**TCO Analysis** (128-node, 1024 GPU, 3-year):
- Software licensing: $0
- Engineering (build custom tools): ~2 FTE × $150K × 3 = $900K
- Maintenance: 3 FTE × $120K × 3 = $1.08M
- **Total**: $1.98M

---

### Option 2: Run:AI Enterprise Platform

**Architecture**:
```
Kubernetes Cluster
├── Run:AI Control Plane (SaaS or self-hosted)
│   ├── Scheduler (gang scheduling, bin packing)
│   ├── GPU Pooling & Fractions
│   └── Chargeback Dashboard
├── NVIDIA GPU Operator
└── Run:AI Agent (per node)
```

**Pros**:
- [o] Advanced GPU pooling (share GPUs across namespaces)
- [o] Built-in fair-share and priority scheduling
- [o] Interactive workload preemption (Jupyter notebooks)
- [o] Commercial support and SLA
- [o] Integrated chargeback and utilization dashboards
- [o] Faster time-to-production

**Cons**:
- [x] **High licensing cost**: ~$1,000-1,500/GPU/year
- [x] Vendor lock-in (Run:AI-specific APIs)
- [x] Requires Kubernetes (no k3s official support in docs)
- [x] Less control over scheduling algorithms
- [x] Additional complexity in air-gapped environments

**TCO Analysis** (128-node, 1024 GPU, 3-year):
- Run:AI licenses: 1024 GPU × $1,250/year × 3 = $3.84M
- Engineering (integration): 1 FTE × $150K × 1 = $150K
- Maintenance: 2 FTE × $120K × 3 = $720K
- **Total**: $4.71M

---

### Option 3: Hybrid Approach (k3s + Selective Run:AI)

**Architecture**:
```
Phase 1 (MAV): k3s + GPU Operator only
Phase 2 (HA): k3s + GPU Operator + custom scheduling
Phase 3 (SuperPod): Kubernetes + Run:AI (for commercial features)
```

**Pros**:
- [o] Defer licensing costs until commercial launch
- [o] Validate architecture with zero capex
- [o] Learn Kubernetes GPU scheduling deeply before commercial platform
- [o] Flexibility to choose final platform after validation

**Cons**:
- [x] Potential rework when migrating to Run:AI
- [x] Team must maintain two skillsets
- [x] Risk of custom code becoming legacy

---

## Decision Outcome

**Chosen option**: **Option 3 - Hybrid Approach with staged adoption**

### Rationale

**Phase 1 (Current): k3s + GPU Operator**
- **Purpose**: Architectural validation, zero licensing risk
- **Scale**: 1 node → 3 nodes (MAV + HA validation)
- **Investment**: $0 software, minimal engineering overhead
- **Duration**: 6-12 months

**Justification**:
1. **Cost Efficiency**: MAV validation requires experimentation; licensing 4-12 GPUs at $5K-18K/year is wasteful
2. **Learning Depth**: Team gains deep Kubernetes GPU scheduling knowledge (valuable for troubleshooting at scale)
3. **Architecture Validation**: Proven patterns (ResourceQuota, time-slicing, MIG) work identically at SuperPod scale
4. **Vendor Independence**: No early lock-in; can evaluate multiple commercial platforms (Run:AI, Slurm, custom)

**Phase 2 (Target Q4 2026): k3s with Advanced Scheduling**
- **Purpose**: HA validation, custom fair-share implementation
- **Scale**: 3-node cluster (12-16 GPUs)
- **Investment**: 1-2 FTE for scheduler extensions
- **Decision Point**: Evaluate if custom solution meets 80% of Run:AI features

**Phase 3 (Target 2027): Kubernetes + Commercial Platform Evaluation**
- **Purpose**: Commercial launch (128-node, 1024+ GPU)
- **Platform Options**:
  1. Run:AI Enterprise (if ROI justifies $3.84M/3yr)
  2. Open-source Volcano Scheduler + custom billing
  3. Hybrid: k8s native + selective Run:AI for premium tiers

**Decision Triggers** (when to adopt Run:AI):
- Customer demand for SLA-backed resource guarantees
- Fair-share scheduling complexity exceeds team capacity (>3 months dev time)
- Competitive pressure requires faster feature parity with hyperscalers

---

## Comparative Analysis

### Feature Matrix

| Feature | k3s + GPU Operator | Run:AI Enterprise | Gap Analysis |
|---------|-------------------|-------------------|--------------|
| **GPU Time-Slicing** | [o] Native | [o] Enhanced | Run:AI adds dynamic fractions |
| **MIG Support** | [o] Native | [o] Automated | Similar capability |
| **Multi-Tenancy** | [o] Namespace + Quota | [o] Advanced Pooling | Run:AI allows cross-namespace sharing |
| **Fair-Share Scheduling** | [x] Manual | [o] Built-in | **Major Gap** |
| **Gang Scheduling** | [x] (Volcano addon) | [o] Built-in | Run:AI better for distributed training |
| **Preemption** | [o] Pod Priority | [o] Workload-aware | Run:AI checkpointing integration |
| **Chargeback/Billing** | [x] Custom | [o] Built-in Dashboard | **Major Gap** |
| **GPU Metrics** | [o] DCGM Exporter | [o] Enhanced UI | Similar data, Run:AI better UX |
| **SLA Guarantees** | [x] | [o] Commercial | Run:AI provides contractual SLA |

### Cost Comparison (1024 GPU, 3-year)

| Component | k3s + Operator | Run:AI | Delta |
|-----------|----------------|--------|-------|
| **Software License** | $0 | $3.84M | +$3.84M |
| **Engineering** | $900K (2 FTE) | $150K (0.5 FTE) | -$750K |
| **Maintenance** | $1.08M (3 FTE) | $720K (2 FTE) | -$360K |
| **Total** | **$1.98M** | **$4.71M** | **+$2.73M (138% premium)** |

**Break-Even Analysis**:
- Run:AI premium: $2.73M ÷ 1024 GPUs = **$2,667/GPU over 3 years**
- Monthly premium: $2,667 ÷ 36 = **$74/GPU/month**
- If rental rate is $2.50/GPU-hour → need **30 hours/month more utilization** to justify

**Conclusion**: Run:AI only justified if:
1. Fair-share scheduling increases utilization >5% (50 hours/month/GPU)
2. Faster GTM reduces time-to-revenue by >6 months
3. Enterprise customers require SLA-backed guarantees

---

## Migration Path Analysis

### k3s → Kubernetes (Standard Distribution)

**Compatibility**:
- [o] All k3s workloads run on standard k8s (CNCF conformant)
- [o] GPU Operator deployment identical
- [o] Helm charts, CRDs, operators unchanged

**Migration Strategy**:
```bash
# Phase 2 → Phase 3 Migration
1. Deploy new k8s cluster (kubeadm or RKE2)
2. Install GPU Operator with identical config
3. Velero backup/restore or GitOps redeploy
4. Cutover namespaces incrementally
5. Decommission k3s nodes
```

**Estimated Downtime**: <4 hours (per namespace, rolling migration)

**Risk Level**: Low (proven migration pattern, documented by Rancher/SUSE)

---

### Native k8s → Run:AI

**Integration Points**:
- Run:AI installs as Helm chart on existing k8s cluster
- Requires labeling nodes: `run.ai/node-type=gpu`
- Workloads modified to use Run:AI `RunaiJob` CRD (not native `Job`)

**Migration Complexity**: Medium
- Custom scheduling logic must be rewritten
- Existing ResourceQuotas replaced by Run:AI Projects
- DCGM metrics pipeline may need adjustment

**Estimated Effort**: 2-3 months (1 FTE)

**Reversibility**: High (Run:AI is additive; can uninstall and revert to native k8s)

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **Custom scheduler development exceeds capacity** | Medium | High | Evaluate Volcano scheduler (CNCF) before custom build |
| **Run:AI pricing increases** | Medium | Medium | Negotiate multi-year lock with price cap |
| **Team lacks Run:AI expertise at scale** | Low | Medium | Hire Run:AI-certified engineer in Phase 3 |
| **k3s performance issues at 3-node scale** | Low | Low | k3s proven to 100+ nodes (edge deployments) |
| **Vendor lock-in with Run:AI APIs** | Medium | High | Abstract workload submission via internal API layer |

---

## Success Metrics

### Phase 1 (MAV) - Q1-Q2 2026
- [ ] GPU utilization >60% with native time-slicing
- [ ] Multi-tenant namespaces with ResourceQuota enforcement
- [ ] DCGM metrics integrated to Prometheus
- [ ] Zero licensing cost validated

### Phase 2 (HA) - Q3-Q4 2026
- [ ] 3-node cluster with HA control plane
- [ ] Custom fair-share scheduler (if needed) or Volcano adoption
- [ ] Chargeback system prototype (cost per GPU-hour tracking)
- [ ] Decision document: Build vs Buy for Phase 3

### Phase 3 (Commercial) - 2027+
- [ ] 128-node cluster operational
- [ ] Commercial billing system integrated
- [ ] GPU utilization >80% (target for rental profitability)
- [ ] SLA compliance >99.99%
- [ ] Final platform selection (Run:AI, custom, or hybrid) based on validated ROI

---

## Alternatives Considered (Brief)

### Slurm + GPU
- **Pro**: HPC-proven, batch workload optimized
- **Con**: Poor fit for cloud-native apps, no Kubernetes integration
- **Verdict**: Rejected (not cloud-native)

### NVIDIA Base Command Platform
- **Pro**: Official NVIDIA stack, integrated monitoring
- **Con**: Requires DGX hardware, limited multi-cloud support
- **Verdict**: Deferred until Phase 3 hardware selection

### Custom Scheduler from Scratch
- **Pro**: Ultimate flexibility
- **Con**: >12 months development, high maintenance burden
- **Verdict**: Rejected (CNCF alternatives like Volcano sufficient)

---

## References

- [Run:AI Platform Overview](https://www.run.ai/)
- [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/)
- [Volcano Scheduler (CNCF)](https://volcano.sh/)
- [k3s Production Deployments](https://docs.k3s.io/architecture)
- [Run:AI vs Kubernetes Comparison (PDF)](https://pages.run.ai/hubfs/PDFs/RunAI-Platform-vs-Kubernetes.pdf)

---

## Revision History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2026-01-22 | 0.1 | Range | Initial platform comparison and hybrid strategy |

---

## Appendix: Run:AI Pricing Model (2026)

**Tier Structure** (per GPU/year):
- **Starter**: ~$800/GPU (basic scheduling, community support)
- **Professional**: ~$1,200/GPU (fair-share, chargeback, email support)
- **Enterprise**: ~$1,500/GPU (SLA, dedicated support, air-gap deployment)

**Volume Discounts**:
- 100-500 GPUs: 15% discount
- 500-1000 GPUs: 25% discount
- 1000+ GPUs: 30-35% discount (negotiable)

**Estimated Cost for 1024 GPUs** (Enterprise tier with 30% discount):
- List: 1024 × $1,500 = $1.536M/year
- Discounted: $1.536M × 0.70 = **$1.075M/year**
- 3-year commit: $1.075M × 3 = **$3.225M**

**Additional Costs**:
- Professional services (deployment): ~$50K one-time
- Training (10 engineers): ~$20K
- Maintenance (optional): 15% annual ($161K/year)

**Total 3-year TCO**: $3.225M + $50K + $20K + $483K = **$3.778M**

---

<div align="center">

**Decision Authority**: Infrastructure Lead  
**Review Cycle**: Quarterly (re-evaluate at Phase 2 completion)  
**Next Review**: 2026-Q4 (post-HA validation)

</div>
