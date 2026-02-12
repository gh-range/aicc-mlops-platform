#!/bin/bash
set -e

echo "=== NetworkPolicy Test Suite ==="
echo ""

test_endpoint() {
    local name=$1
    local url=$2
    echo -n "Testing $name... "
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")
    if echo "$HTTP_CODE" | grep -qE "200|302"; then
        echo "[o] PASS ($HTTP_CODE)"
        return 0
    else
        echo "[x] FAIL ($HTTP_CODE)"
        return 1
    fi
}

FAILED=0

# Test JupyterHub
test_endpoint "JupyterHub" "https://jupyter.mlops.work" || FAILED=1

# Check NetworkPolicies exist
echo ""
echo "Checking NetworkPolicies..."
TRAEFIK_NP=$(kubectl get networkpolicy -n traefik-system --no-headers 2>/dev/null | wc -l)
JUPYTER_NP=$(kubectl get networkpolicy -n jupyterhub --no-headers 2>/dev/null | wc -l)
echo "  Traefik: $TRAEFIK_NP policy(ies)"
echo "  JupyterHub: $JUPYTER_NP policy(ies)"

# Check pods running
echo ""
echo "Checking pod status..."
TRAEFIK_PODS=$(kubectl get pods -n traefik-system -l app.kubernetes.io/name=traefik --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
JUPYTER_PODS=$(kubectl get pods -n jupyterhub -l component=proxy --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
echo "  Traefik pods running: $TRAEFIK_PODS"
echo "  JupyterHub proxy running: $JUPYTER_PODS"

echo ""
if [ $FAILED -eq 0 ]; then
    echo "[o] All tests PASSED"
    exit 0
else
    echo "[x] Some tests FAILED"
    exit 1
fi
