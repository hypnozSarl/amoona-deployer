# GUIDE D'INSTALLATION VPS - Configuration Légère (4 CPU / 16 Go RAM)

## Document pour Environnement de Développement avec Harbor Registry

**Version:** 1.0
**Date:** Décembre 2024
**Configuration:** 4 CPU / 16 Go RAM / Dev uniquement

---

# TABLE DES MATIÈRES

1. [Vue d'ensemble](#1-vue-densemble)
2. [Configuration Initiale du VPS](#2-configuration-initiale-du-vps)
3. [Installation de K3s](#3-installation-de-k3s)
4. [Déploiement de l'Infrastructure](#4-déploiement-de-linfrastructure)
5. [Configuration de Harbor (Registry Docker)](#5-configuration-de-harbor-registry-docker)
6. [Intégration GitLab CI/CD](#6-intégration-gitlab-cicd)
7. [Accès aux Services](#7-accès-aux-services)
8. [Maintenance](#8-maintenance)

---

# 1. Vue d'ensemble

## 1.1 Architecture Déployée

Cette configuration est optimisée pour un VPS avec ressources limitées:

```
┌─────────────────────────────────────────────────────────────┐
│                    VPS (4 CPU / 16 Go RAM)                  │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ amoona-api  │  │amoona-front │  │      Harbor         │  │
│  │   (1 Go)    │  │  (128 Mo)   │  │  (Registry Docker)  │  │
│  └──────┬──────┘  └─────────────┘  │    (~1.5 Go)        │  │
│         │                          └─────────────────────┘  │
│         │                                                    │
│  ┌──────┴──────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ PostgreSQL  │  │    Redis    │  │       MinIO         │  │
│  │  (512 Mo)   │  │  (256 Mo)   │  │     (512 Mo)        │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐                           │
│  │ Prometheus  │  │   Grafana   │   Total: ~5-6 Go RAM      │
│  │  (512 Mo)   │  │  (256 Mo)   │   Libre: ~10 Go système   │
│  └─────────────┘  └─────────────┘                           │
└─────────────────────────────────────────────────────────────┘
```

## 1.2 Services Inclus

| Service | Description | RAM | Stockage |
|---------|-------------|-----|----------|
| **PostgreSQL** | Base de données | 512 Mo | 10 Go |
| **Redis** | Cache | 256 Mo | - |
| **MinIO** | Stockage S3 | 512 Mo | 20 Go |
| **Harbor** | Registry Docker | ~1.5 Go | 30 Go |
| **Prometheus** | Métriques | 512 Mo | - |
| **Grafana** | Dashboards | 256 Mo | - |
| **amoona-api** | Backend | 1 Go | - |
| **amoona-front** | Frontend | 128 Mo | - |

## 1.3 Services NON Inclus (économie de ressources)

- ❌ Elasticsearch (2-4 Go RAM)
- ❌ Logstash (1 Go RAM)
- ❌ Kibana (512 Mo RAM)
- ❌ SonarQube (2 Go RAM)

---

# 2. Configuration Initiale du VPS

## 2.1 Connexion SSH

```bash
ssh root@VOTRE_IP_VPS
```

## 2.2 Mise à Jour Système

```bash
# Mise à jour complète
sudo apt update && sudo apt upgrade -y

# Installation des dépendances
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    git \
    jq \
    openssl \
    htop
```

## 2.3 Configuration Système pour Kubernetes

```bash
# Désactiver le swap (OBLIGATOIRE)
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Vérifier que le swap est désactivé
free -h  # Swap doit être à 0

# Modules kernel
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Paramètres sysctl
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
vm.max_map_count                    = 262144
EOF

sudo sysctl --system
```

## 2.4 Configuration Pare-feu

```bash
sudo ufw enable
sudo ufw allow 22/tcp      # SSH
sudo ufw allow 80/tcp      # HTTP
sudo ufw allow 443/tcp     # HTTPS
sudo ufw allow 6443/tcp    # Kubernetes API
sudo ufw status
```

---

# 3. Installation de K3s

## 3.1 Installer K3s

```bash
# Installation (sans Traefik par défaut, on l'installe manuellement)
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644

# Attendre le démarrage (30-60 secondes)
sleep 30

# Vérifier l'installation
sudo k3s kubectl get nodes
```

## 3.2 Configurer kubectl

```bash
# Configurer kubectl pour l'utilisateur courant
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Vérifier
kubectl get nodes
# Résultat attendu: STATUS = Ready
```

## 3.3 Installer Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

---

# 4. Déploiement de l'Infrastructure

## 4.1 Cloner le Repository

```bash
cd ~
git clone https://github.com/hypnozSarl/amoona-deployer.git
cd amoona-deployer
```

## 4.2 Configurer l'Accès au Registry GitHub

```bash
# Remplacer avec vos credentials
export GITHUB_USER="VOTRE_USERNAME_GITHUB"
export GITHUB_TOKEN="VOTRE_TOKEN_GITHUB"

# Créer le namespace
kubectl create namespace amoona-dev

# Créer le secret pour GHCR
kubectl create secret docker-registry ghcr-secret \
    --docker-server=ghcr.io \
    --docker-username=$GITHUB_USER \
    --docker-password=$GITHUB_TOKEN \
    -n amoona-dev
```

## 4.3 Générer les Secrets

```bash
# Rendre le script exécutable
chmod +x scripts/generate-secrets-dev-light.sh

# Générer tous les secrets
./scripts/generate-secrets-dev-light.sh

# IMPORTANT: Sauvegardez les mots de passe affichés !
```

## 4.4 Déployer l'Infrastructure

```bash
# Méthode 1: Script automatique
chmod +x scripts/deploy-dev-light.sh
./scripts/deploy-dev-light.sh

# OU Méthode 2: Commande manuelle
kubectl apply -k k8s/overlays/dev-light
```

## 4.5 Vérifier le Déploiement

```bash
# Voir tous les pods
kubectl get pods -n amoona-dev -w

# Attendre que tous soient "Running" (peut prendre 5-10 minutes)
# Ctrl+C pour arrêter le watch

# Vérifier les services
kubectl get svc -n amoona-dev

# Vérifier le stockage
kubectl get pvc -n amoona-dev
```

---

# 5. Configuration de Harbor (Registry Docker)

## 5.1 Accéder à Harbor

```bash
# Port-forward pour accéder à Harbor
kubectl port-forward svc/harbor -n amoona-dev 8080:80

# Ouvrir dans le navigateur: http://localhost:8080
```

## 5.2 Connexion à Harbor

- **URL**: http://localhost:8080 (ou votre domaine)
- **Username**: admin
- **Password**: (affiché lors de la génération des secrets)

## 5.3 Créer un Projet dans Harbor

1. Connectez-vous à Harbor
2. Cliquez sur "New Project"
3. Nom: `amoona` (ou le nom de votre projet)
4. Access Level: Private
5. Cliquez sur "OK"

## 5.4 Configurer Docker pour Harbor

Sur votre machine de build (ou GitLab Runner):

```bash
# Option 1: Harbor avec HTTP (développement)
# Ajouter à /etc/docker/daemon.json
{
  "insecure-registries": ["registry.amoona.local:80", "VOTRE_IP_VPS:30080"]
}

# Redémarrer Docker
sudo systemctl restart docker

# Login
docker login VOTRE_IP_VPS:30080 -u admin
```

---

# 6. Intégration GitLab CI/CD

## 6.1 Variables GitLab à Configurer

Dans GitLab > Settings > CI/CD > Variables, ajoutez:

| Variable | Value | Protected | Masked |
|----------|-------|-----------|--------|
| `HARBOR_URL` | `VOTRE_IP_VPS:30080` | No | No |
| `HARBOR_USER` | `admin` | No | No |
| `HARBOR_PASSWORD` | `(mot de passe Harbor)` | Yes | Yes |
| `HARBOR_PROJECT` | `amoona` | No | No |

## 6.2 Exemple .gitlab-ci.yml

```yaml
stages:
  - build
  - push
  - deploy

variables:
  IMAGE_NAME: $HARBOR_URL/$HARBOR_PROJECT/$CI_PROJECT_NAME
  IMAGE_TAG: $CI_COMMIT_SHORT_SHA

# Build de l'image Docker
build:
  stage: build
  image: docker:24.0.5
  services:
    - docker:24.0.5-dind
  variables:
    DOCKER_TLS_CERTDIR: ""
  before_script:
    - echo "$HARBOR_PASSWORD" | docker login $HARBOR_URL -u $HARBOR_USER --password-stdin
  script:
    - docker build -t $IMAGE_NAME:$IMAGE_TAG .
    - docker tag $IMAGE_NAME:$IMAGE_TAG $IMAGE_NAME:latest
  only:
    - main
    - develop

# Push vers Harbor
push:
  stage: push
  image: docker:24.0.5
  services:
    - docker:24.0.5-dind
  variables:
    DOCKER_TLS_CERTDIR: ""
  before_script:
    - echo "$HARBOR_PASSWORD" | docker login $HARBOR_URL -u $HARBOR_USER --password-stdin
  script:
    - docker push $IMAGE_NAME:$IMAGE_TAG
    - docker push $IMAGE_NAME:latest
  only:
    - main
    - develop

# Déploiement (optionnel)
deploy:
  stage: deploy
  image: bitnami/kubectl:latest
  script:
    - kubectl set image deployment/amoona-api amoona-api=$IMAGE_NAME:$IMAGE_TAG -n amoona-dev
  only:
    - main
  when: manual
```

## 6.3 Exposer Harbor avec NodePort (pour GitLab externe)

Si GitLab est externe au cluster:

```bash
# Créer un service NodePort pour Harbor
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: harbor-nodeport
  namespace: amoona-dev
spec:
  type: NodePort
  ports:
    - port: 80
      targetPort: 8080
      nodePort: 30080
  selector:
    app: harbor
    component: portal
EOF
```

Harbor sera accessible sur `http://VOTRE_IP_VPS:30080`

---

# 7. Accès aux Services

## 7.1 Script de Port-Forward

Créez ce script sur votre machine locale:

```bash
#!/bin/bash
# port-forward-dev.sh

echo "Démarrage des port-forwards..."

kubectl port-forward svc/harbor -n amoona-dev 8080:80 &
kubectl port-forward svc/grafana -n amoona-dev 3000:3000 &
kubectl port-forward svc/prometheus -n amoona-dev 9090:9090 &
kubectl port-forward svc/minio -n amoona-dev 9001:9001 &
kubectl port-forward svc/amoona-api -n amoona-dev 8081:80 &
kubectl port-forward svc/amoona-front -n amoona-dev 8082:80 &

echo ""
echo "Services disponibles:"
echo "  Harbor:      http://localhost:8080"
echo "  Grafana:     http://localhost:3000"
echo "  Prometheus:  http://localhost:9090"
echo "  MinIO:       http://localhost:9001"
echo "  API:         http://localhost:8081"
echo "  Frontend:    http://localhost:8082"
echo ""
echo "Appuyez sur Ctrl+C pour arrêter"

wait
```

## 7.2 Récupérer les Mots de Passe

```bash
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
# Voir l'utilisation des ressources
kubectl top pods -n amoona-dev
kubectl top nodes

# Voir les logs
kubectl logs -f deployment/amoona-api -n amoona-dev
kubectl logs -f deployment/harbor-core -n amoona-dev

# Redémarrer un service
kubectl rollout restart deployment/amoona-api -n amoona-dev

# Voir les events
kubectl get events -n amoona-dev --sort-by='.lastTimestamp'
```

## 8.2 Sauvegardes

### PostgreSQL

```bash
# Backup
kubectl exec -it statefulset/postgres -n amoona-dev -- \
  pg_dump -U amoona amoona_db > backup_$(date +%Y%m%d).sql

# Restore
kubectl exec -i statefulset/postgres -n amoona-dev -- \
  psql -U amoona amoona_db < backup_20241216.sql
```

### Harbor (Images Docker)

Harbor stocke les images dans le PVC `harbor-registry-pvc`. Pour sauvegarder:

```bash
# Backup du volume
kubectl exec -it deployment/harbor-registry -n amoona-dev -- \
  tar czf /tmp/images-backup.tar.gz /storage

kubectl cp amoona-dev/harbor-registry-xxx:/tmp/images-backup.tar.gz ./images-backup.tar.gz
```

## 8.3 Nettoyage des Images Anciennes

Dans Harbor UI:
1. Administration > Garbage Collection
2. Cliquez sur "GC Now"

Ou configurer un schedule automatique.

## 8.4 Monitoring des Ressources

Si le VPS devient lent, vérifiez:

```bash
# Ressources par pod
kubectl top pods -n amoona-dev --sort-by=memory

# Si un pod consomme trop, vous pouvez le redémarrer
kubectl delete pod POD_NAME -n amoona-dev
```

---

# RÉSUMÉ DES COMMANDES

```bash
# 1. Installation K3s
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644

# 2. Configuration kubectl
mkdir -p ~/.kube && sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config

# 3. Cloner le repo
git clone https://github.com/hypnozSarl/amoona-deployer.git && cd amoona-deployer

# 4. Créer le namespace et secret GHCR
kubectl create namespace amoona-dev
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=$GITHUB_USER \
  --docker-password=$GITHUB_TOKEN \
  -n amoona-dev

# 5. Générer les secrets
./scripts/generate-secrets-dev-light.sh

# 6. Déployer
kubectl apply -k k8s/overlays/dev-light

# 7. Vérifier
kubectl get pods -n amoona-dev
```

---

*Document généré le 16 Décembre 2024*
