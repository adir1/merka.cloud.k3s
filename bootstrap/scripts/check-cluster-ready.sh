#!/bin/bash

# Quick Cluster Readiness Check
# Simple script to verify basic cluster functionality

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}Checking WSL2 K3s single-node cluster readiness...${NC}"

# Find kubeconfig in multiple locations
kubeconfig_found=false
kubeconfig_locations=(
    "$HOME/.kube/config"
    "/opt/k3s/kubeconfig"
    "/etc/rancher/k3s/k3s.yaml"
    "${KUBECONFIG_PATH:-}"
)

for config_path in "${kubeconfig_locations[@]}"; do
    if [[ -n "$config_path" && -f "$config_path" ]]; then
        KUBECONFIG_PATH="$config_path"
        kubeconfig_found=true
        echo -e "${BLUE}Using kubeconfig: $config_path${NC}"
        break
    fi
done

if [[ "$kubeconfig_found" == "false" ]]; then
    echo -e "${RED}✗ Kubeconfig not found in any expected location${NC}"
    echo "Expected locations:"
    for config_path in "${kubeconfig_locations[@]}"; do
        [[ -n "$config_path" ]] && echo "  - $config_path"
    done
    exit 1
fi

# Set kubeconfig
export KUBECONFIG="$KUBECONFIG_PATH"

# Check 1: kubectl connectivity
echo -n "Checking kubectl connectivity... "
if kubectl cluster-info &> /dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    echo "Try: export KUBECONFIG=$KUBECONFIG_PATH"
    exit 1
fi

# Check 2: WSL2 Node readiness
echo -n "Checking WSL2 node readiness... "
if kubectl get nodes | grep -q " Ready "; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    exit 1
fi

# Check 3: System pods (minimal for WSL2)
echo -n "Checking system pods... "
if kubectl get pods -n kube-system | grep -q "Running"; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    exit 1
fi

# Check 4: DNS service
echo -n "Checking DNS service... "
if kubectl get service -n kube-system | grep -q "kube-dns\|coredns"; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    exit 1
fi

# Check 5: K3s storage
echo -n "Checking K3s storage... "
if [ -d "/var/lib/rancher/k3s" ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}⚠${NC} (using default paths)"
fi

echo -e "${GREEN}WSL2 K3s cluster is ready!${NC}"

# Show basic cluster info
echo
echo "WSL2 Cluster Information:"
kubectl get nodes -o wide
echo
echo "System Pods:"
kubectl get pods -n kube-system --no-headers | awk '{print $1 "\t" $3}'
echo
echo "Cluster Resources:"
kubectl top nodes 2>/dev/null || echo "Metrics not available (metrics-server may be disabled)"