#!/bin/bash
#
# Traefik IngressRoute Scanner
# Scans all IngressRoutes across namespaces and generates inventory reports
#
# Usage:
#   ./router-scanner.sh [--json|--markdown|--both]
#   Default: --both
#
# Output:
#   - router-inventory.json
#   - router-inventory.md

set -euo pipefail

# Configuration
OUTPUT_DIR="${OUTPUT_DIR:-./reports}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S %Z')
JSON_OUTPUT="${OUTPUT_DIR}/router-inventory.json"
MD_OUTPUT="${OUTPUT_DIR}/router-inventory.md"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
FORMAT="${1:---both}"

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Initialize JSON array
echo "[" > "${JSON_OUTPUT}"
FIRST_ENTRY=true

# Initialize Markdown report
cat > "${MD_OUTPUT}" << 'MDHEADER'
# Traefik IngressRoute Inventory

**Generated**: TIMESTAMP_PLACEHOLDER

## Summary

MDHEADER

# Replace timestamp
sed -i "s|TIMESTAMP_PLACEHOLDER|${TIMESTAMP}|g" "${MD_OUTPUT}"

# Scan all IngressRoutes
log_info "Scanning IngressRoutes across all namespaces..."

ROUTER_COUNT=0
NAMESPACES=$(kubectl get ingressroute --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\n"}{end}' | sort -u)

for NS in $NAMESPACES; do
    ROUTERS=$(kubectl get ingressroute -n "$NS" -o name 2>/dev/null || true)
    
    for ROUTER in $ROUTERS; do
        ROUTER_NAME=$(echo "$ROUTER" | cut -d'/' -f2)
        
        log_info "Processing: ${NS}/${ROUTER_NAME}"
        
        # Extract router details
        YAML=$(kubectl get ingressroute "$ROUTER_NAME" -n "$NS" -o yaml)
        
        # Parse fields using kubectl jsonpath
        HOST=$(kubectl get ingressroute "$ROUTER_NAME" -n "$NS" -o jsonpath='{.spec.routes[0].match}' | grep -oP "Host\(\`\K[^\`]+")
        ENTRYPOINTS=$(kubectl get ingressroute "$ROUTER_NAME" -n "$NS" -o jsonpath='{.spec.entryPoints[*]}')
        TLS_SECRET=$(kubectl get ingressroute "$ROUTER_NAME" -n "$NS" -o jsonpath='{.spec.tls.secretName}')
        TLS_OPTIONS=$(kubectl get ingressroute "$ROUTER_NAME" -n "$NS" -o jsonpath='{.spec.tls.options.name}')
        
        # Backend service info
        BACKEND_NAME=$(kubectl get ingressroute "$ROUTER_NAME" -n "$NS" -o jsonpath='{.spec.routes[0].services[0].name}')
        BACKEND_NS=$(kubectl get ingressroute "$ROUTER_NAME" -n "$NS" -o jsonpath='{.spec.routes[0].services[0].namespace}')
        BACKEND_PORT=$(kubectl get ingressroute "$ROUTER_NAME" -n "$NS" -o jsonpath='{.spec.routes[0].services[0].port}')
        
        # If backend namespace not specified, same as IngressRoute namespace
        BACKEND_NS=${BACKEND_NS:-$NS}
        
        # Middleware chain
        MIDDLEWARES=$(kubectl get ingressroute "$ROUTER_NAME" -n "$NS" -o jsonpath='{.spec.routes[0].middlewares[*].name}' | tr ' ' ',')
        
        # Check backend service status
        if [ "$BACKEND_NAME" != "api@internal" ]; then
            if kubectl get svc "$BACKEND_NAME" -n "$BACKEND_NS" >/dev/null 2>&1; then
                ENDPOINTS=$(kubectl get endpoints "$BACKEND_NAME" -n "$BACKEND_NS" -o jsonpath='{.subsets[0].addresses[*].ip}' | wc -w)
                if [ "$ENDPOINTS" -gt 0 ]; then
                    STATUS="Ready"
                else
                    STATUS="NoEndpoints"
                fi
            else
                STATUS="ServiceNotFound"
            fi
        else
            STATUS="Internal"
        fi
        
        # Build JSON entry
        if [ "$FIRST_ENTRY" = false ]; then
            echo "," >> "${JSON_OUTPUT}"
        fi
        FIRST_ENTRY=false
        
        cat >> "${JSON_OUTPUT}" << JSONENTRY
  {
    "name": "${ROUTER_NAME}",
    "namespace": "${NS}",
    "host": "${HOST}",
    "entryPoints": "${ENTRYPOINTS}",
    "backend": {
      "service": "${BACKEND_NAME}",
      "namespace": "${BACKEND_NS}",
      "port": "${BACKEND_PORT}",
      "status": "${STATUS}"
    },
    "tls": {
      "secretName": "${TLS_SECRET}",
      "options": "${TLS_OPTIONS}"
    },
    "middlewares": "${MIDDLEWARES}"
  }
JSONENTRY
        
        ROUTER_COUNT=$((ROUTER_COUNT + 1))
    done
done

# Close JSON array
echo "" >> "${JSON_OUTPUT}"
echo "]" >> "${JSON_OUTPUT}"

log_info "Found ${ROUTER_COUNT} IngressRoutes"

# Generate Markdown table from JSON
cat >> "${MD_OUTPUT}" << MDSUMMARY
- **Total Routers**: ${ROUTER_COUNT}
- **Namespaces**: $(echo "$NAMESPACES" | wc -l)
- **TLS Certificate**: mlops-work-wildcard-tls (shared)

---

## Router Details

| Router Name | Host | Backend Service | Backend NS | Port | Status | Middlewares |
|-------------|------|-----------------|------------|------|--------|-------------|
MDSUMMARY

# Parse JSON and append to Markdown
jq -r '.[] | "| \(.name) | \(.host) | \(.backend.service) | \(.backend.namespace) | \(.backend.port) | \(.backend.status) | \(.middlewares) |"' "${JSON_OUTPUT}" >> "${MD_OUTPUT}"

cat >> "${MD_OUTPUT}" << 'MDFOOTER'

---

## TLS Configuration

All routers use the same wildcard certificate:
- **Secret Name**: mlops-work-wildcard-tls
- **Secret Namespace**: traefik-system
- **TLS Options**: enterprise-tls-policy
- **Certificate Issuer**: Let's Encrypt R13
- **Valid For**: *.mlops.work

## Status Legend

- **Ready**: Service exists with active endpoints
- **NoEndpoints**: Service exists but no Pods available
- **ServiceNotFound**: Backend service does not exist
- **Internal**: Traefik internal service (api@internal)

---

**Report Location**: 
- JSON: `router-inventory.json`
- Markdown: `router-inventory.md`

**Regenerate**: 
```bash
./tools/router-scanner.sh
```
MDFOOTER

# Output results
log_info "Reports generated:"
log_info "  - JSON: ${JSON_OUTPUT}"
log_info "  - Markdown: ${MD_OUTPUT}"

# Display quick summary
echo ""
echo "=== Quick Summary ==="
jq -r '.[] | "\(.host) -> \(.backend.service).\(.backend.namespace):\(.backend.port) [\(.backend.status)]"' "${JSON_OUTPUT}"

exit 0
