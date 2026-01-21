#!/bin/bash
set -euo pipefail

echo "=== GPU Resource Recovery Test ==="
echo

echo "[1/5] Initial state - gpu-test-a quota:"
kubectl get resourcequota gpu-quota -n gpu-test-a -o jsonpath='{.status.used.requests\.nvidia\.com/gpu}' | xargs -I {} echo "  Used: {}/2"
echo

echo "[2/5] Deleting 2 pods from gpu-test-a..."
kubectl delete pod gpu-pod-1 gpu-pod-2 -n gpu-test-a --wait=true
echo "  Pods deleted"
echo

echo "[3/5] Waiting for quota update (5s)..."
sleep 5
echo

echo "[4/5] After deletion - gpu-test-a quota:"
kubectl get resourcequota gpu-quota -n gpu-test-a -o jsonpath='{.status.used.requests\.nvidia\.com/gpu}' | xargs -I {} echo "  Used: {}/2"
echo

echo "[5/5] Redeploying pods to verify resource reallocation..."
kubectl apply -f tests/gpu-isolation/concurrent-pods.yaml
sleep 10

RUNNING=$(kubectl get pods -n gpu-test-a --field-selector=status.phase=Running --no-headers | wc -l)
if [ "$RUNNING" -eq 2 ]; then
  echo "[o] Recovery test PASSED: GPU resources reclaimed and reallocated"
else
  echo "[x] Recovery test FAILED: Only $RUNNING/2 pods running"
  exit 1
fi

