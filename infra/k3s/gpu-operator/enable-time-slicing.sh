#!/bin/bash

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=========================================="
echo "Enable GPU Time-Slicing in Device Plugin"
echo "=========================================="
echo ""

# 1. Check ConfigMap exists
echo "[*] Step 1: Verify Time-Slicing ConfigMap"
if kubectl get configmap -n gpu-operator time-slicing-config &>/dev/null; then
  echo "[o] ConfigMap exists"
else
  echo "[x] ConfigMap not found"
  echo "    Run: ./infra/k3s/gpu-operator/deploy-time-slicing.sh"
  exit 1
fi
echo ""

# 2. Update GPU Operator to use time-slicing config
echo "[*] Step 2: Update GPU Operator Values"
echo "Patching devicePlugin configuration..."

# Create temporary values file with updated config
cat > /tmp/gpu-operator-timeslicing-values.yaml << 'VALUES'
devicePlugin:
  enabled: true
  config:
    name: time-slicing-config
    default: any
VALUES

echo "[o] Updated values prepared"
echo ""
cat /tmp/gpu-operator-timeslicing-values.yaml
echo ""

# 3. Upgrade Helm release
echo "[*] Step 3: Upgrade GPU Operator Helm Release"
helm upgrade gpu-operator nvidia/gpu-operator \
  -n gpu-operator \
  -f infra/k3s/gpu-operator/values.yaml \
  -f /tmp/gpu-operator-timeslicing-values.yaml \
  --reuse-values

if [ $? -eq 0 ]; then
  echo "[o] Helm upgrade successful"
else
  echo "[x] Helm upgrade failed"
  exit 1
fi
echo ""

# 4. Restart device plugin pods
echo "[*] Step 4: Restart Device Plugin Pods"
echo "Deleting device plugin pods to apply new config..."
kubectl delete pod -n gpu-operator -l app=nvidia-device-plugin-daemonset

if [ $? -eq 0 ]; then
  echo "[o] Device plugin pods deleted (will be recreated)"
else
  echo "[x] Failed to delete pods"
  exit 1
fi
echo ""

# 5. Wait for pods to be ready
echo "[*] Step 5: Wait for Device Plugin Pods to be Ready"
echo "Waiting up to 60 seconds..."
kubectl wait --for=condition=Ready pod \
  -n gpu-operator \
  -l app=nvidia-device-plugin-daemonset \
  --timeout=60s

if [ $? -eq 0 ]; then
  echo "[o] Device plugin pods are ready"
else
  echo "[x] Pods not ready within timeout"
  echo "    Check status: kubectl get pods -n gpu-operator -l app=nvidia-device-plugin-daemonset"
fi
echo ""

# 6. Check GPU count
echo "[*] Step 6: Verify GPU Count (should be 4 now)"
sleep 5  # Give kubelet time to update allocatable resources

GPU_COUNT=$(kubectl get nodes -o jsonpath='{.items[].status.allocatable.nvidia\.com/gpu}')
echo "GPU count: nvidia.com/gpu = $GPU_COUNT"
echo ""

if [ "$GPU_COUNT" = "4" ]; then
  echo "[o] Time-slicing is active! 4 virtual GPUs available"
else
  echo "[!] GPU count is $GPU_COUNT (expected 4)"
  echo "    This may take a few more seconds to update"
  echo ""
  echo "Check again with:"
  echo "  kubectl get nodes -o json | jq '.items[].status.allocatable'"
fi
echo ""

# 7. Show device plugin logs
echo "[*] Step 7: Device Plugin Logs (last 20 lines)"
PLUGIN_POD=$(kubectl get pods -n gpu-operator -l app=nvidia-device-plugin-daemonset --no-headers | awk '{print $1}' | head -1)
if [ -n "$PLUGIN_POD" ]; then
  kubectl logs -n gpu-operator $PLUGIN_POD --tail=20
else
  echo "[!] Device plugin pod not found"
fi
echo ""

echo "=========================================="
echo "Time-Slicing Configuration Complete"
echo "=========================================="
echo ""
echo "Summary:"
echo "  ConfigMap: time-slicing-config"
echo "  Replicas: 4"
echo "  Physical GPU: 1x RTX A4000 16GB"
echo "  Virtual GPUs: $GPU_COUNT"
echo ""
echo "Next: Verify with test pods"
echo ""
