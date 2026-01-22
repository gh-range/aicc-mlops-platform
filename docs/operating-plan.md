# Operating Plan: MAV to Commercial SuperPod

**Version**: 0.3
**Date**: 2026-01-22  
**Owner**: Infrastructure Architecture Team  
**Review Cycle**: Quarterly

---

## Executive Summary

This operating plan defines the strategic roadmap for scaling from a single-node Micro-Architecture Validation (MAV) platform to a commercial-grade 128-node NVIDIA B200 SuperPod serving GPU-as-a-Service customers or enterprise private cloud deployments.

**Strategic Approach**: Phased validation minimizes risk and capex exposure:
1. **MAV Phase (6 months)**: Validate architecture patterns at zero licensing cost
2. **HA Phase (6 months)**: Validate high availability and operational procedures
3. **Commercial Phase (12-18 months)**: Deploy production infrastructure with revenue generation

**Target Economics**:
- Break-even: 18 months post-commercial launch
- Revenue target: $2-4M/month at 80% GPU utilization
- TCO advantage: 40-50% lower than hyperscaler pricing (see ADR-005)

---

## Current State (Phase 1: MAV)

### Infrastructure Snapshot

| Component | Specification | Status |
|-----------|---------------|--------|
| **Nodes** | 1 (llm1) | Operational |
| **CPU** | i9-10900F (10C/20T) | ~30% average utilization |
| **RAM** | 128GB DDR4 | ~40GB used |
| **GPU** | 1x RTX A4000 16GB (4 virtual via time-slicing) | ~60% utilization |
| **Storage** | 1TB NVMe + 2TB RAID10 SSD | 1TB used |
| **Network** | 1Gbps Ethernet | ~100Mbps peak |
| **OS** | Ubuntu 24.04 LTS | Zabbix monitoring active |

### Team Structure

- **Current**: 1 Infrastructure Engineer (full-stack)
- **On-call**: Not formalized (single-person team)
- **Knowledge Transfer**: Documentation-driven (runbooks, ADRs)

### Monthly Operating Costs

| Category | Cost |
|----------|------|
| Electricity (24/7) | ~$10 |
| Internet + DNS/SSL | $40 |
| **Total** | **$50/month** |

**Hardware Capex**: Initial investment completed (estimated <$5K total including upgrades)

---

## Phase 1: Micro-Architecture Validation (Current)

**Timeline**: Month 1-6 (Q1-Q2 2026)  
**Status**: 60% complete

### Objectives

- [o] Validate GPU Time-Slicing for multi-tenancy
- [o] Validate ResourceQuota enforcement
- [o] Integrate JupyterHub with GPU allocation
- [ ] Complete GitOps workflow (ArgoCD ApplicationSets)
- [ ] Implement disaster recovery (Velero)
- [ ] Production-grade monitoring (Prometheus + Grafana dashboards)
- [ ] Document all operational runbooks

### Key Deliverables

**Week 1-4** (Complete):
- k3s cluster with GPU Operator
- Time-Slicing configuration (1 → 4 virtual GPUs)
- Multi-tenant namespaces with ResourceQuotas

**Week 5-8** (In Progress):
- JupyterHub deployment (GitHub OAuth)
- DCGM metrics integration
- ArgoCD installation

**Week 9-12** (Planned):
- Velero backup/restore testing
- Complete monitoring stack
- Operational runbook finalization

**Week 13-24** (Extended Validation):
- 30-day uptime test (target: 99%+)
- Load testing (sustained 60%+ GPU utilization)
- Documentation review and ADR finalization

### Success Metrics

| Metric | Target | Current |
|--------|--------|---------|
| GPU Utilization | >60% | ~60% |
| Platform Uptime | >99% | TBD (monitoring setup) |
| Documentation Coverage | 100% | ~70% |
| Team Onboarding Time | <3 days | N/A (single engineer) |

### Investment Summary

- **Capex**: $0 (hardware already procured)
- **Opex**: $50/month
- **Personnel**: 1 FTE (existing)
- **Software Licensing**: $0 (open-source stack)

**Total Phase 1 Cost**: ~$300 opex + existing salary

### Decision Gate (Month 6)

**Proceed to Phase 2 if**:
- All technical validation complete (>90% checklist)
- Team bandwidth available (or hire plan approved)
- Budget allocation secured for HA hardware ($30-50K)

---

## Phase 2: High-Availability Validation

**Timeline**: Month 7-12 (Q3-Q4 2026)  
**Status**: Planned

### Objectives

- Deploy 3-node k3s HA cluster
- Validate control plane failover (<30s)
- Implement distributed storage (Longhorn)
- Custom fair-share scheduler or Volcano adoption
- 7-day sustained load test (80%+ GPU utilization)
- Finalize commercial platform decision (Run:AI vs custom)

