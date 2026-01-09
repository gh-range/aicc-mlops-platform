#!/bin/bash

# This script requires root/sudo privileges
if [ "$EUID" -ne 0 ]; then
  echo "[!] Error: This script must be run with sudo"
  exit 1
fi

echo "=========================================="
echo "etcd Snapshot Backup Configuration"
echo "=========================================="
echo ""

# 1. Create backup directory
BACKUP_DIR="/var/lib/rancher/k3s/server/db/snapshots"
echo "[*] Step 1: Ensure backup directory exists"
mkdir -p $BACKUP_DIR
chmod 700 $BACKUP_DIR
echo "[o] Backup directory: $BACKUP_DIR"
echo ""

# 2. Create manual snapshot
echo "[*] Step 2: Create manual snapshot (test)"
SNAPSHOT_NAME="manual-test-$(date +%Y%m%d-%H%M%S)"
k3s etcd-snapshot save --name $SNAPSHOT_NAME
if [ $? -eq 0 ]; then
  echo "[o] Manual snapshot created: $SNAPSHOT_NAME"
else
  echo "[x] Failed to create manual snapshot"
  exit 1
fi
echo ""

# 3. List existing snapshots
echo "[*] Step 3: List all snapshots"
k3s etcd-snapshot ls
echo ""

# 4. Check snapshot file
echo "[*] Step 4: Verify snapshot file"
SNAPSHOT_FILE=$(find $BACKUP_DIR -name "$SNAPSHOT_NAME*" -type f)
if [ -f "$SNAPSHOT_FILE" ]; then
  echo "[o] Snapshot file exists"
  ls -lh $SNAPSHOT_FILE
  echo ""
  echo "File size: $(du -h $SNAPSHOT_FILE | cut -f1)"
else
  echo "[x] Snapshot file not found"
fi
echo ""

# 5. Configure automatic snapshots via k3s service
echo "[*] Step 5: Configure automatic snapshots"
echo ""
echo "k3s supports automatic snapshots via these parameters:"
echo "  --etcd-snapshot-schedule-cron '0 */12 * * *'  # Every 12 hours"
echo "  --etcd-snapshot-retention 5                   # Keep last 5 snapshots"
echo ""

# Check if auto-snapshot is already configured
if systemctl cat k3s.service | grep -q "etcd-snapshot-schedule-cron"; then
  echo "[o] Automatic snapshots already configured"
else
  echo "[!] Automatic snapshots NOT configured"
  echo ""
  echo "To enable, you need to:"
  echo "1. Stop k3s: systemctl stop k3s"
  echo "2. Edit /etc/systemd/system/k3s.service.env (add parameters)"
  echo "3. Reload and restart: systemctl daemon-reload && systemctl start k3s"
  echo ""
  read -p "Do you want to configure automatic snapshots now? (yes/no): " CONFIRM
  
  if [ "$CONFIRM" = "yes" ]; then
    echo ""
    echo "[*] Configuring automatic snapshots..."
    
    # Create service override directory
    mkdir -p /etc/systemd/system/k3s.service.d
    
    # Create override file
    cat > /etc/systemd/system/k3s.service.d/etcd-snapshot.conf << 'OVERRIDE'
[Service]
ExecStart=
ExecStart=/usr/local/bin/k3s server \
  --cluster-init \
  --disable traefik \
  --disable servicelb \
  --write-kubeconfig-mode 644 \
  --etcd-snapshot-schedule-cron "0 */12 * * *" \
  --etcd-snapshot-retention 5
OVERRIDE

    echo "[o] Override file created: /etc/systemd/system/k3s.service.d/etcd-snapshot.conf"
    echo ""
    echo "[*] Reloading systemd and restarting k3s..."
    systemctl daemon-reload
    systemctl restart k3s
    
    echo "[*] Waiting for k3s to be ready..."
    sleep 10
    
    if systemctl is-active --quiet k3s; then
      echo "[o] k3s restarted successfully with automatic snapshots enabled"
    else
      echo "[x] k3s failed to restart, check logs: journalctl -u k3s -f"
      exit 1
    fi
  else
    echo "[!] Skipping automatic snapshot configuration"
  fi
fi
echo ""

# 6. Summary
echo "=========================================="
echo "Backup Configuration Summary"
echo "=========================================="
echo ""
echo "Snapshot directory: $BACKUP_DIR"
echo "Manual snapshot command: k3s etcd-snapshot save --name <name>"
echo "List snapshots: k3s etcd-snapshot ls"
echo ""
echo "Current snapshots:"
k3s etcd-snapshot ls | tail -5
echo ""
echo "[o] Backup configuration completed"
echo "=========================================="
