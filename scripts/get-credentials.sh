#!/bin/bash
# =============================================================================
# Script pour récupérer toutes les credentials des services
# =============================================================================
# Usage: ./scripts/get-credentials.sh [namespace]
# Par défaut: namespace = amoona-dev
# =============================================================================

set -euo pipefail

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

NAMESPACE="${1:-amoona-dev}"
VPS_IP="${VPS_IP:-195.35.2.238}"

echo ""
echo -e "${BOLD}=============================================="
echo "  CREDENTIALS - Environnement: $NAMESPACE"
echo "  VPS: $VPS_IP"
echo -e "==============================================${NC}"

# Fonction pour récupérer un secret
get_secret() {
    local secret_name=$1
    local key=$2
    kubectl get secret "$secret_name" -n "$NAMESPACE" -o jsonpath="{.data.$key}" 2>/dev/null | base64 -d 2>/dev/null || echo "N/A"
}

# =============================================================================
# PostgreSQL
# =============================================================================
echo ""
echo -e "${CYAN}┌─────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC}  ${BOLD}PostgreSQL${NC}                                 ${CYAN}│${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────┘${NC}"
echo -e "  ${BLUE}Host:${NC}     $VPS_IP"
echo -e "  ${BLUE}Port:${NC}     30432 (externe) / 5432 (interne)"
echo -e "  ${BLUE}Database:${NC} $(get_secret postgres-secret POSTGRES_DB)"
echo -e "  ${BLUE}User:${NC}     $(get_secret postgres-secret POSTGRES_USER)"
echo -e "  ${BLUE}Password:${NC} ${YELLOW}$(get_secret postgres-secret POSTGRES_PASSWORD)${NC}"
echo ""
echo -e "  ${GREEN}JDBC URL:${NC}"
echo -e "  jdbc:postgresql://$VPS_IP:30432/$(get_secret postgres-secret POSTGRES_DB)"

# =============================================================================
# Redis
# =============================================================================
echo ""
echo -e "${CYAN}┌─────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC}  ${BOLD}Redis${NC}                                      ${CYAN}│${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────┘${NC}"
echo -e "  ${BLUE}Host:${NC}     $VPS_IP"
echo -e "  ${BLUE}Port:${NC}     30379 (externe) / 6379 (interne)"
echo -e "  ${BLUE}Password:${NC} ${YELLOW}$(get_secret redis-secret REDIS_PASSWORD)${NC}"
echo ""
echo -e "  ${GREEN}Redis URL:${NC}"
echo -e "  redis://:$(get_secret redis-secret REDIS_PASSWORD)@$VPS_IP:30379"

# =============================================================================
# MinIO
# =============================================================================
echo ""
echo -e "${CYAN}┌─────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC}  ${BOLD}MinIO (S3 Compatible)${NC}                      ${CYAN}│${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────┘${NC}"
echo -e "  ${BLUE}S3 API:${NC}   http://$VPS_IP:30900"
echo -e "  ${BLUE}Console:${NC}  http://$VPS_IP:30901"
echo -e "  ${BLUE}User:${NC}     $(get_secret minio-secret MINIO_ROOT_USER)"
echo -e "  ${BLUE}Password:${NC} ${YELLOW}$(get_secret minio-secret MINIO_ROOT_PASSWORD)${NC}"
echo ""
echo -e "  ${GREEN}AWS CLI Config:${NC}"
echo -e "  export AWS_ACCESS_KEY_ID=$(get_secret minio-secret MINIO_ROOT_USER)"
echo -e "  export AWS_SECRET_ACCESS_KEY=$(get_secret minio-secret MINIO_ROOT_PASSWORD)"
echo -e "  export AWS_ENDPOINT_URL=http://$VPS_IP:30900"

# =============================================================================
# Grafana
# =============================================================================
echo ""
echo -e "${CYAN}┌─────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC}  ${BOLD}Grafana${NC}                                    ${CYAN}│${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────┘${NC}"
echo -e "  ${BLUE}URL:${NC}      http://grafana.$VPS_IP.nip.io"
echo -e "  ${BLUE}User:${NC}     $(get_secret grafana-secret GF_SECURITY_ADMIN_USER)"
echo -e "  ${BLUE}Password:${NC} ${YELLOW}$(get_secret grafana-secret GF_SECURITY_ADMIN_PASSWORD)${NC}"

# =============================================================================
# ArgoCD
# =============================================================================
echo ""
echo -e "${CYAN}┌─────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC}  ${BOLD}ArgoCD${NC}                                     ${CYAN}│${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────┘${NC}"
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "N/A")
echo -e "  ${BLUE}URL:${NC}      http://argocd.$VPS_IP.nip.io"
echo -e "  ${BLUE}NodePort:${NC} http://$VPS_IP:30080"
echo -e "  ${BLUE}User:${NC}     admin"
echo -e "  ${BLUE}Password:${NC} ${YELLOW}$ARGOCD_PASSWORD${NC}"

# =============================================================================
# API Secrets
# =============================================================================
echo ""
echo -e "${CYAN}┌─────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC}  ${BOLD}Amoona API Secrets${NC}                         ${CYAN}│${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────┘${NC}"
echo -e "  ${BLUE}JWT Secret:${NC}    $(get_secret amoona-api-secrets JWT_SECRET | head -c 20)..."
echo -e "  ${BLUE}DB URL:${NC}        $(get_secret amoona-api-secrets DB_URL)"

# =============================================================================
# Résumé des URLs
# =============================================================================
echo ""
echo -e "${BOLD}=============================================="
echo "  URLS D'ACCÈS"
echo -e "==============================================${NC}"
echo ""
echo -e "  ${GREEN}Applications:${NC}"
echo -e "    Frontend:    http://app.$VPS_IP.nip.io"
echo -e "    API:         http://api.$VPS_IP.nip.io"
echo ""
echo -e "  ${GREEN}DevOps:${NC}"
echo -e "    ArgoCD:      http://$VPS_IP:30080"
echo -e "    Grafana:     http://grafana.$VPS_IP.nip.io"
echo -e "    Prometheus:  http://prometheus.$VPS_IP.nip.io"
echo -e "    MinIO:       http://minio.$VPS_IP.nip.io"
echo ""
echo -e "  ${GREEN}Bases de données (externes):${NC}"
echo -e "    PostgreSQL:  $VPS_IP:30432"
echo -e "    Redis:       $VPS_IP:30379"
echo -e "    MinIO S3:    $VPS_IP:30900"
echo ""
echo -e "${BOLD}==============================================${NC}"
echo ""
