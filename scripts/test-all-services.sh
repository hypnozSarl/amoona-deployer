#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default namespace
NAMESPACE="${1:-amoona-dev}"

echo ""
echo "=================================="
echo "  Service Connectivity Tests"
echo "  Namespace: $NAMESPACE"
echo "=================================="
echo ""

passed=0
failed=0

test_service() {
    local name=$1
    local command=$2
    local expected=$3

    printf "%-20s" "$name..."

    if output=$(eval "$command" 2>&1); then
        if [[ -z "$expected" ]] || echo "$output" | grep -q "$expected"; then
            echo -e "${GREEN}PASS${NC}"
            ((passed++))
            return 0
        fi
    fi

    echo -e "${RED}FAIL${NC}"
    echo -e "  ${YELLOW}Command:${NC} $command"
    echo -e "  ${YELLOW}Output:${NC} $output"
    ((failed++))
    return 1
}

echo -e "${BLUE}Testing Infrastructure Services...${NC}"
echo ""

# PostgreSQL
test_service "PostgreSQL" \
    "kubectl exec -n $NAMESPACE postgres-0 -- pg_isready -U amoona 2>/dev/null" \
    "accepting connections" || true

# Redis
test_service "Redis" \
    "kubectl exec -n $NAMESPACE deploy/redis -- redis-cli ping 2>/dev/null" \
    "PONG" || true

# MinIO Health
test_service "MinIO API" \
    "kubectl exec -n $NAMESPACE deploy/minio -- curl -sf http://localhost:9000/minio/health/live 2>/dev/null" \
    "" || true

# Elasticsearch
test_service "Elasticsearch" \
    "kubectl exec -n $NAMESPACE elasticsearch-0 -- curl -sf http://localhost:9200/_cluster/health 2>/dev/null" \
    "" || true

echo ""
echo -e "${BLUE}Testing Monitoring Services...${NC}"
echo ""

# Prometheus
test_service "Prometheus" \
    "kubectl exec -n $NAMESPACE deploy/prometheus -- wget -qO- http://localhost:9090/-/ready 2>/dev/null" \
    "" || true

# Grafana
test_service "Grafana" \
    "kubectl exec -n $NAMESPACE deploy/grafana -- wget -qO- http://localhost:3000/api/health 2>/dev/null" \
    "" || true

echo ""
echo -e "${BLUE}Testing DNS Resolution...${NC}"
echo ""

# DNS Tests
for svc in postgres redis minio elasticsearch prometheus grafana; do
    test_service "DNS: $svc" \
        "kubectl run -n $NAMESPACE dns-test-$svc --rm -i --restart=Never --image=busybox -- nslookup $svc.$NAMESPACE.svc.cluster.local 2>/dev/null" \
        "Address" || true
done

echo ""
echo -e "${BLUE}Testing Pod Status...${NC}"
echo ""

# Check all pods are running
not_running=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep -v "Running\|Completed" | wc -l || echo "0")
if [[ "$not_running" -eq 0 ]]; then
    echo -e "All Pods Running:   ${GREEN}PASS${NC}"
    ((passed++))
else
    echo -e "All Pods Running:   ${RED}FAIL${NC}"
    echo "  Pods not running:"
    kubectl get pods -n "$NAMESPACE" --no-headers | grep -v "Running\|Completed" || true
    ((failed++))
fi

echo ""
echo "=================================="
echo "  Test Results"
echo "=================================="
echo ""
echo -e "  Passed: ${GREEN}$passed${NC}"
echo -e "  Failed: ${RED}$failed${NC}"
echo ""

if [[ $failed -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${YELLOW}Some tests failed. Check the output above.${NC}"
    exit 1
fi
