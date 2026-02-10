#!/bin/bash
# Test TLS Protocol Version Enforcement

ENDPOINT="jupyter.mlops.work:443"

echo "=== TLS Protocol Version Test ==="
echo "Endpoint: $ENDPOINT"
echo ""

# Test old protocols (should fail)
echo "--- Legacy Protocols (Should be REJECTED) ---"
for VER in "ssl3" "tls1" "tls1_1"; do
    echo -n "Testing $VER: "
    if timeout 3 openssl s_client -connect "$ENDPOINT" "-$VER" </dev/null 2>&1 | grep -q "Cipher.*:"; then
        echo "[x] FAIL (Insecure protocol accepted)"
    else
        echo "[o] PASS (Rejected)"
    fi
done

echo ""
echo "--- Modern Protocols (Should be ACCEPTED) ---"
for VER in "tls1_2" "tls1_3"; do
    echo -n "Testing $VER: "
    if timeout 3 openssl s_client -connect "$ENDPOINT" "-$VER" </dev/null 2>&1 | grep -q "Cipher.*:"; then
        echo "[o] PASS (Accepted)"
    else
        echo "[x] FAIL (Modern protocol rejected)"
    fi
done
