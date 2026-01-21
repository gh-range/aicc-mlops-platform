# 12-Month Operating Plan: AI Data Center MLOps Platform

**Version**: 0.2 
**Date**: 2026-01-21  
**Owner**: AI Infrastructure Lead  
**Review Cycle**: Quarterly

---

## Executive Summary

This document outlines a 12-month roadmap to scale our single-node AI/ML platform into a production-grade, multi-node GPU cluster capable of serving 10-20 data scientists and ML engineers. The plan covers infrastructure expansion, team growth, strategic budget allocation, and risk management.

**Key Objectives:**
- Scale from 1 node → 5 nodes (5x GPU capacity)
- Support 5 concurrent users → 20 concurrent users
- Establish 24/7 operational readiness
- Implement cost-per-GPU-hour tracking
- Build a 3-person infrastructure team

**Strategic Vision:**
This MAV (Micro-Architecture Validation) deployment serves as the technical foundation for large-scale commercial infrastructure. Validated patterns will scale to multi-rack NVIDIA B200 SuperPod environments (target: 128+ GPU deployment).

---

## Current State (Month 0)

### Infrastructure

| Component | Specification | Utilization |
|-----------|---------------|-------------|
| Nodes | 1x Ubuntu 24.04 | N/A |
| CPU | i9-10900F (10C/20T) | ~30% average |
| RAM | 128GB DDR4 | ~40GB used |
| GPU | 1x RTX A4000 16GB | ~60% utilization |
| Storage1 | 1TB M.2 SSD | 200GB used |
| Storage2 | 2TB RAID 10 SSD | 800GB used |
| Network | 1Gbps | ~100Mbps peak |

### Team

- **Current**: 1 Infrastructure Engineer
- **Bottlenecks**: On-call burden, single point of failure

### Costs

- **Capex**: Initial hardware investment completed
- **Opex**: 
  - Electricity: ~$10/month (24/7 operation, local rates)
  - Internet + DNS/SSL: $40/month
**Total Monthly**: ~$50

---

## Q1 2026 (Months 1-3): Foundation

### Goals

- Complete single-node platform (k3s, GPU Operator, monitoring)
- Deploy core ML services (JupyterHub, Ollama, training pipeline)
- Establish GitOps workflow (ArgoCD, CI/CD)
- Document all runbooks and disaster recovery procedures

### Infrastructure Changes

**Planned Additions:**
- Network upgrade (2.5Gbps NIC + managed switch)
- ISP bandwidth increase for remote access
- UPS backup power (1kVA on-line unit for service continuity)
- External NAS storage (4TB for distributed workloads)

**Investment Approach**: Phased procurement based on validated requirements

### Team

- **Current**: 1 engineer
- **Action**: Begin recruiting for DevOps Engineer (start Month 3)

### Deliverables

1. **Week 4**: Production k3s cluster with GPU support
2. **Week 8**: All ML services operational
3. **Week 12**: Complete documentation + disaster recovery tested

### KPIs

- Platform uptime: >99% (max 7 hours downtime)
- GPU utilization: >60%
- User satisfaction: >4.0/5.0 (survey)
- Documentation coverage: 100% of critical systems

---

## Q2 2026 (Months 4-6): Team Building

### Goals

- Hire DevOps Engineer
- Add 2nd GPU node (identical to first)
- Implement advanced monitoring (cost tracking, chargeback)
- Launch internal "GPU-as-a-Service" for other departments

### Infrastructure Changes

**Node 2 Procurement:**
- Specification: Match or exceed Node 1 capabilities
- Target: i9-12900 or equivalent, 128GB DDR5, RTX A4000 16GB
- Setup time: 2 weeks (OS install, k3s join, validation)

**Network Enhancement:**
- Managed 2.5Gbps switch for node interconnect

**Budget Allocation**: Strategic capex investment in Q2, exact amounts subject to market conditions and hardware availability

### Team

- **Addition**: 1x DevOps Engineer
- **Total team**: 2 engineers
- **On-call rotation**: Established (1 week on, 1 week off)

### Deliverables

1. **Month 4**: DevOps Engineer onboarded
2. **Month 5**: Node 2 operational, multi-node tested
3. **Month 6**: Cost tracking dashboard launched

### KPIs

- Cluster uptime: >99.5%
- GPU utilization: >70%
- Cost per GPU-hour: Market-competitive rates
- Incident MTTR: <2 hours

