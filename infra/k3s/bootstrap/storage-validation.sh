#!/bin/bash

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=========================================="
echo "Cluster Health Check - Part 3: Storage"
echo "=========================================="
echo ""

# 1. Check storage class
echo "[*] Step 1: Storage Class"
kubectl get storageclass
echo ""
SC_COUNT=$(kubectl get storageclass --no-headers 2>/dev/null | wc -l)
if [ $SC_COUNT -gt 0 ]; then
  echo "[o] Storage classes available: $SC_COUNT"
else
  echo "[x] No storage classes found"
  exit 1
fi
echo ""

# 2. Check local-path-provisioner
echo "[*] Step 2: local-path-provisioner Status"
kubectl get pods -n kube-system -l app=local-path-provisioner
echo ""
LPP_STATUS=$(kubectl get pods -n kube-system -l app=local-path-provisioner --no-headers 2>/dev/null | awk '{print $3}')
if [ "$LPP_STATUS" = "Running" ]; then
  echo "[o] local-path-provisioner is running"
else
  echo "[x] local-path-provisioner status: $LPP_STATUS"
  exit 1
fi
echo ""

# 3. Check default storage path
echo "[*] Step 3: Storage Path Configuration"
# Note: This dynamically reads the path from ConfigMap in case it was customized
# See: docs/design-decisions/03-local-path-storage-configuration.md'
DEFAULT_PATH=$(kubectl get configmap local-path-config -n kube-system -o jsonpath='{.data.config\.json}' | grep -oP '"paths"\s*:\s*\[\s*"\K[^"]+')
#DEFAULT_PATH="/var/lib/rancher/k3s/storage"
if [ -d "$DEFAULT_PATH" ]; then
  echo "[o] Default storage path exists: $DEFAULT_PATH"
  echo "Disk usage:"
  sudo du -sh $DEFAULT_PATH 2>/dev/null || echo "  (empty)"
else
  echo "[!] Default storage path not found (will be created on first use)"
fi
echo ""

# 4. Create test namespace
echo "[*] Step 4: Create Test Namespace"
kubectl create namespace storage-test 2>/dev/null || echo "[!] Namespace already exists"
echo ""

# 5. Create PVC
echo "[*] Step 5: Create PersistentVolumeClaim"
cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: storage-test
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 1Gi
YAML

if [ $? -eq 0 ]; then
  echo "[o] PVC created"
else
  echo "[x] Failed to create PVC"
  exit 1
fi
echo ""

# Check initial PVC status (should be Pending)
echo "Initial PVC status:"
kubectl get pvc test-pvc -n storage-test
echo "[!] Note: PVC will remain Pending until a Pod uses it (WaitForFirstConsumer)"
echo ""

# 6. Create pod with volume (this triggers PV creation)
echo "[*] Step 6: Create Pod with Volume Mount"
cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-storage-pod
  namespace: storage-test
spec:
  containers:
  - name: test-container
    image: busybox:latest
    command: ['sh', '-c', 'echo "Hello from PVC" > /data/test.txt && sleep 3600']
    volumeMounts:
    - name: test-volume
      mountPath: /data
  volumes:
  - name: test-volume
    persistentVolumeClaim:
      claimName: test-pvc
YAML

if [ $? -eq 0 ]; then
  echo "[o] Pod with volume created"
else
  echo "[x] Failed to create pod"
  exit 1
fi
echo ""

# Wait for PVC to be bound (after pod is scheduled)
echo "Waiting for PVC to be bound (max 60 seconds)..."
for i in {1..60}; do
  PVC_STATUS=$(kubectl get pvc test-pvc -n storage-test --no-headers 2>/dev/null | awk '{print $2}')
  if [ "$PVC_STATUS" = "Bound" ]; then
    echo "[o] PVC is now bound"
    break
  fi
  echo "  Waiting... ($i/60) Status: $PVC_STATUS"
  sleep 1
done
echo ""

