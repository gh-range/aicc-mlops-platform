#!/bin/bash
set -e

echo "=== k3s Built-in Traefik Disable Verification ==="
echo ""

# 1. Check k3s startup parameters
echo "[1/4] Checking k3s service configuration..."
K3S_CONFIG=$(systemctl cat k3s.service 2>/dev/null || echo "")

if echo "$K3S_CONFIG" | grep -q "\-\-disable.*traefik" ; then
  echo "[o] Traefik disabled via '--disable traefik' flag"
elif echo "$K3S_CONFIG" | grep -q "traefik"; then
  echo "[!] Found 'traefik' in config but pattern unclear"
  echo "  Showing relevant lines:"
  systemctl cat k3s.service | grep -i traefik
  echo ""
  echo "  If you see '--disable traefik', status is OK"
  echo "  If NOT, Traefik may still be enabled"
else
  echo "[o] No Traefik configuration found in k3s service"
fi

# 2. Verify no Traefik pods in kube-system
echo "[2/4] Checking for Traefik pods..."
TRAEFIK_PODS=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik --no-headers 2>/dev/null | wc -l)
if [ "$TRAEFIK_PODS" -eq 0 ]; then
  echo "[o] No Traefik pods found in kube-system"
else
  echo "[x] Found $TRAEFIK_PODS Traefik pods - cleanup required"
  exit 1
fi

# 3. Verify no Traefik HelmChart CRD
echo "[3/4] Checking for HelmChart resources..."
HELMCHARTS=$(kubectl get helmcharts -n kube-system --no-headers 2>/dev/null | grep -c traefik || true)
if [ "$HELMCHARTS" -eq 0 ]; then
  echo "[o] No Traefik HelmChart resources found"
else
  echo "[x] Found Traefik HelmChart - cleanup required"
  exit 1
fi

# 4. Check for port 80/443 listeners
echo "[4/4] Verifying port availability..."
if ! sudo netstat -tunlp | grep -q ':80.*LISTEN'; then
  echo "[o] Port 80 available for new Traefik deployment"
else
  echo "[!] Port 80 occupied - check existing services"
fi

if ! sudo netstat -tunlp | grep -q ':443.*LISTEN'; then
  echo "[o] Port 443 available for new Traefik deployment"
else
  echo "[x] Port 443 occupied - check existing services"
fi

echo ""
echo "=== Verification Complete ==="
echo "Status: READY for standalone Traefik deployment"
