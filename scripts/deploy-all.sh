#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
ENVIRONMENT="${1:-dev}"
DRY_RUN=false
WAIT_FOR_READY=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-wait)
            WAIT_FOR_READY=false
            shift
            ;;
        dev|prod)
            ENVIRONMENT="$1"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [dev|prod] [--dry-run] [--no-wait]"
            echo ""
            echo "Options:"
            echo "  dev|prod     Environment to deploy (default: dev)"
            echo "  --dry-run    Generate manifests without applying"
            echo "  --no-wait    Don't wait for resources to be ready"
            echo "  -h, --help   Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi

    if ! command -v kustomize &> /dev/null; then
        log_warning "kustomize not found, using kubectl kustomize"
        KUSTOMIZE_CMD="kubectl kustomize"
    else
        KUSTOMIZE_CMD="kustomize build"
    fi

    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi

    log_success "Prerequisites check passed"
}

# Validate manifests
validate_manifests() {
    log_info "Validating Kustomize manifests for $ENVIRONMENT..."

    OVERLAY_PATH="$PROJECT_ROOT/k8s/overlays/$ENVIRONMENT"

    if [[ ! -d "$OVERLAY_PATH" ]]; then
        log_error "Overlay directory not found: $OVERLAY_PATH"
        exit 1
    fi

    # Generate and validate
    if $KUSTOMIZE_CMD "$OVERLAY_PATH" > /dev/null 2>&1; then
        log_success "Manifests validated successfully"
    else
        log_error "Manifest validation failed"
        $KUSTOMIZE_CMD "$OVERLAY_PATH"
        exit 1
    fi
}

# Deploy to cluster
deploy() {
    log_info "Deploying $ENVIRONMENT environment..."

    OVERLAY_PATH="$PROJECT_ROOT/k8s/overlays/$ENVIRONMENT"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Dry run mode - generating manifests to stdout..."
        $KUSTOMIZE_CMD "$OVERLAY_PATH"
        return 0
    fi

    # Apply manifests
    log_info "Applying manifests..."
    $KUSTOMIZE_CMD "$OVERLAY_PATH" | kubectl apply -f -

    log_success "Manifests applied successfully"
}

# Wait for deployments
wait_for_ready() {
    if [[ "$WAIT_FOR_READY" == "false" ]] || [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    NAMESPACE="amoona-$ENVIRONMENT"

    log_info "Waiting for deployments to be ready in namespace $NAMESPACE..."

    # Wait for StatefulSets
    for sts in postgres elasticsearch; do
        log_info "Waiting for StatefulSet $sts..."
        kubectl rollout status statefulset/$sts -n "$NAMESPACE" --timeout=300s || {
            log_warning "StatefulSet $sts not ready within timeout"
        }
    done

    # Wait for Deployments
    for deploy in redis minio prometheus grafana; do
        log_info "Waiting for Deployment $deploy..."
        kubectl rollout status deployment/$deploy -n "$NAMESPACE" --timeout=120s || {
            log_warning "Deployment $deploy not ready within timeout"
        }
    done

    log_success "All deployments are ready"
}

# Print status
print_status() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    NAMESPACE="amoona-$ENVIRONMENT"

    echo ""
    log_info "Deployment Status:"
    echo "===================="
    kubectl get all -n "$NAMESPACE" 2>/dev/null || log_warning "Could not get resources"

    echo ""
    log_info "Service Endpoints:"
    echo "===================="
    echo "  PostgreSQL: postgres.$NAMESPACE.svc.cluster.local:5432"
    echo "  Redis:      redis.$NAMESPACE.svc.cluster.local:6379"
    echo "  MinIO API:  minio.$NAMESPACE.svc.cluster.local:9000"
    echo "  MinIO UI:   minio.$NAMESPACE.svc.cluster.local:9001"
    echo "  Elasticsearch: elasticsearch.$NAMESPACE.svc.cluster.local:9200"
    echo "  Prometheus: prometheus.$NAMESPACE.svc.cluster.local:9090"
    echo "  Grafana:    grafana.$NAMESPACE.svc.cluster.local:3000"
}

# Main execution
main() {
    echo ""
    echo "=================================="
    echo "  Amoona Kubernetes Deployer"
    echo "  Environment: $ENVIRONMENT"
    echo "=================================="
    echo ""

    check_prerequisites
    validate_manifests
    deploy
    wait_for_ready
    print_status

    echo ""
    log_success "Deployment complete!"
}

main
