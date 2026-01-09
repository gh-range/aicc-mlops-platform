#!/bin/bash

echo "=========================================="
echo "kubectl & Helm Shell Environment Setup"
echo "=========================================="
echo ""

BASHRC="$HOME/.bashrc"
BACKUP="$HOME/.bashrc.backup-$(date +%Y%m%d-%H%M%S)"

# Backup existing .bashrc
echo "[*] Step 1: Backup current .bashrc"
cp $BASHRC $BACKUP
echo "[o] Backup created: $BACKUP"
echo ""

# 1. KUBECONFIG environment variable
echo "[*] Step 2: Configure KUBECONFIG"
if grep -q "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" $BASHRC; then
  echo "[!] KUBECONFIG already configured in .bashrc"
else
  cat >> $BASHRC << 'KUBECONFIG_SETUP'

# k3s kubectl configuration
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
KUBECONFIG_SETUP
  echo "[o] KUBECONFIG added to .bashrc"
fi
echo ""

# 2. kubectl bash completion
echo "[*] Step 3: Configure kubectl bash completion"
if grep -q "kubectl completion bash" $BASHRC; then
  echo "[!] kubectl completion already configured"
else
  cat >> $BASHRC << 'KUBECTL_COMPLETION'

# kubectl bash completion
source <(kubectl completion bash)
alias k=kubectl
complete -F __start_kubectl k
KUBECTL_COMPLETION
  echo "[o] kubectl completion added to .bashrc"
fi
echo ""

# 3. Helm bash completion
echo "[*] Step 4: Configure Helm bash completion"
if grep -q "helm completion bash" $BASHRC; then
  echo "[!] Helm completion already configured"
else
  cat >> $BASHRC << 'HELM_COMPLETION'

# Helm bash completion
source <(helm completion bash)
HELM_COMPLETION
  echo "[o] Helm completion added to .bashrc"
fi
echo ""

# 4. Useful kubectl aliases
echo "[*] Step 5: Add kubectl aliases"
if grep -q "# kubectl aliases" $BASHRC; then
  echo "[!] kubectl aliases already configured"
else
  cat >> $BASHRC << 'KUBECTL_ALIASES'

# kubectl aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
alias kga='kubectl get all'
alias kgpa='kubectl get pods -A'
alias kdp='kubectl describe pod'
alias kds='kubectl describe svc'
alias kdn='kubectl describe node'
alias kl='kubectl logs'
alias klf='kubectl logs -f'
alias kex='kubectl exec -it'
alias kctx='kubectl config current-context'
alias kns='kubectl config set-context --current --namespace'
KUBECTL_ALIASES
  echo "[o] kubectl aliases added to .bashrc"
fi
echo ""

# 5. Helm aliases
echo "[*] Step 6: Add Helm aliases"
if grep -q "# Helm aliases" $BASHRC; then
  echo "[!] Helm aliases already configured"
else
  cat >> $BASHRC << 'HELM_ALIASES'

# Helm aliases
alias h='helm'
alias hls='helm list -A'
alias hs='helm search repo'
alias hi='helm install'
alias hu='helm upgrade'
alias hd='helm delete'
alias hg='helm get'
HELM_ALIASES
  echo "[o] Helm aliases added to .bashrc"
fi
echo ""

# 6. k3s specific aliases
echo "[*] Step 7: Add k3s specific aliases"
if grep -q "# k3s aliases" $BASHRC; then
  echo "[!] k3s aliases already configured"
else
  cat >> $BASHRC << 'K3S_ALIASES'

# k3s aliases
alias k3s-status='sudo systemctl status k3s'
alias k3s-logs='sudo journalctl -u k3s -f'
alias k3s-restart='sudo systemctl restart k3s'
alias k3s-stop='sudo systemctl stop k3s'
alias k3s-start='sudo systemctl start k3s'
alias k3s-snap='sudo k3s etcd-snapshot save --name'
alias k3s-snap-ls='sudo k3s etcd-snapshot ls'
K3S_ALIASES
  echo "[o] k3s aliases added to .bashrc"
fi
echo ""

# 7. Useful functions
echo "[*] Step 8: Add utility functions"
if grep -q "# kubectl utility functions" $BASHRC; then
  echo "[!] Utility functions already configured"
else
  cat >> $BASHRC << 'KUBECTL_FUNCTIONS'

# kubectl utility functions
# Get pod by partial name
kgpn() {
  kubectl get pods -A | grep -i "$1"
}

# Get logs by pod partial name
kln() {
  POD=$(kubectl get pods -A --no-headers | grep -i "$1" | head -1 | awk '{print $2}')
  NS=$(kubectl get pods -A --no-headers | grep -i "$1" | head -1 | awk '{print $1}')
  if [ -n "$POD" ]; then
    kubectl logs -n $NS $POD
  else
    echo "Pod not found matching: $1"
  fi
}

# Exec into pod by partial name
kexn() {
  POD=$(kubectl get pods -A --no-headers | grep -i "$1" | head -1 | awk '{print $2}')
  NS=$(kubectl get pods -A --no-headers | grep -i "$1" | head -1 | awk '{print $1}')
  if [ -n "$POD" ]; then
    kubectl exec -it -n $NS $POD -- /bin/sh
  else
    echo "Pod not found matching: $1"
  fi
}
KUBECTL_FUNCTIONS
  echo "[o] Utility functions added to .bashrc"
fi
echo ""

# 8. PS1 customization with kubectl context (optional)
echo "[*] Step 9: Add kubectl context to prompt (optional)"
read -p "Do you want to show kubectl context in PS1 prompt? (yes/no): " ADD_PS1
if [ "$ADD_PS1" = "yes" ]; then
  if grep -q "# kubectl context in PS1" $BASHRC; then
    echo "[!] PS1 customization already configured"
  else
    cat >> $BASHRC << 'PS1_CUSTOM'

# kubectl context in PS1
kube_ps1() {
  if [ -n "$KUBECONFIG" ]; then
    CTX=$(kubectl config current-context 2>/dev/null)
    if [ -n "$CTX" ]; then
      echo " [k8s:$CTX]"
    fi
  fi
}
PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w$(kube_ps1)\$ '
PS1_CUSTOM
    echo "[o] PS1 customization added"
  fi
else
  echo "[!] Skipping PS1 customization"
fi
echo ""

# Summary
echo "=========================================="
echo "Configuration Summary"
echo "=========================================="
echo ""
echo "[o] KUBECONFIG environment variable configured"
echo "[o] kubectl bash completion enabled"
echo "[o] Helm bash completion enabled"
echo "[o] kubectl aliases added (k, kgp, kgs, etc.)"
echo "[o] Helm aliases added (h, hls, hs, etc.)"
echo "[o] k3s aliases added (k3s-status, k3s-logs, etc.)"
echo "[o] Utility functions added (kgpn, kln, kexn)"
echo ""
echo "To apply changes immediately:"
echo "  source ~/.bashrc"
echo ""
echo "Available aliases:"
echo "  k           - kubectl"
echo "  kgp         - kubectl get pods"
echo "  kgpa        - kubectl get pods -A"
echo "  h           - helm"
echo "  hls         - helm list -A"
echo "  k3s-status  - systemctl status k3s"
echo "  k3s-logs    - journalctl -u k3s -f"
echo ""
echo "Available functions:"
echo "  kgpn <name> - Get pods by partial name"
echo "  kln <name>  - Get logs by pod partial name"
echo "  kexn <name> - Exec into pod by partial name"
echo ""
echo "=========================================="

