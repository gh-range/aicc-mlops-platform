#!/bin/bash

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=========================================="
echo "Cluster Health Check - Part 1: Basic"
echo "=========================================="
echo ""

# 1. API Server health
echo "[*] Step 1: API Server Health"
if kubectl cluster-info --request-timeout=5s &>/dev/null; then
  echo "[o] API Server is responding"
  kubectl cluster-info | head -2
else
  echo "[x] API Server is not responding"
  exit 1
fi
echo ""

# 2. Node status
echo "[*] Step 2: Node Status"
kubectl get nodes -o wide
echo ""
NODE_STATUS=$(kubectl get nodes --no-headers | awk '{print $2}')
if [ "$NODE_STATUS" = "Ready" ]; then
  echo "[o] Node status: Ready"
else
  echo "[x] Node status: $NODE_STATUS"
  exit 1
fi
echo ""

# 3. Node resource usage
echo "[*] Step 3: Node Resource Allocation"
kubectl describe node $(kubectl get nodes --no-headers | awk '{print $1}') | grep -A 5 "Allocated resources"
echo ""

# 4. Core component status
echo "[*] Step 4: Core Components"
echo ""
echo "kube-system pods:"
kubectl get pods -n kube-system -o wide
echo ""

# Check critical pods
CRITICAL_PODS=("coredns" "local-path-provisioner" "metrics-server")
for pod_name in "${CRITICAL_PODS[@]}"; do
  POD_STATUS=$(kubectl get pods -n kube-system --no-headers | grep $pod_name | awk '{print $3}')
  if [ "$POD_STATUS" = "Running" ]; then
    echo "[o] $pod_name: Running"
  else
    echo "[x] $pod_name: $POD_STATUS"
  fi
done
echo ""

# 5. etcd health
echo "[*] Step 5: etcd Health"
if [ -d "/var/lib/rancher/k3s/server/db/etcd" ]; then
  echo "[o] etcd data directory exists"
  echo "Size: $(sudo du -sh /var/lib/rancher/k3s/server/db/etcd | cut -f1)"
  echo ""
  echo "Recent snapshots:"
  sudo k3s etcd-snapshot ls 2>/dev/null | tail -5 || echo "[!] No snapshots yet"
else
  echo "[x] etcd data directory not found"
fi
echo ""

# 6. API Server endpoint
echo "[*] Step 6: API Server Endpoint"
API_ENDPOINT=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
echo "Endpoint: $API_ENDPOINT"
if curl -k -s $API_ENDPOINT/healthz &>/dev/null; then
  echo "[o] API Server health endpoint accessible"
else
  echo "[x] API Server health endpoint not accessible"
fi
echo ""

# 7. Certificate expiry check
echo "[*] Step 7: Certificate Status"
CERT_FILE="/var/lib/rancher/k3s/server/tls/serving-kube-apiserver.crt"
if [ -f "$CERT_FILE" ]; then
  EXPIRY=$(sudo openssl x509 -in $CERT_FILE -noout -enddate 2>/dev/null | cut -d= -f2)
  echo "API Server cert expires: $EXPIRY"
  
  # Calculate days until expiry
  EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s 2>/dev/null || echo "0")
  NOW_EPOCH=$(date +%s)
  DAYS_LEFT=$(( ($EXPIRY_EPOCH - $NOW_EPOCH) / 86400 ))
  
  if [ $DAYS_LEFT -gt 30 ]; then
    echo "[o] Certificate valid for $DAYS_LEFT days"
  else
    echo "[!] Certificate expires in $DAYS_LEFT days (consider renewal)"
  fi
else
  echo "[!] Certificate file not found (k3s auto-manages certs)"
fi
echo ""

# 8. k3s service health
echo "[*] Step 8: k3s Service Status"
sudo systemctl status k3s --no-pager -l | head -15
echo ""
if sudo systemctl is-active --quiet k3s; then
  echo "[o] k3s service is active"
  
  # Check for recent restarts
  RESTART_COUNT=$(sudo systemctl show k3s -p NRestarts --value)
  echo "Service restarts: $RESTART_COUNT"
  
  # Check uptime
  UPTIME=$(sudo systemctl show k3s -p ActiveEnterTimestamp --value)
  echo "Active since: $UPTIME"
else
  echo "[x] k3s service is not active"
  exit 1
fi
echo ""

# 9. Resource limits check
echo "[*] Step 9: Resource Limits"
echo ""
echo "Memory:"
free -h | grep -E "Mem:|Swap:"
echo ""
echo "Disk:"
df -h / | grep -v Filesystem
echo ""
echo "k3s data directory:"
sudo du -sh /var/lib/rancher/k3s
echo ""

# 10. Recent events
echo "[*] Step 10: Recent Cluster Events"
echo "Last 10 events:"
kubectl get events -A --sort-by='.lastTimestamp' | tail -10
echo ""

# Summary
echo "=========================================="
echo "Basic Health Check Summary"
echo "=========================================="
echo ""

CHECKS=0
PASSED=0

# Check 1: API Server
if kubectl cluster-info --request-timeout=5s &>/dev/null; then
  echo "[o] API Server: Healthy"
  ((PASSED++))
else
  echo "[x] API Server: Unhealthy"
fi
((CHECKS++))

# Check 2: Node Ready
if [ "$(kubectl get nodes --no-headers | awk '{print $2}')" = "Ready" ]; then
  echo "[o] Node: Ready"
  ((PASSED++))
else
  echo "[x] Node: Not Ready"
fi
((CHECKS++))

# Check 3: Core pods
RUNNING=$(kubectl get pods -n kube-system --no-headers | grep Running | wc -l)
TOTAL=$(kubectl get pods -n kube-system --no-headers | wc -l)
if [ $RUNNING -eq $TOTAL ]; then
  echo "[o] System Pods: All running ($RUNNING/$TOTAL)"
  ((PASSED++))
else
  echo "[!] System Pods: Some not running ($RUNNING/$TOTAL)"
fi
((CHECKS++))

# Check 4: k3s service
if sudo systemctl is-active --quiet k3s; then
  echo "[o] k3s Service: Active"
  ((PASSED++))
else
  echo "[x] k3s Service: Inactive"
fi
((CHECKS++))

# Check 5: etcd
if [ -d "/var/lib/rancher/k3s/server/db/etcd" ]; then
  echo "[o] etcd: Data directory present"
  ((PASSED++))
else
  echo "[x] etcd: Data directory missing"
fi
((CHECKS++))

echo ""
echo "Result: $PASSED / $CHECKS checks passed"
echo ""

if [ $PASSED -eq $CHECKS ]; then
  echo "[o] All basic health checks passed"
  exit 0
else
  echo "[!] Some health checks failed"
  exit 1
fi
echo ""
echo "=========================================="
