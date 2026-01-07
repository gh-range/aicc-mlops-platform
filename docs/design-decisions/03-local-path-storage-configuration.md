# ADR-003: Custom local-path-provisioner Configuration

**Status**: Accepted  
**Date**: 2026-01-07  
**Deciders**: Infrastructure Lead  
**Technical Story**: Customize storage path for better disk management

---

## Context and Problem Statement

The default local-path-provisioner uses `/var/lib/rancher/k3s/storage` which may not be ideal for:
- Systems with multiple disks/partitions
- Dedicated storage volumes
- Specific backup/monitoring requirements

**Key Requirements:**
- Use dedicated storage path
- Maintain dynamic provisioning capability
- Support future multi-node expansion

---

## Decision

Modified local-path-provisioner to use custom storage path.

### Configuration Changes

**Original default**:
```json
{
  "nodePathMap": [
    {
      "node": "DEFAULT_PATH_FOR_NON_LISTED_NODES",
      "paths": ["/var/lib/rancher/k3s/storage"]
    }
  ]
}
```

**Modified to**:
```json
{
  "nodePathMap": [
    {
      "node": "DEFAULT_PATH_FOR_NON_LISTED_NODES",
      "paths": ["/your/custom/path"]
    }
  ]
}
```

---

## How to Modify

### Step 1: Edit ConfigMap
```bash
# Method 1: Direct edit
kubectl edit configmap local-path-config -n kube-system

# Method 2: Apply from file
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
    mkdir -m 0777 -p "$VOL_DIR"
  teardown: |-
    #!/bin/sh
    set -eu
    rm -rf "$VOL_DIR"
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

### Step 2: Ensure Directory Exists
```bash
# Create custom path on host
sudo mkdir -p /your/custom/path
sudo chmod 755 /your/custom/path

# Verify permissions
ls -ld /your/custom/path
```

### Step 3: Restart local-path-provisioner
```bash
# Delete the pod (will be recreated by Deployment)
kubectl delete pod -n kube-system -l app=local-path-provisioner

# Wait for pod to be ready
kubectl wait --for=condition=Ready pod -n kube-system -l app=local-path-provisioner --timeout=60s

# Verify new configuration is loaded
kubectl logs -n kube-system -l app=local-path-provisioner --tail=20
```

### Step 4: Verify Configuration
```bash
# Check ConfigMap
kubectl get configmap local-path-config -n kube-system -o yaml

# Extract configured path
kubectl get configmap local-path-config -n kube-system -o jsonpath='{.data.config\.json}' | grep -oP '"paths"\s*:\s*\[\s*"\K[^"]+'

# Test with a PVC
kubectl create namespace storage-test
kubectl apply -f - <<EOF
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
      storage: 100Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: storage-test
spec:
  containers:
  - name: test
    image: busybox
    command: ['sh', '-c', 'echo test > /data/file && sleep 3600']
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: test-pvc
EOF

# Check where PV was created
kubectl get pv -o custom-columns=NAME:.metadata.name,PATH:.spec.local.path

# Cleanup test
kubectl delete namespace storage-test
```

---

## Multi-Node Configuration (Future)

For multi-node clusters, specify paths per node:
```json
{
  "nodePathMap": [
    {
      "node": "node1",
      "paths": ["/mnt/disk1/k3s-storage", "/mnt/disk2/k3s-storage"]
    },
    {
      "node": "node2",
      "paths": ["/data/k3s-storage"]
    },
    {
      "node": "DEFAULT_PATH_FOR_NON_LISTED_NODES",
      "paths": ["/var/lib/rancher/k3s/storage"]
    }
  ]
}
```

---

## Consequences

### Positive
- Better disk space management
- Easier to monitor storage usage
- Can use dedicated high-performance disks
- Separates system and data storage

### Negative
- Need to ensure path exists before first PVC creation
- Manual configuration required (not default)
- Must document for team members

### Neutral
- Configuration change requires pod restart
- Existing PVs not affected (only new ones)

---

## Troubleshooting

### Issue: PVC stuck in Pending
```bash
# Check provisioner logs
kubectl logs -n kube-system -l app=local-path-provisioner

# Common errors:
# 1. Directory doesn't exist
sudo mkdir -p /your/custom/path

# 2. Permission denied
sudo chmod 755 /your/custom/path

# 3. ConfigMap not reloaded
kubectl delete pod -n kube-system -l app=local-path-provisioner
```

### Issue: Wrong path still being used
```bash
# Force provisioner to reload config
kubectl rollout restart deployment local-path-provisioner -n kube-system

# Or recreate the pod
kubectl delete pod -n kube-system -l app=local-path-provisioner
```

---

## References

- [local-path-provisioner Documentation](https://github.com/rancher/local-path-provisioner)
- [Kubernetes Local Persistent Volumes](https://kubernetes.io/docs/concepts/storage/volumes/#local)

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2026-01-07 | Range | Initial configuration change |

