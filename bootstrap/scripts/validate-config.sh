#!/bin/bash

# K3s Configuration Validation Script
# Validates K3s configuration files for syntax and logical consistency

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/../configs"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Usage information
usage() {
    cat << EOF
Usage: $0 [CONFIG_FILE]

Validate K3s configuration files for syntax and logical consistency.

ARGUMENTS:
    CONFIG_FILE    Path to configuration file (default: cluster-config.yaml)

EXAMPLES:
    $0                           # Validate default config
    $0 development.yaml          # Validate development config
    $0 /path/to/custom.yaml      # Validate custom config file

EOF
}

# Check if required tools are available
check_dependencies() {
    local missing_deps=()
    
    # Check for Python (for YAML validation) - common in WSL2 Debian
    if ! command -v python3 &> /dev/null; then
        log_warn "python3 not found - installing via apt..."
        if command -v apt &> /dev/null; then
            apt update && apt install -y python3 python3-yaml
        else
            missing_deps+=("python3")
        fi
    fi
    
    # Check for yq (optional, for advanced YAML processing)
    if ! command -v yq &> /dev/null; then
        log_warn "yq not found - some advanced validations will be skipped"
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Please install the missing dependencies and try again"
        exit 1
    fi
}

# Validate YAML syntax
validate_yaml_syntax() {
    local config_file="$1"
    
    log_info "Validating YAML syntax for: $config_file"
    
    if ! python3 -c "
import yaml
import sys
try:
    with open('$config_file', 'r') as f:
        yaml.safe_load(f)
    print('YAML syntax is valid')
except yaml.YAMLError as e:
    print(f'YAML syntax error: {e}')
    sys.exit(1)
except FileNotFoundError:
    print(f'File not found: $config_file')
    sys.exit(1)
" 2>/dev/null; then
        log_error "YAML syntax validation failed"
        return 1
    fi
    
    log_success "YAML syntax validation passed"
    return 0
}

# Validate network configuration
validate_network_config() {
    local config_file="$1"
    
    log_info "Validating network configuration..."
    
    # Extract network values using Python
    local validation_result=$(python3 << EOF
import yaml
import ipaddress
import sys

try:
    with open('$config_file', 'r') as f:
        config = yaml.safe_load(f) or {}
    
    errors = []
    warnings = []
    
    # Validate cluster CIDR
    cluster_cidr = config.get('cluster-cidr', '10.42.0.0/16')
    try:
        cluster_net = ipaddress.ip_network(cluster_cidr, strict=False)
        if cluster_net.prefixlen > 24:
            warnings.append(f"Cluster CIDR {cluster_cidr} has small network size")
    except ValueError as e:
        errors.append(f"Invalid cluster-cidr: {cluster_cidr} - {e}")
    
    # Validate service CIDR
    service_cidr = config.get('service-cidr', '10.43.0.0/16')
    try:
        service_net = ipaddress.ip_network(service_cidr, strict=False)
        if service_net.prefixlen > 24:
            warnings.append(f"Service CIDR {service_cidr} has small network size")
    except ValueError as e:
        errors.append(f"Invalid service-cidr: {service_cidr} - {e}")
    
    # Check for CIDR overlap
    try:
        if cluster_net.overlaps(service_net):
            errors.append(f"Cluster CIDR {cluster_cidr} overlaps with service CIDR {service_cidr}")
    except:
        pass  # Skip if CIDRs are invalid
    
    # Validate cluster DNS
    cluster_dns = config.get('cluster-dns', '10.43.0.10')
    try:
        dns_ip = ipaddress.ip_address(cluster_dns)
        if dns_ip not in service_net:
            errors.append(f"Cluster DNS {cluster_dns} is not within service CIDR {service_cidr}")
    except ValueError as e:
        errors.append(f"Invalid cluster-dns: {cluster_dns} - {e}")
    except:
        pass  # Skip if service CIDR is invalid
    
    # Print results
    for error in errors:
        print(f"ERROR: {error}")
    for warning in warnings:
        print(f"WARNING: {warning}")
    
    if errors:
        sys.exit(1)
    else:
        print("Network configuration validation passed")

except Exception as e:
    print(f"ERROR: Failed to validate network configuration - {e}")
    sys.exit(1)
EOF
)
    
    if [ $? -ne 0 ]; then
        echo "$validation_result"
        log_error "Network configuration validation failed"
        return 1
    fi
    
    echo "$validation_result"
    log_success "Network configuration validation passed"
    return 0
}

# Validate resource limits and settings
validate_resource_config() {
    local config_file="$1"
    
    log_info "Validating resource configuration..."
    
    # Check kubelet arguments for resource settings
    if grep -q "max-pods" "$config_file"; then
        local max_pods=$(grep "max-pods" "$config_file" | sed 's/.*max-pods=\([0-9]*\).*/\1/')
        if [ "$max_pods" -gt 250 ]; then
            log_warn "max-pods is set to $max_pods, which may cause performance issues"
        elif [ "$max_pods" -lt 10 ]; then
            log_warn "max-pods is set to $max_pods, which is very low"
        fi
    fi
    
    # Check for eviction settings (important for WSL2 memory constraints)
    if grep -q "eviction-hard" "$config_file"; then
        log_info "Eviction policies are configured (good for WSL2)"
    else
        log_warn "No eviction policies configured - recommended for WSL2 memory management"
    fi
    
    log_success "Resource configuration validation completed"
    return 0
}

# Validate security settings
validate_security_config() {
    local config_file="$1"
    
    log_info "Validating security configuration..."
    
    # Check for security-related settings
    local security_issues=()
    
    # Check secrets encryption
    if grep -q "secrets-encryption.*false" "$config_file"; then
        security_issues+=("Secrets encryption is disabled")
    fi
    
    # Check kernel defaults protection
    if grep -q "protect-kernel-defaults.*false" "$config_file"; then
        security_issues+=("Kernel defaults protection is disabled")
    fi
    
    # Check network policy
    if grep -q "disable-network-policy.*true" "$config_file"; then
        security_issues+=("Network policies are disabled")
    fi
    
    # Report security issues
    if [ ${#security_issues[@]} -gt 0 ]; then
        log_warn "Security configuration issues found:"
        for issue in "${security_issues[@]}"; do
            log_warn "  - $issue"
        done
        log_warn "Consider reviewing security settings for production environments"
    else
        log_success "Security configuration looks good"
    fi
    
    return 0
}

# Main validation function
validate_config() {
    local config_file="$1"
    
    # Convert relative path to absolute if needed
    if [[ ! "$config_file" = /* ]]; then
        config_file="${CONFIG_DIR}/$config_file"
    fi
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        return 1
    fi
    
    log_info "Validating configuration file: $config_file"
    echo "----------------------------------------"
    
    local validation_failed=0
    
    # Run all validations
    validate_yaml_syntax "$config_file" || validation_failed=1
    validate_network_config "$config_file" || validation_failed=1
    validate_resource_config "$config_file" || validation_failed=1
    validate_security_config "$config_file" || validation_failed=1
    
    echo "----------------------------------------"
    
    if [ $validation_failed -eq 0 ]; then
        log_success "All validations passed for: $config_file"
        return 0
    else
        log_error "Validation failed for: $config_file"
        return 1
    fi
}

# Main script execution
main() {
    local config_file="${1:-cluster-config.yaml}"
    
    if [[ "$config_file" == "-h" || "$config_file" == "--help" ]]; then
        usage
        exit 0
    fi
    
    check_dependencies
    validate_config "$config_file"
}

# Execute main function with all arguments
main "$@"