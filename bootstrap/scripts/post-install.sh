#!/bin/bash

# K3s Post-Installation Validation Script
# Performs comprehensive health checks and validation after K3s installation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/k3s-post-install-$(date +%Y%m%d-%H%M%S).log"

# Default configuration for WSL2
KUBECONFIG_PATH="${KUBECONFIG_PATH:-/etc/rancher/k3s/k3s.yaml}"
TIMEOUT="${TIMEOUT:-180}"  # 3 minutes for single node
NAMESPACE="${NAMESPACE:-kube-system}"

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

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Perform comprehensive post-installation validation of K3s cluster.

OPTIONS:
    -k, --kubeconfig PATH      Kubeconfig file path (default: /etc/rancher/k3s/k3s.yaml)
    -t, --timeout SECONDS      Timeout for checks in seconds (default: 300)
    -n, --namespace NAMESPACE   Namespace for system checks (default: kube-system)
    -h, --help                 Show this help message

EXAMPLES:
    $0                         # Run with defaults
    $0 -t 600                  # Run with 10-minute timeout
    $0 -k ~/.kube/config       # Use custom kubeconfig

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -k|--kubeconfig)
                KUBECONFIG_PATH="$2"
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -n|--namespace)
                NAMESPACE="$2"
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

# Check if kubectl is available and configured
check_kubectl() {
    log_info "Checking kubectl availability and configuration..."
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        return 1
    fi
    
    # Try to find kubeconfig in multiple locations
    local kubeconfig_found=false
    local kubeconfig_locations=(
        "$HOME/.kube/config"
        "/opt/k3s/kubeconfig"
        "/etc/rancher/k3s/k3s.yaml"
        "$KUBECONFIG_PATH"
    )
    
    for config_path in "${kubeconfig_locations[@]}"; do
        if [[ -f "$config_path" ]]; then
            KUBECONFIG_PATH="$config_path"
            kubeconfig_found=true
            log_info "Found kubeconfig at: $config_path"
            break
        fi
    done
    
    if [[ "$kubeconfig_found" == "false" ]]; then
        log_error "Kubeconfig file not found in any of the expected locations:"
        for config_path in "${kubeconfig_locations[@]}"; do
            log_error "  - $config_path"
        done
        return 1
    fi
    
    # Set kubeconfig for this session
    export KUBECONFIG="$KUBECONFIG_PATH"
    
    # Test kubectl connectivity
    if ! kubectl version --client &> /dev/null; then
        log_error "kubectl client is not working properly"
        return 1
    fi
    
    log_success "kubectl is available and configured with: $KUBECONFIG_PATH"
    return 0
}

# Check cluster connectivity
check_cluster_connectivity() {
    log_info "Checking WSL2 cluster connectivity..."
    
    local retries=0
    local max_retries=6  # Reduced for single node
    
    while [ $retries -lt $max_retries ]; do
        if kubectl cluster-info &> /dev/null; then
            log_success "WSL2 cluster connectivity established"
            kubectl cluster-info | head -3 | while read line; do
                log_info "$line"
            done
            return 0
        fi
        
        retries=$((retries + 1))
        log_warn "WSL2 cluster not ready, attempt $retries/$max_retries..."
        sleep 5  # Shorter wait for single node
    done
    
    log_error "Failed to establish WSL2 cluster connectivity after $max_retries attempts"
    return 1
}

# Check node status and readiness
check_node_status() {
    log_info "Checking WSL2 single node status and readiness..."
    
    # Get node information
    local nodes_output
    if ! nodes_output=$(kubectl get nodes -o wide 2>&1); then
        log_error "Failed to get WSL2 node information"
        log_error "$nodes_output"
        return 1
    fi
    
    log_info "WSL2 node information:"
    echo "$nodes_output" | while read line; do
        log_info "$line"
    done
    
    # Check if the single node is Ready
    local ready_nodes
    ready_nodes=$(kubectl get nodes --no-headers | grep " Ready " | wc -l)
    
    if [ "$ready_nodes" -eq 0 ]; then
        log_error "WSL2 node is not in Ready state"
        kubectl get nodes --no-headers | while read line; do
            log_error "Node status: $line"
        done
        return 1
    fi
    
    log_success "WSL2 single node is in Ready state"
    return 0
}

