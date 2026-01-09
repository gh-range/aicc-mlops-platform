#!/bin/bash

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=========================================="
echo "Cluster Health Check - Part 2: Network"
echo "=========================================="
echo ""

# 1. Check CNI plugin
echo "[*] Step 1: CNI Plugin Status"
echo "k3s uses flannel as default CNI"
if kubectl get pods -n kube-system | grep -q flannel; then
  echo "[o] Flannel pods found"
else
  echo "[!] Flannel runs as part of k3s process (not as pod)"
fi
echo ""

# 2. Check network configuration
echo "[*] Step 2: Network Configuration"
echo "Pod CIDR:"
kubectl cluster-info dump | grep -m 1 cluster-cidr 2>/dev/null || echo "  10.42.0.0/16 (default)"
echo "Service CIDR:"
kubectl cluster-info dump | grep -m 1 service-cluster-ip-range 2>/dev/null || echo "  10.43.0.0/16 (default)"
echo ""

# 3. Deploy test pods
echo "[*] Step 3: Deploy Test Pods"
echo "Creating test namespace..."
kubectl create namespace network-test 2>/dev/null || echo "[!] Namespace already exists"

echo "Deploying test pods..."
cat <<YAML | kubectl apply -f - &>/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: test-pod-1
  namespace: network-test
  labels:
    app: network-test
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 3
      periodSeconds: 2
---
apiVersion: v1
kind: Pod
metadata:
  name: test-pod-2
  namespace: network-test
  labels:
    app: network-test
spec:
  containers:
  - name: busybox
    image: busybox:latest
    command: ['sh', '-c', 'sleep 3600']
---
apiVersion: v1
kind: Service
metadata:
  name: test-service
  namespace: network-test
spec:
  selector:
    app: network-test
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
YAML

if [ $? -eq 0 ]; then
  echo "[o] Test resources created"
else
  echo "[x] Failed to create test resources"
  exit 1
fi
echo ""

# Wait for pods to be ready
echo "Waiting for pods to be ready (max 60 seconds)..."
kubectl wait --for=condition=Ready pod/test-pod-1 -n network-test --timeout=60s 2>/dev/null
kubectl wait --for=condition=Ready pod/test-pod-2 -n network-test --timeout=60s 2>/dev/null
echo ""

# 4. Check pod IPs
echo "[*] Step 4: Pod IP Assignment"
kubectl get pods -n network-test -o wide
echo ""
POD1_IP=$(kubectl get pod test-pod-1 -n network-test -o jsonpath='{.status.podIP}')
POD2_IP=$(kubectl get pod test-pod-2 -n network-test -o jsonpath='{.status.podIP}')
if [ -n "$POD1_IP" ] && [ -n "$POD2_IP" ]; then
  echo "[o] Pod IPs assigned:"
  echo "    test-pod-1: $POD1_IP"
  echo "    test-pod-2: $POD2_IP"
else
  echo "[x] Some pods do not have IPs assigned"
fi
echo ""

# 5. Test pod-to-pod connectivity
echo "[*] Step 5: Pod-to-Pod Connectivity"
echo "Testing test-pod-2 -> test-pod-1 ($POD1_IP)..."
if kubectl exec -n network-test test-pod-2 -- wget -qO- --timeout=5 http://$POD1_IP 2>/dev/null | grep -q nginx; then
  echo "[o] Pod-to-pod communication successful"
else
  echo "[x] Pod-to-pod communication failed"
fi
echo ""

# 6. Test service discovery
echo "[*] Step 6: Service Discovery (DNS)"
SVC_IP=$(kubectl get svc test-service -n network-test -o jsonpath='{.spec.clusterIP}')
echo "Service IP: $SVC_IP"
echo ""
echo "Testing DNS resolution..."
if kubectl exec -n network-test test-pod-2 -- nslookup test-service.network-test.svc.cluster.local 2>/dev/null | grep -q "Address:"; then
  echo "[o] DNS resolution successful"
else
  echo "[x] DNS resolution failed"
fi
echo ""

# Additional delay to ensure service is fully ready
echo "[*] Waiting 15 seconds for http service to stabilize..."
sleep 15
echo ""

