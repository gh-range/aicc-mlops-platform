# Infrastructure: cert-manager

## Overview
This component implements automated X.509 certificate management for the AICC MLOps platform. It integrates with Let's Encrypt via ACME protocol to provide Auto-TLS for all internal and external-facing services (e.g., JupyterHub, Ollama API).

## Architecture Role
- **Trust Root**: Establishes the foundation for Zero-Trust Network Policy.
- **Scalability**: Designed to support wildcard certificates for multi-tenant SuperPod namespaces.
- **Lifecycle**: Handles automatic renewal 30 days before expiration.

## Key Resources
- **ClusterIssuer**: `letsencrypt-prod` (ACME-based production issuer).
- **CRDs**: Certificate, Issuer, ClusterIssuer, Order, Challenge.

## Maintenance
- Logs: `kubectl logs -n cert-manager -l app.kubernetes.io/instance=cert-manager`
- Status: `kubectl get certificate --all-namespaces`

---

**Part of**: AI Data Center MLOps Platform  
**Managed by**: Range  
**Last Updated**: 2025-01-28
