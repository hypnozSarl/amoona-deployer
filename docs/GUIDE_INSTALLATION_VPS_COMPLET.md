# GUIDE COMPLET D'INSTALLATION VPS - INFRASTRUCTURE AMOONA

## Document de Référence pour la Réinitialisation et le Déploiement

**Version:** 3.0
**Date:** Décembre 2024
**Auteur:** Équipe DevOps Amoona

---

# TABLE DES MATIÈRES

1. [PRÉREQUIS ET SPÉCIFICATIONS](#1-prérequis-et-spécifications)
2. [CONFIGURATION INITIALE DU VPS](#2-configuration-initiale-du-vps)
3. [INSTALLATION DE KUBERNETES (K3s)](#3-installation-de-kubernetes-k3s)
4. [CONFIGURATION DE L'ACCÈS À DISTANCE](#4-configuration-de-laccès-à-distance)
5. [DÉPLOIEMENT DE L'INFRASTRUCTURE](#5-déploiement-de-linfrastructure)
6. [CONFIGURATION DES SECRETS](#6-configuration-des-secrets)
7. [DÉPLOIEMENT DES APPLICATIONS](#7-déploiement-des-applications)
8. [CONFIGURATION DE L'INGRESS ET DNS](#8-configuration-de-lingress-et-dns)
9. [GESTION DES RESSOURCES (OPTIMISATION)](#9-gestion-des-ressources-optimisation)
10. [MONITORING ET OBSERVABILITÉ](#10-monitoring-et-observabilité)
11. [SÉCURITÉ](#11-sécurité)
12. [ACCÈS AUX SERVICES DEPUIS VOS APPLICATIONS](#12-accès-aux-services-depuis-vos-applications)
13. [MAINTENANCE ET DÉPANNAGE](#13-maintenance-et-dépannage)
14. [CHECKLIST DE DÉPLOIEMENT](#14-checklist-de-déploiement)

---

# 1. PRÉREQUIS ET SPÉCIFICATIONS

## 1.1 Spécifications Minimales du VPS

| Composant | Minimum | Recommandé | Production |
|-----------|---------|------------|------------|
| **CPU** | 4 cores | 8 cores | 16+ cores |
| **RAM** | 16 GB | 32 GB | 64+ GB |
| **Stockage** | 100 GB SSD | 250 GB NVMe | 500+ GB NVMe |
| **OS** | Ubuntu 22.04 LTS | Ubuntu 22.04 LTS | Ubuntu 22.04 LTS |
| **Bande passante** | 100 Mbps | 1 Gbps | 1+ Gbps |

## 1.2 Estimation des Ressources par Service

| Service | CPU Request | CPU Limit | RAM Request | RAM Limit | Stockage |
|---------|-------------|-----------|-------------|-----------|----------|
| **amoona-api** | 250m | 1000m | 512Mi | 1536Mi | - |
| **amoona-front** | 100m | 500m | 256Mi | 512Mi | - |
| **PostgreSQL** | 250m | 1000m | 512Mi | 1Gi | 50Gi |
| **Redis** | 100m | 500m | 128Mi | 512Mi | - |
| **MinIO** | 100m | 500m | 256Mi | 512Mi | 100Gi |
| **Elasticsearch** | 500m | 2000m | 2Gi | 4Gi | 100Gi |
| **Logstash** | 100m | 500m | 512Mi | 1Gi | - |
| **Kibana** | 100m | 500m | 256Mi | 512Mi | - |
| **Prometheus** | 250m | 1000m | 512Mi | 1Gi | - |
| **Grafana** | 100m | 500m | 256Mi | 512Mi | - |
| **TOTAL ESTIMÉ** | ~2 cores | ~8 cores | ~5.5Gi | ~12Gi | ~250Gi |

> **⚠️ IMPORTANT**: Ces valeurs sont pour un environnement de production. Pour le développement, divisez par 2.

## 1.3 Informations à Préparer Avant l'Installation

- [ ] Adresse IP publique du VPS
- [ ] Accès SSH (utilisateur + clé ou mot de passe)
- [ ] Nom de domaine configuré (ex: amoona.tech)
- [ ] Token GitHub avec droits `read:packages` pour accéder aux images Docker
- [ ] Adresses email pour les certificats Let's Encrypt

---

# 2. CONFIGURATION INITIALE DU VPS

## 2.1 Connexion au VPS

```bash
# Connexion SSH
ssh root@VOTRE_IP_VPS

# OU avec clé SSH
ssh -i ~/.ssh/votre_cle root@VOTRE_IP_VPS
```

## 2.2 Création d'un Utilisateur Non-Root (Recommandé)

```bash
# Créer un nouvel utilisateur
adduser amoona

# Ajouter aux groupes sudo et docker
usermod -aG sudo amoona

# Configurer l'accès SSH pour cet utilisateur
mkdir -p /home/amoona/.ssh
cp ~/.ssh/authorized_keys /home/amoona/.ssh/
chown -R amoona:amoona /home/amoona/.ssh
chmod 700 /home/amoona/.ssh
chmod 600 /home/amoona/.ssh/authorized_keys

# Se connecter avec le nouvel utilisateur
su - amoona
```

## 2.3 Mise à Jour du Système

```bash
# Mise à jour complète
sudo apt update && sudo apt upgrade -y

# Installation des dépendances essentielles
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    jq \
    openssl \
    htop \
    iotop \
    net-tools \
    unzip \
    wget
```

## 2.4 Configuration du Pare-feu (UFW)

```bash
# Activer UFW
sudo ufw enable

# Ports essentiels
sudo ufw allow 22/tcp      # SSH
sudo ufw allow 80/tcp      # HTTP
sudo ufw allow 443/tcp     # HTTPS
sudo ufw allow 6443/tcp    # Kubernetes API

# Ports pour l'accès à distance aux services (optionnel - via port-forward recommandé)
sudo ufw allow 30000:32767/tcp  # NodePort range

# Vérifier le statut
sudo ufw status verbose
```

## 2.5 Configuration Système pour Kubernetes

```bash
# Désactiver le swap (OBLIGATOIRE pour Kubernetes)
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Vérifier que le swap est désactivé
free -h  # La ligne Swap doit afficher 0

# Charger les modules kernel nécessaires
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Configurer les paramètres sysctl
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
vm.max_map_count                    = 262144
EOF

# Appliquer les paramètres
sudo sysctl --system

# Vérifier
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward
```

## 2.6 Optimisation du Système (Performance)

```bash
# Augmenter les limites de fichiers ouverts
cat <<EOF | sudo tee /etc/security/limits.d/kubernetes.conf
* soft nofile 65536
* hard nofile 65536
* soft nproc 65536
* hard nproc 65536
EOF

# Optimiser les performances réseau
cat <<EOF | sudo tee -a /etc/sysctl.d/k8s.conf
# Performance réseau
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_tw_reuse = 1
EOF

sudo sysctl --system
```

---

# 3. INSTALLATION DE KUBERNETES (K3s)

## 3.1 Installation de K3s (Recommandé pour VPS Unique)

K3s est une distribution légère de Kubernetes, idéale pour les VPS.

```bash
# Installation de K3s avec Traefik désactivé (on utilisera notre propre ingress)
curl -sfL https://get.k3s.io | sh -s - \
    --write-kubeconfig-mode 644 \
    --disable traefik

# Attendre que K3s démarre (30-60 secondes)
sleep 30

# Vérifier l'installation
sudo k3s kubectl get nodes

# Configurer kubectl pour l'utilisateur courant
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Vérifier kubectl
kubectl get nodes
kubectl cluster-info
```

## 3.2 Vérification de l'Installation

```bash
# Le node doit être "Ready"
kubectl get nodes
# NAME        STATUS   ROLES                  AGE   VERSION
# vps-name    Ready    control-plane,master   1m    v1.28.x

# Vérifier les pods système
kubectl get pods -n kube-system
# Tous les pods doivent être "Running"
```

## 3.3 Installation d'Outils Supplémentaires

```bash
# Installation de Helm (gestionnaire de packages Kubernetes)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Vérifier Helm
helm version

# Installation de kustomize (si non inclus dans kubectl)
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
sudo mv kustomize /usr/local/bin/

# Installation de k9s (interface terminal pour Kubernetes - optionnel mais très utile)
curl -sS https://webinstall.dev/k9s | bash
```

---

# 4. CONFIGURATION DE L'ACCÈS À DISTANCE

## 4.1 Accès kubectl depuis votre Machine Locale

### Option A: Copie du Kubeconfig (Recommandé)

```bash
# Sur votre machine locale
mkdir -p ~/.kube

# Copier le fichier de configuration
scp amoona@VOTRE_IP_VPS:/home/amoona/.kube/config ~/.kube/config-amoona

# Éditer le fichier pour changer l'adresse du serveur
# Remplacer 127.0.0.1 par l'IP publique du VPS
sed -i 's/127.0.0.1/VOTRE_IP_VPS/g' ~/.kube/config-amoona

# Utiliser ce kubeconfig
export KUBECONFIG=~/.kube/config-amoona

# OU fusionner avec votre config existante
export KUBECONFIG=~/.kube/config:~/.kube/config-amoona
kubectl config view --flatten > ~/.kube/config-merged
mv ~/.kube/config-merged ~/.kube/config

# Vérifier la connexion
kubectl get nodes
```

### Option B: Tunnel SSH (Plus Sécurisé)

```bash
# Créer un tunnel SSH pour accéder à l'API Kubernetes
ssh -L 6443:127.0.0.1:6443 amoona@VOTRE_IP_VPS -N &

# Utiliser kubectl avec le kubeconfig local (127.0.0.1:6443)
kubectl get nodes
```

## 4.2 Accès aux Services via Port-Forward

### Méthode Automatique avec Script

Créez un script pour ouvrir tous les port-forwards nécessaires:

```bash
# Créer le script sur votre machine locale
cat > ~/port-forward-amoona.sh << 'EOF'
#!/bin/bash

NAMESPACE="${1:-amoona-prod}"

echo "Démarrage des port-forwards pour $NAMESPACE..."

# Arrêter les anciens port-forwards
pkill -f "kubectl port-forward" 2>/dev/null

# Services principaux
kubectl port-forward svc/grafana -n $NAMESPACE 3000:3000 &
kubectl port-forward svc/prometheus -n $NAMESPACE 9090:9090 &
kubectl port-forward svc/kibana -n $NAMESPACE 5601:5601 &
kubectl port-forward svc/minio -n $NAMESPACE 9001:9001 &
kubectl port-forward svc/pgadmin -n $NAMESPACE 5050:80 &

echo ""
echo "Services accessibles:"
echo "  Grafana:     http://localhost:3000"
echo "  Prometheus:  http://localhost:9090"
echo "  Kibana:      http://localhost:5601"
echo "  MinIO:       http://localhost:9001"
echo "  pgAdmin:     http://localhost:5050"
echo ""
echo "Appuyez sur Ctrl+C pour arrêter tous les port-forwards"

wait
EOF

chmod +x ~/port-forward-amoona.sh
```

### Accès Manuel par Service

```bash
# Grafana (Monitoring dashboards)
kubectl port-forward svc/grafana -n amoona-prod 3000:3000
# Accès: http://localhost:3000

# Prometheus (Métriques)
kubectl port-forward svc/prometheus -n amoona-prod 9090:9090
# Accès: http://localhost:9090

# Kibana (Logs)
kubectl port-forward svc/kibana -n amoona-prod 5601:5601
# Accès: http://localhost:5601

# MinIO Console (Stockage S3)
kubectl port-forward svc/minio -n amoona-prod 9001:9001
# Accès: http://localhost:9001

# PostgreSQL (Base de données)
kubectl port-forward svc/postgres -n amoona-prod 5432:5432
# Connexion: psql -h localhost -U amoona -d amoona_db

# Redis
kubectl port-forward svc/redis -n amoona-prod 6379:6379
# Connexion: redis-cli -h localhost

# Elasticsearch
kubectl port-forward svc/elasticsearch -n amoona-prod 9200:9200
# Accès: http://localhost:9200
```

## 4.3 Configuration DNS pour l'Accès Public

### Configuration des Enregistrements DNS

Chez votre fournisseur DNS, ajoutez ces enregistrements:

```
# Enregistrements A (pointer vers l'IP du VPS)
@                    A    VOTRE_IP_VPS
api                  A    VOTRE_IP_VPS
app                  A    VOTRE_IP_VPS
grafana              A    VOTRE_IP_VPS
prometheus           A    VOTRE_IP_VPS
kibana               A    VOTRE_IP_VPS
minio                A    VOTRE_IP_VPS
s3                   A    VOTRE_IP_VPS
argocd               A    VOTRE_IP_VPS

# OU un wildcard (plus simple)
*                    A    VOTRE_IP_VPS
```

---

# 5. DÉPLOIEMENT DE L'INFRASTRUCTURE

## 5.1 Cloner le Repository

```bash
# Sur le VPS
cd ~
git clone https://github.com/hypnozSarl/amoona-deployer.git
cd amoona-deployer

# Vérifier la branche
git checkout main
```

## 5.2 Créer les Namespaces

```bash
# Créer les namespaces
kubectl create namespace amoona-dev
kubectl create namespace amoona-prod
kubectl create namespace argocd
kubectl create namespace cert-manager
kubectl create namespace monitoring

# Ajouter les labels pour l'injection Linkerd (si utilisé)
kubectl label namespace amoona-dev linkerd.io/inject=enabled --overwrite
kubectl label namespace amoona-prod linkerd.io/inject=enabled --overwrite
```

## 5.3 Configurer l'Accès au Registry GitHub (GHCR)

```bash
# Remplacer YOUR_GITHUB_USERNAME et YOUR_GITHUB_TOKEN
export GITHUB_USER="YOUR_GITHUB_USERNAME"
export GITHUB_TOKEN="YOUR_GITHUB_TOKEN"

# Créer le secret dans les deux namespaces
for ns in amoona-dev amoona-prod; do
    kubectl create secret docker-registry ghcr-secret \
        --docker-server=ghcr.io \
        --docker-username=$GITHUB_USER \
        --docker-password=$GITHUB_TOKEN \
        -n $ns
done

# Vérifier
kubectl get secrets -n amoona-prod | grep ghcr
```

## 5.4 Installation de Traefik (Ingress Controller)

```bash
# Installer Traefik via Helm
helm repo add traefik https://helm.traefik.io/traefik
helm repo update

helm install traefik traefik/traefik \
    --namespace kube-system \
    --set ports.web.exposedPort=80 \
    --set ports.websecure.exposedPort=443 \
    --set service.type=LoadBalancer

# Vérifier l'installation
kubectl get pods -n kube-system | grep traefik
kubectl get svc -n kube-system | grep traefik
```

## 5.5 Installation de Cert-Manager (Certificats TLS)

```bash
# Installer cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

# Attendre que cert-manager soit prêt
kubectl wait --for=condition=available deployment/cert-manager -n cert-manager --timeout=300s
kubectl wait --for=condition=available deployment/cert-manager-webhook -n cert-manager --timeout=300s

# Créer le ClusterIssuer pour Let's Encrypt
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: VOTRE_EMAIL@domain.com
    privateKeySecretRef:
      name: letsencrypt-prod
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
    email: VOTRE_EMAIL@domain.com
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: traefik
EOF
```

## 5.6 Déploiement de l'Infrastructure Complète

### Méthode 1: Déploiement Automatique (Recommandé)

```bash
# Générer les secrets d'abord
./scripts/generate-secrets.sh prod

# Déployer toute l'infrastructure
./scripts/deploy-all.sh prod

# Suivre le déploiement
kubectl get pods -n amoona-prod -w
```

### Méthode 2: Déploiement Manuel Étape par Étape

```bash
# ÉTAPE 1: Infrastructure de base (Bases de données et services)
kubectl apply -k k8s/overlays/prod

# ÉTAPE 2: Attendre que PostgreSQL soit prêt
kubectl wait --for=condition=ready pod -l app=postgres -n amoona-prod --timeout=300s

# ÉTAPE 3: Attendre que Redis soit prêt
kubectl wait --for=condition=ready pod -l app=redis -n amoona-prod --timeout=120s

# ÉTAPE 4: Attendre que MinIO soit prêt
kubectl wait --for=condition=ready pod -l app=minio -n amoona-prod --timeout=120s

# ÉTAPE 5: Attendre que Elasticsearch soit prêt (peut prendre plusieurs minutes)
kubectl wait --for=condition=ready pod -l app=elasticsearch -n amoona-prod --timeout=600s

# ÉTAPE 6: Vérifier tous les pods
kubectl get pods -n amoona-prod
```

## 5.7 Vérification du Déploiement

```bash
# Voir tous les pods
kubectl get pods -n amoona-prod

# Résultat attendu (tous en Running):
# NAME                            READY   STATUS    RESTARTS   AGE
# postgres-0                      1/1     Running   0          5m
# redis-xxxxx                     1/1     Running   0          5m
# minio-xxxxx                     1/1     Running   0          5m
# elasticsearch-0                 1/1     Running   0          5m
# logstash-xxxxx                  1/1     Running   0          5m
# kibana-xxxxx                    1/1     Running   0          5m
# prometheus-xxxxx                1/1     Running   0          5m
# grafana-xxxxx                   1/1     Running   0          5m

# Voir les services
kubectl get svc -n amoona-prod

# Voir les PVC (stockage persistant)
kubectl get pvc -n amoona-prod
```

---

# 6. CONFIGURATION DES SECRETS

## 6.1 Génération Automatique des Secrets

```bash
# Se placer dans le répertoire du projet
cd ~/amoona-deployer

# Générer les secrets pour la production
./scripts/generate-secrets.sh prod

# Le script génère et affiche:
# - POSTGRES_PASSWORD
# - MINIO_PASSWORD
# - GRAFANA_PASSWORD
# - REDIS_PASSWORD
# - ELASTIC_PASSWORD
# - JWT_SECRET

# IMPORTANT: SAUVEGARDEZ CES MOTS DE PASSE!
# Ils sont aussi stockés dans:
# - k8s/overlays/prod/secrets-patch.yaml
# - k8s/overlays/prod/apps/amoona-api/secrets.yaml
```

## 6.2 Application des Secrets

```bash
# Les secrets sont automatiquement appliqués avec kustomize
# Si vous devez les réappliquer manuellement:

kubectl apply -k k8s/overlays/prod

# OU appliquer uniquement les secrets:
kubectl apply -f k8s/overlays/prod/secrets-patch.yaml -n amoona-prod
kubectl apply -f k8s/overlays/prod/apps/amoona-api/secrets.yaml -n amoona-prod
```

## 6.3 Récupérer les Mots de Passe

```bash
# Grafana
kubectl get secret grafana-secret -n amoona-prod -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' | base64 -d && echo

# PostgreSQL
kubectl get secret postgres-secret -n amoona-prod -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d && echo

# MinIO
kubectl get secret minio-secret -n amoona-prod -o jsonpath='{.data.MINIO_ROOT_PASSWORD}' | base64 -d && echo

# Redis
kubectl get secret redis-secret -n amoona-prod -o jsonpath='{.data.REDIS_PASSWORD}' | base64 -d && echo
```

---

# 7. DÉPLOIEMENT DES APPLICATIONS

## 7.1 Déployer l'API Backend

```bash
# L'API est déjà configurée dans les overlays
# Elle sera déployée automatiquement avec:
kubectl apply -k k8s/overlays/prod

# OU déployer uniquement l'API:
kubectl apply -k k8s/overlays/prod/apps/amoona-api

# Vérifier
kubectl get pods -l app=amoona-api -n amoona-prod
kubectl logs -l app=amoona-api -n amoona-prod -f
```

## 7.2 Déployer le Frontend

```bash
# Déployer le frontend
kubectl apply -k k8s/overlays/prod/apps/amoona-front

# Vérifier
kubectl get pods -l app=amoona-front -n amoona-prod
```

## 7.3 Mise à Jour des Images

```bash
# Pour mettre à jour l'image de l'API
cd k8s/overlays/prod/apps/amoona-api

# Éditer kustomization.yaml et changer le tag de l'image
# OU utiliser kustomize edit:
kustomize edit set image ghcr.io/hypnozsarl/amoona-api=ghcr.io/hypnozsarl/amoona-api:NOUVEAU_TAG

# Appliquer
kubectl apply -k .

# Suivre le rolling update
kubectl rollout status deployment/amoona-api -n amoona-prod
```

---

# 8. CONFIGURATION DE L'INGRESS ET DNS

## 8.1 Appliquer les Règles Ingress

```bash
# Mettre à jour le fichier d'ingress pour la production
# Éditer k8s/overlays/prod/ingress-patch.yaml avec vos domaines

# Appliquer
kubectl apply -k k8s/overlays/prod
```

## 8.2 Exemple de Configuration Ingress

```yaml
# k8s/overlays/prod/ingress-patch.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: amoona-ingress
  namespace: amoona-prod
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - api.amoona.tech
    - app.amoona.tech
    - grafana.amoona.tech
    - kibana.amoona.tech
    secretName: amoona-tls
  rules:
  - host: api.amoona.tech
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: amoona-api
            port:
              number: 80
  - host: app.amoona.tech
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: amoona-front
            port:
              number: 80
  - host: grafana.amoona.tech
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 3000
```

## 8.3 Vérifier les Certificats TLS

```bash
# Voir les certificats
kubectl get certificates -n amoona-prod

# Voir les demandes de certificat
kubectl get certificaterequests -n amoona-prod

# Détails d'un certificat
kubectl describe certificate amoona-tls -n amoona-prod
```

---

# 9. GESTION DES RESSOURCES (OPTIMISATION)

> **Cette section est cruciale si vous avez eu des difficultés avec la gestion des ressources**

## 9.1 Comprendre les Ressources Kubernetes

### Requests vs Limits

- **Requests**: Ressources garanties pour le pod (utilisées pour le scheduling)
- **Limits**: Maximum que le pod peut utiliser (au-delà = OOMKilled ou throttling)

```yaml
resources:
  requests:
    cpu: "250m"      # 0.25 CPU core garanti
    memory: "512Mi"  # 512 Mo de RAM garantis
  limits:
    cpu: "1000m"     # Maximum 1 CPU core
    memory: "1Gi"    # Maximum 1 Go de RAM
```

## 9.2 Ajuster les Ressources selon votre VPS

### Pour un VPS de 16 Go RAM / 4 CPU (Configuration Légère)

Créez un fichier de patch personnalisé:

```bash
cat > k8s/overlays/prod/custom-resources.yaml << 'EOF'
# PostgreSQL - Réduire les ressources
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  template:
    spec:
      containers:
      - name: postgres
        resources:
          requests:
            cpu: "100m"
            memory: "256Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
---
# Redis - Configuration légère
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
spec:
  template:
    spec:
      containers:
      - name: redis
        resources:
          requests:
            cpu: "50m"
            memory: "64Mi"
          limits:
            cpu: "200m"
            memory: "256Mi"
---
# Elasticsearch - ATTENTION: Service le plus gourmand
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: elasticsearch
spec:
  template:
    spec:
      containers:
      - name: elasticsearch
        resources:
          requests:
            cpu: "200m"
            memory: "1Gi"
          limits:
            cpu: "1000m"
            memory: "2Gi"
        env:
        - name: ES_JAVA_OPTS
          value: "-Xms512m -Xmx512m"  # Réduire la heap Java
---
# Logstash
apiVersion: apps/v1
kind: Deployment
metadata:
  name: logstash
spec:
  template:
    spec:
      containers:
      - name: logstash
        resources:
          requests:
            cpu: "50m"
            memory: "256Mi"
          limits:
            cpu: "300m"
            memory: "512Mi"
---
# Prometheus
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
spec:
  template:
    spec:
      containers:
      - name: prometheus
        resources:
          requests:
            cpu: "100m"
            memory: "256Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
---
# Grafana
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
spec:
  template:
    spec:
      containers:
      - name: grafana
        resources:
          requests:
            cpu: "50m"
            memory: "128Mi"
          limits:
            cpu: "200m"
            memory: "256Mi"
---
# API
apiVersion: apps/v1
kind: Deployment
metadata:
  name: amoona-api
spec:
  template:
    spec:
      containers:
      - name: amoona-api
        resources:
          requests:
            cpu: "100m"
            memory: "256Mi"
          limits:
            cpu: "500m"
            memory: "768Mi"
---
# Frontend
apiVersion: apps/v1
kind: Deployment
metadata:
  name: amoona-front
spec:
  template:
    spec:
      containers:
      - name: amoona-front
        resources:
          requests:
            cpu: "50m"
            memory: "64Mi"
          limits:
            cpu: "200m"
            memory: "128Mi"
EOF
```

### Appliquer la configuration personnalisée

```bash
# Ajouter le patch dans kustomization.yaml
cd k8s/overlays/prod
echo "  - custom-resources.yaml" >> kustomization.yaml

# Ou l'ajouter manuellement dans la section patches du kustomization.yaml

# Appliquer
kubectl apply -k .
```

## 9.3 Désactiver les Services Non Essentiels

Si les ressources sont vraiment limitées, vous pouvez désactiver certains services:

```bash
# Désactiver Elasticsearch/Logstash/Kibana (ELK Stack)
# Éditer k8s/overlays/prod/kustomization.yaml
# Commenter ou supprimer les lignes de l'ELK stack

# Alternative: Supprimer directement
kubectl delete statefulset elasticsearch -n amoona-prod
kubectl delete deployment logstash kibana -n amoona-prod
```

## 9.4 Configurer l'Autoscaling (HPA)

```bash
# Voir la configuration HPA actuelle
kubectl get hpa -n amoona-prod

# Modifier le HPA pour l'API
kubectl patch hpa amoona-api-hpa -n amoona-prod --type merge -p '
{
  "spec": {
    "minReplicas": 1,
    "maxReplicas": 3,
    "metrics": [
      {
        "type": "Resource",
        "resource": {
          "name": "cpu",
          "target": {
            "type": "Utilization",
            "averageUtilization": 80
          }
        }
      }
    ]
  }
}'
```

## 9.5 Monitoring des Ressources

```bash
# Voir l'utilisation des ressources par pod
kubectl top pods -n amoona-prod

# Voir l'utilisation par node
kubectl top nodes

# Voir les pods qui consomment le plus de mémoire
kubectl top pods -n amoona-prod --sort-by=memory

# Voir les limites et requests configurées
kubectl get pods -n amoona-prod -o custom-columns=\
NAME:.metadata.name,\
CPU_REQ:.spec.containers[0].resources.requests.cpu,\
CPU_LIM:.spec.containers[0].resources.limits.cpu,\
MEM_REQ:.spec.containers[0].resources.requests.memory,\
MEM_LIM:.spec.containers[0].resources.limits.memory
```

## 9.6 Résolution des Problèmes de Ressources

### Pod en OOMKilled (Out of Memory)

```bash
# Identifier les pods OOMKilled
kubectl get pods -n amoona-prod | grep OOMKilled

# Voir les events
kubectl describe pod NOM_DU_POD -n amoona-prod | grep -A5 "Events"

# Solution: Augmenter les limits de mémoire
kubectl patch deployment NOM_DEPLOYMENT -n amoona-prod --type merge -p '
{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "CONTAINER_NAME",
          "resources": {
            "limits": {
              "memory": "1Gi"
            }
          }
        }]
      }
    }
  }
}'
```

### Pod en Pending (Ressources insuffisantes)

```bash
# Identifier pourquoi le pod est pending
kubectl describe pod NOM_DU_POD -n amoona-prod | grep -A10 "Events"

# Messages courants:
# - "Insufficient cpu" -> Réduire les requests CPU ou ajouter des nodes
# - "Insufficient memory" -> Réduire les requests mémoire ou ajouter des nodes

# Solution: Réduire les requests
kubectl patch deployment NOM_DEPLOYMENT -n amoona-prod --type merge -p '
{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "CONTAINER_NAME",
          "resources": {
            "requests": {
              "cpu": "100m",
              "memory": "256Mi"
            }
          }
        }]
      }
    }
  }
}'
```

---

# 10. MONITORING ET OBSERVABILITÉ

## 10.1 Accéder à Grafana

```bash
# Via port-forward
kubectl port-forward svc/grafana -n amoona-prod 3000:3000

# Accès: http://localhost:3000
# User: admin
# Password: (voir section 6.3)
```

### Dashboards Recommandés à Importer

| Dashboard | ID Grafana | Description |
|-----------|------------|-------------|
| Kubernetes Cluster | 7249 | Vue globale du cluster |
| Node Exporter Full | 1860 | Métriques système détaillées |
| PostgreSQL | 9628 | Monitoring PostgreSQL |
| Redis | 11835 | Monitoring Redis |
| Spring Boot | 12900 | Métriques Spring Boot |

## 10.2 Accéder à Prometheus

```bash
kubectl port-forward svc/prometheus -n amoona-prod 9090:9090
# Accès: http://localhost:9090
```

### Requêtes Prometheus Utiles

```promql
# Utilisation CPU par pod
sum(rate(container_cpu_usage_seconds_total{namespace="amoona-prod"}[5m])) by (pod)

# Utilisation mémoire par pod
sum(container_memory_working_set_bytes{namespace="amoona-prod"}) by (pod)

# Requêtes HTTP par seconde
rate(http_server_requests_seconds_count{namespace="amoona-prod"}[5m])

# Latence moyenne des requêtes
histogram_quantile(0.95, rate(http_server_requests_seconds_bucket{namespace="amoona-prod"}[5m]))
```

## 10.3 Accéder aux Logs (Kibana)

```bash
kubectl port-forward svc/kibana -n amoona-prod 5601:5601
# Accès: http://localhost:5601
```

### Configuration de l'Index Pattern

1. Aller dans Stack Management → Index Patterns
2. Créer un index pattern: `logstash-*`
3. Choisir `@timestamp` comme champ de temps
4. Aller dans Discover pour voir les logs

---

# 11. SÉCURITÉ

## 11.1 NetworkPolicies

Les NetworkPolicies sont automatiquement appliquées pour isoler les services:

```bash
# Voir les policies appliquées
kubectl get networkpolicies -n amoona-prod

# Tester la connectivité
kubectl exec -it deployment/amoona-api -n amoona-prod -- curl -v postgres:5432
```

## 11.2 Installation de Linkerd (mTLS - Optionnel)

```bash
# Installer Linkerd CLI
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install | sh
export PATH=$PATH:$HOME/.linkerd2/bin

# Vérifier les prérequis
linkerd check --pre

# Installer Linkerd
linkerd install --crds | kubectl apply -f -
linkerd install | kubectl apply -f -

# Installer l'extension viz (dashboard)
linkerd viz install | kubectl apply -f -

# Vérifier l'installation
linkerd check

# Voir le dashboard
linkerd viz dashboard
```

## 11.3 Bonnes Pratiques de Sécurité

- ✅ Tous les secrets sont chiffrés et non commités dans Git
- ✅ Les pods tournent en tant qu'utilisateurs non-root
- ✅ Les NetworkPolicies isolent les services
- ✅ TLS activé pour le trafic externe
- ✅ mTLS entre les services (avec Linkerd)

---

# 12. ACCÈS AUX SERVICES DEPUIS VOS APPLICATIONS

## 12.1 Configuration de l'API Backend

L'API utilise ces variables d'environnement pour se connecter aux services:

```yaml
# Variables automatiquement injectées via secrets
SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/amoona_db
SPRING_DATASOURCE_USERNAME: amoona
SPRING_DATASOURCE_PASSWORD: [from secret]

SPRING_DATA_REDIS_HOST: redis
SPRING_DATA_REDIS_PORT: 6379
SPRING_DATA_REDIS_PASSWORD: [from secret]

MINIO_ENDPOINT: http://minio:9000
MINIO_ACCESS_KEY: minio-admin
MINIO_SECRET_KEY: [from secret]

LOGGING_LOGSTASH_HOST: logstash
LOGGING_LOGSTASH_PORT: 5000
```

## 12.2 Noms DNS Internes

Depuis l'intérieur du cluster, utilisez ces noms DNS:

```
postgres.amoona-prod.svc.cluster.local:5432     # PostgreSQL
redis.amoona-prod.svc.cluster.local:6379        # Redis
minio.amoona-prod.svc.cluster.local:9000        # MinIO API
minio.amoona-prod.svc.cluster.local:9001        # MinIO Console
elasticsearch.amoona-prod.svc.cluster.local:9200 # Elasticsearch
logstash.amoona-prod.svc.cluster.local:5000     # Logstash

# Forme courte (même namespace)
postgres:5432
redis:6379
minio:9000
```

## 12.3 Accès Externe (Développement Local)

Pour développer localement avec les services du VPS:

```bash
# Script pour exposer tous les services localement
#!/bin/bash
kubectl port-forward svc/postgres -n amoona-prod 5432:5432 &
kubectl port-forward svc/redis -n amoona-prod 6379:6379 &
kubectl port-forward svc/minio -n amoona-prod 9000:9000 &
kubectl port-forward svc/elasticsearch -n amoona-prod 9200:9200 &

echo "Services disponibles sur localhost:"
echo "  PostgreSQL: localhost:5432"
echo "  Redis: localhost:6379"
echo "  MinIO: localhost:9000"
echo "  Elasticsearch: localhost:9200"
```

---

# 13. MAINTENANCE ET DÉPANNAGE

## 13.1 Commandes de Diagnostic

```bash
# État global
kubectl get nodes
kubectl get pods -n amoona-prod
kubectl top nodes
kubectl top pods -n amoona-prod

# Pods en erreur
kubectl get pods -n amoona-prod | grep -v Running

# Events récents
kubectl get events -n amoona-prod --sort-by='.lastTimestamp' | tail -20

# Logs d'un pod
kubectl logs -f deployment/amoona-api -n amoona-prod

# Logs précédents (si crash)
kubectl logs deployment/amoona-api -n amoona-prod --previous

# Exécuter une commande dans un pod
kubectl exec -it deployment/amoona-api -n amoona-prod -- /bin/sh
```

## 13.2 Problèmes Courants et Solutions

### Pod CrashLoopBackOff

```bash
# Voir les logs
kubectl logs POD_NAME -n amoona-prod --previous

# Causes fréquentes:
# - Secret manquant ou incorrect
# - Service dépendant non disponible
# - Erreur de configuration

# Solution: Vérifier les secrets et dépendances
kubectl get secrets -n amoona-prod
kubectl get pods -n amoona-prod
```

### Pod ImagePullBackOff

```bash
# Vérifier le secret GHCR
kubectl get secret ghcr-secret -n amoona-prod -o yaml

# Recréer le secret
kubectl delete secret ghcr-secret -n amoona-prod
kubectl create secret docker-registry ghcr-secret \
    --docker-server=ghcr.io \
    --docker-username=$GITHUB_USER \
    --docker-password=$GITHUB_TOKEN \
    -n amoona-prod
```

### PostgreSQL ne démarre pas

```bash
# Vérifier les logs
kubectl logs statefulset/postgres -n amoona-prod

# Vérifier le PVC
kubectl get pvc -n amoona-prod | grep postgres

# Si le PVC est en Pending, vérifier le StorageClass
kubectl get storageclass
```

### Elasticsearch ne démarre pas

```bash
# Problème courant: vm.max_map_count trop bas
# Sur le VPS:
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf

# Redémarrer le pod
kubectl delete pod elasticsearch-0 -n amoona-prod
```

## 13.3 Redémarrage des Services

```bash
# Redémarrer un deployment
kubectl rollout restart deployment/amoona-api -n amoona-prod

# Redémarrer tous les deployments
kubectl rollout restart deployment -n amoona-prod

# Redémarrer un StatefulSet
kubectl rollout restart statefulset/postgres -n amoona-prod
```

## 13.4 Sauvegardes

### PostgreSQL

```bash
# Backup
kubectl exec -it postgres-0 -n amoona-prod -- \
    pg_dump -U amoona amoona_db > backup_$(date +%Y%m%d_%H%M%S).sql

# Restore
kubectl exec -i postgres-0 -n amoona-prod -- \
    psql -U amoona amoona_db < backup_20241216.sql
```

### MinIO

```bash
# Installer mc (MinIO Client)
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc && sudo mv mc /usr/local/bin/

# Port-forward MinIO
kubectl port-forward svc/minio -n amoona-prod 9000:9000 &

# Configurer mc
mc alias set amoona http://localhost:9000 minio-admin VOTRE_MOT_DE_PASSE

# Backup d'un bucket
mc mirror amoona/mon-bucket /chemin/vers/backup/
```

## 13.5 Reset Complet

```bash
# ATTENTION: Supprime TOUTES les données!

# Supprimer le namespace (supprime tout ce qu'il contient)
kubectl delete namespace amoona-prod

# Recréer
kubectl create namespace amoona-prod

# Recréer le secret GHCR
kubectl create secret docker-registry ghcr-secret \
    --docker-server=ghcr.io \
    --docker-username=$GITHUB_USER \
    --docker-password=$GITHUB_TOKEN \
    -n amoona-prod

# Régénérer les secrets
./scripts/generate-secrets.sh prod

# Redéployer
kubectl apply -k k8s/overlays/prod
```

---

# 14. CHECKLIST DE DÉPLOIEMENT

## 14.1 Avant l'Installation

- [ ] VPS provisionné avec Ubuntu 22.04 LTS
- [ ] Accès SSH configuré
- [ ] Pare-feu configuré (ports 22, 80, 443, 6443)
- [ ] Swap désactivé
- [ ] Paramètres kernel configurés
- [ ] DNS configuré avec les enregistrements A

## 14.2 Installation Kubernetes

- [ ] K3s installé et fonctionnel
- [ ] kubectl configuré
- [ ] Helm installé
- [ ] Traefik (ingress) installé
- [ ] Cert-manager installé
- [ ] ClusterIssuer créé (Let's Encrypt)

## 14.3 Infrastructure

- [ ] Namespaces créés (amoona-dev, amoona-prod)
- [ ] Secret GHCR créé dans chaque namespace
- [ ] Secrets générés (./scripts/generate-secrets.sh)
- [ ] PostgreSQL déployé et Running
- [ ] Redis déployé et Running
- [ ] MinIO déployé et Running
- [ ] Elasticsearch déployé et Running (optionnel)
- [ ] Logstash déployé et Running (optionnel)

## 14.4 Applications

- [ ] amoona-api déployé et Running
- [ ] amoona-front déployé et Running
- [ ] Ingress configuré
- [ ] Certificats TLS générés

## 14.5 Monitoring

- [ ] Prometheus déployé
- [ ] Grafana déployé
- [ ] Dashboards importés
- [ ] Kibana déployé (si ELK activé)

## 14.6 Sécurité

- [ ] NetworkPolicies appliquées
- [ ] Linkerd installé (optionnel)
- [ ] Mots de passe sauvegardés dans un endroit sécurisé

## 14.7 Accès Distant

- [ ] kubeconfig copié sur machine locale
- [ ] Port-forwards testés
- [ ] Applications accessibles via les domaines

---

# ANNEXES

## A. Commandes Utiles Rapides

```bash
# Voir tout dans un namespace
kubectl get all -n amoona-prod

# Suivre les logs en temps réel
kubectl logs -f -l app=amoona-api -n amoona-prod

# Entrer dans un pod
kubectl exec -it deployment/amoona-api -n amoona-prod -- /bin/sh

# Voir les ressources utilisées
kubectl top pods -n amoona-prod
kubectl top nodes

# Redémarrer un déploiement
kubectl rollout restart deployment/amoona-api -n amoona-prod

# Voir l'historique des déploiements
kubectl rollout history deployment/amoona-api -n amoona-prod

# Rollback
kubectl rollout undo deployment/amoona-api -n amoona-prod
```

## B. URLs des Services (Production)

| Service | URL Interne | URL Externe |
|---------|-------------|-------------|
| API | http://amoona-api:80 | https://api.amoona.tech |
| Frontend | http://amoona-front:80 | https://app.amoona.tech |
| Grafana | http://grafana:3000 | https://grafana.amoona.tech |
| Prometheus | http://prometheus:9090 | (port-forward) |
| Kibana | http://kibana:5601 | https://kibana.amoona.tech |
| MinIO | http://minio:9000/9001 | https://minio.amoona.tech |
| PostgreSQL | postgres:5432 | (port-forward) |
| Redis | redis:6379 | (port-forward) |
| Elasticsearch | elasticsearch:9200 | (port-forward) |

## C. Contacts et Support

- **Repository**: https://github.com/hypnozSarl/amoona-deployer
- **Documentation Kubernetes**: https://kubernetes.io/docs/
- **Documentation K3s**: https://docs.k3s.io/
- **Documentation Linkerd**: https://linkerd.io/docs/

---

*Document généré le 16 Décembre 2024*
*Version: 3.0*
