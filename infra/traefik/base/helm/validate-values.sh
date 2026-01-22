#!/bin/bash
set -e

echo "=== Traefik values.yaml Validation ==="
echo ""

VALUES_FILE="$(dirname $0)/values.yaml"

# Check 1: YAML syntax
echo "[1/5] Validating YAML syntax..."
if command -v yamllint >/dev/null 2>&1; then
  if yamllint -d "{extends: default, rules: {line-length: {max: 120}}}" "$VALUES_FILE" 2>/dev/null; then
    echo "[o] YAML syntax valid"
  else
    echo "[x] YAML syntax errors found"
    exit 1
  fi
else
  echo "[!] yamllint not installed, skipping syntax check"
fi
# Check 2: Helm template dry-run
echo "[2/5] Testing Helm template rendering..."
if helm template traefik traefik/traefik \
  --version 38.0.2 \
  --namespace traefik-system \
  -f "$VALUES_FILE" \
  --dry-run > /dev/null 2>&1; then
  echo "[o] Helm template renders successfully"
else
  echo "[x] Helm template rendering failed"
  exit 1
fi

# Check 3: Verify critical configurations
echo "[3/5] Checking critical configuration values..."

# Check DaemonSet
if grep -q "kind: DaemonSet" "$VALUES_FILE"; then
  echo "[o] Deployment kind: DaemonSet"
else
  echo "[x] Deployment kind not set to DaemonSet"
  exit 1
fi

# Check HostPort
if grep -q "hostPort: 80" "$VALUES_FILE" && grep -q "hostPort: 443" "$VALUES_FILE"; then
  echo "[o] HostPort 80/443 configured"
else
  echo "[x] HostPort not configured"
  exit 1
fi

# Check Resources
if grep -A 5 "resources:" "$VALUES_FILE" | grep -q "requests:"; then
  echo "[o] Resource requests defined"
else
  echo "[x] Resource requests missing"
  exit 1
fi

# Check 4: Security validations
echo "[4/5] Validating security settings..."

if grep -q "runAsNonRoot: true" "$VALUES_FILE"; then
  echo "[o] Running as non-root user"
else
  echo "[!] Running as root (security risk)"
fi

# Check 5: Observability
echo "[5/5] Checking observability configuration..."

if grep -A 3 "prometheus:" "$VALUES_FILE" | grep -q "enabled: true"; then
  echo "[o] Prometheus metrics enabled"
else
  echo "[!] Prometheus metrics disabled"
fi

echo ""
echo "=== Validation Complete ==="
echo "Status: READY for deployment"
