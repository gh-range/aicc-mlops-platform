#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "=== Validating Kubernetes manifests ==="

MANIFEST_DIRS=(
  "${PROJECT_ROOT}/infra/k3s"
  "${PROJECT_ROOT}/apps"
  "${PROJECT_ROOT}/tests"
)

EXIT_CODE=0

for DIR in "${MANIFEST_DIRS[@]}"; do
  if [[ ! -d "${DIR}" ]]; then
    echo "SKIP: Directory not found: ${DIR}"
    continue
  fi

  echo ""
  echo "Checking: ${DIR}"
  
  while IFS= read -r -d '' FILE; do
    echo "  - $(basename "${FILE}")"
    if ! kubectl apply --dry-run=client -f "${FILE}" > /dev/null 2>&1; then
      echo "    ERROR: Validation failed"
      kubectl apply --dry-run=client -f "${FILE}"
      EXIT_CODE=1
    else
      echo "    OK"
    fi
  done < <(find "${DIR}" -type f \( -name "*.yaml" -o -name "*.yml" \) -print0)
done

if [[ ${EXIT_CODE} -eq 0 ]]; then
  echo ""
  echo "=== All manifests are valid ==="
else
  echo ""
  echo "=== Some manifests have errors ==="
fi

exit ${EXIT_CODE}
