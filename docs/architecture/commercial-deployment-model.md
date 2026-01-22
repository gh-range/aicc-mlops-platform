# Commercial Deployment Model: GPU-as-a-Service Architecture

**Document Type**: Architecture Blueprint  
**Version**: 0.1  
**Last Updated**: 2026-01-22  
**Owner**: Platform Architecture Team  
**Status**: Design Phase (Implementation in Phase 3)

---

## Overview

This document defines the architectural design for delivering GPU computing resources as a commercial service, supporting both **external GPU rental (primary)** and **enterprise private cloud (secondary)** deployment models.

**Target Scale**: 128-node NVIDIA B200 SuperPod (1024 GPUs)  
**Revenue Model**: Usage-based billing ($2-4/GPU-hour)  
**SLA Target**: 99.99% uptime (52 minutes downtime/year)

---

## Business Models

### Model 1: Public GPU Rental (Primary)

**Description**: Multi-tenant platform where customers rent GPU resources by the hour, similar to AWS EC2 or Lambda Labs.

**Target Customers**:
- AI startups (model training, fine-tuning)
- Research institutions (computational experiments)
- Independent developers (hobby projects, prototyping)

**Pricing Strategy**:
- On-demand: Pay-as-you-go, no commitment
- Reserved: 1-year or 3-year contracts with discounts
- Spot: Preemptible instances at 40-60% discount

**Revenue Characteristics**:
- High volume, low touch
- Self-service portal
- Credit card payments (Stripe)

---

### Model 2: Enterprise Private Cloud (Secondary)

**Description**: Dedicated GPU infrastructure managed by our team, deployed on-premise or in customer's data center.

**Target Customers**:
- Fortune 500 companies (finance, healthcare, pharma)
- Government agencies (defense, intelligence)
- Cloud providers (white-label GPU offerings)

**Pricing Strategy**:
- Fixed monthly fee (reserved capacity)
- Professional services (deployment, training, support)
- Optional: Consumption-based overage charges

**Revenue Characteristics**:
- Low volume, high value
- Custom SLA terms (99.99% or 99.995%)
- Annual contracts ($1-5M+ per customer)

---

## Multi-Tenancy Architecture

### Isolation Layers

```
┌─────────────────────────────────────────────────────────────┐
│              Layer 5: Billing & Quotas                      │
│  (Per-tenant resource limits, cost tracking)                │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│              Layer 4: Application Isolation                 │
│  (Kubernetes Namespaces, RBAC, NetworkPolicy)               │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│              Layer 3: Compute Isolation                     │
│  (GPU MIG Instances, CPU/Memory ResourceQuotas)             │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│              Layer 2: Storage Isolation                     │
│  (PersistentVolumes, Encryption at Rest, Access Control)    │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│              Layer 1: Network Isolation                     │
│  (Calico GlobalNetworkPolicy, mTLS, Private VLANs)          │
└─────────────────────────────────────────────────────────────┘
```

---

### Layer 1: Network Isolation

**Implementation**: Calico GlobalNetworkPolicy (Zero-Trust)

**Default Policy**: Deny all traffic between namespaces

```yaml
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: default-deny-cross-namespace
spec:
  order: 1000
  selector: all()
  types:
  - Ingress
  - Egress
  ingress:
  - action: Deny
    source:
      notSelector: projectcalico.org/namespace == global.projectcalico.org/namespace
  egress:
  - action: Deny
    destination:
      notSelector: projectcalico.org/namespace == global.projectcalico.org/namespace
```

**Allowed Traffic**:
- Tenant → Internet (egress)
- Tenant → Shared Services (DNS, monitoring, ingress)
- Tenant ↔ Tenant: Explicitly denied

**Additional Security**:
- mTLS for pod-to-pod communication (Istio service mesh)
- Private VLANs for high-security tenants (finance, healthcare)

---

### Layer 2: Storage Isolation

**Implementation**: PersistentVolumeClaims with tenant-specific StorageClass

**Data Isolation**:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: customer-data
  namespace: tenant-acme-corp
  labels:
    tenant: acme-corp
