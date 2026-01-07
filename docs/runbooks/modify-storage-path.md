# Modify local-path-provisioner Storage Path

## Quick Reference

**Current Configuration:**
```bash
kubectl get configmap local-path-config -n kube-system -o jsonpath='{.data.config\.json}' | jq
```

**Current Storage Path:**
```bash
kubectl get configmap local-path-config -n kube-system -o jsonpath='{.data.config\.json}' | grep -oP '"paths"\s*:\s*\[\s*"\K[^"]+'
```

---

## Procedure

### 1. Backup Current Configuration
```bash
# Save current ConfigMap
kubectl get configmap local-path-config -n kube-system -o yaml > /tmp/local-path-config-backup-$(date +%Y%m%d).yaml

# Verify backup
cat /tmp/local-path-config-backup-*.yaml
```

---

### 2. Prepare New Storage Directory
```bash
# Replace with your desired path
NEW_PATH="/your/custom/path"

# Create directory
sudo mkdir -p $NEW_PATH

# Set appropriate permissions
sudo chmod 755 $NEW_PATH

# Verify
ls -ld $NEW_PATH
```

---

### 3. Update ConfigMap

**Option A: Interactive Edit**
```bash
kubectl edit configmap local-path-config -n kube-system
# Edit the "paths" value in config.json
# Save and exit
```

**Option B: Apply YAML**
```bash
cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-path-config
  namespace: kube-system
data:
  config.json: |-
    {
      "nodePathMap": [
        {
          "node": "DEFAULT_PATH_FOR_NON_LISTED_NODES",
          "paths": ["/your/custom/path"]
        }
      ]
    }
  setup: |-
    #!/bin/sh
    set -eu
    mkdir -m 0777 -p "\$VOL_DIR"
  teardown: |-
    #!/bin/sh
    set -eu
    rm -rf "\$VOL_DIR"
  helperPod.yaml: |-
    apiVersion: v1
    kind: Pod
    metadata:
      name: helper-pod
    spec:
      containers:
      - name: helper-pod
        image: busybox:latest
YAML
```

---

### 4. Reload Configuration
```bash
# Method 1: Delete pod (Deployment will recreate it)
kubectl delete pod -n kube-system -l app=local-path-provisioner

# Method 2: Rollout restart
kubectl rollout restart deployment local-path-provisioner -n kube-system

# Wait for ready
kubectl wait --for=condition=Ready pod -n kube-system -l app=local-path-provisioner --timeout=60s
```

---

### 5. Verify Changes
```bash
# Check pod logs
kubectl logs -n kube-system -l app=local-path-provisioner --tail=50

# Verify ConfigMap
kubectl get configmap local-path-config -n kube-system -o jsonpath='{.data.config\.json}' | jq

# Check storage path
kubectl get configmap local-path-config -n kube-system -o jsonpath='{.data.config\.json}' | grep -oP '"paths"\s*:\s*\[\s*"\K[^"]+'
```

---

### 6. Test with New PVC
```bash
# Create test PVC
kubectl create namespace test-storage-change
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-new-path
  namespace: test-storage-change
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: local-path
  resources:
    requests:
      storage: 10Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: test-storage-change
spec:
  containers:
  - name: test
    image: busybox
    command: ['sh', '-c', 'echo "New path test" > /data/test.txt && sleep 300']
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: test-new-path
EOF

# Wait for pod
kubectl wait --for=condition=Ready pod/test-pod -n test-storage-change --timeout=60s

# Check PV path
PV_NAME=$(kubectl get pvc test-new-path -n test-storage-change -o jsonpath='{.spec.volumeName}')
kubectl get pv $PV_NAME -o jsonpath='{.spec.local.path}'
echo ""

# Should show: /your/custom/path/pvc-xxxxx...

# Verify on host
PV_PATH=$(kubectl get pv $PV_NAME -o jsonpath='{.spec.local.path}')
sudo ls -lh $PV_PATH
sudo cat $PV_PATH/test.txt

# Cleanup
kubectl delete namespace test-storage-change
```

---

## Important Notes

1. **Existing PVs are NOT affected** - Only new PVCs will use the new path
2. **Directory must exist before first PVC creation**
3. **Provisioner pod must be restarted** to load new config
4. **Test before production use**

---

## Rollback

If something goes wrong:
```bash
# Restore from backup
kubectl apply -f /tmp/local-path-config-backup-YYYYMMDD.yaml

# Restart provisioner
kubectl delete pod -n kube-system -l app=local-path-provisioner

# Verify
kubectl get configmap local-path-config -n kube-system -o yaml
```

---

## Automation Script
```bash
#!/bin/bash
# File: scripts/setup/change-storage-path.sh

NEW_PATH="$1"

if [ -z "$NEW_PATH" ]; then
  echo "Usage: $0 /new/storage/path"
  exit 1
fi

echo "Changing local-path storage to: $NEW_PATH"

# Create directory
sudo mkdir -p $NEW_PATH
sudo chmod 755 $NEW_PATH

# Update ConfigMap
kubectl patch configmap local-path-config -n kube-system --type=json \
  -p="[{\"op\": \"replace\", \"path\": \"/data/config.json\", \"value\": \"{\\\"nodePathMap\\\":[{\\\"node\\\":\\\"DEFAULT_PATH_FOR_NON_LISTED_NODES\\\",\\\"paths\\\":[\\\"$NEW_PATH\\\"]}]}\"}]"

# Restart provisioner
kubectl delete pod -n kube-system -l app=local-path-provisioner

echo "Done. Verifying..."
sleep 5
kubectl get pod -n kube-system -l app=local-path-provisioner
```

---

## Checklist

- [ ] Backup current ConfigMap
- [ ] Create new directory with correct permissions
- [ ] Update ConfigMap
- [ ] Restart local-path-provisioner pod
- [ ] Verify new configuration loaded
- [ ] Test with new PVC
- [ ] Verify PV created in new path
- [ ] Document change in Git