### Infrastructure Expansion

**New Hardware**:
- 2 additional nodes (specifications matching or exceeding Node 1)
- 10Gbps network switch (for storage replication)
- UPS backup power (1kVA on-line unit per node)
- NAS for centralized backups (4TB+)

**Software Additions**:
- Longhorn distributed storage
- MetalLB for load balancer VIP
- Thanos for long-term Prometheus storage
- Volcano scheduler (CNCF) or custom development

**Estimated Capex**: $30-50K (hardware + networking)  
**Estimated Opex**: +$30/month (electricity, ISP upgrade)

### Team Expansion

**Hiring Plan**:
- **Month 7**: Post job opening for DevOps Engineer
- **Month 8-9**: Interview and onboarding (4-week process)
- **Month 10**: Second engineer productive on HA deployment

**Team Structure (Post-Hire)**:
- Infrastructure Lead: Strategy, architecture, Phase 3 planning
- DevOps Engineer: HA cluster operations, monitoring, on-call rotation

**Personnel Cost**: +$120-150K annual salary (prorated for 6 months)

### Key Deliverables

**Month 7**:
- Hardware procurement and setup
- 3-node k3s cluster deployed
- Control plane HA validated

**Month 8-9**:
- Longhorn storage tested (failover, data integrity)
- Scheduler implementation (Volcano or custom)
- New engineer onboarded

**Month 10-11**:
- 7-day load test (80%+ GPU utilization)
- Chaos engineering (inject failures, validate recovery)
- Commercial platform evaluation (Run:AI demo, cost analysis)

**Month 12**:
- Phase 2 validation report
- Phase 3 business case presentation
- ADR-006: Final platform selection (Run:AI vs custom vs hybrid)

### Success Metrics

| Metric | Target |
|--------|--------|
| HA Uptime | >99.5% (max 3.6 hours downtime/month) |
| Failover Time | <30 seconds (pod rescheduling) |
| GPU Utilization | >75% (sustained over 7 days) |
| Storage Replication | 100% data integrity after failover |
| Team Redundancy | 2 engineers both on-call capable |

### Investment Summary

- **Capex**: $30-50K (hardware)
- **Opex**: $80/month ($50 + $30 expansion)
- **Personnel**: 2 FTE (1 new hire)
- **Total Phase 2 Cost**: ~$90-110K (capex + 6 months opex + prorated salary)

### Decision Gate (Month 12)

**Proceed to Phase 3 if**:
- HA validation successful (all metrics met)
- Commercial platform decision finalized (ADR-006 approved)
- Phase 3 funding secured (estimated $8-15M capex)
- Data center site selection complete

---

## Phase 3: Commercial SuperPod Deployment

**Timeline**: Month 13-30 (2027-2028, 18 months)  
**Status**: Planning

### Objectives

- Deploy 128-node NVIDIA B200 SuperPod (1024+ GPUs)
- Achieve 99.99% SLA (max 52 minutes downtime/year)
- Launch GPU-as-a-Service commercial platform
- Onboard 10+ enterprise customers
- Reach break-even within 18 months of launch

### Infrastructure Scale

**Target Cluster**:
- **Nodes**: 128 (DGX B200 or equivalent)
- **GPUs**: 1024 (8 per node, 180GB HBM3e each)
- **CPU**: 32,768 cores (AMD EPYC Genoa)
- **RAM**: 16 TB total
- **Storage**: 3.84 PB NVMe (GPUDirect Storage)
- **Network**: InfiniBand NDR (400Gbps per node)

**Data Center Requirements**:
- Power: 1.5-2.0 MW (15kW per node)
- Cooling: Liquid-to-chip or rear-door heat exchangers
- Space: 2000+ sq ft raised floor
- Connectivity: 100Gbps redundant internet uplinks

**Software Platform** (Decision at Phase 2 completion):
- Orchestration: Kubernetes (standard distribution or RKE2)
- GPU Management: GPU Operator with MIG profiles
- Commercial Platform: Run:AI, custom, or hybrid (see ADR-005)
- Billing: Custom integration (Stripe, Chargebee, or enterprise CRM)

### Deployment Timeline

**Months 13-15: Planning & Procurement**
- Data center site selection (colocation vs on-premise)
- B200 GPU pre-order (12-18 month lead time)
- InfiniBand fabric design (NVIDIA Quantum-2 switches)
- Hire core team (SREs, network engineers, customer support)

**Months 16-18: Infrastructure Build**
- Data center power/cooling installation
- InfiniBand fabric deployment
- Hardware staging and burn-in testing