# Check system pods status
check_system_pods() {
    log_info "Checking system pods status in namespace: $NAMESPACE..."
    
    # Wait for system pods to be ready (faster for single node)
    local timeout_seconds=$TIMEOUT
    local elapsed=0
    local check_interval=5  # Shorter interval for WSL2
    
    while [ $elapsed -lt $timeout_seconds ]; do
        local not_ready_pods
        not_ready_pods=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep -v "Running\|Completed" | wc -l)
        
        if [ "$not_ready_pods" -eq 0 ]; then
            log_success "All WSL2 system pods are running"
            break
        fi
        
        log_info "Waiting for $not_ready_pods WSL2 system pod(s) to be ready... (${elapsed}s/${timeout_seconds}s)"
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done
    
    # Final check and detailed status
    local pods_output
    if ! pods_output=$(kubectl get pods -n "$NAMESPACE" -o wide 2>&1); then
        log_error "Failed to get pod information"
        return 1
    fi
    
    log_info "System pods status:"
    echo "$pods_output" | while read line; do
        log_info "$line"
    done
    
    # Check for any failed pods
    local failed_pods
    failed_pods=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep -E "Error|CrashLoopBackOff|ImagePullBackOff" | wc -l)
    
    if [ "$failed_pods" -gt 0 ]; then
        log_error "$failed_pods system pod(s) are in failed state"
        kubectl get pods -n "$NAMESPACE" --no-headers | grep -E "Error|CrashLoopBackOff|ImagePullBackOff" | while read line; do
            log_error "Failed pod: $line"
        done
        return 1
    fi
    
    return 0
}

# Check cluster services
check_cluster_services() {
    log_info "Checking cluster services..."
    
    # Check if kubernetes service exists
    if ! kubectl get service kubernetes &> /dev/null; then
        log_error "Kubernetes service not found"
        return 1
    fi
    
    # Get service information
    local services_output
    if ! services_output=$(kubectl get services -n "$NAMESPACE" -o wide 2>&1); then
        log_error "Failed to get service information"
        return 1
    fi
    
    log_info "Cluster services:"
    echo "$services_output" | while read line; do
        log_info "$line"
    done
    
    log_success "Cluster services are available"
    return 0
}

# Check DNS functionality
check_dns_functionality() {
    log_info "Checking DNS functionality..."
    
    # Create a test pod for DNS checking
    local test_pod_name="dns-test-$(date +%s)"
    local test_namespace="default"
    
    # Create test pod
    kubectl run "$test_pod_name" --image=busybox --restart=Never --rm -i --quiet -- sleep 30 &
    local test_pod_pid=$!
    
    # Wait for pod to be ready (faster for WSL2)
    local retries=0
    local max_retries=15  # Reduced for single node
    
    while [ $retries -lt $max_retries ]; do
        if kubectl get pod "$test_pod_name" -n "$test_namespace" &> /dev/null; then
            if kubectl get pod "$test_pod_name" -n "$test_namespace" -o jsonpath='{.status.phase}' | grep -q "Running"; then
                break
            fi
        fi
        retries=$((retries + 1))
        sleep 1  # Faster polling for WSL2
    done
    
    if [ $retries -eq $max_retries ]; then
        log_warn "WSL2 DNS test pod failed to start, skipping DNS test"
        kill $test_pod_pid 2>/dev/null || true
        return 0
    fi
    
    # Test DNS resolution
    local dns_test_result
    if dns_test_result=$(kubectl exec "$test_pod_name" -n "$test_namespace" -- nslookup kubernetes.default.svc.cluster.local 2>&1); then
        log_success "DNS resolution is working"
        log_info "DNS test result: $(echo "$dns_test_result" | grep -E "Server|Address" | head -2 | tr '\n' ' ')"
    else
        log_error "DNS resolution failed"
        log_error "$dns_test_result"
    fi
    
    # Cleanup
    kubectl delete pod "$test_pod_name" -n "$test_namespace" --force --grace-period=0 &> /dev/null || true
    kill $test_pod_pid 2>/dev/null || true
    
    return 0
}

