#!/bin/bash

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=========================================="
echo "Complete Toolchain Verification"
echo "=========================================="
echo ""

# 1. System information
echo "[*] Step 1: System Information"
echo "Hostname: $(hostname)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "Kernel: $(uname -r)"
echo "Date: $(date)"
echo ""

# 2. k3s verification
echo "[*] Step 2: k3s Status"
echo "Version: $(k3s --version | head -1)"
echo "Service: $(sudo systemctl is-active k3s)"
if sudo systemctl is-active --quiet k3s; then
  echo "[o] k3s service is running"
else
  echo "[x] k3s service is not running"
  exit 1
fi
echo ""

# 3. kubectl verification
echo "[*] Step 3: kubectl Status"
echo "Binary: $(which kubectl)"
echo "Version: $(kubectl version --client --short 2>/dev/null)"
kubectl cluster-info --request-timeout=5s 2>&1 | head -2
if [ $? -eq 0 ]; then
  echo "[o] kubectl can connect to cluster"
else
  echo "[x] kubectl cannot connect to cluster"
  exit 1
fi
echo ""

# 4. Helm verification
echo "[*] Step 4: Helm Status"
echo "Binary: $(which helm)"
echo "Version: $(helm version --short)"
REPO_COUNT=$(helm repo list 2>/dev/null | tail -n +2 | wc -l)
echo "Repositories configured: $REPO_COUNT"
if [ $REPO_COUNT -gt 0 ]; then
  echo "[o] Helm repositories configured"
else
  echo "[x] No Helm repositories configured"
fi
echo ""

# 5. Cluster node status
echo "[*] Step 5: Cluster Nodes"
kubectl get nodes -o wide
NODE_STATUS=$(kubectl get nodes --no-headers | awk '{print $2}')
if [ "$NODE_STATUS" = "Ready" ]; then
  echo "[o] Node is Ready"
else
  echo "[x] Node is not Ready: $NODE_STATUS"
  exit 1
fi
echo ""

# 6. Core system pods
echo "[*] Step 6: Core System Pods"
kubectl get pods -n kube-system
RUNNING_PODS=$(kubectl get pods -n kube-system --no-headers | grep Running | wc -l)
TOTAL_PODS=$(kubectl get pods -n kube-system --no-headers | wc -l)
echo "Running pods: $RUNNING_PODS / $TOTAL_PODS"
if [ $RUNNING_PODS -eq $TOTAL_PODS ]; then
  echo "[o] All system pods are running"
else
  echo "[!] Some pods are not running"
fi
echo ""

# 7. Storage class
echo "[*] Step 7: Storage Class"
kubectl get storageclass
if kubectl get storageclass local-path &>/dev/null; then
  echo "[o] Default storage class available"
else
  echo "[x] Default storage class missing"
fi
echo ""

# 8. Test kubectl aliases
echo "[*] Step 8: Test kubectl aliases"

echo ""
echo "To test aliases manually, run in a new terminal:"
echo "  source ~/.bashrc"
echo "  k get nodes"
echo "  kgp"
echo ""
if grep -q "alias k='kubectl'" ~/.bashrc; then
  echo "[o] Aliases are defined in ~/.bashrc"
else
  echo "[x] Aliases not found in ~/.bashrc"
fi

echo ""

# 9. Test Helm functionality
echo "[*] Step 9: Test Helm functionality"
echo "Searching for nginx charts..."
NGINX_CHARTS=$(helm search repo nginx 2>/dev/null | tail -n +2 | wc -l)
echo "Found $NGINX_CHARTS nginx charts"
if [ $NGINX_CHARTS -gt 0 ]; then
  echo "[o] Helm search is functional"
else
  echo "[x] Helm search returned no results"
fi
echo ""

# 10. etcd snapshot capability
echo "[*] Step 10: etcd Snapshot Capability"
if sudo k3s etcd-snapshot ls &>/dev/null; then
  SNAPSHOT_COUNT=$(sudo k3s etcd-snapshot ls 2>/dev/null | tail -n +2 | wc -l)
  echo "Existing snapshots: $SNAPSHOT_COUNT"
  echo "[o] etcd snapshot functionality available"
else
  echo "[x] etcd snapshot command failed"
fi
echo ""

# 11. Network connectivity
echo "[*] Step 11: Network Connectivity"
echo "Testing DNS resolution..."
if kubectl run test-dns --image=busybox --restart=Never --rm -it --command -- nslookup kubernetes.default &>/dev/null; then
  echo "[o] DNS resolution working"
else
  echo "[!] DNS test pod failed (may be normal if pod cleanup issue)"
