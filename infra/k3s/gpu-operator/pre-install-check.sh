#!/bin/bash

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=========================================="
echo "GPU Operator Pre-installation Check"
echo "=========================================="
echo ""

# 1. Check k3s cluster health
echo "[*] Step 1: Check k3s Cluster Health"
if kubectl cluster-info --request-timeout=5s &>/dev/null; then
  echo "[o] k3s cluster is healthy"
else
  echo "[x] k3s cluster is not responding"
  exit 1
fi
echo ""

# 2. Check NVIDIA driver on host
echo "[*] Step 2: Check NVIDIA Driver on Host"
if command -v nvidia-smi &>/dev/null; then
  echo "[o] nvidia-smi is available"
  echo ""
  echo "Driver info:"
  nvidia-smi --query-gpu=driver_version,name,memory.total --format=csv,noheader
  DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader)
  echo ""
  echo "Driver version: $DRIVER_VERSION"
else
  echo "[x] nvidia-smi not found"
  echo "    Please install NVIDIA driver first"
  exit 1
fi
echo ""

# 3. Check Helm
echo "[*] Step 3: Check Helm Installation"
if command -v helm &>/dev/null; then
  HELM_VERSION=$(helm version --short)
  echo "[o] Helm is installed: $HELM_VERSION"
else
  echo "[x] Helm not found"
  exit 1
fi
echo ""

# 4. Check if GPU Operator already installed
echo "[*] Step 4: Check for Existing GPU Operator"
if kubectl get namespace gpu-operator &>/dev/null; then
  echo "[!] Namespace gpu-operator already exists"
  if helm list -n gpu-operator | grep -q gpu-operator; then
    echo "[!] GPU Operator is already installed"
    echo ""
    helm list -n gpu-operator
    echo ""
    read -p "Do you want to continue? This may upgrade existing installation. (yes/no): " CONTINUE
    if [ "$CONTINUE" != "yes" ]; then
      echo "Installation cancelled"
      exit 0
    fi
  else
    echo "[!] Namespace exists but no Helm release found"
  fi
else
  echo "[o] No existing GPU Operator installation found"
fi
echo ""

# 5. Check NVIDIA Helm repo
echo "[*] Step 5: Check NVIDIA Helm Repository"
if helm repo list | grep -q "^nvidia"; then
  echo "[o] NVIDIA Helm repo is configured"
  helm repo list | grep nvidia
else
  echo "[!] NVIDIA Helm repo not found, adding..."
  helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
  if [ $? -eq 0 ]; then
    echo "[o] NVIDIA repo added"
  else
    echo "[x] Failed to add NVIDIA repo"
    exit 1
  fi
fi
echo ""

# 6. Update Helm repos
echo "[*] Step 6: Update Helm Repositories"
helm repo update
echo ""

# 7. Check available GPU Operator versions
echo "[*] Step 7: Available GPU Operator Versions"
helm search repo nvidia/gpu-operator --versions | head -6
echo ""

# 8. Check node resources
echo "[*] Step 8: Node Resource Check"
echo "Available resources:"
kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.allocatable.cpu,MEMORY:.status.allocatable.memory
echo ""

# 9. Check for conflicting resources
echo "[*] Step 9: Check for Conflicting Resources"
CONFLICTS=0

# Check for existing device plugin
if kubectl get daemonset -A | grep -q "nvidia-device-plugin"; then
  echo "[!] WARNING: Existing nvidia-device-plugin DaemonSet found"
  kubectl get daemonset -A | grep nvidia-device-plugin
  echo "    This may conflict with GPU Operator"
  CONFLICTS=$((CONFLICTS + 1))
fi

# Check for RuntimeClass
if kubectl get runtimeclass nvidia &>/dev/null; then
  echo "[!] RuntimeClass 'nvidia' already exists"
  CONFLICTS=$((CONFLICTS + 1))
fi

if [ $CONFLICTS -eq 0 ]; then
  echo "[o] No conflicting resources found"
fi
echo ""

# Summary
echo "=========================================="
echo "Pre-installation Check Summary"
echo "=========================================="
echo ""
echo "[o] k3s cluster: Healthy"
echo "[o] NVIDIA driver: $DRIVER_VERSION"
echo "[o] Helm: Installed"
echo "[o] NVIDIA repo: Configured"
echo ""

if [ $CONFLICTS -gt 0 ]; then
  echo "[!] Found $CONFLICTS potential conflicts"
  echo "    Review warnings above before proceeding"
  echo ""
  read -p "Continue despite conflicts? (yes/no): " PROCEED
  if [ "$PROCEED" != "yes" ]; then
    echo "Installation cancelled"
    exit 1
  fi
fi

echo "Ready to install GPU Operator"
echo ""
echo "Next steps:"
echo "  1. Review values.yaml configuration"
echo "  2. Run installation script"
echo ""
echo "=========================================="
