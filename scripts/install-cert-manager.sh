#!/bin/bash
# Script d'installation de cert-manager pour Kubernetes
# Usage: ./scripts/install-cert-manager.sh

set -e

CERT_MANAGER_VERSION="v1.14.4"

echo "=== Installation de cert-manager ${CERT_MANAGER_VERSION} ==="

# Vérifier si kubectl est disponible
if ! command -v kubectl &> /dev/null; then
    echo "Erreur: kubectl n'est pas installé"
    exit 1
fi

# Vérifier la connexion au cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "Erreur: Impossible de se connecter au cluster Kubernetes"
    exit 1
fi

echo "1. Application des CRDs cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.crds.yaml

echo "2. Création du namespace cert-manager..."
kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -

echo "3. Installation de cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml

echo "4. Attente du démarrage des pods cert-manager..."
kubectl -n cert-manager rollout status deployment/cert-manager --timeout=120s
kubectl -n cert-manager rollout status deployment/cert-manager-webhook --timeout=120s
kubectl -n cert-manager rollout status deployment/cert-manager-cainjector --timeout=120s

echo "5. Vérification de l'installation..."
kubectl get pods -n cert-manager

echo ""
echo "=== cert-manager installé avec succès ==="
echo ""
echo "Prochaines étapes:"
echo "1. Appliquer les ClusterIssuers: kubectl apply -k k8s/base/cert-manager/"
echo "2. Vérifier les issuers: kubectl get clusterissuers"
echo "3. Redéployer les ingress pour obtenir les certificats"
