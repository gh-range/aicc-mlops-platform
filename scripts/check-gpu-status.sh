#!/bin/bash
set -euo pipefail

echo "=========================================="
echo "  GPU Infrastructure Status Check"
echo "=========================================="
echo

echo "[1/5] GPU Operator Health"
echo "---"
OPERATOR_RUNNING=$(kubectl get pods -n gpu-operator --no-headers 2>/dev/null | grep -E "Running|Completed" | wc -l || echo "0")
OPERATOR_TOTAL=$(kubectl get pods -n gpu-operator --no-headers 2>/dev/null | wc -l || echo "0")
echo "  Healthy: $OPERATOR_RUNNING/$OPERATOR_TOTAL pods"
if [ "$OPERATOR_RUNNING" -eq "$OPERATOR_TOTAL" ] && [ "$OPERATOR_TOTAL" -gt 0 ]; then
  echo "  Status: [o] HEALTHY"
else
  echo "  Status: [x] DEGRADED"
fi
echo

echo "[2/5] Node GPU Capacity"
echo "---"
GPU_CAPACITY=$(kubectl get node llm1 -o jsonpath='{.status.allocatable.nvidia\.com/gpu}' 2>/dev/null || echo "0")
echo "  Allocatable: $GPU_CAPACITY GPU"
if [ "$GPU_CAPACITY" -eq 4 ]; then
  echo "  Status: [o] Time-Slicing Active (4x)"
else
  echo "  Status: [x] Unexpected capacity"
fi
echo

echo "[3/5] GPU Resource Allocation"
echo "---"
kubectl describe node llm1 2>/dev/null | grep -A 3 "Allocated resources" | grep nvidia.com/gpu || echo "  Unable to retrieve"
echo

echo "[4/5] Time-Slicing Configuration"
echo "---"
if kubectl get configmap time-slicing-config -n gpu-operator &>/dev/null; then
  REPLICAS=$(kubectl get configmap time-slicing-config -n gpu-operator -o jsonpath='{.data.any}' | grep -oP 'replicas: \K\d+' || echo "N/A")
  echo "  ConfigMap: time-slicing-config"
  echo "  Replicas: $REPLICAS"
  echo "  Status: [o] CONFIGURED"
else
  echo "  Status: [x] ConfigMap not found"
fi
echo

echo "[5/5] Active GPU Pods"
echo "---"
GPU_PODS=$(kubectl get pods -A -o json 2>/dev/null | jq -r '.items[] | select(.spec.containers[].resources.requests."nvidia.com/gpu") | "\(.metadata.namespace)/\(.metadata.name)"' | wc -l || echo "0")
echo "  Total: $GPU_PODS pods requesting GPU"
if [ "$GPU_PODS" -gt 0 ]; then
  kubectl get pods -A -o json 2>/dev/null | jq -r '.items[] | select(.spec.containers[].resources.requests."nvidia.com/gpu") | "  - \(.metadata.namespace)/\(.metadata.name) (\(.status.phase))"'
fi
echo

echo "=========================================="
echo "  Check Complete"
echo "=========================================="
