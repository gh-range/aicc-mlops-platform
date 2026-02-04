#!/bin/bash
set -e

echo "=== Traefik Dashboard Secret Generator ==="
echo ""

# Check if htpasswd is installed
if ! command -v htpasswd &> /dev/null; then
  echo "Error: htpasswd not found. Install with:"
  echo "  sudo apt-get install -y apache2-utils"
  exit 1
fi

# Prompt for password
read -s -p "Enter dashboard password: " PASSWORD
echo ""
read -s -p "Confirm password: " PASSWORD_CONFIRM
echo ""

if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
  echo "Error: Passwords do not match"
  exit 1
fi

# Generate htpasswd and encode
AUTH_BASE64=$(htpasswd -nb admin "$PASSWORD" | base64 -w 0)

# Create secret file
cat > dashboard-auth-secret.yaml <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: traefik-dashboard-auth
  namespace: traefik-system
  labels:
    app.kubernetes.io/name: traefik
    app.kubernetes.io/component: dashboard-auth
type: Opaque
data:
  users: ${AUTH_BASE64}
YAML

echo ""
echo "[o] Secret generated: dashboard-auth-secret.yaml"
echo ""
echo "Apply with:"
echo "  kubectl apply -f dashboard-auth-secret.yaml"
echo ""
echo "[!] WARNING: Do NOT commit this file to Git!