spec:
  storageClassName: encrypted-tenant-storage
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1T
```

**Encryption**:
- At-rest: LUKS encryption on NVMe volumes
- In-transit: TLS for S3 API (MinIO)
- Key management: HashiCorp Vault (per-tenant keys)

**Backup Isolation**:
- Tenant data backed up to separate S3 buckets
- Encryption keys rotated every 90 days
- Immutable backups (WORM compliance for regulated industries)

---

### Layer 3: Compute Isolation

**GPU Isolation**: NVIDIA MIG (Multi-Instance GPU)

**B200 MIG Profiles**:
```yaml
# Each B200 supports 7 MIG instances (1g.10gb profile)
# 1024 GPUs = 7168 MIG instances

MIG Profile: 1g.10gb
  - Compute: 1/7 of GPU cores
  - Memory: 25GB HBM3e (isolated)
  - PCIe: Isolated memory space
  - Fault Isolation: Crash in one MIG doesn't affect others
```

**Allocation Strategy**:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: customer-workload
  namespace: tenant-acme-corp
spec:
  containers:
  - name: training-job
    image: customer-ml-framework:latest
    resources:
      limits:
        nvidia.com/mig-1g.10gb: 1  # Request 1 MIG instance
        memory: 32G
        cpu: 8
```

**CPU/Memory Quotas**:
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-acme-corp-quota
  namespace: tenant-acme-corp
spec:
  hard:
    requests.nvidia.com/mig-1g.10gb: "10"  # Max 10 MIG instances
    requests.cpu: "80"                      # Max 80 CPU cores
    requests.memory: 320G                   # Max 320GB RAM
    persistentvolumeclaims: "20"            # Max 20 PVCs
```

**Fair-Share Scheduling** (if using Run:AI or Volcano):
- Priority queues: urgent > production > development
- Preemption: Urgent jobs can evict low-priority jobs
- Gang scheduling: Distributed training (all-or-nothing allocation)

---

### Layer 4: Application Isolation

**Kubernetes Namespaces**: One namespace per tenant

**Namespace Naming Convention**:
```
tenant-{company-slug}       # e.g., tenant-acme-corp
tenant-{company-slug}-dev   # Separate dev/prod namespaces
tenant-{company-slug}-prod
```

**RBAC Policy**:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: tenant-admin
  namespace: tenant-acme-corp
rules:
- apiGroups: ["", "apps", "batch"]
  resources: ["pods", "deployments", "jobs", "services"]
  verbs: ["get", "list", "create", "update", "delete"]
- apiGroups: [""]
  resources: ["secrets", "configmaps"]
  verbs: ["get", "list"]  # Cannot create secrets (managed by platform)
```

**Service Account Isolation**:
- Each tenant gets a dedicated ServiceAccount
- No cluster-admin or cluster-wide permissions
- API tokens expire every 24 hours (short-lived)

---

### Layer 5: Billing & Quotas

**Metering Architecture**:
```
┌─────────────────────────────────────────────────────────────┐
│  GPU Workloads (with MIG allocation)                        │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  DCGM Exporter (per-GPU metrics)                            │
│  - GPU utilization %                                        │
│  - Memory allocation (bytes)                                │
│  - Power consumption (watts)                                │
│  - Job duration (seconds)                                   │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  Prometheus (metrics storage)                               │
│  - Label: namespace, tenant, gpu_uuid, job_name             │
│  - Retention: 90 days                                       │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  Billing Exporter (custom service)                          │
│  - Aggregate: GPU-hours per tenant per day                  │
│  - Calculate: Cost = hours × rate × tier_multiplier         │
│  - Output: PostgreSQL (billing database)                    │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  Billing API (FastAPI)                                      │
│  - Expose: /api/v1/tenants/{id}/usage                       │
│  - Integrate: Stripe (payments), Chargebee (subscriptions)  │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  Customer Portal (React SPA)                                │
│  - Display: Real-time usage, cost estimates, invoices       │
│  - Actions: Top-up credits, download invoices, support      │
└─────────────────────────────────────────────────────────────┘
```

**Billing Granularity**:
- Metering interval: 1 minute (round up to nearest minute)
- Invoicing: Daily (for on-demand), monthly (for reserved)
- Grace period: 5-minute startup time not billed (pod initialization)

