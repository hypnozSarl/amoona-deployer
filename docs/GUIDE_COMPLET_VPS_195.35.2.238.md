# GUIDE COMPLET D'INSTALLATION ET D'ACCÈS À DISTANCE

## VPS 195.35.2.238 - Environnement de Développement

**Version:** 2.0
**Date:** Décembre 2024
**Configuration:** 4 CPU / 16 Go RAM

---

# TABLE DES MATIÈRES

1. [Prérequis et Préparation](#1-prérequis-et-préparation)
2. [Installation de Kubernetes (K3s)](#2-installation-de-kubernetes-k3s)
3. [Déploiement de l'Infrastructure](#3-déploiement-de-linfrastructure)
4. [Configuration des Noms de Domaine](#4-configuration-des-noms-de-domaine)
5. [Accès à Distance aux Services](#5-accès-à-distance-aux-services)
6. [Configuration ArgoCD (GitOps)](#6-configuration-argocd-gitops)
7. [Configuration Harbor (Registry Docker)](#7-configuration-harbor-registry-docker)
8. [Intégration GitLab CI/CD](#8-intégration-gitlab-cicd)
9. [Sécurité et Pare-feu](#9-sécurité-et-pare-feu)
10. [Maintenance et Dépannage](#10-maintenance-et-dépannage)

---

# 1. Prérequis et Préparation

## 1.1 Informations du VPS

| Paramètre | Valeur |
|-----------|--------|
| **IP Publique** | 195.35.2.238 |
| **CPU** | 4 cores |
| **RAM** | 16 Go |
| **OS** | Ubuntu 22.04 LTS |
| **Domaine** | amoona.tech (ou nip.io) |

## 1.2 Connexion SSH

```bash
# Connexion au VPS
ssh root@195.35.2.238

# Ou avec clé SSH
ssh -i ~/.ssh/votre_cle root@195.35.2.238
```

## 1.3 Mise à Jour et Installation des Dépendances

```bash
# Mise à jour du système
apt update && apt upgrade -y

# Installation des dépendances
apt install -y \
    curl \
    git \
    jq \
    openssl \
    htop \
    ufw
```

## 1.4 Configuration Système pour Kubernetes

```bash
# Désactiver le swap (OBLIGATOIRE)
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Modules kernel
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Paramètres sysctl
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
vm.max_map_count                    = 262144
EOF

sysctl --system
```

## 1.5 Configuration du Pare-feu (UFW)

```bash
# Activer UFW
ufw enable

# Ports essentiels
ufw allow 22/tcp       # SSH
ufw allow 80/tcp       # HTTP
ufw allow 443/tcp      # HTTPS
ufw allow 6443/tcp     # Kubernetes API (accès kubectl distant)

# NodePorts pour accès direct aux services
ufw allow 30080/tcp    # ArgoCD
ufw allow 30443/tcp    # ArgoCD HTTPS
ufw allow 30000:32767/tcp  # Range NodePort complet (optionnel)

# Vérifier
ufw status verbose
```

---

# 2. Installation de Kubernetes (K3s)

## 2.1 Installer K3s

```bash
# Installation de K3s
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644

# Attendre le démarrage (30-60 secondes)
sleep 30

# Vérifier l'installation
k3s kubectl get nodes
```

## 2.2 Configurer kubectl

```bash
# Configuration pour l'utilisateur root
mkdir -p ~/.kube
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config

# Vérifier
kubectl get nodes
kubectl cluster-info
```

## 2.3 Installer Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

---

# 3. Déploiement de l'Infrastructure

## 3.1 Cloner le Repository

```bash
cd ~
git clone https://github.com/hypnozSarl/amoona-deployer.git
cd amoona-deployer

# Basculer sur la branche dev
git checkout dev
```

## 3.2 Créer le Secret pour GitLab Container Registry

```bash
# Créer le namespace
kubectl create namespace amoona-dev

# Créer le secret pour accéder aux images Docker privées sur GitLab
kubectl create secret docker-registry gitlab-registry-secret \
    --docker-server=registry.gitlab.com \
    --docker-username=mbsdev \
    --docker-password=glpat-bLwMr8VZJkOCGY1jHgg58W86MQp1OjJzY2phCw.01.121j53mc1 \
    -n amoona-dev

# Note: Le token GitLab doit avoir les droits "read_registry" et "write_registry"
# Créer un token sur: GitLab > Settings > Access Tokens
```

## 3.3 Générer les Secrets

```bash
# Rendre le script exécutable
chmod +x scripts/generate-secrets-dev-light.sh

# Générer les secrets
./scripts/generate-secrets-dev-light.sh

# ⚠️ IMPORTANT: Notez les mots de passe affichés !
```

## 3.4 Déployer l'Infrastructure

### Option A: Avec domaine personnalisé (recommandé)

```bash
chmod +x scripts/deploy-dev-light.sh

# Déployer avec votre domaine
./scripts/deploy-dev-light.sh --domain amoona.tech --email admin@amoona.tech
```

### Option B: Sans domaine (utilise nip.io)

```bash
# Les URLs seront: app.195.35.2.238.nip.io, api.195.35.2.238.nip.io, etc.
./scripts/deploy-dev-light.sh
```

## 3.5 Vérifier le Déploiement

```bash
# Voir tous les pods (attendre que tous soient "Running")
kubectl get pods -n amoona-dev -w

# Voir les services
kubectl get svc -n amoona-dev

# Voir les ingress
kubectl get ingress -n amoona-dev
```

---

# 4. Configuration des Noms de Domaine

## 4.1 Option 1: Utiliser nip.io (Sans Configuration DNS)

nip.io est un service DNS wildcard gratuit. Pas de configuration nécessaire.

| Service | URL |
|---------|-----|
| Frontend | http://app.195.35.2.238.nip.io |
| API | http://api.195.35.2.238.nip.io |
| ArgoCD | http://argocd.195.35.2.238.nip.io |
| Harbor | http://registry.195.35.2.238.nip.io |
| Grafana | http://grafana.195.35.2.238.nip.io |
| Prometheus | http://prometheus.195.35.2.238.nip.io |
| MinIO | http://minio.195.35.2.238.nip.io |

## 4.2 Option 2: Domaine Personnalisé (amoona.tech)

### Configuration DNS chez votre Provider

Connectez-vous à votre provider DNS (OVH, Cloudflare, Gandi, etc.) et ajoutez:

```
Type   Nom              Valeur           TTL
───────────────────────────────────────────────
A      @                195.35.2.238     3600
A      app              195.35.2.238     3600
A      api              195.35.2.238     3600
A      argocd           195.35.2.238     3600
A      registry         195.35.2.238     3600
A      grafana          195.35.2.238     3600
A      prometheus       195.35.2.238     3600
A      minio            195.35.2.238     3600
A      s3               195.35.2.238     3600
```

**OU simplement un wildcard:**

```
Type   Nom              Valeur           TTL
───────────────────────────────────────────────
A      @                195.35.2.238     3600
A      *                195.35.2.238     3600
```

### Vérifier la Propagation DNS

```bash
# Tester depuis votre machine locale
nslookup app.amoona.tech
dig app.amoona.tech

# Ou utiliser un outil en ligne
# https://dnschecker.org/
```

### URLs avec Domaine Personnalisé

| Service | URL |
|---------|-----|
| Frontend | http://app.amoona.tech |
| API | http://api.amoona.tech |
| ArgoCD | http://argocd.amoona.tech |
| Harbor | http://registry.amoona.tech |
| Grafana | http://grafana.amoona.tech |
| Prometheus | http://prometheus.amoona.tech |
| MinIO | http://minio.amoona.tech |

## 4.3 Activer HTTPS avec Let's Encrypt

```bash
# 1. Installer cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

# Attendre que cert-manager soit prêt (2-3 minutes)
kubectl wait --for=condition=available deployment/cert-manager -n cert-manager --timeout=300s

# 2. Appliquer la configuration TLS
kubectl apply -f k8s/overlays/dev-light/cert-manager.yaml
kubectl apply -f k8s/overlays/dev-light/ingress-tls.yaml

# 3. Vérifier les certificats
kubectl get certificates -n amoona-dev
kubectl get certificaterequests -n amoona-dev
```

---

# 5. Accès à Distance aux Services

## 5.1 Méthode 1: Via Ingress (Recommandé)

Les services sont accessibles via les URLs configurées dans l'ingress.

### Avec nip.io:
- http://app.195.35.2.238.nip.io
- http://api.195.35.2.238.nip.io
- http://grafana.195.35.2.238.nip.io

### Avec domaine personnalisé:
- http://app.amoona.tech
- http://api.amoona.tech
- http://grafana.amoona.tech

## 5.2 Méthode 2: Via NodePort (Accès Direct)

Certains services ont des NodePorts configurés pour un accès direct:

| Service | URL NodePort |
|---------|--------------|
| ArgoCD | http://195.35.2.238:30080 |

### Ajouter des NodePorts pour d'autres services

```bash
# Exemple: Exposer Grafana sur NodePort 30030
kubectl patch svc grafana -n amoona-dev -p '{"spec": {"type": "NodePort", "ports": [{"port": 3000, "nodePort": 30030}]}}'

# Accès: http://195.35.2.238:30030
```

## 5.3 Méthode 3: Via Port-Forward (Développement/Debug)

Depuis votre machine locale avec kubectl configuré:

```bash
# Grafana
kubectl port-forward svc/grafana -n amoona-dev 3000:3000
# Accès: http://localhost:3000

# Prometheus
kubectl port-forward svc/prometheus -n amoona-dev 9090:9090
# Accès: http://localhost:9090

# Harbor
kubectl port-forward svc/harbor -n amoona-dev 8080:80
# Accès: http://localhost:8080

# MinIO Console
kubectl port-forward svc/minio -n amoona-dev 9001:9001
# Accès: http://localhost:9001

# PostgreSQL
kubectl port-forward svc/postgres -n amoona-dev 5432:5432
# Connexion: psql -h localhost -U amoona -d amoona_db

# Redis
kubectl port-forward svc/redis -n amoona-dev 6379:6379
# Connexion: redis-cli -h localhost
```

### Script de Port-Forward Automatique

Créez ce script sur votre machine locale:

```bash
#!/bin/bash
# port-forward-all.sh

echo "Démarrage des port-forwards vers 195.35.2.238..."

# Arrêter les anciens port-forwards
pkill -f "kubectl port-forward" 2>/dev/null

# Démarrer les port-forwards
kubectl port-forward svc/grafana -n amoona-dev 3000:3000 &
kubectl port-forward svc/prometheus -n amoona-dev 9090:9090 &
kubectl port-forward svc/harbor -n amoona-dev 8080:80 &
kubectl port-forward svc/minio -n amoona-dev 9001:9001 &
kubectl port-forward svc/postgres -n amoona-dev 5432:5432 &
kubectl port-forward svc/redis -n amoona-dev 6379:6379 &

echo ""
echo "Services accessibles:"
echo "  Grafana:    http://localhost:3000"
echo "  Prometheus: http://localhost:9090"
echo "  Harbor:     http://localhost:8080"
echo "  MinIO:      http://localhost:9001"
echo "  PostgreSQL: localhost:5432"
echo "  Redis:      localhost:6379"
echo ""
echo "Ctrl+C pour arrêter"
wait
```

## 5.4 Configurer kubectl sur votre Machine Locale

### Copier le Kubeconfig depuis le VPS

```bash
# Sur votre machine locale
mkdir -p ~/.kube

# Copier le fichier depuis le VPS
scp root@195.35.2.238:/etc/rancher/k3s/k3s.yaml ~/.kube/config-amoona

# Modifier l'adresse du serveur (remplacer 127.0.0.1 par l'IP publique)
sed -i 's/127.0.0.1/195.35.2.238/g' ~/.kube/config-amoona

# Utiliser ce kubeconfig
export KUBECONFIG=~/.kube/config-amoona

# Tester la connexion
kubectl get nodes
```

### Fusionner avec votre Config Existante (Optionnel)

```bash
# Backup de l'ancienne config
cp ~/.kube/config ~/.kube/config.backup

# Fusionner les configs
KUBECONFIG=~/.kube/config:~/.kube/config-amoona kubectl config view --flatten > ~/.kube/config-merged
mv ~/.kube/config-merged ~/.kube/config

# Voir les contextes disponibles
kubectl config get-contexts

# Basculer vers le contexte amoona
kubectl config use-context default  # ou le nom du contexte
```

## 5.5 Tableau Récapitulatif des Accès

| Service | Ingress (nip.io) | Ingress (domaine) | NodePort | Port-Forward |
|---------|------------------|-------------------|----------|--------------|
| **Frontend** | app.195.35.2.238.nip.io | app.amoona.tech | - | localhost:8082 |
| **API** | api.195.35.2.238.nip.io | api.amoona.tech | - | localhost:8081 |
| **ArgoCD** | argocd.195.35.2.238.nip.io | argocd.amoona.tech | 195.35.2.238:30080 | localhost:8080 |
| **Harbor** | registry.195.35.2.238.nip.io | registry.amoona.tech | - | localhost:8080 |
| **Grafana** | grafana.195.35.2.238.nip.io | grafana.amoona.tech | - | localhost:3000 |
| **Prometheus** | prometheus.195.35.2.238.nip.io | prometheus.amoona.tech | - | localhost:9090 |
| **MinIO** | minio.195.35.2.238.nip.io | minio.amoona.tech | - | localhost:9001 |
| **PostgreSQL** | - | - | - | localhost:5432 |
| **Redis** | - | - | - | localhost:6379 |

---

# 6. Configuration ArgoCD (GitOps)

## 6.1 Accéder à ArgoCD

**URL:** http://argocd.195.35.2.238.nip.io ou http://195.35.2.238:30080

**Credentials:**
```bash
# Username
admin

# Password (récupérer sur le VPS)
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

## 6.2 Applications Configurées

ArgoCD surveille automatiquement la branche `dev`:

| Application | Path | Description |
|-------------|------|-------------|
| amoona-infra-dev | k8s/overlays/dev-light | Infrastructure complète |
| amoona-api-dev | k8s/overlays/dev-light/apps/amoona-api | API Backend |
| amoona-front-dev | k8s/overlays/dev-light/apps/amoona-front | Frontend |

## 6.3 Workflow de Déploiement Automatique

```
┌─────────────────┐
│  Développeur    │
│  git push dev   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  GitHub         │
│  Branche dev    │
└────────┬────────┘
         │
         ▼ (webhook ou polling)
┌─────────────────┐
│  ArgoCD         │
│  Détecte le     │
│  changement     │
└────────┬────────┘
         │
         ▼ (sync automatique)
┌─────────────────┐
│  Kubernetes     │
│  195.35.2.238   │
│  Déploiement    │
└─────────────────┘
```

## 6.4 Mettre à Jour une Image

1. Modifier le tag dans `k8s/overlays/dev-light/apps/amoona-api/kustomization.yaml`:
```yaml
images:
  - name: ghcr.io/hypnozsarl/amoona-api
    newTag: "NOUVEAU_TAG"
```

2. Commit et push:
```bash
git add .
git commit -m "chore(dev): update amoona-api to NOUVEAU_TAG"
git push origin dev
```

3. ArgoCD synchronise automatiquement (3-5 minutes)

---

# 7. Configuration Harbor (Registry Docker)

## 7.1 Accéder à Harbor

**URL:** http://registry.195.35.2.238.nip.io ou http://registry.amoona.tech

**Credentials:**
```bash
# Username
admin

# Password
kubectl get secret harbor-secret -n amoona-dev -o jsonpath='{.data.HARBOR_ADMIN_PASSWORD}' | base64 -d && echo
```

## 7.2 Créer un Projet dans Harbor

1. Connectez-vous à Harbor
2. Cliquez sur **"New Project"**
3. Nom: `amoona`
4. Access Level: **Private**
5. Cliquez sur **OK**

## 7.3 Configurer Docker pour Harbor

Sur la machine qui build les images (GitLab Runner, local, etc.):

```bash
# Ajouter Harbor comme registry non sécurisé (HTTP)
sudo cat > /etc/docker/daemon.json << 'EOF'
{
  "insecure-registries": [
    "registry.195.35.2.238.nip.io",
    "registry.amoona.tech"
  ]
}
EOF

# Redémarrer Docker
sudo systemctl restart docker

# Login
docker login registry.195.35.2.238.nip.io -u admin
# Entrer le mot de passe Harbor
```

## 7.4 Pousser une Image vers Harbor

```bash
# Build l'image
docker build -t registry.195.35.2.238.nip.io/amoona/mon-app:v1.0 .

# Push vers Harbor
docker push registry.195.35.2.238.nip.io/amoona/mon-app:v1.0
```

---

# 8. Intégration GitLab CI/CD

## 8.1 Variables GitLab à Configurer

Dans **GitLab > Settings > CI/CD > Variables**:

| Variable | Valeur | Protected | Masked |
|----------|--------|-----------|--------|
| `HARBOR_URL` | registry.195.35.2.238.nip.io | No | No |
| `HARBOR_USER` | admin | No | No |
| `HARBOR_PASSWORD` | (mot de passe Harbor) | Yes | Yes |
| `HARBOR_PROJECT` | amoona | No | No |
| `GITLAB_USER` | (votre username GitLab) | No | No |
| `GITLAB_TOKEN` | (token GitLab avec read_registry, write_registry) | Yes | Yes |

## 8.2 Exemple Complet .gitlab-ci.yml

```yaml
stages:
  - build
  - push
  - deploy

variables:
  DOCKER_TLS_CERTDIR: ""
  IMAGE_NAME: $HARBOR_URL/$HARBOR_PROJECT/$CI_PROJECT_NAME

# ═══════════════════════════════════════════════════════════════
# BUILD: Construire l'image Docker
# ═══════════════════════════════════════════════════════════════
build:
  stage: build
  image: docker:24.0.5
  services:
    - docker:24.0.5-dind
  before_script:
    - echo "$HARBOR_PASSWORD" | docker login $HARBOR_URL -u $HARBOR_USER --password-stdin
  script:
    - docker build -t $IMAGE_NAME:$CI_COMMIT_SHORT_SHA .
    - docker tag $IMAGE_NAME:$CI_COMMIT_SHORT_SHA $IMAGE_NAME:latest
  only:
    - dev
    - main

# ═══════════════════════════════════════════════════════════════
# PUSH: Pousser vers Harbor
# ═══════════════════════════════════════════════════════════════
push:
  stage: push
  image: docker:24.0.5
  services:
    - docker:24.0.5-dind
  before_script:
    - echo "$HARBOR_PASSWORD" | docker login $HARBOR_URL -u $HARBOR_USER --password-stdin
  script:
    - docker push $IMAGE_NAME:$CI_COMMIT_SHORT_SHA
    - docker push $IMAGE_NAME:latest
  only:
    - dev
    - main

# ═══════════════════════════════════════════════════════════════
# DEPLOY: Mettre à jour le manifeste pour ArgoCD
# ═══════════════════════════════════════════════════════════════
deploy:
  stage: deploy
  image: alpine/git
  before_script:
    - apk add --no-cache sed
  script:
    # Cloner le repo de déploiement (depuis GitLab)
    - git clone https://$GITLAB_USER:$GITLAB_TOKEN@gitlab.com/hypnozsarl/amoona-deployer.git
    - cd amoona-deployer
    - git checkout dev

    # Mettre à jour le tag de l'image
    - |
      sed -i "s/newTag: .*/newTag: \"$CI_COMMIT_SHORT_SHA\"/" \
        k8s/overlays/dev-light/apps/$CI_PROJECT_NAME/kustomization.yaml

    # Commit et push
    - git config user.email "gitlab-ci@amoona.tech"
    - git config user.name "GitLab CI"
    - git add .
    - git commit -m "chore(dev): update $CI_PROJECT_NAME to $CI_COMMIT_SHORT_SHA [skip ci]"
    - git push origin dev
  only:
    - dev
  when: on_success
```

---

# 9. Sécurité et Pare-feu

## 9.1 Ports Ouverts sur le VPS

```bash
# Vérifier les ports ouverts
ufw status verbose

# Résultat attendu:
# 22/tcp    ALLOW    # SSH
# 80/tcp    ALLOW    # HTTP
# 443/tcp   ALLOW    # HTTPS
# 6443/tcp  ALLOW    # Kubernetes API
# 30080/tcp ALLOW    # ArgoCD NodePort
```

## 9.2 Récupérer tous les Mots de Passe

```bash
# Script pour récupérer tous les mots de passe
echo "=== MOTS DE PASSE ==="
echo ""
echo "ArgoCD:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
echo ""
echo "Grafana:"
kubectl get secret grafana-secret -n amoona-dev -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' | base64 -d && echo
echo ""
echo "Harbor:"
kubectl get secret harbor-secret -n amoona-dev -o jsonpath='{.data.HARBOR_ADMIN_PASSWORD}' | base64 -d && echo
echo ""
echo "MinIO:"
kubectl get secret minio-secret -n amoona-dev -o jsonpath='{.data.MINIO_ROOT_PASSWORD}' | base64 -d && echo
echo ""
echo "PostgreSQL:"
kubectl get secret postgres-secret -n amoona-dev -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d && echo
echo ""
echo "Redis:"
kubectl get secret redis-secret -n amoona-dev -o jsonpath='{.data.REDIS_PASSWORD}' | base64 -d && echo
```

## 9.3 Bonnes Pratiques de Sécurité

- ✅ Utiliser des mots de passe forts générés automatiquement
- ✅ Ne jamais commiter les fichiers de secrets dans Git
- ✅ Limiter les ports ouverts au strict nécessaire
- ✅ Utiliser HTTPS en production
- ✅ Configurer les NetworkPolicies Kubernetes
- ✅ Mettre à jour régulièrement le système et K3s

---

# 10. Maintenance et Dépannage

## 10.1 Commandes Utiles

```bash
# État des pods
kubectl get pods -n amoona-dev
kubectl get pods -n argocd

# Logs d'un pod
kubectl logs -f deployment/amoona-api -n amoona-dev

# Logs ArgoCD
kubectl logs -f deployment/argocd-server -n argocd

# Ressources utilisées
kubectl top pods -n amoona-dev
kubectl top nodes

# Events récents
kubectl get events -n amoona-dev --sort-by='.lastTimestamp' | tail -20

# Redémarrer un déploiement
kubectl rollout restart deployment/amoona-api -n amoona-dev

# Voir les ingress
kubectl get ingress -n amoona-dev

# Décrire un service
kubectl describe svc grafana -n amoona-dev
```

## 10.2 Problèmes Courants

### Les services ne sont pas accessibles

```bash
# Vérifier que les pods tournent
kubectl get pods -n amoona-dev

# Vérifier les ingress
kubectl get ingress -n amoona-dev

# Vérifier Traefik (ingress controller)
kubectl get pods -n kube-system | grep traefik

# Vérifier les logs Traefik
kubectl logs -f deployment/traefik -n kube-system
```

### ArgoCD ne synchronise pas

```bash
# Vérifier les applications
kubectl get applications -n argocd

# Forcer un refresh
kubectl exec -n argocd deployment/argocd-server -- argocd app get amoona-infra-dev --refresh

# Voir les logs
kubectl logs -f deployment/argocd-application-controller -n argocd
```

### Certificat SSL ne se génère pas

```bash
# Vérifier cert-manager
kubectl get pods -n cert-manager

# Vérifier les certificats
kubectl get certificates -n amoona-dev
kubectl get certificaterequests -n amoona-dev

# Détails d'un certificat
kubectl describe certificate amoona-app-tls -n amoona-dev
```

## 10.3 Sauvegardes

### PostgreSQL

```bash
# Backup
kubectl exec -it statefulset/postgres -n amoona-dev -- \
  pg_dump -U amoona amoona_db > backup_$(date +%Y%m%d_%H%M%S).sql

# Restore
kubectl exec -i statefulset/postgres -n amoona-dev -- \
  psql -U amoona amoona_db < backup.sql
```

## 10.4 Redémarrage Complet

```bash
# Redémarrer tous les déploiements
kubectl rollout restart deployment -n amoona-dev

# Ou supprimer et recréer le namespace (ATTENTION: perte de données!)
# kubectl delete namespace amoona-dev
# ./scripts/deploy-dev-light.sh --domain amoona.tech
```

---

# RÉSUMÉ DES COMMANDES D'INSTALLATION

```bash
# ═══════════════════════════════════════════════════════════════
# INSTALLATION COMPLÈTE SUR LE VPS 195.35.2.238
# ═══════════════════════════════════════════════════════════════

# 1. Connexion
ssh root@195.35.2.238

# 2. Préparation système
apt update && apt upgrade -y
swapoff -a

# 3. Pare-feu
ufw allow 22/tcp && ufw allow 80/tcp && ufw allow 443/tcp
ufw allow 6443/tcp && ufw allow 30080/tcp && ufw enable

# 4. Installation K3s
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
mkdir -p ~/.kube && cp /etc/rancher/k3s/k3s.yaml ~/.kube/config

# 5. Cloner le repo
cd ~ && git clone https://github.com/hypnozSarl/amoona-deployer.git
cd amoona-deployer && git checkout dev

# 6. Secret GitLab Registry
kubectl create namespace amoona-dev
kubectl create secret docker-registry gitlab-registry-secret \
  --docker-server=registry.gitlab.com \
  --docker-username=VOTRE_USER \
  --docker-password=VOTRE_TOKEN \
  -n amoona-dev

# 7. Générer les secrets
chmod +x scripts/*.sh
./scripts/generate-secrets-dev-light.sh

# 8. Déployer
./scripts/deploy-dev-light.sh --domain amoona.tech --email admin@amoona.tech

# 9. Vérifier
kubectl get pods -n amoona-dev
kubectl get pods -n argocd
```

---

# URLS FINALES

| Service | URL |
|---------|-----|
| **Frontend** | http://app.amoona.tech |
| **API** | http://api.amoona.tech |
| **ArgoCD** | http://argocd.amoona.tech ou http://195.35.2.238:30080 |
| **Harbor** | http://registry.amoona.tech |
| **Grafana** | http://grafana.amoona.tech |
| **Prometheus** | http://prometheus.amoona.tech |
| **MinIO** | http://minio.amoona.tech |

---

*Document généré le 16 Décembre 2024*
*VPS: 195.35.2.238*
