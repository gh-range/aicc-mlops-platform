## Dashboard Authentication Setup

### Generate Secret

```bash
cd ~/aicc-mlops-platform/infra/traefik/configs/middlewares

# Run generator script
./generate-dashboard-secret.sh

# Apply to cluster
kubectl apply -f dashboard-auth-secret.yaml
```

### Manual Generation

```bash
# Set your password
DASHBOARD_PASSWORD="your-secure-password"

# Generate and apply
kubectl create secret generic traefik-dashboard-auth \
  --from-literal=users=$(htpasswd -nb admin "$DASHBOARD_PASSWORD") \
  --namespace traefik-system
```

### Security Notes

[!] **IMPORTANT**: 
- `dashboard-auth-secret.yaml` is in `.gitignore`
- Never commit actual secrets to Git
- Use strong passwords in production
- Rotate credentials regularly
