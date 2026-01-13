#!/bin/bash

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=========================================="
echo "GPU Operator Post-Installation Verification"
echo "=========================================="
echo ""

CHECKS=0
PASSED=0

# Helper functions
check_pass() {
  echo "[o] $1"
  ((PASSED++)) || true
}

check_fail() {
  echo "[x] $1"
}

# 1. Check all pods running
echo "[*] Step 1: Check All Pods Status"
((CHECKS++)) || true

echo "DEBUG: Getting pod list..."
TOTAL_PODS=$(kubectl get pods -n gpu-operator --no-headers 2>/dev/null | wc -l)
echo "DEBUG: Total pods: $TOTAL_PODS"

NOT_READY=$(kubectl get pods -n gpu-operator --no-headers 2>/dev/null | grep -vE "Running|Completed" | wc -l || echo "0")
echo "DEBUG: Not ready pods: $NOT_READY"

READY_PODS=$((TOTAL_PODS - NOT_READY))
echo "DEBUG: Ready pods: $READY_PODS"

echo "Pod status: $READY_PODS / $TOTAL_PODS ready"
if [ "$NOT_READY" -eq 0 ]; then
  check_pass "All pods are Running or Completed"
else
  check_fail "Some pods are not ready"
  kubectl get pods -n gpu-operator 2>/dev/null | grep -vE "Running|Completed" || echo "No problematic pods"
fi
echo ""

# 2. Check GPU resources advertised
echo "[*] Step 2: Check GPU Resources Advertised"
((CHECKS++)) || true

GPU_COUNT=$(kubectl get nodes -o jsonpath='{.items[0].status.allocatable.nvidia\.com/gpu}' 2>/dev/null || echo "0")
echo "GPU count: $GPU_COUNT"

if [ "$GPU_COUNT" != "0" ] && [ -n "$GPU_COUNT" ]; then
  check_pass "GPU resources are advertised"
  kubectl get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\\.com/gpu 2>/dev/null || true
else
  check_fail "GPU resources not advertised"
  echo "    Check device plugin logs:"
  echo "    kubectl logs -n gpu-operator -l app=nvidia-device-plugin-daemonset"
fi
echo ""

# 3. Check node labels
echo "[*] Step 3: Check Node GPU Labels"
((CHECKS++)) || true

LABELS=$(kubectl get nodes -o json 2>/dev/null | jq -r '.items[0].metadata.labels' 2>/dev/null | grep "nvidia.com/gpu" || echo "")
if [ -n "$LABELS" ]; then
  check_pass "Node has GPU labels"
  echo "Sample labels:"
  kubectl get nodes -o json 2>/dev/null | jq -r '.items[0].metadata.labels' | grep nvidia.com | head -6 || true
  echo "    ..."
else
  check_fail "No GPU labels found"
  echo "    Check GFD logs:"
  echo "    kubectl logs -n gpu-operator -l app=gpu-feature-discovery"
fi
echo ""

# 4. Check RuntimeClass
echo "[*] Step 4: Check RuntimeClass"
((CHECKS++)) || true

if kubectl get runtimeclass nvidia &>/dev/null 2>&1; then
  check_pass "RuntimeClass 'nvidia' exists"
  kubectl get runtimeclass nvidia -o wide 2>/dev/null || true
else
  check_fail "RuntimeClass 'nvidia' not found"
fi
echo ""

# 5. Check DCGM exporter service
echo "[*] Step 5: Check DCGM Exporter Service"
((CHECKS++)) || true

if kubectl get svc -n gpu-operator nvidia-dcgm-exporter &>/dev/null 2>&1; then
  check_pass "DCGM Exporter service exists"
  kubectl get svc -n gpu-operator nvidia-dcgm-exporter 2>/dev/null || true
else
  check_fail "DCGM Exporter service not found"
fi
echo ""

# 6. Test GPU scheduling
echo "[*] Step 6: Test GPU Pod Scheduling"
((CHECKS++)) || true

echo "Creating test pod with GPU access..."
kubectl run test-gpu-verify \
  --rm -i \
  --restart=Never \
  --image=nvidia/cuda:13.1.0-base-ubuntu24.04 \
  --overrides='{"spec":{"runtimeClassName":"nvidia","containers":[{"name":"test-gpu-verify","image":"nvidia/cuda:13.1.0-base-ubuntu24.04","command":["nvidia-smi"],"stdin":true,"tty":false,"resources":{"limits":{"nvidia.com/gpu":"1"}}}]}}' \
  > /tmp/gpu-test.log 2>&1 || echo "Test pod execution completed"

if grep -q "NVIDIA-SMI" /tmp/gpu-test.log 2>/dev/null; then
  check_pass "Test pod successfully accessed GPU"
  echo ""
  echo "GPU info from test pod:"
  grep -A 3 "NVIDIA-SMI" /tmp/gpu-test.log | head -5 || true
else
  check_fail "Test pod could not access GPU"
  echo "Test output:"
  cat /tmp/gpu-test.log 2>/dev/null || echo "No log output"
fi
echo ""

# 7. Check DCGM metrics
echo "[*] Step 7: Check DCGM Metrics Availability"
((CHECKS++)) || true