**Example Calculation**:
```python
# Pseudo-code
def calculate_cost(tenant_id, start_time, end_time):
    gpu_hours = query_prometheus(
        query=f'sum(dcgm_gpu_utilization{{namespace=~"tenant-{tenant_id}-.*"}}) / 3600',
        start=start_time,
        end=end_time
    )
    
    tier = get_tenant_tier(tenant_id)  # on-demand, reserved, spot
    rate = PRICING_TIERS[tier]         # $3.50, $2.80, $2.00
    
    cost = gpu_hours * rate
    
    # Apply discounts
    if gpu_hours > 1000:  # Volume discount
        cost *= 0.90
    
    return cost
```

---

## Self-Service Portal

### Customer-Facing Features

**Dashboard**:
- Real-time GPU utilization (current active jobs)
- Cost meter (today, this week, this month)
- Resource quotas (used/total)
- Billing history (invoices, payments)

**Job Management**:
- Submit jobs via web UI or API
- Job templates (PyTorch, TensorFlow, custom containers)
- Jupyter Notebook launcher (persistent sessions)
- Job logs and metrics (TensorBoard integration)

**Access Control**:
- Team management (invite users, assign roles)
- API keys (create, rotate, revoke)
- SSH key management (for remote access)

**Support**:
- Ticket system (integrated with Zendesk or Freshdesk)
- Documentation (API docs, tutorials, best practices)
- Community forum (optional: Discourse)

---

### API Design

**Authentication**: OAuth 2.0 + API Keys

**Core Endpoints**:
```yaml
POST /api/v1/jobs
  # Submit a GPU job
  Request:
    {
      "name": "training-run-42",
      "image": "pytorch/pytorch:2.10.0-cuda13.0",
      "command": ["python", "train.py"],
      "resources": {
        "gpu": 4,              # Request 4 MIG instances
        "cpu": 16,
        "memory": "64Gi"
      },
      "volumes": [
        {"name": "dataset", "pvc": "my-dataset"}
      ]
    }
  Response:
    {
      "job_id": "job-abc123",
      "status": "pending",
      "estimated_cost": "$14.00/hour"
    }

GET /api/v1/jobs/{job_id}
  # Get job status
  Response:
    {
      "job_id": "job-abc123",
      "status": "running",
      "gpu_allocation": ["GPU-1", "GPU-2", "GPU-3", "GPU-4"],
      "runtime": "2h 15m",
      "cost_so_far": "$31.50"
    }

DELETE /api/v1/jobs/{job_id}
  # Cancel a running job
  Response:
    {
      "job_id": "job-abc123",
      "status": "cancelled",
      "total_cost": "$31.50"
    }

GET /api/v1/billing/usage
  # Get usage summary
  Query Params:
    ?start_date=2026-01-01&end_date=2026-01-31
  Response:
    {
      "gpu_hours": 1523.5,
      "total_cost": "$5,332.25",
      "breakdown": {
        "on_demand": "$4,200.00",
        "reserved": "$1,132.25"
      }
    }
```

**Rate Limiting**:
- API calls: 1000 requests/hour per tenant
- Job submissions: 100 jobs/day (on-demand), unlimited (reserved)

---

## SLA Framework

### Tier Definitions

**Tier 1: Standard (99.9% uptime)**
- **Target**: 8.76 hours downtime/year
- **Included**:
  - Email support (24-hour response)
  - Community forum access
  - Documentation and tutorials
- **SLA Credits**:
  - 99.0-99.9%: 10% monthly fee refund
  - 95.0-99.0%: 25% refund
  - <95.0%: 50% refund
- **Pricing**: Base rate ($3.50/GPU-hour)

**Tier 2: Premium (99.99% uptime)**
- **Target**: 52.56 minutes downtime/year
- **Included**:
  - Phone/Slack support (1-hour response)
  - Dedicated Customer Success Engineer
  - Quarterly business reviews
- **SLA Credits**:
  - 99.90-99.99%: 10% refund
  - 99.00-99.90%: 25% refund
  - <99.00%: 50% refund + reserved capacity guarantee
- **Pricing**: +20% premium ($4.20/GPU-hour)

**Tier 3: Mission-Critical (99.995% uptime)**
- **Target**: 26.28 minutes downtime/year
- **Included**:
  - 24/7 hotline (15-minute response)
  - On-site engineer (optional)
  - Custom SLA terms
- **SLA Credits**:
  - 99.990-99.995%: 15% refund
  - 99.900-99.990%: 50% refund
  - <99.900%: 100% refund + penalty clause
- **Pricing**: +50% premium ($5.25/GPU-hour)

