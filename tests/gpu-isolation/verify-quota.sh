#!/bin/bash
set -euo pipefail

echo "=== ResourceQuota Enforcement Validation ==="
echo

echo "[1/2] Current quota status in gpu-test-a:"
kubectl describe resourcequota gpu-quota -n gpu-test-a | grep -A 2 "nvidia.com/gpu"
echo

echo "[2/2] Attempting to exceed quota..."
OUTPUT=$(kubectl apply -f tests/gpu-isolation/quota-exceed-test.yaml 2>&1 || true)

if echo "$OUTPUT" | grep -q "exceeded quota"; then
  echo "[o] Quota enforcement PASSED: Admission Controller rejected request"
  echo "  Rejection reason: $(echo "$OUTPUT" | grep "exceeded quota")"
else
  echo "[x] Quota enforcement FAILED: Request was not rejected"
  exit 1
fi
