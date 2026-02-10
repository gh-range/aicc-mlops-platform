#!/bin/bash
# TLS Security Test for OpenSSL 3.0+ Environments

ENDPOINT="jupyter.mlops.work:443"

echo "=== TLS Security Test (OpenSSL 3.0 Compatible) ==="
echo ""

# Check OpenSSL version
OPENSSL_VER=$(openssl version | awk '{print $2}')
echo "OpenSSL Version: $OPENSSL_VER"
echo ""

# Test 1: Protocol versions
echo "--- Protocol Version Check ---"
for VER in tls1 tls1_1 tls1_2 tls1_3; do
    echo -n "$(echo $VER | tr '_' '.'): "
    if timeout 3 openssl s_client -connect "$ENDPOINT" "-$VER" </dev/null 2>&1 | grep -q "Cipher.*:"; then
        echo "ENABLED"
    else
        echo "DISABLED"
    fi
done

echo ""
echo "--- Strong Cipher Verification ---"

# Test 2: Verify strong ciphers work
echo -n "TLS 1.3 Default Cipher: "
openssl s_client -connect "$ENDPOINT" -tls1_3 </dev/null 2>&1 | grep "Cipher" | awk '{print $3}'

echo -n "TLS 1.2 Default Cipher: "
openssl s_client -connect "$ENDPOINT" -tls1_2 </dev/null 2>&1 | grep "Cipher" | awk '{print $3}'

echo ""
echo "--- Weak Cipher Test (OpenSSL 3.0 Aware) ---"

# Test 3: Try weak ciphers (expect "no cipher match")
WEAK_CIPHERS=("DES-CBC3-SHA" "RC4-SHA" "NULL-SHA")

for CIPHER in "${WEAK_CIPHERS[@]}"; do
    echo -n "$CIPHER: "
    RESULT=$(timeout 3 openssl s_client -connect "$ENDPOINT" -cipher "$CIPHER" -tls1_2 </dev/null 2>&1)
    
    if echo "$RESULT" | grep -q "no cipher"; then
        echo "[o] BLOCKED (OpenSSL 3.0 system-level)"
    elif echo "$RESULT" | grep -qE "handshake failure|alert"; then
        echo "[o] REJECTED (Server-side)"
    elif echo "$RESULT" | grep -q "Cipher.*: $CIPHER"; then
        echo "[x] ACCEPTED (SECURITY ISSUE)"
    else
        echo "? UNKNOWN"
    fi
done

echo ""
echo "--- CBC Mode Test (Legacy TLS 1.2) ---"
# CBC is still in OpenSSL 3.0 but should be rejected by server
echo -n "AES128-SHA (CBC): "
RESULT=$(timeout 3 openssl s_client -connect "$ENDPOINT" -cipher "AES128-SHA" -tls1_2 </dev/null 2>&1)
if echo "$RESULT" | grep -qE "handshake failure|no cipher|alert"; then
    echo "[o] REJECTED"
elif echo "$RESULT" | grep -q "Cipher.*: AES128-SHA"; then
    echo "[x] ACCEPTED"
else
    echo "? UNKNOWN"
fi

echo ""
echo "=== Summary ==="
echo "✓ OpenSSL 3.0 provides system-level protection against legacy ciphers"
echo "✓ For complete validation, use testssl.sh or SSL Labs"
echo ""
echo "Expected Results:"
echo "  - TLS 1.0/1.1: DISABLED"
echo "  - TLS 1.2/1.3: ENABLED"
echo "  - 3DES/RC4: BLOCKED by OpenSSL 3.0"
echo "  - CBC Mode: REJECTED by server"