**Months 19-21: Software Deployment**
- Kubernetes cluster bootstrap
- GPU Operator with MIG configuration
- Commercial billing system integration
- Security hardening (Zero-Trust, compliance audits)

**Months 22-24: Customer Onboarding**
- Beta customer program (10% capacity)
- SLA validation (99.99% uptime testing)
- Monitoring and alerting tuning

**Months 25-30: Revenue Ramp**
- General availability launch
- Target: 50% utilization by Month 27
- Target: 80% utilization by Month 30 (break-even)

### Team Structure (Full Commercial Team)

**Infrastructure (5 FTE)**:
- SRE Lead (on-call coordinator)
- 2x Platform Engineers (Kubernetes, GPU Operator)
- 2x Network Engineers (InfiniBand, BGP)

**Customer Success (3 FTE)**:
- Support Lead
- 2x Customer Success Engineers (24/7 rotation)

**Security & Compliance (2 FTE)**:
- Security Engineer (pen testing, Zero-Trust)
- Compliance Officer (SOC 2, GDPR)

**Business Development (2 FTE)** (not included in technical team budget):
- Sales Engineer
- Account Manager

**Total Technical Team**: 10 FTE

### Revenue Model

**Pricing Tiers**:

| Tier | Product | Price | Target Market |
|------|---------|-------|---------------|
| **On-Demand** | B200 MIG (1/7 GPU) | $3.50/hour | Startups, research |
| **On-Demand** | B200 Full GPU | $28/hour | Production workloads |
| **Reserved 1-year** | 20% discount | $2.80/hour | Enterprise batch jobs |
| **Reserved 3-year** | 30% discount | $2.45/hour | Fortune 500 |
| **Spot** | Dynamic pricing | $1.50-2.50/hour | Fault-tolerant workloads |

**Utilization Targets**:
- Month 1-6: 30% (beta customers)
- Month 7-12: 50% (general availability)
- Month 13-18: 80% (break-even, profitability)

**Revenue Projections** (80% utilization, average $2.50/hour):
- 1024 GPUs × 0.80 × 730 hours/month × $2.50 = **$1.49M/month**
- Annual revenue: **$17.9M/year**

**Break-Even Analysis**:
- Annual costs: ~$8-10M (hardware amortization + opex + personnel)
- Break-even: 50-55% utilization sustained
- Target margin: 40-50% at 80% utilization

### Investment Summary

**Phase 3 Capex** (one-time):
- Hardware (128 DGX B200): $8-12M (estimated $70-90K per node)
- InfiniBand fabric: $1-2M
- Data center build-out: $500K-1M (if on-premise)
- Professional services (deployment): $200K
- **Total Capex**: **$10-15M**

**Phase 3 Opex** (annual):
- Data center costs: $1.5-2M/year (power, cooling, space)
- Internet connectivity: $150K/year (100Gbps)
- Software licensing: $0-3.8M/year (if Run:AI, see ADR-005)
- Maintenance contracts: $500K/year (NVIDIA support)
- **Total Opex**: **$2.2-6.5M/year** (depends on platform choice)

**Phase 3 Personnel** (annual):
- 10 FTE × $120-150K average = **$1.2-1.5M/year**

**Total Year 1 Cost**: $10-15M capex + $3.4-8M opex = **$13.4-23M**

**Funding Strategy**:
- Venture capital or private equity (50-70% of capex)
- Pre-sales commitments (enterprise customers, 20-30%)
- Retained earnings or line of credit (10-20%)

### Success Metrics

**Technical**:
- 99.99% uptime (SLA compliance)
- GPU utilization >80%
- Mean time to resolution (MTTR) <1 hour
- Zero security incidents

**Business**:
- 10+ enterprise customers signed
- $1.5M+ monthly recurring revenue
- Customer churn <10% annually
- Net Promoter Score (NPS) >50

**Operational**:
- On-call incident load <5 per week
- Automated resolution rate >70%
- Documentation coverage 100%
- Employee retention >90%

---

## Risk Management

### Phase 1 Risks (MAV)

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Single engineer burnout | Medium | High | Document everything, flexible timeline |
| Hardware failure (no redundancy) | Low | Medium | Cloud backup (offsite Velero snapshots) |
| Budget constraints for Phase 2 | Low | High | Demonstrate clear ROI, seek early funding approval |

### Phase 2 Risks (HA)

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Hiring delays | Medium | Medium | Start recruitment early (Month 7) |
| k3s performance issues | Low | Medium | Validate at 3-node scale; fallback to k8s if needed |
| HA complexity underestimated | Medium | High | Allocate 4 months instead of 3 for testing |

