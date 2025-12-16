#!/bin/bash
# =============================================================================
# Script de Configuration des Domaines
# =============================================================================
# Usage: ./scripts/configure-domains.sh [DOMAIN] [EMAIL] [VPS_IP]
#
# Exemples:
#   ./scripts/configure-domains.sh amoona.tech admin@amoona.tech 195.35.2.238
#   ./scripts/configure-domains.sh                    # Mode interactif
# =============================================================================

set -euo pipefail

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OVERLAY_DIR="$PROJECT_ROOT/k8s/overlays/dev-light"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo "=============================================="
echo "  Configuration des Domaines - Amoona"
echo "=============================================="
echo ""

# Paramètres
DOMAIN="${1:-}"
EMAIL="${2:-}"
VPS_IP="${3:-195.35.2.238}"

# Mode interactif si pas de paramètres
if [[ -z "$DOMAIN" ]]; then
    echo -e "${CYAN}Configuration interactive${NC}"
    echo ""

    read -p "Domaine principal (ex: amoona.tech): " DOMAIN
    read -p "Email admin pour Let's Encrypt: " EMAIL
    read -p "IP du VPS [$VPS_IP]: " input_ip
    VPS_IP="${input_ip:-$VPS_IP}"
fi

# Validation
if [[ -z "$DOMAIN" ]] || [[ -z "$EMAIL" ]]; then
    log_error "Domaine et email sont obligatoires"
    exit 1
fi

echo ""
log_info "Configuration:"
echo "  Domaine: $DOMAIN"
echo "  Email: $EMAIL"
echo "  IP VPS: $VPS_IP"
echo ""

# Confirmation
read -p "Continuer? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warning "Annulé"
    exit 0
fi

# =============================================================================
# Mise à jour des fichiers de configuration
# =============================================================================

log_info "Mise à jour de la configuration DNS..."

# 1. Mettre à jour dns-config.yaml
cat > "$OVERLAY_DIR/dns-config.yaml" << EOF
# =============================================================================
# CONFIGURATION DNS - Généré automatiquement
# Date: $(date +%Y-%m-%d)
# =============================================================================
apiVersion: v1
kind: ConfigMap
metadata:
  name: dns-config
  labels:
    app: amoona
    component: dns-config
data:
  BASE_DOMAIN: "$DOMAIN"
  VPS_IP: "$VPS_IP"
  ADMIN_EMAIL: "$EMAIL"

  # Sous-domaines
  FRONTEND_HOST: "app.$DOMAIN"
  API_HOST: "api.$DOMAIN"
  ARGOCD_HOST: "argocd.$DOMAIN"
  HARBOR_HOST: "registry.$DOMAIN"
  GRAFANA_HOST: "grafana.$DOMAIN"
  PROMETHEUS_HOST: "prometheus.$DOMAIN"
  MINIO_HOST: "minio.$DOMAIN"
  MINIO_S3_HOST: "s3.$DOMAIN"

  # SSL/TLS
  ENABLE_TLS: "true"
  CERT_ISSUER: "letsencrypt-prod"
EOF

log_success "dns-config.yaml mis à jour"

# 2. Mettre à jour ingress.yaml (HTTP simple)
cat > "$OVERLAY_DIR/ingress.yaml" << EOF
# =============================================================================
# INGRESS HTTP - Domaine: $DOMAIN
# =============================================================================
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: amoona-dev-ingress
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  ingressClassName: traefik
  rules:
    - host: app.$DOMAIN
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: amoona-front
                port:
                  number: 80
    - host: api.$DOMAIN
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: amoona-api
                port:
                  number: 80
    - host: grafana.$DOMAIN
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: grafana
                port:
                  number: 3000
    - host: prometheus.$DOMAIN
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: prometheus
                port:
                  number: 9090
    - host: minio.$DOMAIN
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: minio
                port:
                  number: 9001
    - host: s3.$DOMAIN
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: minio
                port:
                  number: 9000
    - host: registry.$DOMAIN
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: harbor
                port:
                  number: 80
          - path: /v2
            pathType: Prefix
            backend:
              service:
                name: harbor-registry
                port:
                  number: 5000
EOF

log_success "ingress.yaml mis à jour"