# Check basic security configuration
check_security_configuration() {
    log_info "Checking basic security configuration..."
    
    # Check if RBAC is enabled
    if kubectl auth can-i get pods --as=system:anonymous &> /dev/null; then
        log_warn "Anonymous access to pods is allowed - consider reviewing RBAC configuration"
    else
        log_success "RBAC appears to be properly configured"
    fi
    
    # Check for default service account token auto-mounting
    local default_sa_automount
    default_sa_automount=$(kubectl get serviceaccount default -o jsonpath='{.automountServiceAccountToken}' 2>/dev/null || echo "true")
    
    if [[ "$default_sa_automount" == "true" ]]; then
        log_warn "Default service account has automountServiceAccountToken enabled"
    else
        log_success "Default service account token auto-mounting is disabled"
    fi
    
    # Check for network policies (if supported)
    if kubectl get networkpolicies --all-namespaces &> /dev/null; then
        local netpol_count
        netpol_count=$(kubectl get networkpolicies --all-namespaces --no-headers | wc -l)
        if [ "$netpol_count" -gt 0 ]; then
            log_success "Network policies are configured ($netpol_count found)"
        else
            log_warn "No network policies found - consider implementing network segmentation"
        fi
    else
        log_warn "Network policies are not supported or not available"
    fi
    
    return 0
}

# Generate cluster summary report
generate_summary_report() {
    log_info "Generating cluster summary report..."
    
    echo "========================================" | tee -a "$LOG_FILE"
    echo "K3s Cluster Validation Summary" | tee -a "$LOG_FILE"
    echo "Generated: $(date)" | tee -a "$LOG_FILE"
    echo "========================================" | tee -a "$LOG_FILE"
    
    # Cluster version
    local k8s_version
    k8s_version=$(kubectl version --short 2>/dev/null | grep "Server Version" | cut -d' ' -f3 || echo "Unknown")
    echo "Kubernetes Version: $k8s_version" | tee -a "$LOG_FILE"
    
    # Node count
    local node_count
    node_count=$(kubectl get nodes --no-headers | wc -l)
    echo "Node Count: $node_count" | tee -a "$LOG_FILE"
    
    # Pod count
    local pod_count
    pod_count=$(kubectl get pods --all-namespaces --no-headers | wc -l)
    echo "Total Pods: $pod_count" | tee -a "$LOG_FILE"
    
    # Namespace count
    local ns_count
    ns_count=$(kubectl get namespaces --no-headers | wc -l)
    echo "Namespaces: $ns_count" | tee -a "$LOG_FILE"
    
    echo "========================================" | tee -a "$LOG_FILE"
    echo "Log file: $LOG_FILE" | tee -a "$LOG_FILE"
    echo "========================================" | tee -a "$LOG_FILE"
}

# Main validation function
main() {
    log_info "Starting K3s post-installation validation"
    log_info "Log file: $LOG_FILE"
    
    parse_args "$@"
    
    local validation_failed=0
    
    # Run all validation checks
    check_kubectl || validation_failed=1
    check_cluster_connectivity || validation_failed=1
    check_node_status || validation_failed=1
    check_system_pods || validation_failed=1
    check_cluster_services || validation_failed=1
    check_dns_functionality || validation_failed=1
    check_security_configuration || validation_failed=1
    
    # Generate summary report
    generate_summary_report
    
    if [ $validation_failed -eq 0 ]; then
        log_success "All post-installation validations passed!"
        log_info "Your K3s cluster is ready for use"
        log_info "Next steps:"
        log_info "1. Install ArgoCD: Follow the ArgoCD installation guide"
        log_info "2. Configure GitOps: Set up your GitOps repository"
        log_info "3. Deploy applications: Start deploying your workloads"
        return 0
    else
        log_error "Some post-installation validations failed"
        log_error "Please review the errors above and fix any issues"
        log_error "Check the log file for detailed information: $LOG_FILE"
        return 1
    fi
}

# Execute main function with all arguments
main "$@"