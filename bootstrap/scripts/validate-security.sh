#!/bin/bash

# K3s Security Configuration Validation
# Validates basic security configurations and best practices

set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG_PATH:-/etc/rancher/k3s/k3s.yaml}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

# Set kubeconfig
export KUBECONFIG="$KUBECONFIG_PATH"

log_info "Starting WSL2 security configuration validation..."

# Check 1: RBAC Configuration
log_info "Checking RBAC configuration..."
if kubectl auth can-i get pods --as=system:anonymous &> /dev/null; then
    log_warn "Anonymous access to pods is allowed"
else
    log_success "RBAC is properly restricting anonymous access"
fi

# Check 2: Service Account Token Auto-mounting
log_info "Checking service account token auto-mounting..."
default_sa_automount=$(kubectl get serviceaccount default -o jsonpath='{.automountServiceAccountToken}' 2>/dev/null || echo "true")
if [[ "$default_sa_automount" == "true" ]]; then
    log_warn "Default service account has automountServiceAccountToken enabled"
else
    log_success "Default service account token auto-mounting is disabled"
fi

# Check 3: Network Policies
log_info "Checking network policies..."
if kubectl get networkpolicies --all-namespaces &> /dev/null; then
    netpol_count=$(kubectl get networkpolicies --all-namespaces --no-headers | wc -l)
    if [ "$netpol_count" -gt 0 ]; then
        log_success "Network policies are configured ($netpol_count found)"
    else
        log_warn "No network policies found"
    fi
else
    log_warn "Network policies are not supported or available"
fi

# Check 4: Pod Security Standards
log_info "Checking pod security standards..."
if kubectl get podsecuritypolicy &> /dev/null; then
    psp_count=$(kubectl get podsecuritypolicy --no-headers | wc -l)
    log_success "Pod Security Policies are configured ($psp_count found)"
else
    log_warn "Pod Security Policies are not configured"
fi

# Check 5: Secrets Encryption
log_info "Checking secrets encryption..."
if ps aux | grep -q "encryption-provider-config"; then
    log_success "Secrets encryption appears to be enabled"
else
    log_warn "Secrets encryption may not be enabled"
fi

# Check 6: API Server Security
log_info "Checking API server security settings..."
if ps aux | grep kube-apiserver | grep -q "audit-log"; then
    log_success "API server audit logging is enabled"
else
    log_warn "API server audit logging is not configured"
fi

# Check 7: Kubelet Security
log_info "Checking kubelet security settings..."
if ps aux | grep kubelet | grep -q "protect-kernel-defaults"; then
    log_success "Kubelet kernel defaults protection is enabled"
else
    log_warn "Kubelet kernel defaults protection may not be enabled"
fi

# Check 8: Container Runtime Security
log_info "Checking container runtime security..."
if ps aux | grep containerd | grep -q "config"; then
    log_success "Containerd is configured with custom settings"
else
    log_warn "Containerd may be using default configuration"
fi

log_info "WSL2 security validation completed"
echo
log_info "WSL2 Security Recommendations:"
log_info "1. Network policies are optional for single-node WSL2 clusters"
log_info "2. Enable secrets encryption for sensitive data"
log_info "3. Configure audit logging for compliance requirements"
log_info "4. Regularly update K3s to latest stable version"
log_info "5. Use least-privilege RBAC policies for applications"
log_info "6. Consider WSL2 host security (Windows Defender, etc.)"
log_info "7. Backup /var/lib/rancher/k3s directory regularly"