#!/bin/bash

#===============================================================================
# create-service.sh - Script interactif pour créer un nouveau service Kubernetes
# Usage: ./scripts/create-service.sh [service-name] [type] [namespace] [image]
#===============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
DEFAULT_NAMESPACE="amoona-dev"
DEFAULT_TYPE="deployment"
DEFAULT_REPLICAS="1"
DEFAULT_PORT="8080"

print_header() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║       🚀 Amoona Kubernetes Service Creator                    ║"
    echo "║                                                               ║"
    echo "║  Créez rapidement un nouveau service pour votre cluster K8s  ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to prompt for input with default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local result

    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " result
        echo "${result:-$default}"
    else
        read -p "$prompt: " result
        echo "$result"
    fi
}

# Function to validate service name
validate_service_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-z][a-z0-9-]*[a-z0-9]$ ]] && [[ ! "$name" =~ ^[a-z]$ ]]; then
        print_error "Le nom du service doit commencer par une lettre minuscule et ne contenir que des lettres minuscules, chiffres et tirets"
        return 1
    fi
    return 0
}

# Function to create deployment manifest
create_deployment() {
    local service_name="$1"
    local image="$2"
    local port="$3"
    local replicas="$4"

    cat << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${service_name}
  labels:
    app: ${service_name}
spec:
  replicas: ${replicas}
  selector:
    matchLabels:
      app: ${service_name}
  template:
    metadata:
      labels:
        app: ${service_name}
    spec:
      containers:
        - name: ${service_name}
          image: ${image}
          ports:
            - containerPort: ${port}
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "200m"
          livenessProbe:
            httpGet:
              path: /health
              port: ${port}
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /ready
              port: ${port}
            initialDelaySeconds: 5
            periodSeconds: 5
EOF
}

# Function to create statefulset manifest
create_statefulset() {
    local service_name="$1"
    local image="$2"
    local port="$3"
    local replicas="$4"

    cat << EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: ${service_name}
  labels:
    app: ${service_name}
spec:
  serviceName: ${service_name}
  replicas: ${replicas}
  selector:
    matchLabels:
      app: ${service_name}
  template:
    metadata:
      labels:
        app: ${service_name}
    spec:
      containers:
        - name: ${service_name}
          image: ${image}
          ports:
            - containerPort: ${port}
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          volumeMounts:
            - name: ${service_name}-data
              mountPath: /data
  volumeClaimTemplates:
    - metadata:
        name: ${service_name}-data
      spec:
        storageClassName: local-path
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 1Gi
EOF
}

# Function to create service manifest
create_service() {
    local service_name="$1"
    local port="$2"
    local target_port="$3"

    cat << EOF
apiVersion: v1
kind: Service
metadata:
  name: ${service_name}
  labels:
    app: ${service_name}
spec:
  type: ClusterIP
  ports:
    - port: ${port}
      targetPort: ${target_port}
      protocol: TCP
      name: http
  selector:
    app: ${service_name}
EOF
}

# Function to create configmap manifest
create_configmap() {
    local service_name="$1"

    cat << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${service_name}-config
  labels:
    app: ${service_name}
data:
  # Add your configuration here
  APP_ENV: "production"
  LOG_LEVEL: "info"
EOF
}

# Function to create kustomization.yaml
create_kustomization() {
    local service_name="$1"
    local workload_type="$2"

    cat << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ${workload_type}.yaml
  - service.yaml
  - configmap.yaml

labels:
  - pairs:
      app: ${service_name}
      tier: application
EOF
}

# Function to create ingress patch
create_ingress_patch() {
    local service_name="$1"
    local port="$2"
    local subdomain="$3"
    local env="$4"

    local domain
    if [ "$env" == "prod" ]; then
        domain="${subdomain}.amoona.tech"
    else
        domain="${subdomain}.dev.amoona.tech"
    fi

    cat << EOF
# Add this to k8s/overlays/${env}/ingress-patch.yaml
# Under spec.rules:

    # ${service_name}
    - host: ${domain}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${service_name}
                port:
                  number: ${port}
EOF
}