---

## Q3 2026 (Months 7-9): Scalability

### Goals

- Add Node 3 (total 3x RTX A4000)
- Deploy Kubeflow for ML pipelines
- Implement model registry (MLflow)
- Support 15 concurrent users

### Infrastructure Changes

**Node 3 Procurement:**
- Specification: Consistent with Node 2
- High-availability networking: Redundant switch configuration

**Software Stack:**
- S3-compatible object storage: MinIO cluster (open source)
- Container registry: Harbor (open source)

**Investment Strategy**: Continue phased hardware acquisition aligned with user demand

### Team

- **Addition**: 1x ML Platform Engineer
- **Total team**: 3 engineers
- **Structure**:
  - Infrastructure Lead: Strategy, architecture
  - DevOps Engineer: Operations, monitoring
  - ML Platform Engineer: Kubeflow, MLflow, user support

### Deliverables

1. **Month 7**: Node 3 operational
2. **Month 8**: Kubeflow deployed, first pipeline running
3. **Month 9**: MLflow model registry integrated

### KPIs

- Cluster uptime: >99.7%
- GPU utilization: >75%
- Active users: 15+
- Model deployment time: <10 minutes (registry → inference)

---

## Q4 2026 (Months 10-12): Productionization

### Goals

- Add Nodes 4 & 5 (total 5x RTX A4000 = 80GB VRAM)
- Implement enterprise features (LDAP, SSO, audit logs)
- Prepare for SOC 2 compliance audit
- Validate architecture for B200 SuperPod migration

### Infrastructure Changes

**Nodes 4 & 5:**
- Dual-node deployment for HA testing

**Enterprise Enhancements:**
- Backup solution: Velero + S3 storage
- LDAP/Active Directory integration: FreeIPA (open source)
- Log aggregation: ELK stack (self-hosted)

**Strategic Planning**: Finalize B200 SuperPod architecture based on MAV validation results

### Team

- **Total**: 3 engineers (no additions)
- **Focus**: Efficiency improvements, automation, SuperPod preparation

### Deliverables

1. **Month 10**: Nodes 4 & 5 operational
2. **Month 11**: Enterprise features (SSO, audit logs) live
3. **Month 12**: SOC 2 readiness assessment + B200 migration blueprint complete

### KPIs

- Cluster uptime: >99.9% (SLA-grade)
- GPU utilization: >80%
- Active users: 20+
- Security incidents: 0
- Compliance readiness: 90%+

---

## Budget Summary

### Year 1 Investment Framework

| Category | Approach |
|----------|----------|
| **Capex (Hardware)** | Phased procurement aligned with validation milestones |
| - Initial MAV setup | Completed |
| - Nodes 2-5 expansion | Q2-Q4 strategic investment |
| - Networking & UPS | Q1-Q2 reliability enhancement |
| **Opex (Monthly)** | Incremental scaling from $50/month baseline |
| **Personnel** | 2 new hires (competitive market rates) |

**Financial Principles:**
- Hardware costs subject to market volatility (RAM, SSD, GPU availability)
- Exact budget finalized after MAV validation (Q1 completion)
- ROI targets aligned with commercial SuperPod economics

### Cost per GPU-Hour Projection

**Methodology:**
- 5 GPUs running 24/7 = 43,800 GPU-hours/year
- 3-year hardware depreciation cycle
- On-premise cost advantage vs. cloud (no egress fees, no vendor markup)

**Target Economics:**
- Infrastructure cost: Estimated sub-$0.20/GPU-hour (hardware only)
- Fully-loaded cost: Market-competitive with cloud offerings
- Break-even analysis: Updated post-MAV validation

**Cloud Comparison Baseline:**
- AWS p3.2xlarge (V100 16GB): $3.06/hour
- Azure NC6s v3 (V100 16GB): $3.06/hour
- GCP A2 (A100 40GB): $3.67/hour

---

## SuperPod Migration Strategy (128+ GPU Deployment)

### Phase 1: MAV Validation (Current)
- **Hardware**: RTX A4000 (5-node cluster)
- **Purpose**: Validate orchestration, multi-tenancy, GitOps workflows
- **Timeline**: Q1-Q4 2026