# 7. Test service connectivity
echo "[*] Step 7: Service Connectivity"
echo "Testing test-pod-2 -> test-service..."
if kubectl exec -n network-test test-pod-2 -- wget -qO- --timeout=5 http://test-service 2>/dev/null | grep -q nginx; then
  echo "[o] Service communication successful"
else
  echo "[x] Service communication failed"
fi
echo ""

# 8. Test external DNS
echo "[*] Step 8: External DNS Resolution"
echo "Testing external DNS (google.com)..."
if kubectl exec -n network-test test-pod-2 -- nslookup google.com 2>/dev/null | grep -q "Address:"; then
  echo "[o] External DNS resolution successful"
else
  echo "[x] External DNS resolution failed"
fi
echo ""

# 9. Test internet connectivity
echo "[*] Step 9: Internet Connectivity"
echo "Testing outbound connection to google.com..."
if kubectl exec -n network-test test-pod-2 -- wget -qO- --timeout=10 https://www.google.com 2>/dev/null | grep -q "google"; then
  echo "[o] Internet connectivity successful"
else
  echo "[!] Internet connectivity failed (may be firewall/proxy)"
fi
echo ""

# 10. Check CoreDNS
echo "[*] Step 10: CoreDNS Health"
kubectl get pods -n kube-system -l k8s-app=kube-dns
echo ""
COREDNS_READY=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep -c Running)
if [ $COREDNS_READY -gt 0 ]; then
  echo "[o] CoreDNS pods running: $COREDNS_READY"
else
  echo "[x] No CoreDNS pods running"
fi
echo ""

# 11. Check network policies (if any)
echo "[*] Step 11: Network Policies"
NETPOL_COUNT=$(kubectl get networkpolicies -A --no-headers 2>/dev/null | wc -l)
echo "Network policies defined: $NETPOL_COUNT"
if [ $NETPOL_COUNT -eq 0 ]; then
  echo "[!] No network policies (default allow all)"
else
  kubectl get networkpolicies -A
fi
echo ""

# Cleanup
echo "[*] Step 12: Cleanup Test Resources"
read -p "Do you want to cleanup test resources? (yes/no): " CLEANUP
if [ "$CLEANUP" = "yes" ]; then
  kubectl delete namespace network-test --wait=false
  echo "[o] Cleanup initiated (running in background)"
else
  echo "[!] Test resources kept in namespace: network-test"
  echo "    To cleanup later: kubectl delete namespace network-test"
fi
echo ""

# Summary
echo "=========================================="
echo "Network Validation Summary"
echo "=========================================="
echo ""

CHECKS=0
PASSED=0

# Check 1: Pod IPs
if [ -n "$POD1_IP" ] && [ -n "$POD2_IP" ]; then
  echo "[o] IP Assignment: Working"
  ((PASSED++))
else
  echo "[x] IP Assignment: Failed"
fi
((CHECKS++))

# Check 2: Pod-to-pod
if kubectl exec -n network-test test-pod-2 -- wget -qO- --timeout=5 http://$POD1_IP 2>/dev/null | grep -q nginx; then
  echo "[o] Pod-to-Pod: Working"
  ((PASSED++))
else
  echo "[x] Pod-to-Pod: Failed"
fi
((CHECKS++))

# Check 3: DNS
if kubectl exec -n network-test test-pod-2 -- nslookup test-service.network-test.svc.cluster.local 2>/dev/null | grep -q "Address:"; then
  echo "[o] DNS Resolution: Working"
  ((PASSED++))
else
  echo "[x] DNS Resolution: Failed"
fi
((CHECKS++))

# Check 4: Service
if kubectl exec -n network-test test-pod-2 -- wget -qO- --timeout=5 http://test-service 2>/dev/null | grep -q nginx; then
  echo "[o] Service Communication: Working"
  ((PASSED++))
else
  echo "[x] Service Communication: Failed"
fi
((CHECKS++))

# Check 5: CoreDNS
if [ $COREDNS_READY -gt 0 ]; then
  echo "[o] CoreDNS: Healthy"
  ((PASSED++))
else
  echo "[x] CoreDNS: Unhealthy"
fi
((CHECKS++))

echo ""
echo "Result: $PASSED / $CHECKS checks passed"
echo ""

if [ $PASSED -eq $CHECKS ]; then
  echo "[o] All network checks passed"
  exit 0
else
  echo "[!] Some network checks failed"
  exit 1
fi
echo ""
echo "=========================================="
