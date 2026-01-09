#!/bin/bash

set -e  # Exit on any error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "k3s Single-Node HA Installation"
echo "=========================================="
echo ""

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ] && ! sudo -n true 2>/dev/null; then
  echo -e "${RED}Error: This script requires sudo privileges${NC}"
  exit 1
fi

# Check if k3s is already installed
if command -v k3s &> /dev/null; then
  echo -e "${YELLOW}Warning: k3s is already installed${NC}"
  k3s --version
  echo ""
  read -p "Do you want to reinstall? This will destroy existing cluster. (yes/no): " CONFIRM
  if [ "$CONFIRM" != "yes" ]; then
    echo "Installation cancelled"
    exit 0
  fi
  echo "Uninstalling existing k3s..."
  /usr/local/bin/k3s-uninstall.sh
  sleep 5
fi

echo -e "${GREEN}Starting k3s installation...${NC}"
echo ""

# Installation parameters explanation
cat << 'PARAMS'
Installation Parameters:
========================

--cluster-init
  └─ Initialize embedded etcd for HA
  └─ Enables multi-master capability
  └─ Data stored in /var/lib/rancher/k3s/server/db/etcd

--disable traefik
  └─ We will install Traefik manually via Helm
  └─ Allows custom configuration and version control

--disable servicelb
  └─ Disable default klipper-lb
  └─ Use Traefik as LoadBalancer instead

--write-kubeconfig-mode 644
  └─ Make kubeconfig readable by non-root users
  └─ Located at /etc/rancher/k3s/k3s.yaml

PARAMS

echo ""
read -p "Press Enter to continue with installation..."
echo ""

# Execute installation
echo -e "${GREEN}Downloading and installing k3s...${NC}"

curl -sfL https://get.k3s.io | sh -s - server \
  --cluster-init \
  --disable traefik \
  --disable servicelb \
  --write-kubeconfig-mode 644

echo ""
echo -e "${GREEN}Installation complete!${NC}"
echo ""

# Wait for k3s to be ready
echo "Waiting for k3s to be ready..."
sleep 10

# Check service status
echo ""
echo "=== k3s Service Status ==="
sudo systemctl status k3s --no-pager -l | head -15

echo ""
echo "=== k3s Version ==="
k3s --version

echo ""
echo "=== Kubeconfig Location ==="
echo "/etc/rancher/k3s/k3s.yaml"
echo ""
echo "To use kubectl as current user, run:"
echo "  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
echo "  kubectl get nodes"

echo ""
echo "=== Installation Summary ==="
echo "o k3s binary: /usr/local/bin/k3s"
echo "o kubeconfig: /etc/rancher/k3s/k3s.yaml"
echo "o data dir: /var/lib/rancher/k3s/"
echo "o uninstall script: /usr/local/bin/k3s-uninstall.sh"

echo ""
echo "=========================================="
echo "Installation completed successfully!"
echo "=========================================="
