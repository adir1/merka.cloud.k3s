#!/bin/bash

# K3s Cluster Installation Script
# This script automates the installation and configuration of a K3s cluster
# with parameter handling, error checking, and comprehensive logging

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/../configs"
LOG_FILE="/tmp/k3s-install-$(date +%Y%m%d-%H%M%S).log"

# Default configuration values
K3S_VERSION="${K3S_VERSION:-latest}"
CLUSTER_NAME="${CLUSTER_NAME:-k3s-cluster}"
CONFIG_FILE="${CONFIG_FILE:-${CONFIG_DIR}/cluster-config.yaml}"
NODE_TYPE="${NODE_TYPE:-server}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-/etc/rancher/k3s/k3s.yaml}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"
}

log_info() {
    log "INFO" "${BLUE}$*${NC}"
}

log_warn() {
    log "WARN" "${YELLOW}$*${NC}"
}

log_error() {
    log "ERROR" "${RED}$*${NC}"
}

log_success() {
    log "SUCCESS" "${GREEN}$*${NC}"
}

# Error handling
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_error "Installation failed with exit code $exit_code"
        log_error "Check log file: $LOG_FILE"
    fi
    exit $exit_code
}

trap cleanup EXIT

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Install and configure a K3s cluster with comprehensive validation and logging.

OPTIONS:
    -v, --version VERSION       K3s version to install (default: latest)
    -n, --name NAME            Cluster name (default: k3s-cluster)
    -c, --config FILE          Configuration file path (default: ../configs/cluster-config.yaml)
    -t, --type TYPE            Node type: server or agent (default: server)
    -k, --kubeconfig PATH      Kubeconfig output path (default: /etc/rancher/k3s/k3s.yaml)
    -h, --help                 Show this help message

EXAMPLES:
    $0                         # Install with defaults
    $0 -v v1.28.3+k3s1        # Install specific version
    $0 -n production -t server # Install server node for production cluster

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--version)
                K3S_VERSION="$2"
                shift 2
                ;;
            -n|--name)
                CLUSTER_NAME="$2"
                shift 2
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -t|--type)
                NODE_TYPE="$2"
                shift 2
                ;;
            -k|--kubeconfig)
                KUBECONFIG_PATH="$2"
                shift 2
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
}

# Pre-flight checks
preflight_checks() {
    log_info "Running pre-flight checks for WSL2 Debian..."
    
    # Check if running as root or with sudo (WSL2 friendly)
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        log_error "This script must be run as root or with sudo privileges"
        log_info "In WSL2, you can run: sudo $0 $*"
        exit 1
    fi
    
    # Check if running in WSL2
    if grep -qi microsoft /proc/version; then
        log_info "WSL2 environment detected"
    else
        log_warn "Not running in WSL2 - some optimizations may not apply"
    fi
    
    # Check system requirements
    log_info "Checking system requirements..."
    
    # Check available memory (minimum 512MB for WSL2)
    local mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local mem_mb=$((mem_kb / 1024))
    if [ $mem_mb -lt 512 ]; then
        log_error "Insufficient memory. Minimum 512MB required for WSL2, found ${mem_mb}MB"
        exit 1
    fi
    log_info "Memory check passed: ${mem_mb}MB available"
    
    # Check available disk space (minimum 2GB for WSL2)
    local disk_gb=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    if [ $disk_gb -lt 2 ]; then
        log_error "Insufficient disk space. Minimum 2GB required for WSL2, found ${disk_gb}GB"
        exit 1
    fi
    log_info "Disk space check passed: ${disk_gb}GB available"
    
    # Create K3s directories
    log_info "Creating K3s directories..."
    mkdir -p /var/lib/rancher/k3s
    mkdir -p /var/log
    
    # Check if K3s is already installed
    if command -v k3s &> /dev/null; then
        log_warn "K3s is already installed. This will upgrade/reconfigure the existing installation."
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled by user"
            exit 0
        fi
    fi
    
    # Validate node type
    if [[ "$NODE_TYPE" != "server" && "$NODE_TYPE" != "agent" ]]; then
        log_error "Invalid node type: $NODE_TYPE. Must be 'server' or 'agent'"
        exit 1
    fi
    
    # Check configuration file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    log_success "Pre-flight checks completed successfully"
}

# Validate configuration file
validate_config() {
    log_info "Validating configuration file: $CONFIG_FILE"
    
    # Check if file is valid YAML
    if ! python3 -c "import yaml; yaml.safe_load(open('$CONFIG_FILE'))" 2>/dev/null; then
        log_error "Invalid YAML in configuration file: $CONFIG_FILE"
        exit 1
    fi
    
    # Additional configuration validation can be added here
    log_success "Configuration validation completed"
}