### Phase 3 Risks (Commercial)

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| B200 GPU shortage | High | Critical | Pre-order 12+ months ahead, dual-source (H200 fallback) |
| Funding shortfall | Medium | Critical | Secure commitments early, phased deployment (64 nodes → 128 nodes) |
| Customer acquisition slower than projected | Medium | High | Pre-sales during Phase 2, incentivize early adopters |
| Run:AI pricing increases | Medium | Medium | Negotiate multi-year contract with price cap |
| Data center delays | Medium | High | Select colocation (faster than on-premise build) |
| Security breach | Low | Critical | Zero-Trust architecture, quarterly pen tests, bug bounty |

---

## Quarterly Review Process

### Review Cadence

**Month 3, 6, 9, 12** (and quarterly thereafter):

1. **Week 1**: Metrics review meeting
   - Compare actuals vs targets
   - Identify bottlenecks and risks

2. **Week 2**: Financial reconciliation
   - Budget vs actual spending
   - Revenue projections (Phase 3 only)

3. **Week 3**: Stakeholder presentation
   - Executive summary deck
   - Go/no-go decision for next phase

4. **Week 4**: Plan adjustments
   - Update operating plan (version control)
   - Revise ADRs if strategy changes

### Key Performance Indicators (KPIs)

**Technical KPIs**:
- Platform uptime %
- GPU utilization %
- Incident MTTR
- Deployment frequency (GitOps velocity)

**Business KPIs**:
- Revenue (Phase 3 only)
- Customer acquisition cost (CAC)
- Customer lifetime value (LTV)
- Burn rate vs runway

**Operational KPIs**:
- Team satisfaction (quarterly survey)
- On-call load (incidents per week)
- Documentation coverage %
- Hiring pipeline health

---

## Competitive Analysis

### Build vs Buy vs Rent

| Option | Year 1 Cost | Year 3 Cost | Control | Flexibility |
|--------|-------------|-------------|---------|-------------|
| **Self-Built (this plan)** | $13-23M | $20-40M | Full | Maximum |
| **AWS/Azure GPU Rental** | $32M | $96M | Minimal | High (pay-as-go) |
| **Run:AI + Cloud** | $35M | $100M | Medium | Medium |
| **Managed Service (CoreWeave)** | $28M | $84M | Low | High |

**Assumptions**: 1024 GPUs, 80% utilization, 3-year horizon

**Conclusion**: Self-built approach achieves 40-50% TCO savings at commercial scale, justifying upfront investment.

### Market Positioning

**Target Segment**: Mid-market AI companies and enterprise private cloud

**Competitive Advantages**:
- **Price**: 15-25% below hyperscaler on-demand rates
- **Performance**: InfiniBand fabric (vs cloud TCP/IP)
- **Data Sovereignty**: On-premise option for regulated industries
- **Support**: Dedicated customer success engineers

**Competitive Disadvantages**:
- **Scale**: Cannot match hyperscaler global footprint
- **Elasticity**: Fixed capacity (must pre-provision)
- **Brand**: Unknown vs AWS/Azure/GCP

**Mitigation**:
- Partner with cloud providers (hybrid model: burst to cloud)
- Focus on niche markets (finance, healthcare, government)
- Build reputation through case studies and whitepapers

---

## Appendix: Phased Procurement Strategy

### Phase 1 (Complete)
- $0 new investment (existing hardware)

### Phase 2 (Q3-Q4 2026)
- **Month 7**: RFQ for 2 nodes + networking
- **Month 8**: Purchase order, 4-6 week lead time
- **Month 9**: Hardware arrival, deployment

### Phase 3 (2027-2028)
- **Month 13**: Data center site selection finalized
- **Month 14**: B200 GPU pre-order (NVIDIA Enterprise Alliance)
- **Month 15**: InfiniBand fabric procurement
- **Month 16-18**: Hardware staging, phased deployment
  - Stage 1: 32 nodes (2 racks)
  - Stage 2: 64 nodes (4 racks)
  - Stage 3: 128 nodes (8 racks)

**Risk Mitigation**: Phased deployment reduces cash flow pressure and allows early revenue generation from partial capacity.

---

## Revision History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2025-12-31 | 0.1 | Range | Initial 12-month plan |
| 2026-01-21 | 0.2 | Range | Budget refinement, B200 strategy |
| 2026-01-22 | 0.3 | Range | Complete rewrite: 3-phase roadmap (MAV → HA → SuperPod) |

---

<div align="center">

**Next Review**: 2026-04-22 (Q1 completion checkpoint)  
**Decision Gate**: 2026-07-01 (Phase 2 go/no-go)  
**Commercial Launch Target**: Q1 2027

**For detailed technical specifications, see [Scaling Roadmap](architecture/scaling-roadmap.md)**

</div>