### Phase 2: Pilot SuperPod (2027)
- **Hardware**: NVIDIA B200 Blackwell architecture
- **Scale**: 8-16 GPU initial deployment
- **Infrastructure**: InfiniBand fabric, RDMA networking, NVLink
- **Purpose**: Production workload migration, performance benchmarking

### Phase 3: Full SuperPod Deployment (2027-2028)
- **Target Scale**: 128+ NVIDIA B200 GPUs
- **Architecture**: Multi-rack DGX SuperPod configuration
- **Networking**: NVIDIA Quantum-2 InfiniBand (400Gbps per port)
- **Storage**: GPUDirect Storage with NVMe-oF
- **Economics**: Commercial GPU rental services, multi-tenant SaaS

**Investment Timeline:**
- Q4 2026: Finalize B200 SuperPod budget and procurement plan
- Q1 2027: Data center site preparation and infrastructure
- Q2-Q3 2027: Hardware procurement and deployment
- Q4 2027: Production launch and commercial operations

---

## Risk Matrix

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **Hardware failure** | Medium | High | UPS, RAID, hot-spare components |
| **Single point of failure** | High | Critical | Hire team, document everything |
| **Budget overrun** | Medium | Medium | Phased approach, market-tracking procurement |
| **B200 availability constraints** | Medium | High | Early vendor engagement, flexible timelines |
| **Slow user adoption** | Medium | Medium | Regular training, support docs |
| **Security breach** | Low | High | NetworkPolicy, audit logs, patching |
| **Power outage** | Low | High | UPS (4-hour runtime), generator (future) |
| **Network bottleneck** | Medium | Medium | 10Gbps upgrade planning, monitoring |

---

## Success Metrics Dashboard

### Technical Metrics

- **Uptime**: 99.9% (track via Prometheus)
- **GPU Utilization**: 80% average (DCGM Exporter)
- **Job Queue Time**: <5 minutes (Kubernetes metrics)
- **Incident MTTR**: <1 hour (PagerDuty)

### Business Metrics

- **Active Users**: 20+ (JupyterHub analytics)
- **Cost per GPU-hour**: Market-competitive (internal chargeback)
- **Team Satisfaction**: >4.2/5.0 (quarterly survey)
- **Training Completed**: 80% of users (completion rate)

### Operational Metrics

- **Documentation Coverage**: 100% (runbook checklist)
- **Backup Success Rate**: 100% (daily verification)
- **Patch Compliance**: <7 days for critical CVEs
- **Change Failure Rate**: <5% (post-deployment issues)

---

## Quarterly Review Process

1. **Week 1 of Quarter**: Metrics review meeting
   - Compare actuals vs targets
   - Identify bottlenecks

2. **Week 2**: Budget reconciliation
   - Update cost projections based on market conditions
   - Adjust hiring timeline if needed

3. **Week 3**: Stakeholder presentation
   - Executive summary slides (see `docs/executive-summaries/`)
   - ROI demonstration
   - Next quarter priorities

4. **Week 4**: Plan adjustments
   - Update this document
   - Commit to Git (version control)

---

## Appendix: Build vs Buy Analysis

### Strategy Comparison

| Option | Approach | Advantage | Consideration |
|--------|----------|-----------|---------------|
| **Self-built (MAV → SuperPod)** | Phased validation | Full control, on-premise economics | Requires expertise, longer timeline |
| **Cloud GPU (AWS/Azure/GCP)** | Rental model | Instant access, managed service | High recurring costs, egress fees |
| **Commercial Platform (Run:ai, etc.)** | Licensed orchestration | Advanced scheduling | Additional licensing cost |
| **Hybrid Model** | MAV validation + cloud burst | Risk mitigation | Complexity in multi-cloud management |

**Strategic Decision:** MAV validation reduces risk for large-scale SuperPod investment

---

## References

- [NVIDIA B200 Platform Guide](https://www.nvidia.com/en-us/data-center/dgx-b200/)
- [NVIDIA GPU TCO Calculator](https://www.nvidia.com/en-us/data-center/gpu-tco-calculator/)
- [CNCF Cloud Native Maturity Model](https://maturitymodel.cncf.io/)

---

## Revision History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2025-12-31 | 0.1 | Range | Initial 12-month plan |
| 2026-01-21 | 0.2 | Range | Update B200 strategy, budget framework refinement |

---

<div align="center">

**This document should be reviewed and updated quarterly.**  
**Budget specifics finalized post-MAV validation (Q1 2026 completion).**

</div>