---

### SLA Measurement

**Uptime Calculation**:
```python
def calculate_uptime(month):
    total_minutes = month.total_days * 24 * 60
    
    # Exclude planned maintenance (announced 7 days ahead)
    planned_downtime = sum(maintenance_windows)
    
    # Count unplanned outages
    unplanned_downtime = sum(incident_durations)
    
    uptime_minutes = total_minutes - unplanned_downtime
    uptime_percentage = (uptime_minutes / (total_minutes - planned_downtime)) * 100
    
    return uptime_percentage
```

**Outage Definition**:
- **Partial Outage**: >10% of GPUs unavailable → prorated SLA credit
- **Full Outage**: >90% of GPUs unavailable → full SLA credit
- **Degraded Performance**: GPU utilization <50% due to platform issue → counted as downtime

**Exclusions** (not counted as downtime):
- Customer misconfiguration (invalid container images, quota exceeded)
- Network issues outside our control (ISP outages)
- DDoS attacks (if mitigated within 2 hours)
- Force majeure (natural disasters, power grid failure)

---

## Disaster Recovery & Business Continuity

### Backup Strategy

**Data Backup**:
- **Frequency**: Daily incremental, weekly full
- **Retention**: 30 days rolling, 12 monthly snapshots
- **Storage**: S3-compatible (MinIO + AWS S3 replication)
- **Encryption**: AES-256 at rest, TLS in transit

**Kubernetes State Backup** (Velero):
```yaml
Schedule: Daily at 2 AM UTC
Includes:
  - All PersistentVolumeClaims (tenant data)
  - ConfigMaps, Secrets (excluding Vault-managed)
  - Custom Resource Definitions (CRDs)
Excludes:
  - Pods (ephemeral, recreated from deployments)
  - Logs (retained in Loki for 30 days only)
```

**etcd Backup**:
- Frequency: Every 6 hours
- Retention: 7 days
- Storage: Encrypted S3 bucket

---

### Disaster Scenarios

**Scenario 1: Single Node Failure**
- **Detection**: Prometheus alert (node down >5 minutes)
- **Automated Response**: Pods rescheduled to healthy nodes (<30 seconds)
- **Manual Response**: Replace failed hardware within 24 hours
- **RTO**: <1 minute (no customer impact)
- **RPO**: 0 (no data loss, PVCs replicated)

**Scenario 2: Rack Failure** (16 nodes, 128 GPUs)
- **Detection**: Multiple node alerts, InfiniBand link down
- **Automated Response**: Workloads migrate to other racks
- **Manual Response**: Troubleshoot power/network, restore rack
- **RTO**: <5 minutes (failover time)
- **RPO**: 0 (distributed storage replication)

**Scenario 3: Data Center Outage** (full cluster down)
- **Detection**: External monitoring (UptimeRobot), ISP confirms outage
- **Automated Response**: None (requires manual intervention)
- **Manual Response**:
  1. Restore power/cooling (1-4 hours)
  2. Bootstrap Kubernetes control plane (30 minutes)
  3. Restore etcd from backup (15 minutes)
  4. Verify all nodes healthy (1 hour)
  5. Restore tenant workloads from Velero (2-4 hours)
- **RTO**: <8 hours (worst case)
- **RPO**: <24 hours (last daily backup)

**Scenario 4: Cyber Attack / Ransomware**
- **Detection**: Anomaly detection (unusual API calls, mass file encryption)
- **Automated Response**: Isolate affected nodes (network segmentation)
- **Manual Response**:
  1. Engage security incident response team
  2. Assess blast radius (which tenants affected)
  3. Restore from immutable backups
  4. Forensic analysis, patch vulnerabilities
- **RTO**: <24 hours
- **RPO**: <24 hours (daily backups, immutable)

---

### Failover Testing

**Chaos Engineering** (quarterly drills):
```bash
# Test 1: Random node termination
kubectl drain $(kubectl get nodes -o name | shuf -n 1) --force --ignore-daemonsets

# Test 2: Network partition (simulate rack isolation)
iptables -A INPUT -s 10.0.1.0/24 -j DROP

# Test 3: etcd corruption
systemctl stop etcd && rm -rf /var/lib/etcd/*

# Test 4: Control plane failure
systemctl stop kube-apiserver kube-controller-manager kube-scheduler
```

