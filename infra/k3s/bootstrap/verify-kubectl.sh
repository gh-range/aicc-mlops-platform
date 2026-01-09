#!/bin/bash

echo "=========================================="
echo "kubectl Verification"
echo "=========================================="
echo ""

# 1. Check kubectl binary
echo "[*] Step 1: Check kubectl binary"
if command -v kubectl &> /dev/null; then
  echo "[o] kubectl is available"
  which kubectl
else
  echo "[x] kubectl not found"
  exit 1
fi
echo ""

# 2. Check if kubectl is symlink to k3s
echo "[*] Step 2: Check kubectl type"
KUBECTL_PATH=$(which kubectl)
if [ -L "$KUBECTL_PATH" ]; then
  echo "[o] kubectl is a symlink"
  ls -l $KUBECTL_PATH
else
  echo "[!] kubectl is a standalone binary"
fi
echo ""

# 3. Check kubectl version
echo "[*] Step 3: kubectl version"
kubectl version --client --short 2>/dev/null || kubectl version --client
echo ""

# 4. Check KUBECONFIG
echo "[*] Step 4: KUBECONFIG environment"
if [ -n "$KUBECONFIG" ]; then
  echo "[o] KUBECONFIG is set: $KUBECONFIG"
else
  echo "[!] KUBECONFIG not set in environment"
  echo "    kubectl will use default: ~/.kube/config"
  echo "    For k3s, should be: /etc/rancher/k3s/k3s.yaml"
fi
echo ""

# 5. Test cluster connectivity
echo "[*] Step 5: Test cluster connectivity"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl cluster-info 2>/dev/null
if [ $? -eq 0 ]; then
  echo "[o] Successfully connected to cluster"
else
  echo "[x] Failed to connect to cluster"
  echo "    Check if k3s is running: sudo systemctl status k3s"
  exit 1
fi
echo ""

# 6. Test basic operations
echo "[*] Step 6: Test basic kubectl operations"
echo ""
echo "Nodes:"
kubectl get nodes
echo ""
echo "Namespaces:"
kubectl get namespaces
echo ""
echo "Pods (all namespaces):"
kubectl get pods -A
echo ""

# 7. Check kubectl config
echo "[*] Step 7: kubectl configuration"
kubectl config view --minify
echo ""

# Summary
echo "=========================================="
echo "kubectl Verification Summary"
echo "=========================================="
echo ""
echo "[o] kubectl binary: $(which kubectl)"
echo "[o] kubectl version: $(kubectl version --client --short 2>/dev/null | head -1)"
echo "[o] Cluster accessible: Yes"
echo ""
echo "To set KUBECONFIG permanently:"
echo "  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
echo "  echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc"
echo ""
echo "=========================================="
