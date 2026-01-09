#!/bin/bash

echo "=========================================="
echo "網路與防火牆狀態檢查"
echo "=========================================="
echo ""

# 檢查網路介面
echo " 網路介面資訊："
ip addr show | grep -E "inet |mtu"
echo ""

# 檢查預設路由
echo " 預設路由："
ip route | grep default
echo ""

# 檢查 DNS 設定
echo " DNS 設定："
cat /etc/resolv.conf | grep nameserver
echo ""

# 檢查防火牆狀態（UFW）
echo " 防火牆狀態 (UFW)："
if command -v ufw &> /dev/null; then
  sudo ufw status verbose
else
  echo "UFW 未安裝"
fi
echo ""

# 檢查 iptables 規則數量
echo "  iptables 規則："
sudo iptables -L -n | head -10
echo ""

# 檢查目前監聽的 ports
echo " 目前監聽的 Ports："
sudo ss -tulpn | grep LISTEN | head -10
echo ""

# 檢查主機名稱
echo "  主機名稱："
hostname
hostname -f 2>/dev/null || echo "FQDN 未設定"
echo ""

echo "=========================================="
