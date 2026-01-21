#!/bin/bash
set -euo pipefail

echo "=== GPU Multi-Tenant Namespace Validation ==="
echo

# Check namespaces exist
echo "[1/3] Verifying namespaces..."
for ns in gpu-test-a gpu-test-b; do
  if kubectl get namespace "$ns" &>/dev/null; then
    echo "  ✓ Namespace $ns exists"
  else
    echo "  ✗ Namespace $ns NOT found"
    exit 1
  fi
done
echo

# Check ResourceQuotas
echo "[2/3] Verifying ResourceQuotas..."
for ns in gpu-test-a gpu-test-b; do
  if kubectl get resourcequota gpu-quota -n "$ns" &>/dev/null; then
    echo "  ✓ ResourceQuota exists in $ns"
    
    # Extract GPU quota
    gpu_hard=$(kubectl get resourcequota gpu-quota -n "$ns" -o jsonpath='{.spec.hard.requests\.nvidia\.com/gpu}')
    echo "    GPU Hard Limit: $gpu_hard"
  else
    echo "  ✗ ResourceQuota NOT found in $ns"
    exit 1
  fi
done
echo

# Display current quota usage
echo "[3/3] Current quota usage:"
for ns in gpu-test-a gpu-test-b; do
  echo
  echo "--- $ns ---"
  kubectl describe resourcequota gpu-quota -n "$ns" | grep -A 15 "Resource"
done

echo
echo "=== Validation Complete ==="
