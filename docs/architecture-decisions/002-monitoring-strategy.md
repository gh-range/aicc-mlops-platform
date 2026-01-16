# ADR-002: Monitoring Strategy for MAV Node

## Status
Accepted

## Context
MAV node requires GPU and infrastructure monitoring. Two monitoring approaches available:
1. Existing Zabbix 7 with nvidia-smi integration
2. Cloud-native Prometheus + Grafana stack

## Decision
**Phased Approach**:

### Phase 1 (Current)
- **Primary**: Zabbix 7 for infrastructure and basic GPU monitoring
- **Deferred**: Prometheus Operator + Grafana deployment
- **Rationale**: Focus on core deliverable (JupyterHub with GPU Time-Slicing)

### Phase 2 (Post-Delivery Enhancement)
- Deploy kube-prometheus-stack via Helm
- Enable DCGM ServiceMonitor for detailed GPU metrics
- Establish baseline for SuperPod migration planning

## Consequences

### Positive
- Reduced deployment complexity during critical deadline
- Leverage existing Zabbix expertise
- No additional resource overhead (2GB RAM, 2 CPU saved)
- Prometheus can be added non-disruptively later

### Negative
- Missing cloud-native k8s monitoring temporarily
- No DCGM fine-grained metrics during Phase 1
- Dual monitoring systems to maintain in Phase 2

## Monitoring Coverage (Phase 1)

| Metric Category | Tool | Status |
|----------------|------|--------|
| Host Resources | Zabbix | [o] Active |
| GPU Basic (nvidia-smi) | Zabbix | [o] Active |
| GPU Fine-grained (DCGM) | - | Deferred to Phase 2 |
| K8s Cluster State | - | Deferred to Phase 2 |
| Time-Slicing Utilization | - | Deferred to Phase 2 |

## Future Implementation Reference
- Section: Chapter 7 - Monitoring & Observability
- Helm Chart: kube-prometheus-stack v55.x
- DCGM Dashboard: NVIDIA GPU Operator Dashboard (ID: 12239)

## Date
2026-01-16
