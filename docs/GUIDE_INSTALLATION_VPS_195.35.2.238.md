# GUIDE D'INSTALLATION COMPLET - VPS 195.35.2.238

## Environnement de Développement avec ArgoCD et Harbor

**Version:** 1.0
**Date:** Décembre 2024
**VPS:** 195.35.2.238 (4 CPU / 16 Go RAM)

---

# TABLE DES MATIÈRES

1. [Connexion et Préparation du VPS](#1-connexion-et-préparation-du-vps)
2. [Installation de K3s](#2-installation-de-k3s)
3. [Déploiement de l'Infrastructure](#3-déploiement-de-linfrastructure)
4. [Configuration d'ArgoCD](#4-configuration-dargocd)
5. [Configuration de Harbor](#5-configuration-de-harbor)
6. [Intégration GitLab CI/CD](#6-intégration-gitlab-cicd)
7. [URLs des Services](#7-urls-des-services)
8. [Maintenance](#8-maintenance)

---

# 1. Connexion et Préparation du VPS

## 1.1 Connexion SSH

```bash
ssh root@195.35.2.238
```

## 1.2 Mise à Jour et Dépendances

```bash
# Mise à jour système
apt update && apt upgrade -y

# Installation des dépendances
apt install -y curl git jq openssl htop
```

## 1.3 Configuration Système

```bash
# Désactiver le swap
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

## 1.4 Pare-feu

```bash
ufw allow 22/tcp     # SSH
ufw allow 80/tcp     # HTTP
ufw allow 443/tcp    # HTTPS
ufw allow 6443/tcp   # Kubernetes API
ufw allow 30000:32767/tcp  # NodePorts
ufw enable
```

---

# 2. Installation de K3s

## 2.1 Installer K3s

```bash
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644

# Attendre le démarrage
sleep 30

# Configurer kubectl
mkdir -p ~/.kube
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config

# Vérifier
kubectl get nodes
```

## 2.2 Installer Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
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

## 3.2 Configurer le Secret GHCR

```bash
# Créer le namespace
kubectl create namespace amoona-dev

# Créer le secret (remplacer avec vos credentials)
kubectl create secret docker-registry ghcr-secret \
    --docker-server=ghcr.io \
    --docker-username=VOTRE_USERNAME_GITHUB \
    --docker-password=VOTRE_TOKEN_GITHUB \
    -n amoona-dev
```

## 3.3 Générer les Secrets

```bash
chmod +x scripts/generate-secrets-dev-light.sh
./scripts/generate-secrets-dev-light.sh

# IMPORTANT: Notez les mots de passe affichés !
```

## 3.4 Déployer avec le Script Automatique

```bash
chmod +x scripts/deploy-dev-light.sh
./scripts/deploy-dev-light.sh
```

## 3.5 Vérifier le Déploiement

```bash
# Voir tous les pods
kubectl get pods -n amoona-dev

# Attendre que tout soit Running
kubectl get pods -n amoona-dev -w
```

---

# 4. Configuration d'ArgoCD

## 4.1 ArgoCD est Installé Automatiquement

Le script de déploiement installe ArgoCD et configure les applications.

## 4.2 Accéder à ArgoCD

**URL:** http://argocd.195.35.2.238.nip.io
**Ou:** http://195.35.2.238:30080

**Credentials:**
- Username: `admin`
- Password: Récupérer avec:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

## 4.3 Applications Configurées

ArgoCD surveille automatiquement la branche `dev` pour:

| Application | Path | Sync |
|-------------|------|------|
| `amoona-infra-dev` | `k8s/overlays/dev-light` | Auto |
| `amoona-api-dev` | `k8s/overlays/dev-light/apps/amoona-api` | Auto |
| `amoona-front-dev` | `k8s/overlays/dev-light/apps/amoona-front` | Auto |

## 4.4 Workflow de Déploiement Automatique

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitLab CI     │───▶│   Push branche  │───▶│    ArgoCD       │
│   Build Image   │    │      dev        │    │   Auto Sync     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                                              │
         │                                              ▼
         │                                    ┌─────────────────┐
         └───────────────────────────────────▶│   Kubernetes    │
                    Push Image                │   Deployment    │
                    vers Harbor               └─────────────────┘
```

## 4.5 Mettre à Jour une Image via ArgoCD

1. **Modifier le tag de l'image** dans le fichier kustomization:
```bash
# Fichier: k8s/overlays/dev-light/apps/amoona-api/kustomization.yaml
images:
  - name: ghcr.io/hypnozsarl/amoona-api
    newTag: "NOUVEAU_TAG"  # Changer ici
```

2. **Commit et push sur la branche dev:**
```bash
git add .
git commit -m "chore(dev): update amoona-api image to NOUVEAU_TAG"
git push origin dev
```

3. **ArgoCD détecte et déploie automatiquement** (en ~3 minutes)

---

# 5. Configuration de Harbor

## 5.1 Accéder à Harbor

**URL:** http://registry.195.35.2.238.nip.io

**Credentials:**
- Username: `admin`
- Password: Récupérer avec:
```bash
kubectl get secret harbor-secret -n amoona-dev -o jsonpath='{.data.HARBOR_ADMIN_PASSWORD}' | base64 -d && echo
```

## 5.2 Créer un Projet dans Harbor

1. Connectez-vous à Harbor
2. Cliquez sur **"New Project"**
3. Nom: `amoona`
4. Access Level: **Private**
5. Cliquez sur **OK**

## 5.3 Configurer Docker pour Harbor

Sur la machine de build (GitLab Runner ou local):

```bash
# Ajouter Harbor comme registry non sécurisé
cat > /etc/docker/daemon.json << 'EOF'
{
  "insecure-registries": ["registry.195.35.2.238.nip.io"]
}
EOF

# Redémarrer Docker
systemctl restart docker

# Login
docker login registry.195.35.2.238.nip.io -u admin
```

---

# 6. Intégration GitLab CI/CD

## 6.1 Variables GitLab à Configurer

Dans **GitLab > Settings > CI/CD > Variables**:

| Variable | Value | Protected | Masked |
|----------|-------|-----------|--------|
| `HARBOR_URL` | `registry.195.35.2.238.nip.io` | No | No |
| `HARBOR_USER` | `admin` | No | No |
| `HARBOR_PASSWORD` | `(mot de passe Harbor)` | Yes | Yes |
| `HARBOR_PROJECT` | `amoona` | No | No |

## 6.2 Exemple Complet .gitlab-ci.yml

```yaml
stages:
  - build
  - push
  - update-manifest

variables:
  DOCKER_TLS_CERTDIR: ""
  IMAGE_NAME: $HARBOR_URL/$HARBOR_PROJECT/$CI_PROJECT_NAME

# =============================================================================
# BUILD: Construire l'image Docker
# =============================================================================
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

# =============================================================================
# PUSH: Pousser l'image vers Harbor
# =============================================================================
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

# =============================================================================
# UPDATE MANIFEST: Mettre à jour le tag dans le repo de déploiement
# =============================================================================
update-manifest:
  stage: update-manifest
  image: alpine/git
  before_script:
    - apk add --no-cache sed
  script:
    # Cloner le repo de déploiement
    - git clone https://$GITHUB_USER:$GITHUB_TOKEN@github.com/hypnozSarl/amoona-deployer.git
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
    - git commit -m "chore(dev): update $CI_PROJECT_NAME image to $CI_COMMIT_SHORT_SHA"
    - git push origin dev
  only:
    - dev
  when: on_success
```

## 6.3 Workflow Complet

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Developer  │────▶│  GitLab CI  │────▶│   Harbor    │────▶│   ArgoCD    │
│  git push   │     │  build+push │     │  store img  │     │  deploy     │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                           │                                       │
                           │  Update kustomization.yaml            │
                           └───────────────────────────────────────┘
                                    (trigger ArgoCD sync)
```

---

# 7. URLs des Services

## 7.1 URLs Publiques (via nip.io)

| Service | URL |
|---------|-----|
| **Frontend** | http://app.195.35.2.238.nip.io |
| **API** | http://api.195.35.2.238.nip.io |
| **ArgoCD** | http://argocd.195.35.2.238.nip.io |
| **Harbor** | http://registry.195.35.2.238.nip.io |
| **Grafana** | http://grafana.195.35.2.238.nip.io |
| **Prometheus** | http://prometheus.195.35.2.238.nip.io |
| **MinIO** | http://minio.195.35.2.238.nip.io |

## 7.2 Accès Direct (NodePort)

| Service | URL |
|---------|-----|
| **ArgoCD** | http://195.35.2.238:30080 |

## 7.3 Récupérer les Mots de Passe

```bash
# ArgoCD
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Grafana
kubectl get secret grafana-secret -n amoona-dev \
  -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' | base64 -d && echo

# Harbor
kubectl get secret harbor-secret -n amoona-dev \
  -o jsonpath='{.data.HARBOR_ADMIN_PASSWORD}' | base64 -d && echo

# MinIO
kubectl get secret minio-secret -n amoona-dev \
  -o jsonpath='{.data.MINIO_ROOT_PASSWORD}' | base64 -d && echo

# PostgreSQL
kubectl get secret postgres-secret -n amoona-dev \
  -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d && echo
```

---

# 8. Maintenance

## 8.1 Commandes Utiles

```bash
# État des pods
kubectl get pods -n amoona-dev
kubectl get pods -n argocd

# Logs
kubectl logs -f deployment/amoona-api -n amoona-dev
kubectl logs -f deployment/argocd-server -n argocd

# Ressources utilisées
kubectl top pods -n amoona-dev
kubectl top nodes

# Redémarrer un service
kubectl rollout restart deployment/amoona-api -n amoona-dev

# Forcer un sync ArgoCD
kubectl exec -n argocd deployment/argocd-server -- argocd app sync amoona-api-dev
```

## 8.2 Sauvegardes

### PostgreSQL
```bash
# Backup
kubectl exec -it statefulset/postgres -n amoona-dev -- \
  pg_dump -U amoona amoona_db > backup_$(date +%Y%m%d).sql

# Restore
kubectl exec -i statefulset/postgres -n amoona-dev -- \
  psql -U amoona amoona_db < backup.sql
```

## 8.3 Problèmes Courants

### ArgoCD ne synchronise pas
```bash
# Vérifier le statut
kubectl get applications -n argocd

# Forcer le refresh
kubectl exec -n argocd deployment/argocd-server -- \
  argocd app get amoona-infra-dev --refresh
```

### Pod en erreur
```bash
# Voir les logs
kubectl logs POD_NAME -n amoona-dev --previous

# Voir les events
kubectl describe pod POD_NAME -n amoona-dev
```

---

# RÉSUMÉ DES COMMANDES D'INSTALLATION

```bash
# 1. Préparer le système
apt update && apt upgrade -y
swapoff -a

# 2. Installer K3s
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
mkdir -p ~/.kube && cp /etc/rancher/k3s/k3s.yaml ~/.kube/config

# 3. Cloner et configurer
cd ~ && git clone https://github.com/hypnozSarl/amoona-deployer.git
cd amoona-deployer && git checkout dev

# 4. Créer les secrets
kubectl create namespace amoona-dev
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=USER --docker-password=TOKEN \
  -n amoona-dev
./scripts/generate-secrets-dev-light.sh

# 5. Déployer tout
./scripts/deploy-dev-light.sh
```

---

*Document pour VPS 195.35.2.238 - Décembre 2024*