fi
echo ""

# 12. Resource availability
echo "[*] Step 12: Resource Availability"
echo ""
echo "CPU and Memory:"
kubectl top nodes 2>/dev/null || echo "[!] metrics-server not ready yet (normal for new install)"
echo ""

# Generate version report
echo "[*] Step 13: Generate version report"
cat > /tmp/toolchain-versions.txt << VERSIONS
=== Toolchain Version Report ===
Generated: $(date)

System:
  OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
  Kernel: $(uname -r)
  Hostname: $(hostname)

k3s:
  Version: $(k3s --version | head -1)
  Service: $(sudo systemctl is-active k3s)

kubectl:
  Version: $(kubectl version --client --short 2>/dev/null)
  Server: $(kubectl version --short 2>/dev/null | grep Server || echo "N/A")

Helm:
  Version: $(helm version --short)
  Repositories: $(helm repo list 2>/dev/null | tail -n +2 | wc -l)

Cluster Status:
  Nodes: $(kubectl get nodes --no-headers | wc -l)
  Node Status: $(kubectl get nodes --no-headers | awk '{print $2}')
  Running Pods: $(kubectl get pods -A --no-headers | grep Running | wc -l)
  Total Pods: $(kubectl get pods -A --no-headers | wc -l)

etcd:
  Snapshots: $(sudo k3s etcd-snapshot ls 2>/dev/null | tail -n +2 | wc -l)
  Data Dir: /var/lib/rancher/k3s/server/db/etcd

GPU (if available):
  Driver: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null || echo "Not available")
  GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo "Not available")
VERSIONS

cat /tmp/toolchain-versions.txt
echo ""
echo "[o] Version report saved to: /tmp/toolchain-versions.txt"
echo ""

# Summary
echo "=========================================="
echo "Verification Summary"
echo "=========================================="
echo ""

# Count checks
CHECKS_PASSED=0
CHECKS_TOTAL=8

# Check k3s
if sudo systemctl is-active --quiet k3s; then
  echo "[o] k3s service running"
  ((CHECKS_PASSED++))
else
  echo "[x] k3s service not running"
fi

# Check kubectl
if kubectl cluster-info --request-timeout=5s &>/dev/null; then
  echo "[o] kubectl connectivity"
  ((CHECKS_PASSED++))
else
  echo "[x] kubectl connectivity failed"
fi

# Check Helm
if [ $(helm repo list 2>/dev/null | tail -n +2 | wc -l) -gt 0 ]; then
  echo "[o] Helm repositories configured"
  ((CHECKS_PASSED++))
else
  echo "[x] Helm repositories not configured"
fi

# Check node status
if [ "$(kubectl get nodes --no-headers | awk '{print $2}')" = "Ready" ]; then
  echo "[o] Node is Ready"
  ((CHECKS_PASSED++))
else
  echo "[x] Node is not Ready"
fi

# Check system pods
RUNNING=$(kubectl get pods -n kube-system --no-headers | grep Running | wc -l)
TOTAL=$(kubectl get pods -n kube-system --no-headers | wc -l)
if [ $RUNNING -eq $TOTAL ]; then
  echo "[o] All system pods running ($RUNNING/$TOTAL)"
  ((CHECKS_PASSED++))
else
  echo "[!] Some pods not running ($RUNNING/$TOTAL)"
fi

# Check storage
if kubectl get storageclass local-path &>/dev/null; then
  echo "[o] Storage class available"
  ((CHECKS_PASSED++))
else
  echo "[x] Storage class missing"
fi

# Check aliases
#if type k &>/dev/null; then
if grep -q "alias k='kubectl'" ~/.bashrc; then
      	echo "[o] kubectl aliases configured"
  ((CHECKS_PASSED++))
else
  echo "[!] kubectl aliases not loaded (source ~/.bashrc)"
fi

# Check etcd
if sudo k3s etcd-snapshot ls &>/dev/null; then
  echo "[o] etcd snapshot functional"
  ((CHECKS_PASSED++))
else
  echo "[x] etcd snapshot not functional"
fi

echo ""
echo "Result: $CHECKS_PASSED / $CHECKS_TOTAL checks passed"
echo ""

if [ $CHECKS_PASSED -eq $CHECKS_TOTAL ]; then
  echo "[o] All checks passed! Toolchain is ready."
  echo ""
  echo "Next steps:"
  echo "  - Chapter 4.5: Verify cluster health"
  echo "  - Chapter 5: Install NVIDIA GPU Operator"
else
  echo "[!] Some checks failed. Review output above."
fi

echo ""
echo "=========================================="
