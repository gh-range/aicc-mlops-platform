#!/bin/bash
echo "=== JupyterHub NetworkPolicy Verification ==="
echo ""

# Test 1: Browser-like curl (with redirect)
echo "Test 1: Full request with redirect..."
HTTP_CODE=$(curl -L -s -o /dev/null -w "%{http_code}" --max-time 30 https://jupyter.mlops.work)
echo "  Final status: $HTTP_CODE"
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
    echo "[o] PASS"
else
    echo "[x] FAIL"
fi

# Test 2: Check pods
echo ""
echo "Test 2: JupyterHub pods status..."
kubectl get pods -n jupyterhub --no-headers | awk '{print "  " $1 ": " $3}'

# Test 3: Check NetworkPolicy
echo ""
echo "Test 3: NetworkPolicy applied..."
NP_COUNT=$(kubectl get networkpolicy -n jupyterhub --no-headers | wc -l)
echo "  NetworkPolicies: $NP_COUNT"
kubectl get networkpolicy -n jupyterhub --no-headers | awk '{print "  - " $1}'

# Test 4: Check logs for errors
echo ""
echo "Test 4: Recent proxy logs..."
kubectl logs -n jupyterhub -l component=proxy --tail=5 2>&1 | grep -iE "error|fail|502" || echo " [o] No errors in logs"

echo ""
echo "=== Summary ==="
echo "Browser accessible: [Manual test required]"
echo "Pods running: $(kubectl get pods -n jupyterhub --field-selector=status.phase=Running --no-headers | wc -l)/$(kubectl get pods -n jupyterhub --no-headers | wc -l)"
echo ""
echo "[o] If browser works, NetworkPolicy is CORRECT"
