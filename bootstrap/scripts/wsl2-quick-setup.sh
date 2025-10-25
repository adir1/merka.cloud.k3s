#!/bin/bash

# WSL2 K3s Quick Setup Script
# Optimized one-command setup for Debian WSL2 single-node cluster

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Check if running in WSL2
check_wsl2() {
    if ! grep -qi microsoft /proc/version; then
        log_error "This script is designed for WSL2 environment"
        exit 1
    fi
    log_success "WSL2 environment detected"
}

# Install prerequisites
install_prerequisites() {
    log_info "Installing prerequisites for WSL2..."
    
    # Update package list
    apt update
    
    # Install required packages
    apt install -y curl wget python3 python3-yaml
    
    log_success "Prerequisites installed"
}

# Setup K3s directories
setup_directories() {
    log_info "Setting up K3s directories..."
    
    mkdir -p /var/lib/rancher/k3s
    mkdir -p /var/log
    mkdir -p /opt/k3s
    
    # Set permissions
    chmod 755 /var/lib/rancher/k3s
    chmod 755 /opt/k3s
    
    log_success "K3s directories created"
}

# Main setup function
main() {
    log_info "Starting WSL2 K3s quick setup..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        log_info "Run: sudo $0"
        exit 1
    fi
    
    check_wsl2
    install_prerequisites
    setup_directories
    
    log_success "WSL2 setup completed!"
    echo
    log_info "Next steps:"
    log_info "1. Install K3s: sudo ${SCRIPT_DIR}/install-k3s.sh -c development.yaml"
    log_info "2. Exit sudo session and return to your user account"
    log_info "3. Validate installation: ${SCRIPT_DIR}/post-install.sh"
    log_info "4. Quick check: ${SCRIPT_DIR}/check-cluster-ready.sh"
    echo
    log_info "Available configurations:"
    log_info "- development.yaml  (ultra-lightweight for dev)"
    log_info "- staging.yaml      (balanced for testing)"
    log_info "- production.yaml   (optimized for production)"
    echo
    log_info "Kubeconfig will be automatically copied to:"
    log_info "- ~/.kube/config (for regular user access)"
    log_info "- /opt/k3s/kubeconfig (backup location)"
    log_info "- /etc/rancher/k3s/k3s.yaml (K3s default)"
}

main "$@"