DCGM_POD=$(kubectl get pods -n gpu-operator -l app=nvidia-dcgm-exporter --no-headers 2>/dev/null | awk '{print $1}' | head -1)

if [ -n "$DCGM_POD" ]; then
  echo "Testing metrics from pod: $DCGM_POD"
  
  POD_IP=$(kubectl get pod -n gpu-operator "$DCGM_POD" -o jsonpath='{.status.podIP}' 2>/dev/null)
  
  if [ -n "$POD_IP" ]; then
    METRICS=$(curl -s --max-time 5 http://"$POD_IP":9400/metrics 2>/dev/null | grep "DCGM_FI_DEV_GPU_UTIL" | head -1 || echo "")
    
    if [ -n "$METRICS" ]; then
      check_pass "DCGM metrics are available"
      echo "Sample metric: $METRICS"
    else
      check_fail "DCGM metrics not available yet"
      echo "    This may be normal if GPU not under load"
      echo "    Verify endpoint: curl http://$POD_IP:9400/metrics | head"
    fi
  else
    check_fail "Failed to get DCGM pod IP"
  fi
else
  check_fail "DCGM exporter pod not found"
fi
echo ""

# 8. Check containerd config
echo "[*] Step 8: Verify Containerd Configuration"
((CHECKS++)) || true

if [ -f "/var/lib/rancher/k3s/agent/etc/containerd/config.toml" ]; then
  if grep -q "nvidia" /var/lib/rancher/k3s/agent/etc/containerd/config.toml 2>/dev/null; then
    check_pass "Containerd has nvidia runtime configured"
  else
    check_fail "Containerd config missing nvidia runtime"
  fi
else
  check_fail "Containerd config file not found"
fi
echo ""

# 9. Verify Persistence Mode
echo "[*] Step 9: Verify GPU Persistence Mode"
((CHECKS++)) || true

PERSISTENCE_MODE=$(nvidia-smi --query-gpu=persistence_mode --format=csv,noheader 2>/dev/null || echo "Unknown")
echo "Persistence mode: $PERSISTENCE_MODE"

if [ "$PERSISTENCE_MODE" = "Enabled" ]; then
  check_pass "GPU Persistence mode is enabled"
else
  check_fail "Persistence mode is disabled"
  echo "    This may cause Device Plugin instability"
  echo "    Enable with: sudo nvidia-smi -pm 1"
  echo "    Or run: sudo bash setup-nvidia-persistence.sh"
fi
echo ""

# Summary
echo "=========================================="
echo "Verification Summary"
echo "=========================================="
echo ""
echo "Checks completed: $CHECKS"
echo "Checks passed: $PASSED"
echo ""

if [ "$PASSED" -eq "$CHECKS" ]; then
  echo "[o] GPU Operator is fully operational"
  echo ""
  echo "=========================================="
  echo "Your GPU Setup is Ready!"
  echo "=========================================="
  echo ""
  echo "Environment:"
  DRIVER_VER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null || echo "unknown")
  GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo "unknown")
  K3S_VER=$(kubectl version --output=json 2>/dev/null | jq -r '.serverVersion.gitVersion' 2>/dev/null || echo "unknown")
  echo "  Driver: $DRIVER_VER"
  echo "  GPU: $GPU_NAME"
  echo "  k3s: $K3S_VER"
  echo ""
  echo "Next steps:"
  echo "  1. Configure GPU time-slicing"
  echo "  2. Deploy Prometheus/Grafana for GPU monitoring"
  echo "  3. Test with actual ML workload"
  echo ""
  echo "Quick test commands:"
  echo "  # Run GPU workload"
  echo "  kubectl run cuda-test --rm -it --restart=Never \\"
  echo "    --image=nvidia/cuda:13.1.0-base-ubuntu24.04 \\"
  echo "    --overrides='{\"spec\":{\"runtimeClassName\":\"nvidia\",\"containers\":[{\"name\":\"cuda\",\"image\":\"nvidia/cuda:13.1.0-base-ubuntu24.04\",\"command\":[\"nvidia-smi\"],\"resources\":{\"limits\":{\"nvidia.com/gpu\":\"1\"}}}]}}'"
  echo ""
  echo "  # Check GPU metrics"
  echo "  POD=\$(kubectl get pod -n gpu-operator -l app=nvidia-dcgm-exporter -o name | head -1)"
  echo "  kubectl port-forward -n gpu-operator \$POD 9400:9400 &"
  echo "  curl localhost:9400/metrics | grep DCGM_FI_DEV"
  echo ""
  exit 0
else
  FAILED=$((CHECKS - PASSED))
  echo "[x] $FAILED checks failed"
  echo ""
  echo "Troubleshooting commands:"
  echo "  kubectl get pods -n gpu-operator"
  echo "  kubectl logs -n gpu-operator -l app=gpu-operator"
  echo "  kubectl describe node | grep nvidia.com"
  echo "  kubectl logs -n gpu-operator -l app=nvidia-device-plugin-daemonset"
  echo ""
  exit 1
fi
echo ""
echo "=========================================="

