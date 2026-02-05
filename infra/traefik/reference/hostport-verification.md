**Date**: 2026/01/25
**Node**: llm1
**Node IP**: 192.168.10.151

## HostPort Configuration
\`\`\`json
[
  {
    "containerPort": 9100,
    "name": "metrics",
    "protocol": "TCP"
  },
  {
    "containerPort": 9000,
    "name": "traefik",
    "protocol": "TCP"
  },
  {
    "containerPort": 8000,
    "hostPort": 80,
    "name": "web",
    "protocol": "TCP"
  },
  {
    "containerPort": 8443,
    "hostPort": 443,
    "name": "websecure",
    "protocol": "TCP"
  }
]
\`\`\`

## Verification Results

| Test | Result | Status |
|------|--------|--------|
| HTTP :80 | 404 page not found | [o] Working |
| HTTPS :443 | 404 page not found | [o] Working |
| HostPort Config | 80→8000, 443→8443 | [o] Correct |

## Key Points

**[o] 404 is SUCCESS** - Traefik is responding, no routes configured yet

**[!] netstat on host shows nothing** - This is NORMAL
- HostPort binding is in container network namespace
- Use curl to test, not netstat

## Traffic Flow

```
External :80/:443 → iptables DNAT → Container :8000/:8443 → Traefik
```

## Verification Commands

```bash
# Test connectivity
NODE_IP=$(hostname -I | awk '{print $1}')
curl -v http://$NODE_IP:80        # Expected: 404
curl -kv https://$NODE_IP:443     # Expected: 404

# Check container ports
kubectl exec -n traefik-system $(kubectl get pod -n traefik-system -l app.kubernetes.io/name=traefik -o name) -- netstat -tuln | grep -E ':8000|:8443'
```

## Status: [o] HostPort Working Correctly

404 response confirms Traefik is accessible on ports 80/443.
No routes configured yet (expected behavior).

