#!/bin/bash

set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=========================================="
echo "GPU Operator Installation"
echo "=========================================="
echo ""

# Configuration
NAMESPACE="gpu-operator"
RELEASE_NAME="gpu-operator"
CHART="nvidia/gpu-operator"
VALUES_FILE="infra/k3s/gpu-operator/values.yaml"

# Check values file exists
if [ ! -f "$VALUES_FILE" ]; then
  echo "[x] Values file not found: $VALUES_FILE"
  exit 1
fi

echo "[*] Configuration:"
echo "    Namespace: $NAMESPACE"
echo "    Release: $RELEASE_NAME"
echo "    Chart: $CHART"
echo "    Version: $CHART_VERSION"
echo "    Values: $VALUES_FILE"
echo ""

# Display driver info
echo "[*] Current NVIDIA Driver:"
nvidia-smi --query-gpu=driver_version,name,memory.total --format=csv,noheader
echo ""

# Confirm installation
read -p "Proceed with installation? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Installation cancelled"
  exit 0
fi
echo ""

# Create namespace
echo "[*] Step 1: Create Namespace"
kubectl create namespace $NAMESPACE 2>/dev/null || echo "[o] Namespace already exists"
echo ""

# Install GPU Operator
echo "[*] Step 2: Install GPU Operator via Helm"
echo "This may take 5-10 minutes..."
echo ""

helm upgrade --install $RELEASE_NAME $CHART \
  --namespace $NAMESPACE \
  --values $VALUES_FILE \
  --wait \
  --timeout 10m

if [ $? -eq 0 ]; then
  echo ""
  echo "[o] GPU Operator installation completed"
else
  echo ""
  echo "[x] Installation failed"
  exit 1
fi
echo ""

# Wait for pods
echo "[*] Step 3: Wait for Pods to be Ready"
echo "Waiting up to 5 minutes..."
echo ""

kubectl wait --for=condition=Ready pod \
  -n $NAMESPACE \
  --all \
  --timeout=300s 2>/dev/null || echo "[!] Some pods may still be starting"
echo ""

# Display status
echo "=========================================="
echo "Installation Status"
echo "=========================================="
echo ""

echo "[*] Helm Release:"
helm list -n $NAMESPACE
echo ""

echo "[*] GPU Operator Pods:"
kubectl get pods -n $NAMESPACE -o wide
echo ""

echo "[*] DaemonSets:"
kubectl get daemonsets -n $NAMESPACE
echo ""

echo "[*] Node GPU Resources:"
sleep 5
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
GPU:.status.allocatable.nvidia\\.com/gpu
echo ""

echo "=========================================="
echo "Next Steps"
echo "=========================================="
echo ""
echo "Run post-installation verification:"
echo " sudo ./infra/k3s/gpu-operator/post-install-verify.sh"
echo ""
echo "=========================================="
