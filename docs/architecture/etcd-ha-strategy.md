# etcd High Availability Strategy

## Current Setup: Single-Node HA

### Architecture
```
┌─────────────────────────────────────┐
│  k3s Server Process                 │
│  ┌───────────────────────────────┐  │
│  │  Embedded etcd                │  │
│  │  - Stores cluster state       │  │
│  │  - Survives k3s restarts      │  │
│  │  - Data: /var/lib/rancher/... │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │  Kubernetes API Server        │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │  Controller Manager           │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │  Scheduler                    │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

### What "Single-Node HA" Means

**High Availability within single node:**
- etcd data persists across k3s restarts
- No data loss when systemctl restart k3s
- Cluster state survives server process crashes

**NOT protected against:**
- Hardware failure (disk, motherboard, power)
- Complete server failure
- Data center outage

### Comparison with SQLite (default k3s without --cluster-init)

| Feature | SQLite (default) | Embedded etcd (--cluster-init) |
|---------|------------------|--------------------------------|
| Data persistence | Yes | Yes |
| Multi-master capable | No | Yes |
| Can add nodes later | No (requires migration) | Yes (seamless) |
| Production ready | Dev/Test only | Production ready |
| Backup/restore | File copy | etcd snapshots |

---

## Automatic Snapshot Configuration

### Current Schedule
```
Cron: 0 */12 * * *  (Every 12 hours at :00)
Retention: 5 snapshots
Location: /var/lib/rancher/k3s/server/db/snapshots/
```

### Manual Snapshot
```bash
# Create snapshot
sudo k3s etcd-snapshot save --name pre-upgrade-backup

# List snapshots
sudo k3s etcd-snapshot ls

# Snapshots are named: <name>-<node>-<timestamp>
```

---

## Disaster Recovery

### Scenario 1: Restore from Snapshot

**When to use:**
- Accidental deletion of critical resources
- Corrupted cluster state
- Need to rollback after failed upgrade

**Steps:**
```bash
# 1. Stop k3s
sudo systemctl stop k3s

# 2. Restore from snapshot
sudo k3s server \
  --cluster-reset \
  --cluster-reset-restore-path=/var/lib/rancher/k3s/server/db/snapshots/<snapshot-name>

# 3. Start k3s normally
sudo systemctl start k3s

# 4. Verify
kubectl get nodes
kubectl get pods -A
```

### Scenario 2: Complete Disk Failure

**Requirements:**
- Off-site snapshot backup
- Fresh Ubuntu 24.04 installation
- Same hostname

**Steps:**
```bash
# 1. Install k3s with same configuration
curl -sfL https://get.k3s.io | sh -s - server \
  --cluster-init \
  --disable traefik \
  --disable servicelb \
  --write-kubeconfig-mode 644

# 2. Stop k3s
sudo systemctl stop k3s

# 3. Copy snapshot to new server
scp backup.tar.gz new-server:/tmp/

# 4. Extract and restore
sudo k3s server \
  --cluster-reset \
  --cluster-reset-restore-path=/tmp/snapshot-file

# 5. Start k3s
sudo systemctl start k3s
```

---

## Future Expansion: Multi-Node HA

### Why Multi-Node?

**Benefits:**
- True high availability (survive single node failure)
- Load distribution
- Zero-downtime upgrades
- Meet enterprise SLA requirements

**Requirements:**
- Minimum 3 nodes (etcd quorum)
- Stable network between nodes
- Same k3s version across nodes

### Architecture: 3-Node HA Cluster
```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   Master 1   │    │   Master 2   │    │   Master 3   │
│  (existing)  │◄──►│    (new)     │◄──►│    (new)     │
│              │    │              │    │              │
│ etcd member  │    │ etcd member  │    │ etcd member  │
│  k8s API     │    │  k8s API     │    │  k8s API     │
└──────────────┘    └──────────────┘    └──────────────┘
       ▲                   ▲                   ▲
       └───────────────────┴───────────────────┘
              Load Balancer (external)
                  or Traefik IngressRoute
```

### Adding Node 2 (Future)

**On Node 1 (existing):**
```bash
# Get token
sudo cat /var/lib/rancher/k3s/server/node-token
```

**On Node 2 (new server):**
```bash
# Install as additional server
curl -sfL https://get.k3s.io | K3S_TOKEN=<token-from-node1> sh -s - server \
  --server https://<node1-ip>:6443 \
  --disable traefik \
  --disable servicelb
