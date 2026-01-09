#!/bin/bash

echo "=========================================="
echo "k3s 安裝前最終確認"
echo "=========================================="
echo ""

# 檢查是否為 root 或有 sudo 權限
echo " 權限檢查："
if [ "$EUID" -eq 0 ]; then 
  echo " o  以 root 執行"
elif sudo -n true 2>/dev/null; then
  echo " o  sudo 權限可用"
else
  echo " x  需要 sudo 權限"
  exit 1
fi
echo ""

# 檢查記憶體
echo " 記憶體檢查："
TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
FREE_MEM=$(free -g | awk '/^Mem:/{print $4}')
echo "  總記憶體: ${TOTAL_MEM}GB"
echo "  可用記憶體: ${FREE_MEM}GB"
if [ $FREE_MEM -lt 10 ]; then
  echo " x 可用記憶體不足 10GB"
else
  echo " o 記憶體充足"
fi
echo ""

# 檢查磁碟空間
echo " 磁碟空間檢查："
ROOT_AVAIL=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
echo "  根目錄可用: ${ROOT_AVAIL}GB"
if [ $ROOT_AVAIL -lt 50 ]; then
  echo " x 可用空間不足 50GB"
else
  echo " o 磁碟空間充足"
fi
echo ""

# 檢查必要指令
echo " 必要工具檢查："
for cmd in curl systemctl iptables; do
  if command -v $cmd &> /dev/null; then
    echo " o $cmd"
  else
    echo " x $cmd (未安裝)"
  fi
done
echo ""

# 檢查是否已安裝 k3s
echo " k3s 安裝狀態："
if command -v k3s &> /dev/null; then
  echo "  x  k3s 已安裝"
  k3s --version
  echo "  如需重新安裝，請先執行: /usr/local/bin/k3s-uninstall.sh"
else
  echo " o k3s 未安裝（可以繼續）"
fi
echo ""

# 檢查 Port 佔用
echo " 重要 Port 檢查："
for port in 6443 10250 2379 2380; do
  if sudo ss -tulpn | grep -q ":$port "; then
    echo " x  Port $port 已被佔用"
    sudo ss -tulpn | grep ":$port "
  else
    echo " o  Port $port 可用"
  fi
done
echo ""

# 記錄安裝前狀態
echo " 記錄安裝前狀態："
cat > /tmp/pre-install-state.txt << EOF
=== k3s 安裝前系統狀態 ===
日期: $(date)
主機名稱: $(hostname)
核心版本: $(uname -r)
記憶體: ${TOTAL_MEM}GB (可用 ${FREE_MEM}GB)
磁碟空間: ${ROOT_AVAIL}GB 可用
GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo "檢測失敗")
EOF
cat /tmp/pre-install-state.txt
echo ""

echo "=========================================="
echo " o 安裝前檢查完成"
echo "=========================================="
