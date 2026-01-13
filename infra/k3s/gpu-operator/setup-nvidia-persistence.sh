#!/bin/bash

set -e

echo "=========================================="
echo "NVIDIA GPU Persistence Mode Setup"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "[x] Please run as root or with sudo"
  exit 1
fi

# 1. Check current persistence mode status
echo "[*] Step 1: Check Current Persistence Mode"
CURRENT_MODE=$(nvidia-smi --query-gpu=persistence_mode --format=csv,noheader 2>/dev/null || echo "Unknown")
echo "Current mode: $CURRENT_MODE"

if [ "$CURRENT_MODE" = "Enabled" ]; then
  echo "[o] Persistence mode already enabled"
else
  echo "[!] Persistence mode is disabled or unknown"
fi
echo ""

# 2. Enable persistence mode immediately
echo "[*] Step 2: Enable Persistence Mode"
echo "Setting persistence mode on all GPUs..."

if nvidia-smi -pm 1 &>/dev/null; then
  echo "[o] Persistence mode enabled successfully"
else
  echo "[x] Failed to enable persistence mode"
  echo "    Check: sudo nvidia-smi -pm 1"
  exit 1
fi
echo ""

# 3. Verify persistence mode
echo "[*] Step 3: Verify Persistence Mode"
nvidia-smi --query-gpu=index,name,persistence_mode --format=csv,noheader
echo ""

# 4. Setup systemd service for persistence on boot
echo "[*] Step 4: Configure Persistence Mode on Boot"
echo "Creating systemd service..."

cat > /etc/systemd/system/nvidia-persistence.service << 'EOF'
[Unit]
Description=NVIDIA Persistence Mode
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/nvidia-smi -pm 1
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

if [ $? -eq 0 ]; then
  echo "[o] Service file created"
else
  echo "[x] Failed to create service file"
  exit 1
fi
echo ""

# 5. Enable and start service
echo "[*] Step 5: Enable Systemd Service"

systemctl daemon-reload
systemctl enable nvidia-persistence.service
systemctl start nvidia-persistence.service

if systemctl is-active --quiet nvidia-persistence.service; then
  echo "[o] Service enabled and started"
else
  echo "[x] Service failed to start"
  echo "    Check: sudo systemctl status nvidia-persistence.service"
  exit 1
fi
echo ""

# 6. Verify service status
echo "[*] Step 6: Service Status"
systemctl status nvidia-persistence.service --no-pager -l
echo ""

# 7. Final verification
echo "=========================================="
echo "Setup Complete"
echo "=========================================="
echo ""
echo "Persistence Mode Status:"
nvidia-smi | grep -A 1 "Persistence-M"
echo ""
echo "[o] NVIDIA Persistence Mode configured successfully"
echo ""
echo "Next steps:"
echo "  1. Run pre-installation check: sudo bash pre-install-check.sh"
echo "  2. Install GPU Operator: sudo bash install-gpu-operator.sh"
echo ""
echo "To verify after reboot:"
echo "  nvidia-smi | grep Persistence"
echo "  systemctl status nvidia-persistence.service"
echo ""
echo "=========================================="
