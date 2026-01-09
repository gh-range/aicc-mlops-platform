#!/bin/bash

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=========================================="
echo "Deploy GPU Time-Slicing Configuration"
echo "=========================================="
echo ""

# 1. Create ConfigMap
echo "[*] Step 1: Create Time-Slicing ConfigMap"
kubectl apply -f infra/k3s/gpu-operator/time-slicing-config.yaml

if [ $? -eq 0 ]; then
  echo "[o] ConfigMap created"
else
  echo "[x] Failed to create ConfigMap"
  exit 1
fi
echo ""

# 2. Verify ConfigMap
echo "[*] Step 2: Verify ConfigMap"
kubectl get configmap -n gpu-operator time-slicing-config
echo ""
echo "ConfigMap content:"
kubectl get configmap -n gpu-operator time-slicing-config -o yaml | grep -A 10 "any:"
echo ""

# 3. Check current GPU count
echo "[*] Step 3: Current GPU Count (before time-slicing)"
CURRENT_GPU=$(kubectl get nodes -o jsonpath='{.items[].status.allocatable.nvidia\.com/gpu}')
echo "Current: nvidia.com/gpu = $CURRENT_GPU"
echo ""

echo "=========================================="
echo "ConfigMap deployed successfully"
echo "=========================================="
echo ""
echo "Next step: Update device plugin to use this config"
echo ""
