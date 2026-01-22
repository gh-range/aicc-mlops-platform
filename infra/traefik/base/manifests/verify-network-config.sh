#!/bin/bash
set -e

echo "=== Traefik Network Configuration Verification ==="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check 1: Port availability before deployment
echo "[1/6] Checking port availability..."
if sudo netstat -tulpn | grep -q ':80 '; then
  echo -e "${RED}[x] Port 80 is occupied${NC}"
  echo "  Occupied b[x] Port 80 is occupied${NC}"
  echo "  Occupied by:"
  sudo netstat -tulpn | grep ':80 '
  exit 1
else
  echo -e "${GREEN}[o] Port 80 available${NC}"
fi

if sudo netstat -tulpn | grep -q ':443 '; then
  echo -e "${RED}[x] Port 443 is occupied${NC}"
  echo "  Occupied by:"
  sudo netstat -tulpn | grep ':443 '
  exit 1
else
  echo -e "${GREEN}[o] Port 443 available${NC}"
fi

# Check 2: Verify service type
echo "[2/6] Checking service configuration..."
if kubectl get ns traefik-system >/dev/null 2>&1; then
  SERVICE_TYPE=$(kubectl get svc traefik -n traefik-system -o jsonpath='{.spec.type}' 2>/dev/null || echo "not-found")
  if [ "$SERVICE_TYPE" = "ClusterIP" ]; then
    echo -e "${GREEN}[o] Service type: ClusterIP${NC}"
  elif [ "$SERVICE_TYPE" = "not-found" ]; then
    echo -e "${YELLOW}[!] Traefik service not deployed yet${NC}"
  else
    echo -e "${RED}[x] Service type: $SERVICE_TYPE (expected ClusterIP)${NC}"
    exit 1
  fi
else
  echo -e "${YELLOW}[!] traefik-system namespace not found (pre-deployment)${NC}"
fi

# Check 3: Verify hostNetwork setting
echo "[3/6] Checking hostNetwork configuration..."
if kubectl get ns traefik-system >/dev/null 2>&1; then
  HOST_NETWORK=$(kubectl get pods -n traefik-system -l app.kubernetes.io/name=traefik -o jsonpath='{.items[0].spec.hostNetwork}' 2>/dev/null || echo "not-found")
  if [ "$HOST_NETWORK" = "false" ]; then
    echo -e "${GREEN}[o] hostNetwork: false (isolated)${NC}"
  elif [ "$HOST_NETWORK" = "not-found" ]; then
    echo -e "${YELLOW}[!] Traefik pods not found (pre-deployment)${NC}"
  else
    echo -e "${RED}[x] hostNetwork: $HOST_NETWORK (security risk)${NC}"
    exit 1
  fi
else
  echo -e "${YELLOW}[!] Pre-deployment check - skipping pod verification${NC}"
fi

# Check 4: Verify HostPort configuration
echo "[4/6] Checking HostPort binding..."
if kubectl get ns traefik-system >/dev/null 2>&1; then
  HOSTPORT_80=$(kubectl get pods -n traefik-system -l app.kubernetes.io/name=traefik -o jsonpath='{.items[0].spec.containers[0].ports[?(@.containerPort==8000)].hostPort}' 2>/dev/null || echo "not-found")
  HOSTPORT_443=$(kubectl get pods -n traefik-system -l app.kubernetes.io/name=traefik -o jsonpath='{.items[0].spec.containers[0].ports[?(@.containerPort==8443)].hostPort}' 2>/dev/null || echo "not-found")
  
  if [ "$HOSTPORT_80" = "80" ] && [ "$HOSTPORT_443" = "443" ]; then
    echo -e "${GREEN}[o] HostPort configured: 80 → 8000, 443 → 8443${NC}"
  elif [ "$HOSTPORT_80" = "not-found" ]; then
    echo -e "${YELLOW}[!] Traefik pods not found (pre-deployment)${NC}"
  else
    echo -e "${RED}[x] HostPort mismatch: 80→$HOSTPORT_80, 443→$HOSTPORT_443${NC}"
    exit 1
  fi
else
  echo -e "${YELLOW}[!] Pre-deployment check - skipping HostPort verification${NC}"
fi

# Check 5: Security context validation
echo "[5/6] Validating security context..."
if kubectl get ns traefik-system >/dev/null 2>&1; then
  RUN_AS_NON_ROOT=$(kubectl get pods -n traefik-system -l app.kubernetes.io/name=traefik -o jsonpath='{.items[0].spec.containers[0].securityContext.runAsNonRoot}' 2>/dev/null || echo "not-found")
  READ_ONLY_FS=$(kubectl get pods -n traefik-system -l app.kubernetes.io/name=traefik -o jsonpath='{.items[0].spec.containers[0].securityContext.readOnlyRootFilesystem}' 2>/dev/null || echo "not-found")
  
  if [ "$RUN_AS_NON_ROOT" = "true" ] && [ "$READ_ONLY_FS" = "true" ]; then
    echo -e "${GREEN}[o] Security: Non-root user + read-only filesystem${NC}"
  elif [ "$RUN_AS_NON_ROOT" = "not-found" ]; then
    echo -e "${YELLOW}[!] Security context not verified (pre-deployment)${NC}"
  else
    echo -e "${YELLOW}[!] Security context incomplete${NC}"
  fi
else
  echo -e "${YELLOW}[!] Pre-deployment check - skipping security verification${NC}"
fi

# Check 6: Network connectivity test (post-deployment)
echo "[6/6] Testing network connectivity..."
if kubectl get ns traefik-system >/dev/null 2>&1; then
  POD_COUNT=$(kubectl get pods -n traefik-system -l app.kubernetes.io/name=traefik --no-headers 2>/dev/null | wc -l)
  if [ "$POD_COUNT" -gt 0 ]; then
    NODE_IP=$(hostname -I | awk '{print $1}')
    echo "  Testing HTTP on $NODE_IP:80..."
    if curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://$NODE_IP:80 >/dev/null 2>&1; then
      echo -e "${GREEN}[o] HTTP port 80 accessible${NC}"
    else
      echo -e "${YELLOW}[!] HTTP port 80 not responding (may need IngressRoute)${NC}"
    fi
    
    echo "  Testing HTTPS on $NODE_IP:443..."
    if curl -k -s -o /dev/null -w "%{http_code}" --max-time 5 https://$NODE_IP:443 >/dev/null 2>&1; then
      echo -e "${GREEN}[o] HTTPS port 443 accessible${NC}"
    else
      echo -e "${YELLOW}[!] HTTPS port 443 not responding (may need IngressRoute)${NC}"
    fi
  else
    echo -e "${YELLOW}[!] No Traefik pods running (pre-deployment)${NC}"
  fi
else
  echo -e "${YELLOW}[!] Pre-deployment check - skipping connectivity test${NC}"
fi

echo ""
echo "=== Verification Summary ==="
if kubectl get ns traefik-system >/dev/null 2>&1 && [ "$POD_COUNT" -gt 0 ]; then
  echo -e "${GREEN}Status: Traefik deployed and configured correctly${NC}"
else
  echo -e "${YELLOW}Status: Pre-deployment validation passed${NC}"
  echo "Ready for Traefik Helm installation"
fi
