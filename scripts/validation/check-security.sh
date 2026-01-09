#!/usr/bin/env bash
set -euo pipefail

# Ensure we use k3s kubeconfig
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=== Checking Security Configurations (k3s) ==="

echo ""
echo "1. Checking for missing resource limits..."
echo "   (Excluding kube-system and gpu-operator critical pods)"
kubectl get pods --all-namespaces -o json | \
  jq -r '.items[] | 
    select(.metadata.namespace != "kube-system") | 
    select(.spec.containers[].resources.limits == null) | 
    "\(.metadata.namespace)/\(.metadata.name)"' | \
  head -20

echo ""
echo "2. Checking for privileged containers..."
echo "   (GPU Operator requires privileged - this is expected)"
kubectl get pods --all-namespaces -o json | \
  jq -r '.items[] | 
    select(.spec.containers[]?.securityContext?.privileged == true) | 
    "\(.metadata.namespace)/\(.metadata.name): \(.spec.containers[].name)"'

echo ""
echo "3. Checking for pods running as root..."
echo "   (System pods may require root - review case by case)"
kubectl get pods --all-namespaces -o json | \
  jq -r '.items[] | 
    select(.metadata.namespace != "kube-system") |
    select(.spec.containers[]?.securityContext?.runAsUser == 0 or 
           (.spec.containers[]?.securityContext?.runAsUser // null) == null) | 
    "\(.metadata.namespace)/\(.metadata.name)"' | \
  head -20

echo ""
echo "4. Checking for hostPath volumes..."
echo "   (k3s and GPU Operator need hostPath - verify purpose)"
kubectl get pods --all-namespaces -o json | \
  jq -r '.items[] | 
    select(.spec.volumes[]?.hostPath != null) | 
    "\(.metadata.namespace)/\(.metadata.name): \(.spec.volumes[] | select(.hostPath != null) | .hostPath.path)"' | \
  sort -u

echo ""
echo "5. Checking NetworkPolicies..."
NP_COUNT=$(kubectl get networkpolicies --all-namespaces --no-headers 2>/dev/null | wc -l)
if [[ ${NP_COUNT} -eq 0 ]]; then
  echo " [!] No NetworkPolicies found (will be added later)"
else
  kubectl get networkpolicies --all-namespaces
fi

echo ""
echo "6. Checking PodSecurityStandards on namespaces..."
kubectl get namespaces -o json | \
  jq -r '.items[] | 
    "\(.metadata.name): enforce=\(.metadata.labels["pod-security.kubernetes.io/enforce"] // "none"), audit=\(.metadata.labels["pod-security.kubernetes.io/audit"] // "none")"'

echo ""
echo "7. k3s specific: Checking node taints and labels..."
kubectl get nodes -o json | \
  jq -r '.items[] | 
    "Node: \(.metadata.name)\nTaints: \(.spec.taints // [])\nGPU: \(.status.allocatable["nvidia.com/gpu"] // "none")\n"'

echo ""
echo "8. Checking resource quotas..."
RQ_COUNT=$(kubectl get resourcequotas --all-namespaces --no-headers 2>/dev/null | wc -l)
if [[ ${RQ_COUNT} -eq 0 ]]; then
  echo " [x] No ResourceQuotas found (will be added later)"
else
  kubectl get resourcequotas --all-namespaces
fi

echo ""
echo "=== Security check completed ==="
echo ""
echo "Summary:"
echo "- k3s runs many system components as privileged (normal)"
echo "- GPU Operator REQUIRES privileged and hostPath access"
echo "- NetworkPolicies and PSS will be configured in subsequent task"
echo "- Review privileged pods outside kube-system and gpu-operator namespaces"
