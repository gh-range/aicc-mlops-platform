# Traefik Management Tools

Collection of scripts for managing and monitoring Traefik IngressRoutes.

## Available Scripts

### router-scanner.sh

Scans all IngressRoutes across namespaces and generates inventory reports.

**Usage:**
```bash
./router-scanner.sh [--json|--markdown|--both]
```

**Output:**
- `../reports/router-inventory.json` - Machine-readable JSON format
- `../reports/router-inventory.md` - Human-readable Markdown table

**Example:**
```bash
# Generate both formats (default)
./router-scanner.sh

# Generate only JSON
./router-scanner.sh --json

# Custom output directory
OUTPUT_DIR=/tmp/reports ./router-scanner.sh
```

**Information Captured:**
- Router name and namespace
- Host (domain)
- Backend service (name, namespace, port)
- Service endpoint status
- TLS configuration
- Middleware chain

**Requirements:**
- `kubectl` configured with cluster access
- `jq` for JSON processing
- Bash 4.0+

---

## Adding New Tools

When adding new scripts:
1. Use `#!/bin/bash` shebang with `set -euo pipefail`
2. Add usage documentation in script header
3. Make executable: `chmod +x <script-name>.sh`
4. Update this README with script description
5. Follow English-only naming and comments

---

**Part of**: AI Computing Center MLOps Platform
**Managed by**: Range
**Last Updated**: 2026-02-05

