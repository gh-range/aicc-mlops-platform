# TLS Configuration Layer

## Purpose
Centralized TLS policy and certificate management for the platform.

## Components

### enterprise-tls-policy.yaml
Global TLS options enforcing:
- Minimum TLS 1.2
- Enterprise-grade cipher suites (ECDHE, AES-GCM, ChaCha20)
- Strict SNI validation
- NIST P-384/P-521 curve preferences

### Certificate Management
All services use the wildcard certificate: `mlops-work-wildcard-tls`
- **Domain**: `*.mlops.work`
- **Issuer**: Google Trust Services (WE1)
- **Validity**: 90 days
- **Secret Location**: `traefik-system` namespace
- **Managed by**: cert-manager with Google Public CA

## References
- ADR-014: Traefik Networking Correction
- Runbook: Certificate renewal procedures in `/docs/runbooks/`