# Install K3s
install_k3s() {
    log_info "Starting K3s installation..."
    log_info "Version: $K3S_VERSION"
    log_info "Node Type: $NODE_TYPE"
    log_info "Cluster Name: $CLUSTER_NAME"
    
    # Prepare installation command
    local install_cmd="curl -sfL https://get.k3s.io | "
    
    # Add version if not latest
    if [[ "$K3S_VERSION" != "latest" ]]; then
        install_cmd+="INSTALL_K3S_VERSION=$K3S_VERSION "
    fi
    
    # Add WSL2 specific environment variables
    install_cmd+="INSTALL_K3S_EXEC='server --cluster-init' "
    
    # Add configuration file
    install_cmd+="sh -s - --config $CONFIG_FILE"
    
    log_info "Executing: $install_cmd"
    
    # Execute installation
    if eval "$install_cmd" >> "$LOG_FILE" 2>&1; then
        log_success "K3s installation completed successfully"
    else
        log_error "K3s installation failed"
        exit 1
    fi
}

# Configure kubeconfig
configure_kubeconfig() {
    log_info "Configuring kubeconfig..."
    
    # Wait for kubeconfig file to be created
    local timeout=60
    local count=0
    while [[ ! -f "$KUBECONFIG_PATH" && $count -lt $timeout ]]; do
        sleep 1
        ((count++))
    done
    
    if [[ ! -f "$KUBECONFIG_PATH" ]]; then
        log_error "Kubeconfig file not found after $timeout seconds: $KUBECONFIG_PATH"
        exit 1
    fi
    
    # Set proper permissions on original file
    chmod 644 "$KUBECONFIG_PATH"
    
    # Get the original user who ran sudo (if applicable)
    local original_user="${SUDO_USER:-$(logname 2>/dev/null || echo $USER)}"
    local user_home
    
    if [[ "$original_user" != "root" ]]; then
        user_home=$(eval echo "~$original_user")
        
        # Create .kube directory for user
        local user_kube_dir="$user_home/.kube"
        mkdir -p "$user_kube_dir"
        
        # Copy kubeconfig to user's home directory
        local user_kubeconfig="$user_kube_dir/config"
        cp "$KUBECONFIG_PATH" "$user_kubeconfig"
        
        # Set proper ownership and permissions
        chown -R "$original_user:$original_user" "$user_kube_dir"
        chmod 600 "$user_kubeconfig"
        
        log_success "Kubeconfig copied to user directory: $user_kubeconfig"
        log_info "User can now run kubectl without sudo"
        
        # Also create a backup in persistent storage
        mkdir -p /opt/k3s
        local backup_kubeconfig="/opt/k3s/kubeconfig"
        cp "$KUBECONFIG_PATH" "$backup_kubeconfig"
        chown "$original_user:$original_user" "$backup_kubeconfig"
        chmod 600 "$backup_kubeconfig"
        
        log_success "Kubeconfig backup created at: $backup_kubeconfig"
    else
        log_warn "Running as root - kubeconfig only available at: $KUBECONFIG_PATH"
    fi
    
    # Export KUBECONFIG for current session
    export KUBECONFIG="$KUBECONFIG_PATH"
    
    log_success "Kubeconfig configured at: $KUBECONFIG_PATH"
}

# Main installation function
main() {
    log_info "Starting K3s cluster installation"
    log_info "Log file: $LOG_FILE"
    
    parse_args "$@"
    preflight_checks
    validate_config
    install_k3s
    configure_kubeconfig
    
    log_success "K3s cluster installation completed successfully!"
    
    # Get the original user info for instructions
    local original_user="${SUDO_USER:-$(logname 2>/dev/null || echo $USER)}"
    
    log_info "Next steps:"
    if [[ "$original_user" != "root" ]]; then
        log_info "1. Switch to your user account (exit sudo if needed)"
        log_info "2. Run post-installation validation: ./post-install.sh"
        log_info "3. Test cluster: kubectl get nodes (no sudo needed)"
        log_info "4. Kubeconfig is available at: ~/.kube/config"
    else
        log_info "1. Run post-installation validation: ./post-install.sh"
        log_info "2. Configure kubectl: export KUBECONFIG=$KUBECONFIG_PATH"
        log_info "3. Test cluster: kubectl get nodes"
    fi
}

# Execute main function with all arguments
main "$@"