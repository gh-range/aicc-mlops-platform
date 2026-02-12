# DNS Operations Runbook

## Overview

This runbook covers DNS record management for the `mlops.work` domain, managed via Cloudflare.

---

## Prerequisites

### Access Requirements
- Cloudflare account access
- API Token with `Zone:DNS:Edit` permission
- kubectl access to cert-manager namespace

### Environment Setup
```bash
# Extract Cloudflare API Token from cert-manager
export CLOUDFLARE_API_TOKEN=$(kubectl get secret cloudflare-api-token-secret -n cert-manager -o jsonpath='{.data.api-token}' | base64 -d)

# Set Zone ID (get from Cloudflare Dashboard)
export CLOUDFLARE_ZONE_ID="your-zone-id"
```

---

## CAA Record Management

### Current Configuration

**5 Certificate Authorities authorized** (10 CAA records total):

| CA | Purpose |
|----|---------|
| Let's Encrypt | Origin Server (Traefik) |
| Google Trust Services | Cloudflare primary |
| DigiCert | Cloudflare backup |
| Sectigo/Comodo | Cloudflare backup |
| SSL.com | Cloudflare backup |

**Reference**: [ADR-015: CAA Record Security Strategy](../design-decisions/ADR-015-caa-record-security-strategy.md)

---

### View CAA Records

```bash
# Query current CAA records
dig mlops.work CAA +short

# Expected output (10 records):
# 0 issue "letsencrypt.org"
# 0 issuewild "letsencrypt.org"
# 0 issue "pki.goog"
# 0 issuewild "pki.goog"
# ... (and 6 more)
```

---

### Add CAA Record

#### Method 1: Cloudflare Dashboard (Recommended for Manual)

1. Login: https://dash.cloudflare.com/
2. Select zone: `mlops.work`
3. DNS → Add Record
4. Fill:
   - Type: `CAA`
   - Name: `@` (or `mlops.work`)
   - Flags: `0`
   - Tag: `issue` or `issuewild`
   - CA domain: `example.com`

#### Method 2: API (Recommended for Automation)

```bash
# Add new CA authorization
curl -X POST "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{
    "type": "CAA",
    "name": "mlops.work",
    "data": {
      "flags": 0,
      "tag": "issue",
      "value": "newca.com"
    },
    "ttl": 1
  }'
```

---

### Delete CAA Record

```bash
# List all CAA records with IDs
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records?type=CAA" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" | jq -r '.result[] | "\(.id) \(.data.tag) \(.data.value)"'

# Delete specific record
RECORD_ID="abc123"
curl -X DELETE "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records/${RECORD_ID}" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}"
```

---

### Update CAA Records (Full Replacement)

**Use Case**: Cloudflare adds/removes CA partners

```bash
# Script location
cd ~/aicc-mlops-platform

# Delete all existing CAA records
./scripts/delete-all-caa-records.sh

# Recreate with updated CA list
./scripts/create-caa-records-complete.sh

# Verify
dig mlops.work CAA +short
```

---

## Validation

### Test CAA Configuration

```bash
# Online tools
# https://caatest.co.uk/ → Enter "mlops.work"
# https://letsdebug.net/ → Enter "test.mlops.work"

# Command line
dig mlops.work CAA +short | wc -l
# Expected: 10 records (or 11 if iodef added)
```

### Verify Certificate Issuance

```bash
# Force cert-manager to renew certificate
kubectl delete secret mlops-work-wildcard-tls -n traefik-system

# Watch certificate renewal
kubectl get certificate -n traefik-system -w

# Check cert-manager logs for CAA validation
kubectl logs -n cert-manager -l app=cert-manager | grep -i caa
```

---

## Troubleshooting

### Issue: Certificate Renewal Fails

**Symptom**:
```
Error: CAA record for mlops.work does not permit issuance by letsencrypt.org
```

**Solution**:
```bash
# 1. Verify CAA records include Let's Encrypt
dig mlops.work CAA +short | grep letsencrypt

# 2. If missing, add record
# Use Cloudflare Dashboard or API

# 3. Wait for DNS propagation (usually < 5 min)
dig @8.8.8.8 mlops.work CAA +short

# 4. Retry certificate issuance
kubectl delete certificaterequest -n traefik-system --all
```

---

### Issue: CAA Check Timeout

**Symptom**:
```
Timeout during CAA check
```

**Solution**:
```bash
# Check DNS resolution
dig mlops.work +trace

# Test from multiple DNS servers
dig @1.1.1.1 mlops.work CAA +short
dig @8.8.8.8 mlops.work CAA +short

# Verify Cloudflare DNS is authoritative
dig mlops.work NS +short
```

---

## Maintenance Schedule

| Task | Frequency | Command |
|------|-----------|---------|
| Verify CAA records | Quarterly | `dig mlops.work CAA +short` |
| Check Cloudflare CA list | Quarterly | Review Cloudflare SSL docs |
| Test certificate renewal | Monthly | `kubectl delete secret mlops-work-wildcard-tls -n traefik-system` |

---

## Emergency Procedures

### Remove All CAA Records (Emergency Only)

**Use Case**: CAA blocking legitimate certificate issuance

```bash
# Backup current configuration
dig mlops.work CAA +short > /tmp/caa-backup.txt

# Delete all CAA records
./scripts/delete-all-caa-records.sh

# Verify removal
dig mlops.work CAA +short
# Expected: (empty)

# Test certificate issuance
kubectl delete certificaterequest -n traefik-system --all

# Restore CAA after resolution
./scripts/create-caa-records-complete.sh
```

---

## References

- [ADR-015: CAA Record Security Strategy](../design-decisions/ADR-015-caa-record-security-strategy.md)
- [Cloudflare DNS API](https://developers.cloudflare.com/api/operations/dns-records-for-a-zone-create-dns-record)
- [RFC 8659: DNS CAA](https://tools.ietf.org/html/rfc8659)
- [Let's Encrypt CAA](https://letsencrypt.org/docs/caa/)

---

## Changelog

| Date | Version |  Author | Changes |
|------|---------|---------|---------|
| 2026-02-12 | 1.0 | Range | Initial DNS operations runbook with CAA management |

