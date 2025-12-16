#!/bin/bash
# =============================================================================
# Script de déploiement pour environnement léger (4 CPU / 16 Go RAM)
# =============================================================================
# Usage: ./scripts/deploy-dev-light.sh [--domain DOMAIN] [--email EMAIL]
# VPS: 195.35.2.238
#
# Options:
#   --domain DOMAIN    Domaine personnalisé (ex: amoona.tech)
#   --email EMAIL      Email pour Let's Encrypt
#   --enable-tls       Activer HTTPS avec Let's Encrypt
#   --help             Afficher l'aide
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

# Configuration VPS
VPS_IP="195.35.2.238"
DOMAIN=""
EMAIL=""
ENABLE_TLS=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --email)
            EMAIL="$2"
            shift 2
            ;;
        --enable-tls)
            ENABLE_TLS=true
            shift
            ;;
        --help)
            echo "Usage: $0 [--domain DOMAIN] [--email EMAIL] [--enable-tls]"
            echo ""
            echo "Options:"
            echo "  --domain DOMAIN    Domaine personnalisé (ex: amoona.tech)"
            echo "  --email EMAIL      Email pour Let's Encrypt"
            echo "  --enable-tls       Activer HTTPS avec Let's Encrypt"
            exit 0
            ;;
        *)
            echo "Option inconnue: $1"
            exit 1
            ;;
    esac
done

# Si pas de domaine spécifié, utiliser nip.io
if [[ -z "$DOMAIN" ]]; then
    DOMAIN="$VPS_IP.nip.io"
fi

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo "=============================================="
echo "  Amoona - Déploiement Environnement Léger"
echo "  VPS: $VPS_IP (4 CPU / 16 Go RAM)"
echo "  Domaine: $DOMAIN"
if [[ "$ENABLE_TLS" == "true" ]]; then
echo "  TLS: Activé (Let's Encrypt)"
fi
echo "=============================================="
echo ""

# Vérifier les prérequis
log_info "Vérification des prérequis..."

if ! command -v kubectl &> /dev/null; then
    log_error "kubectl n'est pas installé"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    log_error "Impossible de se connecter au cluster Kubernetes"
    exit 1
fi

log_success "Prérequis OK"

# =============================================================================
# CONFIGURATION DES DOMAINES
# =============================================================================
log_info "Configuration des domaines pour: $DOMAIN"

# Mettre à jour le fichier dns-config.yaml
cat > "$PROJECT_ROOT/k8s/overlays/dev-light/dns-config.yaml" << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: dns-config
  labels:
    app: amoona
data:
  BASE_DOMAIN: "$DOMAIN"
  VPS_IP: "$VPS_IP"
  ADMIN_EMAIL: "${EMAIL:-admin@$DOMAIN}"
  FRONTEND_HOST: "app.$DOMAIN"
  API_HOST: "api.$DOMAIN"
  ARGOCD_HOST: "argocd.$DOMAIN"
  HARBOR_HOST: "registry.$DOMAIN"
  GRAFANA_HOST: "grafana.$DOMAIN"
  PROMETHEUS_HOST: "prometheus.$DOMAIN"
  MINIO_HOST: "minio.$DOMAIN"
  MINIO_S3_HOST: "s3.$DOMAIN"
EOF

# Mettre à jour l'ingress avec les bons domaines
cat > "$PROJECT_ROOT/k8s/overlays/dev-light/ingress.yaml" << EOF
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

log_success "Ingress configuré pour $DOMAIN"

# Générer les secrets
log_info "Génération des secrets..."
"$SCRIPT_DIR/generate-secrets-dev-light.sh"

# Créer le namespace si nécessaire
log_info "Création du namespace amoona-dev..."
kubectl create namespace amoona-dev --dry-run=client -o yaml | kubectl apply -f -

# Créer le secret pour GHCR si nécessaire
if ! kubectl get secret ghcr-secret -n amoona-dev &> /dev/null; then
    log_warning "Le secret ghcr-secret n'existe pas"
    echo ""
    echo "Créez-le avec:"
    echo "  kubectl create secret docker-registry ghcr-secret \\"
    echo "    --docker-server=ghcr.io \\"
    echo "    --docker-username=YOUR_GITHUB_USERNAME \\"
    echo "    --docker-password=YOUR_GITHUB_TOKEN \\"
    echo "    -n amoona-dev"
    echo ""
    read -p "Appuyez sur Entrée pour continuer ou Ctrl+C pour annuler..."
fi

# Créer la base de données Harbor dans PostgreSQL
log_info "Préparation de la base de données Harbor..."

# Déployer l'infrastructure
log_info "Déploiement de l'infrastructure..."
kubectl apply -k "$PROJECT_ROOT/k8s/overlays/dev-light"

# Attendre PostgreSQL
log_info "Attente de PostgreSQL..."
kubectl wait --for=condition=ready pod -l app=postgres -n amoona-dev --timeout=300s || {
    log_warning "PostgreSQL n'est pas prêt dans le délai imparti"
}

# Créer la base de données Harbor
log_info "Création de la base de données Harbor..."
kubectl exec -it statefulset/postgres -n amoona-dev -- psql -U amoona -d postgres -c "CREATE DATABASE harbor OWNER amoona;" 2>/dev/null || {
    log_info "La base de données harbor existe peut-être déjà"
}
kubectl exec -it statefulset/postgres -n amoona-dev -- psql -U amoona -d postgres -c "CREATE USER harbor WITH PASSWORD 'harbor_db_password';" 2>/dev/null || true
kubectl exec -it statefulset/postgres -n amoona-dev -- psql -U amoona -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE harbor TO harbor;" 2>/dev/null || true

