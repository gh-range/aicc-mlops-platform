# Traefik Tools Usage Guide

## Daily Operations

### Check Router Status
```bash
./tools/router-healthcheck.sh
```

### Update Router Inventory
```bash
./tools/router-scanner.sh
cp reports/router-inventory.md ../ROUTER_INVENTORY.md
git add ../ROUTER_INVENTORY.md
git commit -m "docs(traefik): update router inventory"
```

## Optional: Automated Monitoring

### Cron Job (Hourly Health Check)
```bash
# Add to crontab
0 * * * * cd /home/range/aicc-mlops-platform/infra/traefik && ./tools/router-healthcheck.sh >> /var/log/traefik-healthcheck.log 2>&1
```

### Weekly Inventory Update
```bash
# Add to crontab
0 0 * * 0 cd /home/range/aicc-mlops-platform/infra/traefik && ./tools/router-scanner.sh
```
