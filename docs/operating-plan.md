# 12-Month Operating Plan: AI Data Center MLOps Platform

**Version**: 0.1 
**Date**: 2025-12-31  
**Owner**: AI Infrastructure Lead  
**Review Cycle**: Quarterly

---

## Executive Summary

This document outlines a 12-month roadmap to scale our single-node AI/ML platform into a production-grade, multi-node GPU cluster capable of serving 10-20 data scientists and ML engineers. The plan covers infrastructure expansion, team growth, budget allocation, and risk management.

**Key Objectives:**
- Scale from 1 node → 5 nodes (5x GPU capacity)
- Support 5 concurrent users → 20 concurrent users
- Establish 24/7 operational readiness
- Implement cost-per-GPU-hour tracking
- Build a 3-person infrastructure team

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

- **Current**: 1 Infrastructure Engineer (#whoami)
- **Bottlenecks**: On-call burden, single point of failure

### Costs

- **Capex**: $0 (In fact, I spent over USD$1050 in total to acquire the host and upgrade parts, but one SATA3 RAID card ended up unused.)
- **Opex**: 
  - Electricity: ~$10/month (24/7 operation, in my location)
  - Internet + DNS/SSL: $40/month
**Total Monthly**: ~$50

---

## Q1 2026 (Months 1-3): Foundation

### Goals

- o Complete single-node platform (k3s, GPU Operator, monitoring)
- o Deploy core ML services (JupyterHub, Ollama, training pipeline)
- o Establish GitOps workflow (ArgoCD, CI/CD)
- o Document all runbooks and disaster recovery procedures

### Infrastructure Changes

**Additions:**
- 2.5Gbps network upgrade(NIC + Switch):
- ISP upgrade(monthly):
- UPS backup power(1kVA On-Line unit):
- External NFS storage(4TB NAS):

**Capex**: $
**Opex**: +$x/month → $x+50/month total

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
- Hardware: ~$
  - CPU: i9-12900 ($ )
  - RAM: DDR5 128GB ($ )
  - GPU: RTX A4000 16GB ($ )
  - Motherboard + PSU + Case + Storage: $
- Setup time: 2 weeks (OS install, k3s join, validation)

**Network:**
- 2.5Gbps switch: $

**Capex**: $
**Opex**: +$20/month (electricity) → $ /month

### Team

- **Addition**: 1x DevOps Engineer (salary: $ /year = $ /month)
- **Total team**: 2 engineers
- **On-call rotation**: Established (1 week on, 1 week off)

### Deliverables

1. **Month 4**: DevOps Engineer onboarded
2. **Month 5**: Node 2 operational, multi-node tested
3. **Month 6**: Cost tracking dashboard launched

### KPIs

- Cluster uptime: >99.5%
- GPU utilization: >70%
- Cost per GPU-hour: <$0.50
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
- Hardware: $ (same spec as Node 2)
- High-availability networking: $ (redundant switches)

**Software:**
- S3-compatible object storage: MinIO cluster (open source, $0)
- Container registry: Harbor (open source, $0)

**Capex**: $ 
**Opex**: +$30/month → $ /month

### Team

- **Addition**: 1x ML Platform Engineer (salary: $ /year = $ /month)
- **Total team**: 3 engineers
- **Structure**:
  - Infrastructure Lead (you): Strategy, architecture
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
- Explore GPU rental revenue stream

### Infrastructure Changes

**Nodes 4 & 5:**
- Hardware: $ (2x $ )

**Enterprise Enhancements:**
- Backup solution: Velero + S3 storage ($20/month)
- LDAP/Active Directory integration: FreeIPA (open source, $0)
- Log aggregation: ELK stack (self-hosted, $0)

**Capex**: $
**Opex**: +$100/month (electricity + backup) → $ /month

### Team

- **Total**: 3 engineers (no additions)
- **Focus**: Efficiency improvements, automation

### Deliverables

1. **Month 10**: Nodes 4 & 5 operational
2. **Month 11**: Enterprise features (SSO, audit logs) live
3. **Month 12**: SOC 2 readiness assessment complete

### KPIs

- Cluster uptime: >99.9% (SLA-grade)
- GPU utilization: >80%
- Active users: 20+
- Security incidents: 0
- Compliance readiness: 90%+

---

## Budget Summary

### Year 1 Total Investment

| Category | Amount |
|----------|--------|
| **Capex (Hardware)** | $ |
| - Initial setup | $ |
| - Node 2 | $ |
| - Node 3 | $ |
| - Nodes 4 & 5 | $ |
| **Opex (Monthly avg)** | $ /month × 12 = $ |
| **Personnel (2 new hires)** | $ |
| **Total Year 1 Cost** | **$ ** |

### Cost per GPU-Hour Calculation

**Assumptions:**
- 5 GPUs running 24/7 = 43,800 GPU-hours/year
- Depreciation: 3-year hardware lifespan

**Breakdown:**
- Hardware amortized: $16,600 / 3 years = $5,533/year
- Opex: $2,820/year
- **Infrastructure cost**: $8,353/year ÷ 43,800 hours = **$0.19/GPU-hour**

**With personnel costs included**:
- Total: $1 /year ÷ 43,800 hours = **$ /GPU-hour**

**Comparison to Cloud**:
- AWS p3.2xlarge (V100 16GB): $3.06/hour
- Azure NC6s v3 (V100 16GB): $3.06/hour
- **Our platform with A4000**: $ /hour (27% premium BUT on-premise, no egress fees)

---

## Risk Matrix

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **Hardware failure** | Medium | High | UPS, RAID, hot-spare components |
| **Single point of failure (you)** | High | Critical | Hire team, document everything |
| **Budget overrun** | Low | Medium | Phased approach, used hardware option |
| **Slow user adoption** | Medium | Medium | Regular training, support docs |
| **Security breach** | Low | High | NetworkPolicy, audit logs, patching |
| **Power outage** | Low | High | UPS (4-hour runtime), generator (future) |
| **Network bottleneck** | Medium | Medium | 10Gbps upgrade (Q1), monitoring |

---

## Migration to Commercial Platform (Optional)

### Scenario: GPU Rental Business

If we wanted to commercialize this infrastructure:

**Additional Requirements:**
- Billing system: Open-source (e.g., Odoo) + Stripe integration
- Multi-tenancy: Namespace isolation, ResourceQuotas
- Self-service portal: Custom web app (Django/FastAPI)
- Legal: Terms of service, SLA contracts

**Estimated Setup Cost**: $ (development) + $ /month (Stripe fees, support)

**Revenue Potential:**
- Charge $2.50/GPU-hour (cloud parity with discount)
- Break-even at: ~1,800 hours/month (10% utilization across 5 GPUs)
- Profitable at: 50% utilization = $5,475/month revenue

**12-Month Projection**:
- Months 1-6: Build platform, $0 revenue
- Months 7-12: Ramp to 30% utilization = $ /month avg
- Year 2: Scale to 70% utilization = $ /month

**ROI**: N months to break even on initial investment

---

## Success Metrics Dashboard

### Technical Metrics

- **Uptime**: 99.9% (track via Prometheus)
- **GPU Utilization**: 80% average (DCGM Exporter)
- **Job Queue Time**: <5 minutes (Kubernetes metrics)
- **Incident MTTR**: <1 hour (PagerDuty)

### Business Metrics

- **Active Users**: 20+ (JupyterHub analytics)
- **Cost per GPU-hour**: <$4.00 (internal chargeback)
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
   - Update cost projections
   - Adjust hiring timeline if needed

3. **Week 3**: Stakeholder presentation
   - Executive summary slides (see `docs/executive-summaries/`)
   - ROI demonstration
   - Next quarter priorities

4. **Week 4**: Plan adjustments
   - Update this document
   - Commit to Git (version control)

---

## Appendix: Vendor Comparison

### Build vs Buy Analysis

| Option | Year 1 Cost | Pros | Cons |
|--------|-------------|------|------|
| **Self-built (this plan)** | $  | Full control, learning, on-premise | Setup effort, team required |
| **AWS SageMaker** | ~$240,000 | Managed, scalable | Vendor lock-in, egress costs |
| **Run:ai (commercial)** | $50,000 license + $181,420 infra = $231,420 | Advanced scheduling | Extra cost, still need hardware |
| **Lambda Labs GPU Cloud** | ~$180,000 (rental) | No capex | No customization, recurring cost |

**Conclusion**: RAM and SSD prices may have been high during 2006–2007, making it difficult to estimate the cost of certain components from 2006 at present.

---

## References

- [NVIDIA GPU TCO Calculator](https://www.nvidia.com/en-us/data-center/gpu-tco-calculator/)
- [CNCF Cloud Native Maturity Model](https://maturitymodel.cncf.io/)
- [Kubernetes Cost Estimation](https://www.kubecost.com/)

---

## Revision History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2025-12-31 | 0.1 | Range | Initial 12-month plan |

---

<div align="center">

**This document should be reviewed and updated quarterly.**  

</div>
