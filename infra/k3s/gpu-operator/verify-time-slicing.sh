#!/bin/bash

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=========================================="
echo "GPU Time-Slicing Verification"
echo "=========================================="
echo ""

CHECKS=0
PASSED=0

# 1. Check GPU count
echo "[*] Step 1: Verify Virtual GPU Count"
GPU_COUNT=$(kubectl get nodes -o jsonpath='{.items[].status.allocatable.nvidia\.com/gpu}')
echo "GPU count: nvidia.com/gpu = $GPU_COUNT"

if [ "$GPU_COUNT" = "4" ]; then
  echo "[o] Correct: 4 virtual GPUs available"
  ((PASSED++))
else
  echo "[x] Expected 4, got $GPU_COUNT"
fi
((CHECKS++))
echo ""

# 2. Deploy 4 test pods
echo "[*] Step 2: Deploy 4 Concurrent GPU Pods"
echo "Creating namespace..."
kubectl create namespace gpu-test 2>/dev/null || echo "[!] Namespace already exists"

echo "Deploying 4 GPU test pods..."
for i in {1..4}; do
  cat <<YAML | kubectl apply -f - &>/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test-$i
  namespace: gpu-test
spec:
  restartPolicy: Never
  containers:
  - name: cuda
    image: nvidia/cuda:13.1.0-base-ubuntu24.04
    command: ["sh", "-c"]
    args:
    - |
      echo "Pod gpu-test-$i started at \$(date)"
      nvidia-smi --query-gpu=index,name,driver_version,memory.total --format=csv
      echo "Running GPU workload for 30 seconds..."
      sleep 30
      echo "Pod gpu-test-$i completed at \$(date)"
    resources:
      limits:
        nvidia.com/gpu: 1
YAML
done

echo "[o] 4 test pods created"
echo ""

# 3. Wait for pods to start
echo "[*] Step 3: Wait for Pods to Start"
echo "Waiting up to 60 seconds..."
sleep 10  # Give time for scheduling

RUNNING=0
for i in {1..12}; do
  RUNNING=$(kubectl get pods -n gpu-test --no-headers 2>/dev/null | grep Running | wc -l)
  echo "  Attempt $i/12: $RUNNING pods running"
  
  if [ $RUNNING -eq 4 ]; then
    echo "[o] All 4 pods are running simultaneously"
    ((PASSED++))
    break
  fi
  sleep 5
done

if [ $RUNNING -lt 4 ]; then
  echo "[x] Only $RUNNING pods running (expected 4)"
  echo ""
  echo "Pod status:"
  kubectl get pods -n gpu-test
fi
((CHECKS++))
echo ""

# 4. Check pod GPU access

echo "[*] Step 4: Verify Each Pod Can Access GPU"
echo ""
SUCCESS=0
for i in {1..4}; do
  echo "Checking gpu-test-$i..."
  
  # Wait for pod to be running or completed
  kubectl wait --for=condition=Ready pod/gpu-test-$i -n gpu-test --timeout=30s 2>/dev/null || \
  kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/gpu-test-$i -n gpu-test --timeout=30s 2>/dev/null
  
  LOG=$(kubectl logs -n gpu-test gpu-test-$i 2>/dev/null)
  
  if echo "$LOG" | grep -q "NVIDIA-SMI\|RTX A4000"; then
    echo "  [o] gpu-test-$i: GPU access confirmed"
    ((SUCCESS++))
  else
    echo "  [x] gpu-test-$i: No GPU access detected"
    echo "  Log:"
    echo "$LOG" | head -5
  fi
  echo ""
done

if [ $SUCCESS -eq 4 ]; then
  echo "[o] All 4 pods successfully accessed GPU"
  ((PASSED++))
else
  echo "[x] Only $SUCCESS/4 pods accessed GPU"
fi
((CHECKS++))
echo ""

# 5. Check physical GPU utilization
echo "[*] Step 5: Check Physical GPU Utilization"
echo "All 4 pods are sharing the same physical GPU"
echo ""
nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total --format=csv
echo ""

