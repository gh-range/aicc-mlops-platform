#!/bin/bash

echo "=========================================="
echo "Helm 3 Installation"
echo "=========================================="
echo ""

# Check if Helm is already installed
if command -v helm &> /dev/null; then
  echo "[!] Helm is already installed"
  helm version --short
  echo ""
  read -p "Do you want to reinstall/upgrade? (yes/no): " CONFIRM
  if [ "$CONFIRM" != "yes" ]; then
    echo "Installation cancelled"
    exit 0
  fi
fi

# 1. Download Helm install script
echo "[*] Step 1: Download Helm installation script"
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o /tmp/get_helm.sh
if [ $? -eq 0 ]; then
  echo "[o] Download successful"
else
  echo "[x] Download failed"
  exit 1
fi
echo ""

# 2. Install Helm
echo "[*] Step 2: Install Helm"
chmod 700 /tmp/get_helm.sh
/tmp/get_helm.sh
if [ $? -eq 0 ]; then
  echo "[o] Helm installed successfully"
else
  echo "[x] Helm installation failed"
  exit 1
fi
echo ""

# 3. Verify installation
echo "[*] Step 3: Verify Helm installation"
if command -v helm &> /dev/null; then
  echo "[o] Helm binary found"
  which helm
else
  echo "[x] Helm binary not found"
  exit 1
fi
echo ""

# 4. Check Helm version
echo "[*] Step 4: Helm version"
helm version --short
echo ""

# 5. Initialize Helm (add stable repo)
echo "[*] Step 5: Add stable Helm repository"
helm repo add stable https://charts.helm.sh/stable 2>/dev/null || echo "[!] Stable repo already exists or deprecated"
echo ""

# 6. Add other useful repos
echo "[*] Step 6: Add common Helm repositories"

# Bitnami (most popular charts)
helm repo add bitnami https://charts.bitnami.com/bitnami
echo "[o] Added bitnami repo"

# Prometheus Community
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
echo "[o] Added prometheus-community repo"

# Grafana
helm repo add grafana https://grafana.github.io/helm-charts
echo "[o] Added grafana repo"

# ArgoCD
helm repo add argo https://argoproj.github.io/argo-helm
echo "[o] Added argo repo"

# JupyterHub
helm repo add jupyterhub https://hub.jupyter.org/helm-chart/
echo "[o] Added jupyterhub repo"

# NVIDIA GPU Operator
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
echo "[o] Added nvidia repo"

echo ""

# 7. Update repo index
echo "[*] Step 7: Update Helm repository index"
helm repo update
if [ $? -eq 0 ]; then
  echo "[o] Repository index updated"
else
  echo "[x] Failed to update repository index"
fi
echo ""

# 8. List repositories
echo "[*] Step 8: List configured repositories"
helm repo list
echo ""

# 9. Test Helm functionality
echo "[*] Step 9: Test Helm search"
echo "Searching for redis charts..."
helm search repo redis --max-col-width 80 | head -5
echo ""

# 10. Configure Helm cache directory (optional)
echo "[*] Step 10: Helm cache configuration"
HELM_CACHE="$HOME/.cache/helm"
mkdir -p $HELM_CACHE
echo "[o] Helm cache directory: $HELM_CACHE"
echo ""

# Cleanup
rm -f /tmp/get_helm.sh

# Summary
echo "=========================================="
echo "Helm Installation Summary"
echo "=========================================="
echo ""
echo "[o] Helm version: $(helm version --short)"
echo "[o] Helm binary: $(which helm)"
echo "[o] Configured repositories: $(helm repo list | wc -l) repos"
echo ""
echo "Common Helm commands:"
echo "  helm search repo <keyword>   - Search for charts"
echo "  helm install <name> <chart>  - Install a chart"
echo "  helm list -A                 - List all releases"
echo "  helm repo update             - Update repo index"
echo ""
echo "=========================================="