# Check if PVC is bound
if [ "$PVC_STATUS" != "Bound" ]; then
  echo "[x] PVC failed to bind"
  echo ""
  echo "PVC details:"
  kubectl describe pvc test-pvc -n storage-test
  echo ""
  echo "Pod details:"
  kubectl describe pod test-storage-pod -n storage-test
  exit 1
fi

# 7. Check PV created
echo "[*] Step 7: Check PersistentVolume"
kubectl get pv
echo ""
PV_NAME=$(kubectl get pvc test-pvc -n storage-test -o jsonpath='{.spec.volumeName}')
if [ -n "$PV_NAME" ]; then
  echo "[o] PV created: $PV_NAME"
else
  echo "[x] No PV associated with PVC"
fi
echo ""

# Wait for pod to be ready
echo "[*] Step 8: Wait for Pod Ready"
kubectl wait --for=condition=Ready pod/test-storage-pod -n storage-test --timeout=60s 2>/dev/null
if [ $? -eq 0 ]; then
  echo "[o] Pod is ready"
else
  echo "[x] Pod failed to become ready"
  kubectl describe pod test-storage-pod -n storage-test | tail -20
fi
echo ""

# 9. Test write operation
echo "[*] Step 9: Test Write Operation"
sleep 3  # Give pod time to write file
if kubectl exec -n storage-test test-storage-pod -- cat /data/test.txt 2>/dev/null | grep -q "Hello from PVC"; then
  echo "[o] Write operation successful"
  echo "Content: $(kubectl exec -n storage-test test-storage-pod -- cat /data/test.txt 2>/dev/null)"
else
  echo "[x] Write operation failed"
fi
echo ""

# 10. Test persistence
echo "[*] Step 10: Test Data Persistence"
echo "Writing additional data..."
kubectl exec -n storage-test test-storage-pod -- sh -c 'echo "Persistence test" >> /data/test.txt' 2>/dev/null
echo "Deleting first pod..."
kubectl delete pod test-storage-pod -n storage-test --wait=true
echo "Recreating pod with same PVC..."
cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-storage-pod-2
  namespace: storage-test
spec:
  containers:
  - name: test-container
    image: busybox:latest
    command: ['sh', '-c', 'sleep 3600']
    volumeMounts:
    - name: test-volume
      mountPath: /data
  volumes:
  - name: test-volume
    persistentVolumeClaim:
      claimName: test-pvc
YAML

echo "Waiting for new pod..."
kubectl wait --for=condition=Ready pod/test-storage-pod-2 -n storage-test --timeout=60s 2>/dev/null
echo ""
echo "Reading data from new pod..."
DATA=$(kubectl exec -n storage-test test-storage-pod-2 -- cat /data/test.txt 2>/dev/null)
if echo "$DATA" | grep -q "Persistence test"; then
  echo "[o] Data persisted across pod recreation"
  echo "Content:"
  echo "$DATA"
else
  echo "[x] Data did not persist"
fi
echo ""

# 11. Check actual storage location
echo "[*] Step 11: Check Physical Storage Location"
if [ -n "$PV_NAME" ]; then
  PV_PATH=$(kubectl get pv $PV_NAME -o jsonpath='{.spec.local.path}')
  echo "PV path: $PV_PATH"
  if [ -d "$PV_PATH" ]; then
    echo "[o] Physical storage exists"
    echo "Contents:"
    sudo ls -lh $PV_PATH
    echo ""
    echo "File content:"
    sudo cat $PV_PATH/test.txt 2>/dev/null || echo "  (file not accessible)"
  else
    echo "[!] PV path not found on host"
  fi
else
  echo "[!] Cannot determine PV path"
fi
echo ""

# 12. Storage capacity check
echo "[*] Step 12: Storage Capacity"
echo "PVC request: 1Gi"
PVC_CAPACITY=$(kubectl get pvc test-pvc -n storage-test -o jsonpath='{.status.capacity.storage}')
echo "PVC capacity: $PVC_CAPACITY"
echo ""
echo "Host storage:"
df -h $DEFAULT_PATH 2>/dev/null || df -h /var/lib/rancher/k3s/storage
echo ""