# 3. Mettre à jour ingress-tls.yaml (HTTPS)
cat > "$OVERLAY_DIR/ingress-tls.yaml" << EOF
# =============================================================================
# INGRESS HTTPS - Domaine: $DOMAIN
# Généré automatiquement le $(date +%Y-%m-%d)
# =============================================================================
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: amoona-main-ingress-tls
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - app.$DOMAIN
        - api.$DOMAIN
      secretName: amoona-app-tls
    - hosts:
        - grafana.$DOMAIN
        - prometheus.$DOMAIN
      secretName: amoona-monitoring-tls
    - hosts:
        - minio.$DOMAIN
        - s3.$DOMAIN
      secretName: amoona-storage-tls
    - hosts:
        - registry.$DOMAIN
      secretName: harbor-tls
  rules:
    - host: app.$DOMAIN
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: amoona-front
                port:
                  number: 80
    - host: api.$DOMAIN
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: amoona-api
                port:
                  number: 80
    - host: grafana.$DOMAIN
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: grafana
                port:
                  number: 3000
    - host: prometheus.$DOMAIN
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: prometheus
                port:
                  number: 9090
    - host: minio.$DOMAIN
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: minio
                port:
                  number: 9001
    - host: s3.$DOMAIN
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: minio
                port:
                  number: 9000
    - host: registry.$DOMAIN
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: harbor
                port:
                  number: 80
          - path: /v2
            pathType: Prefix
            backend:
              service:
                name: harbor-registry
                port:
                  number: 5000
EOF

log_success "ingress-tls.yaml mis à jour"

# 4. Mettre à jour cert-manager.yaml
cat > "$OVERLAY_DIR/cert-manager.yaml" << EOF
# =============================================================================
# CERT-MANAGER - Let's Encrypt pour $DOMAIN
# =============================================================================
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: $EMAIL
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
      - http01:
          ingress:
            class: traefik
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: $EMAIL
    privateKeySecretRef:
      name: letsencrypt-staging-account-key
    solvers:
      - http01:
          ingress:
            class: traefik
EOF

log_success "cert-manager.yaml mis à jour"

# 5. Mettre à jour l'ingress ArgoCD
cat > "$OVERLAY_DIR/argocd/ingress.yaml" << EOF
# =============================================================================
# INGRESS ARGOCD - $DOMAIN
# =============================================================================
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-ingress
  namespace: argocd
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - argocd.$DOMAIN
      secretName: argocd-tls
  rules:
    - host: argocd.$DOMAIN
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 80
---
apiVersion: v1
kind: Service
metadata:
  name: argocd-server-nodeport
  namespace: argocd
spec:
  type: NodePort
  ports:
    - name: http
      port: 80
      targetPort: 8080
      nodePort: 30080
  selector:
    app.kubernetes.io/name: argocd-server
EOF

log_success "argocd/ingress.yaml mis à jour"

echo ""
log_success "Configuration terminée!"
echo ""
echo "=============================================="
echo "  CONFIGURATION DNS REQUISE"
echo "=============================================="
echo ""
echo "  Ajoutez ces enregistrements DNS chez votre provider:"
echo ""
echo "  Type   Nom                    Valeur"
echo "  ─────────────────────────────────────────────"
echo "  A      @                      $VPS_IP"
echo "  A      app                    $VPS_IP"
echo "  A      api                    $VPS_IP"
echo "  A      argocd                 $VPS_IP"
echo "  A      registry               $VPS_IP"
echo "  A      grafana                $VPS_IP"
echo "  A      prometheus             $VPS_IP"
echo "  A      minio                  $VPS_IP"
echo "  A      s3                     $VPS_IP"
echo ""
echo "  OU utilisez un wildcard:"
echo "  A      *                      $VPS_IP"
echo ""
echo "=============================================="
echo "  URLS (après déploiement)"
echo "=============================================="
echo ""
echo "  HTTP (sans TLS):"
echo "    http://app.$DOMAIN"
echo "    http://api.$DOMAIN"
echo "    http://argocd.$DOMAIN"
echo "    http://registry.$DOMAIN"
echo "    http://grafana.$DOMAIN"
echo ""
echo "  HTTPS (avec TLS - après cert-manager):"
echo "    https://app.$DOMAIN"
echo "    https://api.$DOMAIN"
echo "    https://argocd.$DOMAIN"
echo "    https://registry.$DOMAIN"
echo "    https://grafana.$DOMAIN"
echo ""
echo "=============================================="
echo "  PROCHAINES ÉTAPES"
echo "=============================================="
echo ""
echo "  1. Configurer les DNS chez votre provider"
echo "  2. Attendre la propagation DNS (5-30 min)"
echo "  3. Appliquer la configuration:"
echo "     kubectl apply -k k8s/overlays/dev-light"
echo ""
echo "  4. Pour activer HTTPS (après DNS propagé):"
echo "     kubectl apply -f k8s/overlays/dev-light/cert-manager.yaml"
echo "     kubectl apply -f k8s/overlays/dev-light/ingress-tls.yaml"
echo ""
echo "=============================================="