# Attendre les autres services
log_info "Attente des services..."

for deploy in redis minio grafana prometheus; do
    log_info "Attente de $deploy..."
    kubectl wait --for=condition=available deployment/$deploy -n amoona-dev --timeout=180s || {
        log_warning "$deploy n'est pas prêt"
    }
done

# Attendre Harbor
for deploy in harbor-core harbor-registry harbor-portal; do
    log_info "Attente de $deploy..."
    kubectl wait --for=condition=available deployment/$deploy -n amoona-dev --timeout=180s || {
        log_warning "$deploy n'est pas prêt"
    }
done

# Afficher le statut
echo ""
log_info "Statut du déploiement:"
echo "========================"
kubectl get pods -n amoona-dev

echo ""
log_info "Services déployés:"
echo "==================="
kubectl get svc -n amoona-dev

echo ""
log_info "Stockage:"
echo "========="
kubectl get pvc -n amoona-dev

# =============================================================================
# INSTALLATION DE ARGOCD
# =============================================================================
log_info "Installation d'ArgoCD..."

# Créer le namespace ArgoCD
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Installer ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

log_info "Attente du démarrage d'ArgoCD..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s || {
    log_warning "ArgoCD n'est pas prêt dans le délai imparti, continuez manuellement"
}

# Appliquer l'ingress et les applications ArgoCD
log_info "Configuration des applications ArgoCD..."
kubectl apply -f "$PROJECT_ROOT/k8s/overlays/dev-light/argocd/ingress.yaml"
kubectl apply -f "$PROJECT_ROOT/k8s/overlays/dev-light/argocd/applications.yaml"

# Récupérer le mot de passe admin ArgoCD
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "non disponible encore")

# Mettre à jour l'ingress ArgoCD avec le bon domaine
cat > "$PROJECT_ROOT/k8s/overlays/dev-light/argocd/ingress.yaml" << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-ingress
  namespace: argocd
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  ingressClassName: traefik
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

kubectl apply -f "$PROJECT_ROOT/k8s/overlays/dev-light/argocd/ingress.yaml"

echo ""
log_success "Déploiement terminé!"
echo ""
echo "=============================================="
echo "  SERVICES DISPONIBLES"
echo "  Domaine: $DOMAIN"
echo "  VPS: $VPS_IP"
echo "=============================================="
echo ""
echo "  Application:"
echo "    Frontend:    http://app.$DOMAIN"
echo "    API:         http://api.$DOMAIN"
echo ""
echo "  DevOps:"
echo "    ArgoCD:      http://argocd.$DOMAIN"
echo "                 ou http://$VPS_IP:30080"
echo "                 User: admin"
echo "                 Pass: $ARGOCD_PASSWORD"
echo ""
echo "    Harbor:      http://registry.$DOMAIN"
echo "    Grafana:     http://grafana.$DOMAIN"
echo "    Prometheus:  http://prometheus.$DOMAIN"
echo "    MinIO:       http://minio.$DOMAIN"
echo ""
echo "=============================================="
echo "  CONFIGURATION DNS REQUISE"
echo "=============================================="
echo ""
if [[ "$DOMAIN" != *"nip.io"* ]]; then
echo "  Ajoutez ces enregistrements DNS:"
echo ""
echo "    Type   Nom         Valeur"
echo "    A      @           $VPS_IP"
echo "    A      app         $VPS_IP"
echo "    A      api         $VPS_IP"
echo "    A      argocd      $VPS_IP"
echo "    A      registry    $VPS_IP"
echo "    A      grafana     $VPS_IP"
echo "    A      prometheus  $VPS_IP"
echo "    A      minio       $VPS_IP"
echo "    A      s3          $VPS_IP"
echo ""
echo "  OU wildcard:  A   *   $VPS_IP"
echo ""
else
echo "  Utilisation de nip.io - pas de configuration DNS nécessaire"
echo ""
fi
echo "=============================================="
echo "  ARGOCD - LIVRAISON AUTOMATIQUE"
echo "=============================================="
echo ""
echo "  ArgoCD surveille la branche 'dev' du repository:"
echo "  https://github.com/hypnozSarl/amoona-deployer.git"
echo ""
echo "  Workflow de déploiement automatique:"
echo "  1. Push sur la branche 'dev'"
echo "  2. ArgoCD détecte le changement (sync auto)"
echo "  3. Les nouvelles configurations sont appliquées"
echo ""
echo "=============================================="
echo "  CONFIGURATION GITLAB CI/CD"
echo "=============================================="
echo ""
echo "  Pour pousser des images vers Harbor:"
echo ""
echo "  1. Configurer Docker pour Harbor:"
echo "     {\"insecure-registries\": [\"registry.$DOMAIN\"]}"
echo ""
echo "  2. Login:"
echo "     docker login registry.$DOMAIN -u admin"
echo ""
echo "  3. Variables GitLab CI/CD:"
echo "     HARBOR_URL=registry.$DOMAIN"
echo "     HARBOR_USER=admin"
echo "     HARBOR_PASSWORD=(mot de passe Harbor)"
echo ""
echo "=============================================="
echo ""
echo "  Pour activer HTTPS avec Let's Encrypt:"
echo "  ./scripts/configure-domains.sh $DOMAIN $EMAIL $VPS_IP"
echo ""
echo "=============================================="