# Summary
echo "=========================================="
echo "Storage Validation Summary"
echo "=========================================="
echo ""

CHECKS=0
PASSED=0

# Check 1: Storage class
if [ $SC_COUNT -gt 0 ]; then
  echo "[o] Storage Class: Available"
  ((PASSED++))
else
  echo "[x] Storage Class: Not available"
fi
((CHECKS++))

# Check 2: Provisioner
if [ "$LPP_STATUS" = "Running" ]; then
  echo "[o] Provisioner: Running"
  ((PASSED++))
else
  echo "[x] Provisioner: Not running"
fi
((CHECKS++))

# Check 3: PVC binding
if [ "$PVC_STATUS" = "Bound" ]; then
  echo "[o] PVC Binding: Success"
  ((PASSED++))
else
  echo "[x] PVC Binding: Failed"
fi
((CHECKS++))

# Check 4: PV creation
if [ -n "$PV_NAME" ]; then
  echo "[o] PV Creation: Success"
  ((PASSED++))
else
  echo "[x] PV Creation: Failed"
fi
((CHECKS++))

# Check 5: Write operation
if kubectl exec -n storage-test test-storage-pod-2 -- cat /data/test.txt 2>/dev/null | grep -q "Hello"; then
  echo "[o] Write Operation: Success"
  ((PASSED++))
else
  echo "[x] Write Operation: Failed"
fi
((CHECKS++))

# Check 6: Data persistence
if kubectl exec -n storage-test test-storage-pod-2 -- cat /data/test.txt 2>/dev/null | grep -q "Persistence"; then
  echo "[o] Data Persistence: Success"
  ((PASSED++))
else
  echo "[x] Data Persistence: Failed"
fi
((CHECKS++))

echo ""
echo "Result: $PASSED / $CHECKS checks passed"
echo ""

# Cleanup
echo "=========================================="
echo "Cleanup"
echo "=========================================="
echo ""
read -p "Do you want to cleanup all test resources (Pod, PVC, PV)? (yes/no): " CLEANUP

if [ "$CLEANUP" = "yes" ]; then
  echo ""
  echo "[*] Deleting test pod..."
  kubectl delete pod test-storage-pod-2 -n storage-test --wait=true 2>/dev/null
  echo "[o] Pod deleted"
  
  echo ""
  echo "[*] Deleting PVC (this will also delete the PV)..."
  kubectl delete pvc test-pvc -n storage-test --wait=true
  echo "[o] PVC deleted"
  
  echo ""
  echo "[*] Waiting for PV to be cleaned up..."
  sleep 3
  
  if kubectl get pv $PV_NAME &>/dev/null; then
    echo "[!] PV still exists (will be cleaned up by provisioner)"
  else
    echo "[o] PV successfully deleted"
  fi
  
  echo ""
  echo "[*] Deleting namespace..."
  kubectl delete namespace storage-test --wait=false
  echo "[o] Namespace deletion initiated"
  
  echo ""
  echo "[*] Verifying physical storage cleanup..."
  if [ -n "$PV_PATH" ]; then
    if [ -d "$PV_PATH" ]; then
      echo "[!] Physical directory still exists: $PV_PATH"
      echo "    (local-path-provisioner will clean it up shortly)"
    else
      echo "[o] Physical directory cleaned up"
    fi
  fi
  
  echo ""
  echo "[o] Cleanup completed"
else
  echo ""
  echo "[!] Test resources kept in namespace: storage-test"
  echo ""
  echo "To cleanup manually later:"
  echo "  kubectl delete pod test-storage-pod-2 -n storage-test"
  echo "  kubectl delete pvc test-pvc -n storage-test"
  echo "  kubectl delete namespace storage-test"
  echo ""
  echo "Current resources:"
  kubectl get pod,pvc,pv -n storage-test
fi

echo ""
echo "=========================================="

if [ $PASSED -eq $CHECKS ]; then
  exit 0
else
  exit 1
fi
