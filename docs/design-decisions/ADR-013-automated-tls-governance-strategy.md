## ADR-013: Automated TLS Governance Strategy

**Status**: Accepted  
**Date**: 2026-02-11  
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

## TLS Protocol and Cipher Suite Hardening

### Context
Following the initial TLS automation implementation, additional hardening was required to:
1. Achieve SSL Labs A+ rating
2. Implement HSTS (HTTP Strict Transport Security)
3. Prioritize TLS 1.3 over TLS 1.2

### Technical Requirements

#### Cipher Suite Configuration
**Decision**: Implement AEAD-only cipher suites with TLS 1.3 priority

**Rationale**:
- **Security**: AEAD (Authenticated Encryption with Associated Data) prevents padding oracle attacks
- **Performance**: TLS 1.3 reduces handshake latency (1-RTT vs 2-RTT)
- **Compliance**: Exceeds PCI DSS 4.0 requirements for strong cryptography

**Implementation**:
```yaml
# Traefik TLSOption
spec:
  minVersion: VersionTLS12  # Cloudflare compatibility
  maxVersion: VersionTLS13
  cipherSuites:
    # TLS 1.3 (Preferred)
    - TLS_AES_256_GCM_SHA384
    - TLS_CHACHA20_POLY1305_SHA256
    - TLS_AES_128_GCM_SHA256
    # TLS 1.2 (Fallback for Cloudflare)
    - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
    - TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305
    - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
```

**Trade-offs**:
- [o] **Pro**: Removes all CBC-mode ciphers (prevents BEAST, Lucky13)
- [o] **Pro**: Perfect Forward Secrecy (ECDHE)
- [!] **Con**: TLS 1.2 required for Cloudflare Proxied services (ollama, traefik-dashboard)

#### HSTS Configuration

**Decision**: Enable HSTS with 1-year max-age and includeSubDomains

**Configuration**:
```
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
```

**Rationale**:
- **max-age=31536000**: 1 year retention (SSL Labs A+ requirement)
- **includeSubDomains**: Protects all future subdomains automatically
- **preload**: Eligible for browser HSTS preload list

**Impact on SSL Labs Score**:
- Without HSTS: Maximum grade A
- With HSTS (1 year): Grade A+

**Implementation Method**: Traefik Middleware

### Validation Results

#### SSL Labs Test Results
- **Date**: 2026-02-11
- **Test URL**: https://www.ssllabs.com/ssltest/
- **Grade**: **A+**
- **Key Metrics**:
  - Certificate: 100/100
  - Protocol Support: 100/100 (TLS 1.2/1.3 only)
  - Key Exchange: 90/100 (RSA 2048 + ECDHE)
  - Cipher Strength: 90/100 (AEAD only)
  - HSTS: Enabled (max-age=31536000)

#### Security Improvements
1. **Protocol**: TLS 1.0/1.1 disabled (PCI DSS compliant)
2. **Weak Ciphers**: 3DES, RC4, NULL, CBC all rejected
3. **Forward Secrecy**: 100% of connections
4. **HSTS**: Protects against SSL stripping attacks

### Defense in Depth Architecture

#### System-Level Protection (Layer 1)
- **Component**: Ubuntu 24.04 + OpenSSL 3.0.13
- **Protection**: Legacy algorithms removed at compile-time
- **Coverage**: 3DES, RC4, MD5, NULL ciphers

#### Application-Level Protection (Layer 2)
- **Component**: Traefik TLS Policy
- **Protection**: Explicit cipher whitelist + protocol versions
- **Coverage**: CBC mode, TLS 1.0/1.1

#### Network-Level Protection (Layer 3)
- **Component**: Cloudflare (for proxied services)
- **Protection**: DDoS mitigation + WAF
- **Coverage**: External traffic filtering

### Consequences

#### Positive
- [o] **SSL Labs A+ rating** achieved
- [o] **System-level** weak cipher blocking (OpenSSL 3.0)
- [o] **HSTS** protects all future connections
- [o] **TLS 1.3 priority** improves performance
- [o] **Compliance**: Exceeds PCI DSS 4.0 requirements

#### Negative
- [!] **TLS 1.2 dependency** for Cloudflare Proxied services
  - **Mitigation**: Cipher suite prioritizes TLS 1.3
- [!] **Testing limitations** with OpenSSL 3.0
  - **Mitigation**: Use testssl.sh or SSL Labs for validation

#### Neutral
- <!> **HSTS preload**: Requires manual submission to browser vendors
- <!> **Certificate rotation**: Automated by cert-manager

### Maintenance Requirements

#### Quarterly Reviews
- SSL Labs re-test
- OpenSSL CVE monitoring
- Cloudflare TLS policy updates

#### Annual Reviews
- Cipher suite modernization
- Protocol version assessment
- Compliance standard updates

### References

#### Testing Tools
- [SSL Labs](https://www.ssllabs.com/ssltest/)
- [testssl.sh](https://github.com/drwetter/testssl.sh)
- [Mozilla Observatory](https://observatory.mozilla.org/)

#### Security Standards
- [PCI DSS v4.0 - Requirement 4.2](https://www.pcisecuritystandards.org/)
- [NIST SP 800-52 Rev.2](https://csrc.nist.gov/publications/detail/sp/800-52/rev-2/final)
- [RFC 6797 - HTTP Strict Transport Security](https://tools.ietf.org/html/rfc6797)

### Implementation Timeline
- **2026-01-30**: Initial automated TLS deployment
- **2026-02-10**: TLS policy hardening
- **2026-02-11**: HSTS implementation + SSL Labs A+ validation

## Revision History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2026-01-28 | 0.1 | Range | Initial automated TLS governance strategy |
| 2026-01-30 | 0.2 | Range | Added cloudflare proxy considerations |
| 2026-02-11 | 0.3 | Range | Added TLS 1.3 priority, HSTS, SSL Labs A+ validation |

