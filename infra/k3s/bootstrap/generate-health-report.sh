#!/bin/bash

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

REPORT_FILE="docs/runbooks/cluster-health-report-$(date +%Y%m%d-%H%M%S).md"

echo "=========================================="
echo "Generating Complete Cluster Health Report"
echo "=========================================="
echo ""

# Create report header
cat > $REPORT_FILE << 'HEADER'
# Cluster Health Report

**Report Type**: Complete System Health Check  
**Generated**: $(date '+%Y-%m-%d %H:%M:%S %Z')  
**Cluster**: k3s Single-Node HA  
**Purpose**: Verify cluster readiness for production workloads

---

## Executive Summary

HEADER

# Run all health checks and capture results
echo "[*] Running comprehensive health checks..."
echo ""

# 1. Basic health check
echo "[*] Part 1: Basic Health Check"
BASIC_RESULT=0
if sudo ./infra/k3s/bootstrap/cluster-health-check.sh &>/tmp/basic-health.log; then
  BASIC_RESULT=1
  echo "[o] Basic health check passed"
else
  echo "[x] Basic health check failed"
fi
echo ""

# 2. Network validation
echo "[*] Part 2: Network Validation"
NETWORK_RESULT=0
# Run network test with auto-cleanup
echo "yes" | ./infra/k3s/bootstrap/network-validation.sh &>/tmp/network-health.log
if [ $? -eq 0 ]; then
  NETWORK_RESULT=1
  echo "[o] Network validation passed"
else
  echo "[x] Network validation failed"
fi
echo ""

# 3. Storage validation
echo "[*] Part 3: Storage Validation"
STORAGE_RESULT=0
# Run storage test with auto-cleanup
echo "yes" | sudo ./infra/k3s/bootstrap/storage-validation.sh &>/tmp/storage-health.log
if [ $? -eq 0 ]; then
  STORAGE_RESULT=1
  echo "[o] Storage validation passed"
else
  echo "[x] Storage validation failed"
fi
echo ""

# Calculate overall status
TOTAL_CHECKS=3
PASSED_CHECKS=$((BASIC_RESULT + NETWORK_RESULT + STORAGE_RESULT))

# Append summary to report
cat >> $REPORT_FILE << SUMMARY

### Overall Status

| Component | Status |
|-----------|--------|
| Basic Health | $([ $BASIC_RESULT -eq 1 ] && echo "PASS" || echo "FAIL") |
| Network | $([ $NETWORK_RESULT -eq 1 ] && echo "PASS" || echo "FAIL") |
| Storage | $([ $STORAGE_RESULT -eq 1 ] && echo "PASS" || echo "FAIL") |

**Result**: $PASSED_CHECKS / $TOTAL_CHECKS checks passed

$([ $PASSED_CHECKS -eq $TOTAL_CHECKS ] && echo "**Status**: HEALTHY - Cluster is ready for production workloads" || echo "**Status**: UNHEALTHY - Issues detected, review details below")

---

## System Information

### Hardware

SUMMARY

# Collect system information
cat >> $REPORT_FILE << SYSINFO
- **Hostname**: $(hostname)
- **OS**: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
- **Kernel**: $(uname -r)
- **CPU**: $(lscpu | grep "Model name" | cut -d: -f2 | xargs)
- **CPU Cores**: $(nproc)
- **Memory**: $(free -h | awk '/^Mem:/ {print $2}')
- **GPU**: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo "Not available")

### Software Versions

- **k3s**: $(k3s --version | head -1)
- **kubectl**: $(kubectl version --client --short 2>/dev/null | head -1)
- **Helm**: $(helm version --short)
- **NVIDIA Driver**: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null || echo "Not available")
- **CUDA**: $(nvcc --version 2>/dev/null | grep release | awk '{print $5}' | sed 's/,//' || echo "Not available")

---

## Detailed Results

### 1. Basic Health Check

