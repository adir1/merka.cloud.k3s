#!/bin/bash

# Setup Kubeconfig Script
# Copies K3s kubeconfig to user's home directory for easier access

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Setup kubeconfig for easier kubectl access without sudo.

OPTIONS:
    -s, --source PATH      Source kubeconfig path (default: /etc/rancher/k3s/k3s.yaml)
    -d, --dest PATH        Destination path (default: ~/.kube/config)
    -b, --backup           Create backup in WSL2 persistent storage
    -h, --help             Show this help message

EXAMPLES:
    $0                     # Copy with defaults
    $0 -b                  # Copy with WSL2 backup
    $0 -s /custom/path     # Copy from custom source

EOF
}

# Default values
SOURCE_PATH="/etc/rancher/k3s/k3s.yaml"
DEST_PATH="$HOME/.kube/config"
CREATE_BACKUP=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--source)
            SOURCE_PATH="$2"
            shift 2
            ;;
        -d|--dest)
            DEST_PATH="$2"
            shift 2
            ;;
        -b|--backup)
            CREATE_BACKUP=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main setup function
main() {
    log_info "Setting up kubeconfig for easier kubectl access..."
    
    # Check if source exists
    if [[ ! -f "$SOURCE_PATH" ]]; then
        log_error "Source kubeconfig not found: $SOURCE_PATH"
        log_info "Make sure K3s is installed and running"
        exit 1
    fi
    
    # Check if we can read the source
    if [[ ! -r "$SOURCE_PATH" ]]; then
        log_error "Cannot read source kubeconfig: $SOURCE_PATH"
        log_info "You may need to run this script with sudo or fix permissions"
        exit 1
    fi
    
    # Create destination directory
    local dest_dir=$(dirname "$DEST_PATH")
    mkdir -p "$dest_dir"
    
    # Copy kubeconfig
    log_info "Copying kubeconfig from $SOURCE_PATH to $DEST_PATH"
    
    if cp "$SOURCE_PATH" "$DEST_PATH"; then
        chmod 600 "$DEST_PATH"
        log_success "Kubeconfig copied successfully"
    else
        log_error "Failed to copy kubeconfig"
        exit 1
    fi
    
    # Create backup if requested
    if [[ "$CREATE_BACKUP" == "true" ]]; then
        mkdir -p /opt/k3s
        local backup_path="/opt/k3s/kubeconfig"
        log_info "Creating backup at $backup_path"
        
        if cp "$SOURCE_PATH" "$backup_path"; then
            chmod 600 "$backup_path"
            log_success "Backup created"
        else
            log_warn "Failed to create backup"
        fi
    fi
    
    # Test kubectl access
    log_info "Testing kubectl access..."
    export KUBECONFIG="$DEST_PATH"
    
    if kubectl cluster-info &> /dev/null; then
        log_success "kubectl is working with the new kubeconfig!"
        
        # Show cluster info
        echo
        log_info "Cluster information:"
        kubectl get nodes -o wide 2>/dev/null || log_warn "Could not get node information"
        
    else
        log_warn "kubectl test failed - cluster may not be ready yet"
    fi
    
    echo
    log_success "Kubeconfig setup completed!"
    log_info "You can now use kubectl without sudo:"
    log_info "  kubectl get nodes"
    log_info "  kubectl get pods --all-namespaces"
    echo
    log_info "Kubeconfig location: $DEST_PATH"
    if [[ "$CREATE_BACKUP" == "true" ]]; then
        log_info "Backup location: /opt/k3s/kubeconfig"
    fi
}

main "$@"