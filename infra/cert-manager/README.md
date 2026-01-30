# Infrastructure: cert-manager

## Overview
This component implements automated X.509 certificate management for the AICC MLOps platform. It integrates with Let's Encrypt via ACME protocol to provide Auto-TLS for all internal and external-facing services (e.g., JupyterHub, Ollama API).

## Architecture Role
- **Trust Root**: Establishes the foundation for Zero-Trust Network Policy.
- **Scalability**: Designed to support wildcard certificates for multi-tenant SuperPod namespaces.
- **Lifecycle**: Handles automatic renewal 30 days before expiration.

## Key Resources
- **ClusterIssuer**: letsencrypt-prod (ACME-based production issuer).
- **CRDs**: Certificate, Issuer, ClusterIssuer, Order, Challenge.

## Maintenance
- Logs: kubectl logs -n cert-manager -l app.kubernetes.io/instance=cert-manager
- Status: kubectl get certificate --all-namespaces

## Strategic Decision: Challenge Type
- **Primary**: DNS-01 Challenge
- **Reasoning**: Supports wildcard certificates (*.mlops.work) and ensures internal service isolation in high-security SuperPod environments.

## Component Specification
- **Version**: v1.19.2
- **Namespace**: cert-manager
- **Challenge Type**: DNS-01 via Cloudflare

## File Composition
- values.yaml: Helm deployment configurations with node selector for llm1.mlops.work.
- cluster-issuer.yaml.sample: Template for ACME production issuer.
- test-wildcard-cert.yaml: Manifest for validating wildcard certificate issuance.

## Operational Procedures
1. Apply the Cloudflare API Token Secret.
2. 'cp cluster-issuer.yaml.sample cluster-issuer.yaml' and fill in credentials.
3. Deploy via Helm: helm upgrade --install cert-manager jetstack/cert-manager -f values.yaml
4. Verify via 'kubectl get certificate -n cert-manager'.

### Automation
- **Policy**: Automatic renewal is triggered 30 days(720h) before expiration.
- **Verification**: Check Last Transition Time in 'kubectl describe certificate'.

## Cloudflare Proxy Integration
- **Status**: Proxied via Cloudflare Edge.
- **Edge Certificate**: Google Trust Services (Universal SSL).
- **Origin Certificate**: Let's Encrypt (managed by cert-manager).
- **SSL Mode**: Must be set to **Full (Strict)** to ensure end-to-end integrity.

### Metrics for Zabbix 7 Integration
- **Endpoint**: <pod ip>:9402/metrics
- **Key Metrics**:
  - certmanager_certificate_expiration_timestamp_seconds: Monitor for certificates expiring in < 15 days.
  - certmanager_certificate_ready_status: Trigger alert if status is not 1 (Ready).

---

**Part of**: AI Data Center MLOps Platform  
**Managed by**: Range  
**Last Updated**: 2025-01-30

