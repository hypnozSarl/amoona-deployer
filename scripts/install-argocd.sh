#!/bin/bash
set -e

echo "=== Installation d'ArgoCD ==="

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Vérifier kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl n'est pas installé${NC}"
    exit 1
fi

# Vérifier la connexion au cluster
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Impossible de se connecter au cluster Kubernetes${NC}"
    exit 1
fi

echo -e "${GREEN}Connexion au cluster OK${NC}"

# Créer le namespace argocd
echo -e "${YELLOW}Création du namespace argocd...${NC}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Installer ArgoCD
echo -e "${YELLOW}Installation d'ArgoCD v2.13.2...${NC}"
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.13.2/manifests/install.yaml

# Attendre que les pods soient prêts
echo -e "${YELLOW}Attente du démarrage des pods ArgoCD...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n argocd
kubectl wait --for=condition=available --timeout=300s deployment/argocd-redis -n argocd

echo -e "${GREEN}ArgoCD installé avec succès${NC}"

# Configurer le serveur pour le mode insecure (TLS géré par Ingress)
echo -e "${YELLOW}Configuration du mode insecure pour Traefik...${NC}"
kubectl patch deployment argocd-server -n argocd --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/command",
    "value": ["argocd-server", "--insecure"]
  }
]'

# Appliquer l'Ingress
echo -e "${YELLOW}Application de l'Ingress...${NC}"
kubectl apply -f /Users/mbayebabacarsarr/IdeaProjects/amoona-deployer/k8s/base/argocd/ingress.yaml

# Récupérer le mot de passe admin initial
echo -e "${YELLOW}Récupération du mot de passe admin...${NC}"
sleep 10
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo ""
echo -e "${GREEN}=== ArgoCD Installé ===${NC}"
echo ""
echo -e "URL: ${GREEN}https://argocd.dev.amoona.tech${NC}"
echo -e "Username: ${GREEN}admin${NC}"
echo -e "Password: ${GREEN}${ARGOCD_PASSWORD}${NC}"
echo ""
echo -e "${YELLOW}Note: Gardez ce mot de passe en lieu sûr et changez-le après la première connexion.${NC}"
echo ""
echo -e "Pour changer le mot de passe:"
echo -e "  argocd login argocd.dev.amoona.tech"
echo -e "  argocd account update-password"
echo ""
