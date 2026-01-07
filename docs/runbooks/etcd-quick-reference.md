# etcd Quick Reference Card

## Common Commands

### Snapshots
```bash
# Create manual snapshot
sudo k3s etcd-snapshot save --name my-backup

# List snapshots
sudo k3s etcd-snapshot ls

# Restore from snapshot (DESTRUCTIVE - stops cluster)
sudo systemctl stop k3s
sudo k3s server --cluster-reset --cluster-reset-restore-path=<path>
sudo systemctl start k3s
```

### Health Check
```bash
# Check k3s service
sudo systemctl status k3s

# Check nodes
kubectl get nodes

# Check etcd directory
sudo ls -lh /var/lib/rancher/k3s/server/db/etcd
```

### Backup Management
```bash
# Snapshot location
/var/lib/rancher/k3s/server/db/snapshots/

# Copy to external storage
sudo rsync -avz /var/lib/rancher/k3s/server/db/snapshots/ user@backup:/path/

# Disk usage
sudo du -sh /var/lib/rancher/k3s/server/db/etcd
```

---

## Emergency Procedures

### Complete Cluster Lost

1. Reinstall k3s with same parameters
2. Stop k3s: `sudo systemctl stop k3s`
3. Restore: `sudo k3s server --cluster-reset --cluster-reset-restore-path=<snapshot>`
4. Start: `sudo systemctl start k3s`

### Corrupted State

1. Stop k3s: `sudo systemctl stop k3s`
2. Backup current state: `sudo mv /var/lib/rancher/k3s /var/lib/rancher/k3s.bad`
3. Restore from snapshot (see above)

---

## Automatic Backup Status

Check if configured:
```bash
sudo systemctl cat k3s.service | grep etcd-snapshot
```

Current configuration:
- Schedule: Every 12 hours
- Retention: 5 snapshots
- Location: /var/lib/rancher/k3s/server/db/snapshots/
