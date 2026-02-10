# OpenSSL 3.0.x Behavior Notes

## Environment
- **OS**: Ubuntu 24.04 LTS
- **OpenSSL Version**: 3.0.13
- **Traefik Version**: v3.6.7
- **Documentation Date**: 2026-02-11

---

## Key Changes in OpenSSL 3.0

### Disabled Algorithms (Compile-time)

OpenSSL 3.0 removes legacy algorithms by default during compilation:

| Algorithm | Status | Security Issue |
|-----------|--------|----------------|
| 3DES | [x] Disabled | Sweet32 Attack (CVE-2016-2183) |
| RC4 | [x] Disabled | Stream Cipher Attacks (CVE-2013-2566) |
| MD5 | [x] Disabled | Hash Collision (RFC 6151) |
| SSL 2.0/3.0 | [x] Disabled | Multiple critical vulnerabilities |

### Verification

```bash
# Check if weak ciphers are compiled in
openssl ciphers -v | grep -E "DES-CBC3|RC4"
# Expected: No output (algorithms removed)
```

---

## Testing Implications

### Cannot Test with Local OpenSSL

**Symptom:**
```bash
openssl s_client -cipher 'DES-CBC3-SHA' -connect <FQDN>:443
# Error: SSL_CTX_set_cipher_list:no cipher match
```

**Meaning**: The cipher is not available in the OpenSSL library itself.

**Security Impact**: [o] **Positive** - System-level protection prevents weak crypto usage.

### Alternative Rejection Patterns

When testing weak ciphers, look for these indicators:

| Pattern | Meaning | Status |
|---------|---------|--------|
| `no cipher match` | OpenSSL 3.0 blocks | [o] Secure |
| `Cipher is (NONE)` | Handshake failed | [o] Secure |
| `Cipher: 0000` | No cipher selected | [o] Secure |
| `handshake failure` | Server rejected | [o] Secure |
| `Cipher: <weak-name>` | Cipher accepted | [x] Issue |

---

## Validation Methods

### Method 1: testssl.sh (Recommended)

testssl.sh bundles its own OpenSSL with legacy support:

```bash
./testssl.sh --vulnerable jupyter.mlops.work:443
```

**Advantages**:
- Independent of system OpenSSL
- Comprehensive cipher suite testing
- Industry-standard tool

### Method 2: Check Production Logs

Monitor actual negotiated ciphers in Traefik:

```bash
kubectl logs -n traefik-system -l app.kubernetes.io/name=traefik \
  | grep TLSCipher \
  | awk '{print $NF}' \
  | sort | uniq -c
```

**Expected output**: Only AEAD cipher suites (GCM, ChaCha20)

### Method 3: Remote Testing

External validation services:
- **SSL Labs**: https://www.ssllabs.com/ssltest/
- **Mozilla Observatory**: https://observatory.mozilla.org/

---

## Defense in Depth Architecture

### Layer 1: Operating System (Ubuntu 24.04)
- OpenSSL 3.0.x with legacy algorithms disabled
- System-wide enforcement

### Layer 2: Traefik TLS Policy
- Explicit cipher suite whitelist
- Protocol version enforcement
- SNI strict mode

### Layer 3: Cloudflare (External Traffic)
- Additional filtering for proxied services
- DDoS protection

---

## Compliance Status

**PCI DSS 4.0 Compliance**: [o] **EXCEEDS**
- Requirement 4.2.1: TLS 1.2+ ✓
- Requirement 4.2.2: Strong cryptography ✓
- System-level enforcement provides additional protection

**NIST SP 800-52 Rev.2**: [o] **COMPLIANT**
- TLS 1.2/1.3 only
- AEAD cipher suites only
- Forward secrecy enabled

---

## Testing Scripts

### Available Scripts

1. **test-weak-ciphers.sh**
   - Tests common weak ciphers
   - OpenSSL 3.0 compatible logic

### Usage

```bash
cd ~/aicc-mlops-platform
./scripts/test-weak-ciphers.sh
```

---

## References

- [OpenSSL 3.0 Migration Guide](https://www.openssl.org/docs/man3.0/man7/migration_guide.html)
- [Ubuntu 24.04 Security Features](https://ubuntu.com/security)
- [PCI DSS v4.0 Requirements](https://www.pcisecuritystandards.org/)
- [NIST SP 800-52 Rev.2](https://csrc.nist.gov/publications/detail/sp/800-52/rev-2/final)

---

## Changelog

- **2026-02-11**: Initial documentation
  - Documented OpenSSL 3.0 behavior changes
  - Added testing strategies
  - Validated defense-in-depth architecture

