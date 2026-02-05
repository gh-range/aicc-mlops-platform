#!/bin/bash
# Traefik Router Health Check
# Tests HTTPS connectivity and certificate validity for all routers

set -euo pipefail

FAIL_COUNT=0

echo "=== Traefik Router Health Check ==="
echo ""

# Get all routers
ROUTERS=$(kubectl get ingressroute -n traefik-system -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

for ROUTER in $ROUTERS; do
    HOST=$(kubectl get ingressroute "$ROUTER" -n traefik-system -o jsonpath='{.spec.routes[0].match}' | grep -oP "Host\(\`\K[^\`]+")
    
    echo "Testing: $HOST"
    
    # Test HTTPS connectivity
    if curl -s -o /dev/null -w "%{http_code}" "https://$HOST/" --max-time 5 | grep -qE "^(200|301|302|401|404|405)$"; then
        echo " [o] HTTPS accessible"
    else
        echo " [x] HTTPS failed"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    # Verify certificate
    CERT_ISSUER=$(echo | openssl s_client -connect localhost:443 -servername "$HOST" 2>/dev/null | openssl x509 -noout -issuer 2>/dev/null | grep -oP "O = \K[^,]+")
    if [ "$CERT_ISSUER" = "Let's Encrypt" ]; then
        echo " [o] Certificate valid (Let's Encrypt)"
    else
        echo " [!]  Certificate issuer: $CERT_ISSUER"
    fi
    
    echo ""
done

if [ $FAIL_COUNT -eq 0 ]; then
    echo " [o] All routers healthy"
    exit 0
else
    echo " [x] $FAIL_COUNT router(s) failed"
    exit 1
fi
