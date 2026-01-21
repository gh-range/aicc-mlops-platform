#!/bin/bash
set -euo pipefail

echo "=== GPU Allocation Validation ==="
echo

echo "[1/4] Node GPU allocation status:"
kubectl describe node llm1 | grep -A 10 "Allocated resources" | grep nvidia.com/gpu
echo

echo "[2/4] gpu-test-a quota usage:"
kubectl get resourcequota gpu-quota -n gpu-test-a -o jsonpath='{.status.used.requests\.nvidia\.com/gpu}' | xargs -I {} echo "  Used: {} / 2"
echo

echo "[3/4] gpu-test-b quota usage:"
kubectl get resourcequota gpu-quota -n gpu-test-b -o jsonpath='{.status.used.requests\.nvidia\.com/gpu}' | xargs -I {} echo "  Used: {} / 2"
echo

echo "[4/4] Running pods:"
echo "  gpu-test-a:"
kubectl get pods -n gpu-test-a --no-headers | awk '{print "    " $1 " - " $3}'
echo "  gpu-test-b:"
kubectl get pods -n gpu-test-b --no-headers | awk '{print "    " $1 " - " $3}'
echo

if [ "$(kubectl get pods -n gpu-test-a --field-selector=status.phase=Running --no-headers | wc -l)" -eq 2 ] && \
   [ "$(kubectl get pods -n gpu-test-b --field-selector=status.phase=Running --no-headers | wc -l)" -eq 2 ]; then
  echo "[o] Validation PASSED: 4 pods running with GPU allocation"
else
  echo "[x] Validation FAILED"
kubectl get resourcequota gpu-quota -n gpu-test-b -o jsonpath='{.status.used.requests\.nvidia\.com/gpu}' | xargs -I {} echo "  Used: {} / 2"
  exit 1
fi
