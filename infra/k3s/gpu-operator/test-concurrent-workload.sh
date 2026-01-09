#!/bin/bash

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=========================================="
echo "Test Concurrent GPU Workload (2 minutes)"
echo "=========================================="
echo ""

kubectl create namespace gpu-concurrent 2>/dev/null

echo "Deploying 4 concurrent GPU workloads..."
for i in {1..4}; do
  cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: gpu-work-$i
  namespace: gpu-concurrent
spec:
  restartPolicy: Never
  containers:
  - name: cuda
    image: nvidia/cuda:13.1.0-base-ubuntu24.04
    command: ["sh", "-c"]
    args:
    - |
      echo "Worker $i starting at \$(date)"
      while true; do
        nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader
        sleep 5
      done
    resources:
      limits:
        nvidia.com/gpu: 1
YAML
done

echo ""
echo "Waiting for pods to start..."
sleep 15

echo ""
echo "Monitoring GPU utilization (30 seconds)..."
for i in {1..6}; do
  echo ""
  echo "--- Sample $i/6 ---"
  nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv
  sleep 5
done

echo ""
echo "Pod logs sample:"
kubectl logs -n gpu-concurrent gpu-work-1 --tail=5

echo ""
read -p "Cleanup test namespace? (yes/no): " CLEANUP
if [ "$CLEANUP" = "yes" ]; then
  kubectl delete namespace gpu-concurrent
  echo "[o] Cleanup done"
fi
