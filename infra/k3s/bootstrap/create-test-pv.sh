#!/bin/bash

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=========================================="
echo "Create Test PV/PVC Resources"
echo "=========================================="
echo ""

# Step 1: Create test namespace
echo "[*] Step 1: Create Test Namespace"
kubectl create namespace storage-test 2>/dev/null && echo "[o] Namespace created" || echo "[!] Namespace already exists"
echo ""

# Step 2: Check and fix volumeBindingMode if needed
echo "[*] Step 2: Verify and Fix StorageClass Binding Mode"
BINDING_MODE=$(kubectl get storageclass local-path -o jsonpath='{.volumeBindingMode}')
echo "Current binding mode: $BINDING_MODE"

if [ "$BINDING_MODE" = "WaitForFirstConsumer" ]; then
  echo "[!] Patching to Immediate mode for single-node environment..."
  kubectl patch storageclass local-path -p '{"volumeBindingMode":"Immediate"}'
  echo "[o] StorageClass patched to Immediate mode"
else
  echo "[o] Already in Immediate mode"
fi
echo ""

# Step 3: Check local-path-provisioner
echo "[*] Step 3: Check local-path-provisioner Status"
LPP_STATUS=$(kubectl get pods -n kube-system -l app=local-path-provisioner -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
if [ "$LPP_STATUS" = "Running" ]; then
  echo "[o] local-path-provisioner is running"
else
  echo "[x] local-path-provisioner status: $LPP_STATUS"
  kubectl get pods -n kube-system -l app=local-path-provisioner
  exit 1
fi
echo ""

# Step 4: Check storage path configuration
echo "[*] Step 4: Storage Path Configuration"
kubectl get cm -n kube-system local-path-config -o jsonpath='{.data.config\.json}' | jq .
echo ""

# Step 5: Clean up old resources if exist
echo "[*] Step 5: Cleanup Old Test Resources"
kubectl delete pod test-storage-pod -n storage-test --ignore-not-found=true --wait=true
kubectl delete pod test-storage-pod-2 -n storage-test --ignore-not-found=true --wait=true
kubectl delete pvc test-pvc -n storage-test --ignore-not-found=true --wait=true
echo "Waiting for cleanup to complete..."
sleep 5
echo "[o] Cleanup done"
echo ""

# Step 6: Create PVC
echo "[*] Step 6: Create PersistentVolumeClaim"
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

# Step 7: Wait for PVC to be bound
echo "[*] Step 7: Wait for PVC Binding (max 30 seconds)"
for i in {1..30}; do
  PVC_STATUS=$(kubectl get pvc test-pvc -n storage-test -o jsonpath='{.status.phase}' 2>/dev/null)
  if [ "$PVC_STATUS" = "Bound" ]; then
    echo "[o] PVC is bound"
    break
  fi
  echo "  Waiting... ($i/30) Status: $PVC_STATUS"
  sleep 1
done

if [ "$PVC_STATUS" != "Bound" ]; then
  echo "[x] PVC failed to bind"
  echo ""
  echo "PVC Details:"
  kubectl describe pvc test-pvc -n storage-test
  echo ""
  echo "Events:"
  kubectl get events -n storage-test --sort-by='.lastTimestamp' | tail -10
  exit 1
fi
echo ""

# Step 8: Check PV
echo "[*] Step 8: Check PersistentVolume"
PV_NAME=$(kubectl get pvc test-pvc -n storage-test -o jsonpath='{.spec.volumeName}')
if [ -z "$PV_NAME" ]; then
  echo "[x] No PV associated with PVC"
  exit 1
fi

echo "[o] PV created: $PV_NAME"
kubectl get pv $PV_NAME
echo ""

# Step 9: Get PV path
echo "[*] Step 9: Get PV Physical Path"
echo "Full PV spec:"
kubectl get pv $PV_NAME -o jsonpath='{.spec}' | jq .
echo ""

PV_PATH=$(kubectl get pv $PV_NAME -o jsonpath='{.spec.hostPath.path}')
if [ -z "$PV_PATH" ]; then
  echo "[!] Trying spec.local.path..."
  PV_PATH=$(kubectl get pv $PV_NAME -o jsonpath='{.spec.local.path}')
fi

if [ -n "$PV_PATH" ]; then
  echo "[o] PV path: $PV_PATH"
  if [ -d "$PV_PATH" ]; then
    echo "[o] Physical directory exists"
    sudo ls -lhd "$PV_PATH"
  else
    echo "[!] Physical directory does not exist yet (will be created when pod mounts)"
  fi
else
  echo "[x] Cannot determine PV path"
  exit 1
fi
echo ""

# Step 10: Create test pod
echo "[*] Step 10: Create Test Pod with Volume"
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
    command: ['sh', '-c', 'echo "Hello from PVC at $(date)" > /data/test.txt && cat /data/test.txt && sleep 3600']
    volumeMounts:
    - name: test-volume
      mountPath: /data
  volumes:
  - name: test-volume
    persistentVolumeClaim:
      claimName: test-pvc
YAML

if [ $? -eq 0 ]; then
  echo "[o] Pod created"
else
  echo "[x] Failed to create pod"
  exit 1
fi
echo ""

# Step 11: Wait for pod to be ready
echo "[*] Step 11: Wait for Pod Ready (max 60 seconds)"
kubectl wait --for=condition=Ready pod/test-storage-pod -n storage-test --timeout=60s 2>&1
if [ $? -eq 0 ]; then
  echo "[o] Pod is ready"
else
  echo "[x] Pod failed to become ready"
  echo ""
  echo "Pod details:"
  kubectl describe pod test-storage-pod -n storage-test | tail -30
  exit 1
fi
echo ""

# Step 12: Verify write operation
echo "[*] Step 12: Verify Write Operation"
sleep 2
CONTENT=$(kubectl exec -n storage-test test-storage-pod -- cat /data/test.txt 2>/dev/null)
if echo "$CONTENT" | grep -q "Hello from PVC"; then
  echo "[o] Write operation successful"
  echo "Content: $CONTENT"
else
  echo "[x] Write operation failed"
  exit 1
fi
echo ""

# Step 13: Check physical file
echo "[*] Step 13: Check Physical Storage Location"
if [ -d "$PV_PATH" ]; then
  echo "[o] Physical storage directory exists"
  echo "Contents:"
  sudo ls -lh "$PV_PATH"
  echo ""
  echo "File content from host:"
  sudo cat "$PV_PATH/test.txt" 2>/dev/null || echo "  (file not found)"
else
  echo "[x] Physical storage directory not found: $PV_PATH"
fi
echo ""

# Summary
echo "=========================================="
echo "Test PV/PVC Creation Summary"
echo "=========================================="
echo ""
echo "[o] Namespace: storage-test"
echo "[o] PVC: test-pvc (Status: $PVC_STATUS)"
echo "[o] PV: $PV_NAME"
echo "[o] Path: $PV_PATH"
echo "[o] Pod: test-storage-pod (Running)"
echo ""
echo "Next steps:"
echo "1. Run your storage-validation.sh script"
echo "2. Or manually verify with:"
echo "   kubectl get pvc -n storage-test"
echo "   kubectl get pv"
echo "   kubectl exec -n storage-test test-storage-pod -- ls -lh /data"
echo ""
echo "To cleanup:"
echo "   kubectl delete namespace storage-test"
echo ""
echo "=========================================="
