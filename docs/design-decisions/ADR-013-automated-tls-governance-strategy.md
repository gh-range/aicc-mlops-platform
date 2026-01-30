## ADR-013: Automated TLS Governance Strategy

**Status**: Accepted  
**Date**: 2026-01-30  
**Decision Makers**: Platform Engineering Team  
**Technical Story**: AICC MLOps Platform Security Initialization

## Context and Problem Statement

This project aims to establish an MLOps platform scalable to NVIDIA B200 SuperPods. To ensure security and compliance in a multi-tenant environment, automated TLS certificate lifecycle management must be implemented to avoid service interruptions and security vulnerabilities caused by manual certificate updates.

**Key Requirements:**

- Support for `*.mlops.work` wildcard certificates to meet the dynamic generation requirements of multi-tenant subdomains.
- Adhere to a zero-trust architecture; the certificate issuance process should not require the internal network to have Port 80 exposed.
- Integrate with the Cloudflare DNS API for fully automated challenge verification and renewal.

## Decision Drivers

- **Scalability**: The B200 SuperPod architecture will have hundreds of inference endpoints, making manual management impractical.
- **Security**: Avoid exposing the global API key; Cloudflare Scoped API Tokens must be used.
- **Compliance**: Comply with ISO 27001 requirements for encrypted communication and automated management.

## Considered Options

### Option 1: HTTP-01 Challenge (ACME)

**Pros:** Simple configuration, no DNS API permissions required.
**Cons:** Does not support wildcard certificates; requires the edge gateway to have external access for verification, which does not comply with security principles.

### Option 2: DNS-01 Challenge with Cloudflare (Chosen)

**Pros:** Supports wildcard certificates, verification process does not require changes to network firewall rules, suitable for private or restricted network environments.
**Cons:** Requires management of DNS API Token credentials.

## Decision Outcome

**Chosen option**: Option 2 - DNS-01 Challenge with Cloudflare

**Rationale:**
- Wildcard certificates are core to the SuperPod multi-tenant architecture, and only DNS-01 supports this feature.
- By restricting editing to only the 'mlops.work' zone through the Cloudflare API Token, security risks are minimized.

**Expected Benefits:**
- Automatic certificate renewal with zero downtime.
- Internal services (such as JupyterHub) can obtain trusted public certificates, improving the development experience.

## Consequences

### Positive
- Achieve 100% declarative infrastructure goals, certificate management is integrated into the GitOps process.

### Negative
- Dependence on the Cloudflare API.
- **Risk**: API Token leakage risk. **Mitigation**: Use Kubernetes Secrets for storage and enable etcd encryption at the K3s level.

### Neutral
- **Connectivity**: Requires Cloudflare API access. If the egress IP is dynamic, API Token IP filtering must be disabled or managed via a NAT gateway static IP.

## Troubleshooting Note
During validation, Error 9109 was encountered. Resolved by disabling Client IP Address Filtering on Cloudflare API Token to accommodate dynamic egress IPs of the MAV node.

## Cloudflare Proxy Considerations

### Infrastructure Topology
- **Edge Layer**: Cloudflare provides Universal SSL (issued by Google Trust Services) to end-users when Proxy (Orange Cloud) is enabled.
- **Origin Layer**: cert-manager issues Let's Encrypt certificates to the MAV node for internal cluster security.

### Security Compliance
- **Requirement**: Cloudflare SSL/TLS setting MUST be set to **Full (Strict)**.
- **Rationale**: Ensures the connection between Cloudflare Edge and the MAV node is encrypted and validated against the cert-manager issued certificate, preventing Man-in-the-Middle (MITM) attacks and redirection loops.
- **Header Trust**: Traefik must be configured to trust Cloudflare IP ranges to correctly interpret 'X-Forwarded-Proto' headers for backend applications like JupyterHub.

## Implementation Plan
1. **Phase 1**: Create Cloudflare Scoped API Tokens and store it in the Secret of the 'cert-manager' Namespace.
2. **Phase 2**: Deploy the 'cert-manager' Helm Chart and configure the 'ClusterIssuer'.
3. **Phase 3**: Integrate Traefik 'IngressRoute' to achieve automatic signature verification.

## References

- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Cloudflare API Token Permissions](https://developers.cloudflare.com/fundamentals/api/reference/permissions/)
- [Let's Encrypt DNS-01 Challenge](https://letsencrypt.org/docs/challenge-types/#dns-01-challenge)
- [NVIDIA SuperPod Security Best Practices](https://docs.nvidia.com/dgx-superpod/)

## Revision History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2026-01-28 | 0.1 | Range | Initial automated TLS governance strategy |
| 2026-01-30 | 0.2 | Range | Added cloudflare proxy considerations |