\`\`\`
$(tail -50 /tmp/basic-health.log 2>/dev/null || echo "Log not available")
\`\`\`

### 2. Network Validation

\`\`\`
$(tail -50 /tmp/network-health.log 2>/dev/null || echo "Log not available")
\`\`\`

### 3. Storage Validation

\`\`\`
$(tail -50 /tmp/storage-health.log 2>/dev/null || echo "Log not available")
\`\`\`

---

## Current Cluster State

### Nodes

\`\`\`
$(kubectl get nodes -o wide)
\`\`\`

### System Pods

\`\`\`
$(kubectl get pods -n kube-system -o wide)
\`\`\`

### Storage Classes

\`\`\`
$(kubectl get storageclass)
\`\`\`

### Persistent Volumes

\`\`\`
$(kubectl get pv 2>/dev/null || echo "No PVs currently")
\`\`\`

### Resource Usage

\`\`\`
Memory:
$(free -h)

Disk:
$(df -h / /var/lib/rancher/k3s)
\`\`\`

---

## etcd Status

\`\`\`
Data Directory: /var/lib/rancher/k3s/server/db/etcd
Size: $(sudo du -sh /var/lib/rancher/k3s/server/db/etcd 2>/dev/null | cut -f1)

Recent Snapshots:
$(sudo k3s etcd-snapshot ls 2>/dev/null | tail -5 || echo "No snapshots available")
\`\`\`

---

## Recent Events

\`\`\`
$(kubectl get events -A --sort-by='.lastTimestamp' | tail -20)
\`\`\`

---

## Component Health Summary

### API Server
- **Status**: $(kubectl cluster-info --request-timeout=5s &>/dev/null && echo "Healthy" || echo "Unhealthy")
- **Endpoint**: $(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

### etcd
- **Type**: Embedded
- **Status**: $([ -d "/var/lib/rancher/k3s/server/db/etcd" ] && echo "Running" || echo "Not found")
- **Backup**: $([ $(sudo k3s etcd-snapshot ls 2>/dev/null | tail -n +2 | wc -l) -gt 0 ] && echo "Snapshots available" || echo "No snapshots")

### CoreDNS
- **Status**: $(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers | grep -q Running && echo "Running" || echo "Not running")
- **Replicas**: $(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers | wc -l)

### local-path-provisioner
- **Status**: $(kubectl get pods -n kube-system -l app=local-path-provisioner --no-headers | grep -q Running && echo "Running" || echo "Not running")

### metrics-server
- **Status**: $(kubectl get pods -n kube-system | grep metrics-server | grep -q Running && echo "Running" || echo "Not running")

---

## Security Status

### Pod Security Standards
\`\`\`
$(kubectl get namespaces -o json | grep -i podsecurity || echo "Not configured")
\`\`\`

### Network Policies
\`\`\`
Total policies: $(kubectl get networkpolicies -A --no-headers 2>/dev/null | wc -l)
$(kubectl get networkpolicies -A 2>/dev/null || echo "No network policies defined")
\`\`\`

---

## Recommendations

SYSINFO

# Add recommendations based on results
if [ $PASSED_CHECKS -eq $TOTAL_CHECKS ]; then
  cat >> $REPORT_FILE << 'RECO'
### All Checks Passed

The cluster is healthy and ready for:
- [ ] GPU Operator installation
- [ ] Production workload deployment
- [ ] Monitoring stack installation (Prometheus/Grafana)
- [ ] GitOps setup (ArgoCD)

### Next Steps

1. Proceed to NVIDIA GPU Operator deployment
2. Configure automatic etcd snapshots if not already done
3. Set up off-site backup for etcd snapshots
4. Document any custom configurations

RECO
else
  cat >> $REPORT_FILE << 'RECO'
### Issues Detected

Please review the detailed results above and address any failures before proceeding.

### Troubleshooting Steps

1. Review failed component logs:
   - Basic: `sudo journalctl -u k3s -n 100`
   - Network: `kubectl logs -n kube-system -l k8s-app=kube-dns`
   - Storage: `kubectl logs -n kube-system -l app=local-path-provisioner`

2. Check system resources:
   - Disk space: `df -h`
   - Memory: `free -h`
   - Processes: `top`

3. Restart k3s if needed:
   - `sudo systemctl restart k3s`
   - Wait 30 seconds and re-run health checks

RECO
fi

# Add footer
cat >> $REPORT_FILE << 'FOOTER'

---

## Report Metadata

- **Report File**: `$(basename $REPORT_FILE)`
- **Generated By**: Infrastructure Lead
- **Validation Scripts**:
  - `infra/k3s/bootstrap/cluster-health-check.sh`
  - `infra/k3s/bootstrap/network-validation.sh`
  - `infra/k3s/bootstrap/storage-validation.sh`

---

**End of Report**
FOOTER

# Cleanup temp logs
rm -f /tmp/basic-health.log /tmp/network-health.log /tmp/storage-health.log

echo ""
echo "=========================================="
echo "Report Generation Complete"
echo "=========================================="
echo ""
echo "Report saved to: $REPORT_FILE"
echo ""

# Display summary
echo "Summary:"
echo "--------"
echo "Basic Health:   $([ $BASIC_RESULT -eq 1 ] && echo '[o] PASS' || echo '[x] FAIL')"
echo "Network:        $([ $NETWORK_RESULT -eq 1 ] && echo '[o] PASS' || echo '[x] FAIL')"
echo "Storage:        $([ $STORAGE_RESULT -eq 1 ] && echo '[o] PASS' || echo '[x] FAIL')"
echo ""
echo "Overall:        $PASSED_CHECKS / $TOTAL_CHECKS checks passed"
echo ""

if [ $PASSED_CHECKS -eq $TOTAL_CHECKS ]; then
  echo "[o] Cluster is HEALTHY"
else
  echo "[x] Cluster has ISSUES"
  echo ""
  echo "Please review the report and fix issues before proceeding"
fi

echo ""
echo "To view the report:"
echo "  cat $REPORT_FILE"
echo ""
echo "=========================================="

# Return exit code based on results
if [ $PASSED_CHECKS -eq $TOTAL_CHECKS ]; then
  exit 0
else
  exit 1
fi