**Pass Criteria**:
- Workloads automatically reschedule
- No data loss (PVCs intact)
- Customer-facing APIs remain accessible (via load balancer)
- Recovery time meets SLA tier targets

---

## Compliance & Security

### Regulatory Compliance

**SOC 2 Type II**:
- Audit scope: Infrastructure, access controls, data encryption
- Frequency: Annual audit
- Certifications: Valid for 12 months

**ISO 27001**:
- Information security management system (ISMS)
- Risk assessment every 6 months
- Annual surveillance audit

**GDPR** (if EU customers):
- Data residency: Option to deploy in EU data centers
- Right to erasure: Automated tenant data deletion within 30 days
- Data processing agreement (DPA): Standard template for all customers

**HIPAA** (for healthcare customers):
- Business Associate Agreement (BAA)
- Encrypted storage (LUKS + Vault key management)
- Audit logs retained for 7 years

---

### Security Hardening

**Zero-Trust Architecture**:
```yaml
Principles:
  1. No implicit trust (all traffic authenticated)
  2. Least privilege access (RBAC, narrow permissions)
  3. Assume breach (detect and contain, not prevent)

Implementation:
  - mTLS for all pod-to-pod traffic (Istio)
  - No SSH access to nodes (kubectl exec only)
  - API calls require short-lived tokens (24-hour expiry)
  - Network segmentation (Calico GlobalNetworkPolicy)
```

**Vulnerability Management**:
- Container image scanning: Trivy (daily scans)
- Kubernetes security: kube-bench (CIS Benchmark)
- Penetration testing: Quarterly (external firm)
- Bug bounty program: HackerOne ($500-$10K rewards)

**Access Control**:
- Admin access: YubiKey 2FA required
- Customer access: OAuth 2.0 (Google, GitHub, SAML)
- API keys: Rotated every 90 days (automated alerts)
- Audit logs: Immutable, retained for 2 years

---

## Monitoring & Observability

### Customer-Facing Metrics

**Real-Time Dashboard**:
- GPU utilization % (per job)
- Memory usage (per MIG instance)
- Cost meter (current hour, projected daily)
- Job queue position (if queued)

**Alerts** (customer-configurable):
- Job completion notification (email, webhook)
- Cost threshold exceeded ($100/day, $1000/month)
- Quota warning (90% of ResourceQuota used)
- Job failure (exit code != 0)

---

### Internal Observability

**Prometheus Metrics**:
```yaml
Infrastructure:
  - node_cpu_usage, node_memory_usage
  - dcgm_gpu_utilization, dcgm_gpu_memory_used
  - etcd_server_health, kube_apiserver_latency

Application:
  - http_request_duration (API latency)
  - billing_exporter_processing_time
  - customer_portal_active_sessions

Business:
  - revenue_per_hour (real-time)
  - gpu_utilization_percentage (aggregate)
  - customer_churn_rate (monthly)
```

**Grafana Dashboards**:
- **Operations**: Cluster health, node status, GPU allocation
- **Business**: Revenue, utilization, top customers
- **Customer Success**: Ticket volume, response time, NPS score

**Alerting** (PagerDuty):
```yaml
Critical (page on-call immediately):
  - Cluster uptime <99.5%
  - >10% GPUs offline
  - Billing system down
  - Security incident detected

Warning (Slack notification):
  - GPU utilization <50% (revenue risk)
  - etcd backup failed
  - Certificate expiring in 7 days

Info (email summary):
  - New customer signup
  - Monthly usage report
  - Maintenance window reminder
```

---

## References

- [NVIDIA Multi-Instance GPU (MIG) Guide](https://docs.nvidia.com/datacenter/tesla/mig-user-guide/)
- [Kubernetes Multi-Tenancy Working Group](https://github.com/kubernetes-sigs/multi-tenancy)
- [Calico Network Policy](https://docs.tigera.io/calico/latest/network-policy/)
- [SOC 2 Compliance Requirements](https://www.aicpa.org/soc4so)
- [Stripe Billing API](https://stripe.com/docs/billing)

---

<div align="center">

**Implementation Phase**: Phase 3 (2027)  
**Design Status**: Ready for prototype (Q4 2026)  
**Next Review**: Post-Phase 2 completion (Business case validation)

**For technical scaling details, see [Scaling Roadmap](scaling-roadmap.md)**

</div>