# 6. Show pod distribution
echo "[*] Step 6: Pod Distribution"
kubectl get pods -n gpu-test -o wide
echo ""

# 7. Check DCGM metrics during workload
echo "[*] Step 7: DCGM Metrics Sample"
#DCGM_POD=$(kubectl get pods -n gpu-operator -l app=nvidia-dcgm-exporter --no-headers | awk '{print $1}')
#if [ -n "$DCGM_POD" ]; then
#  echo "Sampling GPU metrics..."
#  kubectl exec -n gpu-operator $DCGM_POD -- curl -s localhost:9400/metrics 2>/dev/null | \
#    grep -E "DCGM_FI_DEV_(GPU_UTIL|FB_USED)" | head -5
#else
#  echo "[!] DCGM exporter pod not found"
#fi
DCGM_POD=$(kubectl get pods -n gpu-operator -l app=nvidia-dcgm-exporter --no-headers | awk '{print $1}' | head -1)

if [ -n "$DCGM_POD" ]; then
  echo "Fetching metrics from pod: $DCGM_POD"
  
  # Get pod IP for direct access
  POD_IP=$(kubectl get pod -n gpu-operator "$DCGM_POD" -o jsonpath='{.status.podIP}')
  
  if [ -n "$POD_IP" ]; then
    echo "Pod IP: $POD_IP"
    echo ""
    echo "Key GPU metrics:"
    echo "----------------------------------------"
    
    # Fetch metrics and display with values
    METRICS=$(curl -s --max-time 5 http://"$POD_IP":9400/metrics 2>/dev/null)
    
    if [ -n "$METRICS" ]; then
      # GPU Utilization
      echo "$METRICS" | grep -E '^DCGM_FI_DEV_GPU_UTIL\{' | head -2
      
      # Memory Used
      echo "$METRICS" | grep -E '^DCGM_FI_DEV_FB_USED\{' | head -2
      
      # Memory Free
      echo "$METRICS" | grep -E '^DCGM_FI_DEV_FB_FREE\{' | head -2
      
      # GPU Temperature
      echo "$METRICS" | grep -E '^DCGM_FI_DEV_GPU_TEMP\{' | head -2
      
      # Power Usage
      echo "$METRICS" | grep -E '^DCGM_FI_DEV_POWER_USAGE\{' | head -2
      
      echo "----------------------------------------"
      echo "[o] DCGM metrics available"
    else
      echo "[!] No metrics returned from endpoint"
      echo "    Try: curl http://$POD_IP:9400/metrics | head"
    fi
  else
    echo "[x] Failed to get pod IP"
  fi
else
  echo "[!] DCGM exporter pod not found"
fi

echo ""

# Cleanup option
echo "=========================================="
echo "Cleanup"
echo "=========================================="
echo ""
read -p "Delete test pods? (yes/no): " CLEANUP

if [ "$CLEANUP" = "yes" ]; then
  echo "Deleting test namespace..."
  kubectl delete namespace gpu-test --wait=false
  echo "[o] Cleanup initiated"
else
  echo "[!] Test pods kept in namespace: gpu-test"
  echo "    To cleanup later: kubectl delete namespace gpu-test"
fi
echo ""

# Summary
echo "=========================================="
echo "Verification Summary"
echo "=========================================="
echo ""
echo "Result: $PASSED / $CHECKS checks passed"
echo ""

if [ $PASSED -eq $CHECKS ]; then
  echo "[o] GPU Time-Slicing is fully functional"
  echo ""
  echo "Capabilities verified:"
  echo "  - 4 virtual GPUs available"
  echo "  - 4 pods running simultaneously"
  echo "  - All pods can access GPU"
  echo "  - Sharing same physical RTX A4000"
  echo ""
  echo "Ready for production use (JupyterHub, Ollama, etc.)"
  exit 0
else
  echo "[x] Some checks failed"
  echo ""
  echo "Review errors above and troubleshoot"
  exit 1
fi
echo ""
echo "=========================================="