```

**Result:**
- etcd cluster automatically expands to 2 members
- API server available on both nodes
- Workloads can be scheduled on both

### Adding Node 3 (Future)

Same process as Node 2. After Node 3 joins:
- etcd quorum: 2 out of 3 (can survive 1 node failure)
- API server available on 3 nodes
- Full HA achieved

---

## Monitoring etcd Health

### Check etcd Member List
```bash
# Via k3s
sudo k3s kubectl get nodes

# Via etcdctl (if needed)
sudo k3s etcd-snapshot ls
```

### Metrics

etcd exposes metrics on localhost:2379/metrics (internal only)

**Key metrics:**
- etcd_server_has_leader (should be 1)
- etcd_server_leader_changes_seen_total (should be stable)
- etcd_mvcc_db_total_size_in_bytes (database size)

**Integration:**
- Prometheus will scrape these via DCGM exporter setup (Lesson 2)
- Grafana dashboard for etcd health (Lesson 2)

---

## Backup Best Practices

### Backup Schedule

**Current:** Every 12 hours, keep 5 snapshots

**Recommended for production:**
- Hourly snapshots during business hours
- Daily snapshots retained for 7 days
- Weekly snapshots retained for 4 weeks
- Monthly snapshots retained for 12 months

### Off-Site Backup
```bash
#!/bin/bash
# Copy snapshots to external storage

SNAPSHOT_DIR="/var/lib/rancher/k3s/server/db/snapshots"
BACKUP_TARGET="user@backup-server:/backups/k3s/"

# Sync snapshots
rsync -avz --delete $SNAPSHOT_DIR/ $BACKUP_TARGET

# Or upload to S3
aws s3 sync $SNAPSHOT_DIR s3://my-bucket/k3s-snapshots/
```

**Schedule via cron:**
```
0 2 * * * /path/to/backup-script.sh
```

---

## Testing Recovery (Recommended)

### Quarterly DR Test

1. Create test namespace with resources
2. Take snapshot
3. Delete test namespace
4. Restore from snapshot
5. Verify test namespace recovered

**Script:**
```bash
# 1. Create test
kubectl create namespace dr-test
kubectl create deployment nginx --image=nginx -n dr-test

# 2. Snapshot
sudo k3s etcd-snapshot save --name dr-test-$(date +%Y%m%d)

# 3. Delete
kubectl delete namespace dr-test

# 4. Restore (in maintenance window)
sudo systemctl stop k3s
sudo k3s server --cluster-reset --cluster-reset-restore-path=<snapshot>
sudo systemctl start k3s

# 5. Verify
kubectl get namespace dr-test
kubectl get deployment -n dr-test
```

---

## Troubleshooting

### Problem: etcd snapshot fails

**Symptoms:**
```
Error: failed to save snapshot
```

**Solution:**
```bash
# Check disk space
df -h /var/lib/rancher/k3s

# Check permissions
sudo ls -ld /var/lib/rancher/k3s/server/db/snapshots

# Check k3s logs
sudo journalctl -u k3s -n 50
```

### Problem: Restore fails

**Symptoms:**
```
Error: failed to restore snapshot
```

**Solution:**
```bash
# Ensure k3s is stopped
sudo systemctl stop k3s

# Check snapshot file integrity
sudo ls -lh /path/to/snapshot

# Try with full path
sudo k3s server \
  --cluster-reset \
  --cluster-reset-restore-path=/full/path/to/snapshot

# If still fails, check logs
sudo journalctl -xe
```

---

## Security Considerations

### Snapshot Encryption

**Current:** Snapshots are NOT encrypted at rest

**For production:**
- Encrypt snapshot directory: LUKS, dm-crypt
- Encrypt during backup: gpg, age
- Use encrypted S3 buckets

### Access Control
```bash
# Snapshots contain sensitive data (secrets, tokens)
# Ensure proper permissions
sudo chmod 700 /var/lib/rancher/k3s/server/db/snapshots
sudo chown -R root:root /var/lib/rancher/k3s/server/db/snapshots
```

---

## References

- [k3s etcd Documentation](https://docs.k3s.io/datastore/ha-embedded)
- [etcd Official Docs](https://etcd.io/docs/)
- [Kubernetes Backup Best Practices](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#backing-up-an-etcd-cluster)

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2026-01-02 | Infrastructure Lead | Initial documentation for single-node HA |

