#!/bin/bash

echo "=========================================="
echo "k3s Installation Verification"
echo "=========================================="
echo ""

# Export kubeconfig for current session
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# 1. Check k3s service
echo " Step 1: k3s Service Status"
sudo systemctl is-active k3s
if [ $? -eq 0 ]; then
  echo "o k3s service is running"
else
  echo "x k3s service is not running"
  sudo systemctl status k3s --no-pager
fi
echo ""

# 2. Check k3s version
echo " Step 2: k3s Version"
k3s --version
echo ""

# 3. Check node status
echo " Step 3: Node Status"
kubectl get nodes -o wide
echo ""

# 4. Check system pods
echo " Step 4: System Pods Status"
kubectl get pods -A
echo ""

# 5. Check etcd status
echo " Step 5: Embedded etcd Status"
if sudo k3s etcd-snapshot ls 2>/dev/null; then
  echo "o etcd is accessible"
else
  echo "!  etcd snapshot command not available (normal for new install)"
fi
echo ""

# 6. Check API server
echo " Step 6: API Server Connectivity"
kubectl cluster-info
echo ""

# 7. Check storage class
echo " Step 7: Storage Class"
kubectl get storageclass
echo ""

# 8. Check namespaces
echo " Step 8: Namespaces"
kubectl get namespaces
echo ""

# 9. Verify disabled components
echo " Step 9: Verify Traefik is Disabled"
if kubectl get pods -n kube-system | grep -q traefik; then
  echo "!  Traefik is running (unexpected)"
else
  echo "o Traefik is disabled as expected"
fi
echo ""

# 10. Summary
echo "=========================================="
echo "Verification Summary"
echo "=========================================="
echo ""

# Node ready check
NODE_STATUS=$(kubectl get nodes --no-headers | awk '{print $2}')
if [ "$NODE_STATUS" = "Ready" ]; then
  echo "o Node is Ready"
else
  echo "x Node is not Ready: $NODE_STATUS"
fi

# Pod count
RUNNING_PODS=$(kubectl get pods -A --no-headers | grep -c Running)
echo "o Running pods: $RUNNING_PODS"

# Core components check
CORE_PODS=("coredns" "local-path-provisioner" "metrics-server")
for pod in "${CORE_PODS[@]}"; do
  if kubectl get pods -A | grep -q $pod; then
    echo "o $pod is present"
  else
    echo "x $pod is missing"
  fi
done

echo ""
echo "=========================================="
echo "Next Steps:"
echo "1. Export KUBECONFIG in your shell:"
echo "   export KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
echo "2. Add to ~/.bashrc for persistence:"
echo "   echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc"
echo "=========================================="