# Main script
main() {
    print_header

    # Get service name
    local SERVICE_NAME="${1:-}"
    if [ -z "$SERVICE_NAME" ]; then
        SERVICE_NAME=$(prompt_with_default "Nom du service (ex: my-api)" "")
    fi

    if [ -z "$SERVICE_NAME" ]; then
        print_error "Le nom du service est requis"
        exit 1
    fi

    if ! validate_service_name "$SERVICE_NAME"; then
        exit 1
    fi

    # Get workload type
    local WORKLOAD_TYPE="${2:-}"
    if [ -z "$WORKLOAD_TYPE" ]; then
        echo ""
        echo "Type de workload:"
        echo "  1) deployment (recommandé pour les applications stateless)"
        echo "  2) statefulset (pour les applications avec état persistant)"
        WORKLOAD_TYPE=$(prompt_with_default "Choisissez [1/2]" "1")
        case "$WORKLOAD_TYPE" in
            1|deployment) WORKLOAD_TYPE="deployment" ;;
            2|statefulset) WORKLOAD_TYPE="statefulset" ;;
            *) WORKLOAD_TYPE="deployment" ;;
        esac
    fi

    # Get namespace/environment
    local NAMESPACE="${3:-}"
    if [ -z "$NAMESPACE" ]; then
        echo ""
        echo "Environnement cible:"
        echo "  1) dev (amoona-dev)"
        echo "  2) prod (amoona-prod)"
        local env_choice=$(prompt_with_default "Choisissez [1/2]" "1")
        case "$env_choice" in
            1|dev) NAMESPACE="amoona-dev"; ENV="dev" ;;
            2|prod) NAMESPACE="amoona-prod"; ENV="prod" ;;
            *) NAMESPACE="amoona-dev"; ENV="dev" ;;
        esac
    else
        if [[ "$NAMESPACE" == *"prod"* ]]; then
            ENV="prod"
        else
            ENV="dev"
        fi
    fi

    # Get image
    local IMAGE="${4:-}"
    if [ -z "$IMAGE" ]; then
        IMAGE=$(prompt_with_default "Image Docker" "nginx:alpine")
    fi

    # Get port
    local PORT=$(prompt_with_default "Port du conteneur" "$DEFAULT_PORT")

    # Get replicas
    local REPLICAS=$(prompt_with_default "Nombre de replicas" "$DEFAULT_REPLICAS")

    # Ask about ingress
    echo ""
    local NEED_INGRESS=$(prompt_with_default "Exposer via Ingress? (y/n)" "y")
    local SUBDOMAIN=""
    if [[ "$NEED_INGRESS" =~ ^[Yy]$ ]]; then
        SUBDOMAIN=$(prompt_with_default "Sous-domaine (ex: api pour api.amoona.tech)" "$SERVICE_NAME")
    fi

    # Confirmation
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                    Récapitulatif                              ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo "  Service:     $SERVICE_NAME"
    echo "  Type:        $WORKLOAD_TYPE"
    echo "  Namespace:   $NAMESPACE"
    echo "  Image:       $IMAGE"
    echo "  Port:        $PORT"
    echo "  Replicas:    $REPLICAS"
    if [ -n "$SUBDOMAIN" ]; then
        if [ "$ENV" == "prod" ]; then
            echo "  URL:         https://${SUBDOMAIN}.amoona.tech"
        else
            echo "  URL:         https://${SUBDOMAIN}.dev.amoona.tech"
        fi
    fi
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    local CONFIRM=$(prompt_with_default "Créer ce service? (y/n)" "y")
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        print_warning "Création annulée"
        exit 0
    fi

    # Create directory structure
    local SERVICE_DIR="k8s/base/apps/${SERVICE_NAME}"

    print_info "Création du répertoire ${SERVICE_DIR}..."
    mkdir -p "$SERVICE_DIR"

    # Create manifests
    print_info "Création des manifests Kubernetes..."

    if [ "$WORKLOAD_TYPE" == "deployment" ]; then
        create_deployment "$SERVICE_NAME" "$IMAGE" "$PORT" "$REPLICAS" > "${SERVICE_DIR}/deployment.yaml"
    else
        create_statefulset "$SERVICE_NAME" "$IMAGE" "$PORT" "$REPLICAS" > "${SERVICE_DIR}/statefulset.yaml"
    fi

    create_service "$SERVICE_NAME" "$PORT" "$PORT" > "${SERVICE_DIR}/service.yaml"
    create_configmap "$SERVICE_NAME" > "${SERVICE_DIR}/configmap.yaml"
    create_kustomization "$SERVICE_NAME" "$WORKLOAD_TYPE" > "${SERVICE_DIR}/kustomization.yaml"

    # Update apps kustomization.yaml
    local APPS_KUSTOMIZATION="k8s/base/apps/kustomization.yaml"
    if ! grep -q "- ${SERVICE_NAME}" "$APPS_KUSTOMIZATION" 2>/dev/null; then
        print_info "Mise à jour de ${APPS_KUSTOMIZATION}..."
        echo "  - ${SERVICE_NAME}" >> "$APPS_KUSTOMIZATION"
    fi

    # Create ingress patch instructions
    if [ -n "$SUBDOMAIN" ]; then
        echo ""
        print_info "Configuration Ingress à ajouter:"
        echo ""
        create_ingress_patch "$SERVICE_NAME" "$PORT" "$SUBDOMAIN" "$ENV"
        echo ""
    fi

    # Summary
    echo ""
    print_success "Service ${SERVICE_NAME} créé avec succès!"
    echo ""
    echo -e "${GREEN}Fichiers créés:${NC}"
    ls -la "${SERVICE_DIR}/"
    echo ""
    echo -e "${YELLOW}Prochaines étapes:${NC}"
    echo "  1. Vérifier les manifests générés dans ${SERVICE_DIR}/"
    echo "  2. Ajuster les configurations si nécessaire"
    if [ -n "$SUBDOMAIN" ]; then
        echo "  3. Ajouter la configuration Ingress (voir ci-dessus)"
    fi
    echo "  4. Commit et push:"
    echo ""
    echo -e "${CYAN}     git add ${SERVICE_DIR}/ ${APPS_KUSTOMIZATION}${NC}"
    echo -e "${CYAN}     git commit -m \"feat: add ${SERVICE_NAME} service\"${NC}"
    echo -e "${CYAN}     git push origin main${NC}"
    echo ""
    echo "  5. GitHub Actions déploiera automatiquement le service!"
    echo ""
}

# Run main function
main "$@"
