# Amoona Infrastructure - Guide Complet

## Table des matières

1. [Vue d'ensemble](#1-vue-densemble)
2. [Prérequis](#2-prérequis)
3. [Architecture](#3-architecture)
4. [Installation du serveur](#4-installation-du-serveur)
5. [Déploiement de l'infrastructure](#5-déploiement-de-linfrastructure)
6. [Configuration des secrets](#6-configuration-des-secrets)
7. [Déploiement des applications](#7-déploiement-des-applications)
8. [Monitoring et observabilité](#8-monitoring-et-observabilité)
9. [Sécurité](#9-sécurité)
10. [Maintenance](#10-maintenance)
11. [Troubleshooting](#11-troubleshooting)
12. [Contacts et ressources](#12-contacts-et-ressources)

---

## 1. Vue d'ensemble

### Description du projet

Amoona est une plateforme déployée sur Kubernetes comprenant :
- **Frontend** : Application web (Angular/React)
- **Backend** : API Spring Boot
- **Base de données** : PostgreSQL
- **Cache** : Redis
- **Stockage** : MinIO (S3-compatible)
- **Logging** : ELK Stack (Elasticsearch, Logstash, Kibana)
- **Monitoring** : Prometheus + Grafana
- **CI/CD** : ArgoCD
- **Sécurité** : Vault, Linkerd, Trivy, Falco

### Environnements

| Environnement | Namespace | URL |
|---------------|-----------|-----|
| Development | `amoona-dev` | dev.amoona.tech |
| Production | `amoona-prod` | amoona.tech |

---

## 2. Prérequis

### 2.1 Serveur minimum requis

| Ressource | Minimum | Recommandé |
|-----------|---------|------------|
| CPU | 4 cores | 8+ cores |
| RAM | 16 GB | 32+ GB |
| Stockage | 100 GB SSD | 500+ GB NVMe |
| OS | Ubuntu 22.04 LTS | Ubuntu 22.04 LTS |

### 2.2 Outils à installer sur votre machine locale

```bash
# kubectl - Kubernetes CLI
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# k3s (pour installation légère) ou kubeadm (production)
# Voir section 4 pour l'installation

# Helm (gestionnaire de packages K8s)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# kustomize (déjà inclus dans kubectl >= 1.14)
kubectl version --client

# GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install gh

# Linkerd CLI
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install | sh
export PATH=$PATH:$HOME/.linkerd2/bin
```

### 2.3 Accès requis

- [ ] Accès SSH au serveur
- [ ] Accès au repository GitHub : `hypnozSarl/amoona-deployer`
- [ ] Token GitHub avec droits `read:packages` (pour les images Docker)
- [ ] Accès au DNS (pour configurer les domaines)

---

## 3. Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              INTERNET                                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         INGRESS CONTROLLER                                   │
│                    (Traefik / Nginx Ingress)                                │
│        *.amoona.tech → Services internes                                    │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        │                           │                           │
        ▼                           ▼                           ▼
┌───────────────┐         ┌───────────────┐         ┌───────────────┐
│  amoona-front │         │  amoona-api   │         │   Grafana     │
│    :80        │────────▶│    :8080      │         │    :3000      │
└───────────────┘         └───────────────┘         └───────────────┘
                                    │
        ┌───────────────┬───────────┼───────────┬───────────────┐
        │               │           │           │               │
        ▼               ▼           ▼           ▼               ▼
┌───────────┐   ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐
│ PostgreSQL│   │   Redis   │ │   MinIO   │ │Elasticsearch│ │  Logstash │
│   :5432   │   │   :6379   │ │:9000/:9001│ │   :9200   │ │   :5000   │
└───────────┘   └───────────┘ └───────────┘ └───────────┘ └───────────┘
```

### Structure des dossiers

```
amoona-deployer/
├── k8s/
│   ├── base/                    # Configurations de base
│   │   ├── apps/                # Applications (api, front)
│   │   ├── infra/               # Infrastructure (postgres, redis, etc.)
│   │   ├── monitoring/          # Prometheus, Grafana
│   │   ├── security/            # NetworkPolicies
│   │   ├── service-mesh/        # Linkerd mTLS
│   │   ├── security-scanning/   # Trivy
│   │   ├── audit-logging/       # Falco
│   │   └── ingress/             # Ingress rules
│   ├── overlays/
│   │   ├── dev/                 # Overlay développement
│   │   └── prod/                # Overlay production
│   └── templates/               # Templates réutilisables
├── scripts/                     # Scripts d'automatisation
│   ├── generate-secrets.sh      # Génération des secrets
│   ├── init-vault.sh            # Initialisation Vault
│   └── install-linkerd.sh       # Installation Linkerd
└── docs/                        # Documentation
```

---

## 4. Installation du serveur

### 4.1 Préparation du serveur

```bash
# Connexion SSH au serveur
ssh user@your-server-ip

# Mise à jour du système
sudo apt update && sudo apt upgrade -y

# Installation des dépendances
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    jq \
    openssl

# Désactiver le swap (requis pour Kubernetes)
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Configurer les paramètres kernel
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
```

### 4.2 Installation de K3s (recommandé pour serveur unique)

```bash
# Installation de K3s
curl -sfL https://get.k3s.io | sh -s - \
    --disable traefik \
    --write-kubeconfig-mode 644

# Vérifier l'installation
sudo k3s kubectl get nodes

# Copier le kubeconfig pour kubectl
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Vérifier
kubectl get nodes
```

### 4.3 Alternative : Installation avec kubeadm (production multi-nodes)

```bash
# Installation de containerd
sudo apt install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd

# Installation de kubeadm, kubelet, kubectl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Initialisation du cluster (sur le master)
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Configuration kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Installation du CNI (Flannel)
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Si single node, autoriser les pods sur le master
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

### 4.4 Installation du stockage local

```bash
# Installation de local-path-provisioner (pour K3s, déjà inclus)
# Pour kubeadm :
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml

# Définir comme StorageClass par défaut
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

---

## 5. Déploiement de l'infrastructure

### 5.1 Cloner le repository

```bash
# Sur le serveur ou votre machine locale
git clone https://github.com/hypnozSarl/amoona-deployer.git
cd amoona-deployer

# Checkout de la branche sécurisée
git checkout securite
```

### 5.2 Créer les namespaces

```bash
# Créer les namespaces
kubectl create namespace amoona-dev
kubectl create namespace amoona-prod
kubectl create namespace argocd

# Ajouter les labels pour Linkerd (injection auto)
kubectl label namespace amoona-dev linkerd.io/inject=enabled
kubectl label namespace amoona-prod linkerd.io/inject=enabled
```

### 5.3 Configurer l'accès au registry GitHub

```bash
# Créer le secret pour GitHub Container Registry
# Remplacer YOUR_GITHUB_TOKEN par votre token

kubectl create secret docker-registry ghcr-secret \
    --docker-server=ghcr.io \
    --docker-username=YOUR_GITHUB_USERNAME \
    --docker-password=YOUR_GITHUB_TOKEN \
    -n amoona-dev

kubectl create secret docker-registry ghcr-secret \
    --docker-server=ghcr.io \
    --docker-username=YOUR_GITHUB_USERNAME \
    --docker-password=YOUR_GITHUB_TOKEN \
    -n amoona-prod
```

### 5.4 Déployer l'infrastructure de base

```bash
# Déployer l'infrastructure en dev
kubectl apply -k k8s/overlays/dev

# OU déployer en production
kubectl apply -k k8s/overlays/prod

# Vérifier le déploiement
kubectl get pods -n amoona-prod -w
```

### 5.5 Ordre de déploiement recommandé (si problèmes)

```bash
# 1. Cert-manager (pour les certificats TLS)
kubectl apply -k k8s/base/cert-manager

# 2. Infrastructure (base de données, cache, etc.)
kubectl apply -k k8s/base/infra/postgres
kubectl apply -k k8s/base/infra/redis
kubectl apply -k k8s/base/infra/minio
kubectl apply -k k8s/base/infra/elasticsearch
kubectl apply -k k8s/base/infra/logstash
kubectl apply -k k8s/base/infra/kibana

# 3. Monitoring
kubectl apply -k k8s/base/monitoring

# 4. Sécurité
kubectl apply -k k8s/base/security

# 5. Applications
kubectl apply -k k8s/base/apps

# 6. Ingress
kubectl apply -k k8s/base/ingress
```

---

## 6. Configuration des secrets

### 6.1 Méthode 1 : Secrets Kubernetes (développement)

```bash
# Générer les secrets automatiquement
./scripts/generate-secrets.sh dev   # Pour dev
./scripts/generate-secrets.sh prod  # Pour prod

# Le script génère :
# - k8s/overlays/{env}/secrets-patch.yaml
# - k8s/overlays/{env}/apps/amoona-api/secrets.yaml

# Appliquer les secrets
kubectl apply -f k8s/overlays/prod/secrets-patch.yaml -n amoona-prod
kubectl apply -f k8s/overlays/prod/apps/amoona-api/secrets.yaml -n amoona-prod
```

### 6.2 Méthode 2 : HashiCorp Vault (production recommandée)

```bash
# 1. Déployer Vault
kubectl apply -k k8s/base/infra/vault

# 2. Attendre que Vault soit prêt
kubectl wait --for=condition=ready pod -l app=vault -n vault --timeout=300s

# 3. Initialiser Vault
./scripts/init-vault.sh amoona-prod

# IMPORTANT : Sauvegarder les clés affichées !
# - Root Token
# - Unseal Keys (5 clés, 3 requises pour déverrouiller)

# 4. Activer l'intégration Vault dans le deployment
# Éditer k8s/overlays/prod/apps/amoona-api/kustomization.yaml
# Décommenter : - path: vault-patch.yaml
```

### 6.3 Rotation des secrets

```bash
# Régénérer tous les secrets
./scripts/generate-secrets.sh prod

# Redémarrer les pods pour appliquer les nouveaux secrets
kubectl rollout restart deployment -n amoona-prod

# Avec Vault, les secrets sont automatiquement rotationnés
```

---

## 7. Déploiement des applications

### 7.1 Déploiement manuel

```bash
# Déployer l'API
kubectl apply -k k8s/overlays/prod/apps/amoona-api

# Déployer le Frontend
kubectl apply -k k8s/overlays/prod/apps/amoona-front

# Vérifier le statut
kubectl get pods -n amoona-prod
kubectl get services -n amoona-prod
```

### 7.2 Mise à jour d'une image

```bash
# Mettre à jour le tag de l'image API
cd k8s/overlays/prod/apps/amoona-api
kustomize edit set image ghcr.io/hypnozsarl/amoona-api:NEW_TAG

# Appliquer
kubectl apply -k .

# OU directement
kubectl set image deployment/amoona-api \
    amoona-api=ghcr.io/hypnozsarl/amoona-api:NEW_TAG \
    -n amoona-prod
```

### 7.3 Rollback

```bash
# Voir l'historique des déploiements
kubectl rollout history deployment/amoona-api -n amoona-prod

# Rollback à la version précédente
kubectl rollout undo deployment/amoona-api -n amoona-prod

# Rollback à une révision spécifique
kubectl rollout undo deployment/amoona-api --to-revision=2 -n amoona-prod
```

### 7.4 ArgoCD (GitOps - recommandé)

```bash
# Installer ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Attendre que ArgoCD soit prêt
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

# Récupérer le mot de passe admin
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port-forward pour accéder à l'UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Accéder à https://localhost:8080
# User: admin, Password: (celui récupéré ci-dessus)

# Créer l'application ArgoCD
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: amoona-prod
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/hypnozSarl/amoona-deployer.git
    targetRevision: main
    path: k8s/overlays/prod
  destination:
    server: https://kubernetes.default.svc
    namespace: amoona-prod
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF
```

---

## 8. Monitoring et observabilité

### 8.1 Accéder à Grafana

```bash
# Port-forward Grafana
kubectl port-forward svc/grafana -n amoona-prod 3000:3000

# Accéder à http://localhost:3000
# User: admin
# Password: récupérer avec :
kubectl get secret grafana-secret -n amoona-prod -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' | base64 -d
```

### 8.2 Accéder à Prometheus

```bash
# Port-forward Prometheus
kubectl port-forward svc/prometheus -n amoona-prod 9090:9090

# Accéder à http://localhost:9090
```

### 8.3 Accéder à Kibana (logs)

```bash
# Port-forward Kibana
kubectl port-forward svc/kibana -n amoona-prod 5601:5601

# Accéder à http://localhost:5601
# Configurer l'index pattern : logstash-*
```

### 8.4 Dashboards Grafana recommandés

Importer ces dashboards via Grafana UI (+ → Import) :

| Dashboard | ID | Description |
|-----------|-----|-------------|
| Kubernetes Cluster | 7249 | Vue globale du cluster |
| Node Exporter | 1860 | Métriques des nodes |
| PostgreSQL | 9628 | Monitoring PostgreSQL |
| Redis | 11835 | Monitoring Redis |
| Spring Boot | 12900 | Métriques Spring Boot |

### 8.5 Alertes

```bash
# Vérifier les alertes Prometheus
kubectl port-forward svc/alertmanager -n amoona-prod 9093:9093

# Les règles d'alerte sont dans :
# k8s/base/monitoring/prometheus/prometheus-rules.yaml
```

---

## 9. Sécurité

### 9.1 Installer Linkerd (mTLS)

```bash
# Installer Linkerd
./scripts/install-linkerd.sh

# Vérifier l'installation
linkerd check

# Voir le dashboard
linkerd viz dashboard &

# Vérifier que mTLS est actif
linkerd viz edges deployment -n amoona-prod
```

### 9.2 Installer Trivy (scan de vulnérabilités)

```bash
# Déployer Trivy Operator
kubectl apply -k k8s/base/security-scanning

# Vérifier les rapports de vulnérabilités
kubectl get vulnerabilityreports -n amoona-prod

# Détails d'un rapport
kubectl describe vulnerabilityreport <report-name> -n amoona-prod
```

### 9.3 Installer Falco (détection d'intrusions)

```bash
# Déployer Falco
kubectl apply -k k8s/base/audit-logging

# Voir les logs Falco
kubectl logs -l app=falco -n falco -f

# Les alertes sont dans /var/log/falco/events.json sur chaque node
```

### 9.4 NetworkPolicies

Les NetworkPolicies sont automatiquement appliquées via `k8s/base/security/network-policies.yaml`.

```bash
# Vérifier les NetworkPolicies
kubectl get networkpolicies -n amoona-prod

# Tester la connectivité
kubectl exec -it deployment/amoona-api -n amoona-prod -- curl -v postgres:5432
```

### 9.5 Audit de sécurité

```bash
# Scanner le cluster avec kubescape
curl -s https://raw.githubusercontent.com/kubescape/kubescape/master/install.sh | /bin/bash
kubescape scan framework nsa -v

# Scanner les images avec Trivy CLI
trivy image ghcr.io/hypnozsarl/amoona-api:latest
```

---

## 10. Maintenance

### 10.1 Sauvegardes

#### PostgreSQL

```bash
# Backup manuel
kubectl exec -it deployment/postgres -n amoona-prod -- \
    pg_dump -U amoona amoona_db > backup_$(date +%Y%m%d).sql

# Restore
kubectl exec -i deployment/postgres -n amoona-prod -- \
    psql -U amoona amoona_db < backup_20240101.sql
```

#### MinIO

```bash
# Installer mc (MinIO Client)
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc && sudo mv mc /usr/local/bin/

# Configurer mc
kubectl port-forward svc/minio -n amoona-prod 9000:9000 &
mc alias set amoona http://localhost:9000 minio-admin YOUR_MINIO_PASSWORD

# Backup
mc mirror amoona/bucket-name /path/to/backup/
```

### 10.2 Mises à jour

#### Kubernetes

```bash
# K3s
curl -sfL https://get.k3s.io | sh -

# kubeadm
sudo apt update
sudo apt-mark unhold kubeadm kubelet kubectl
sudo apt install -y kubeadm kubelet kubectl
sudo apt-mark hold kubeadm kubelet kubectl
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.29.x
```

#### Applications

```bash
# Mettre à jour via Git (GitOps)
git pull origin main
kubectl apply -k k8s/overlays/prod

# Ou via ArgoCD
# L'application se synchronise automatiquement
```

### 10.3 Scaling

```bash
# Scale manuel
kubectl scale deployment amoona-api --replicas=5 -n amoona-prod

# Le HPA (Horizontal Pod Autoscaler) gère le scaling automatique
kubectl get hpa -n amoona-prod

# Modifier les limites HPA
kubectl edit hpa amoona-api-hpa -n amoona-prod
```

### 10.4 Logs

```bash
# Logs d'un pod
kubectl logs deployment/amoona-api -n amoona-prod -f

# Logs de tous les pods d'un deployment
kubectl logs -l app=amoona-api -n amoona-prod --all-containers

# Logs avec stern (plus pratique)
brew install stern  # ou apt install stern
stern amoona-api -n amoona-prod
```

### 10.5 Nettoyage

```bash
# Supprimer les pods en erreur
kubectl delete pods --field-selector status.phase=Failed -n amoona-prod

# Supprimer les anciennes ReplicaSets
kubectl delete rs -n amoona-prod $(kubectl get rs -n amoona-prod -o jsonpath='{.items[?(@.spec.replicas==0)].metadata.name}')

# Nettoyer les images non utilisées sur les nodes
# (exécuter sur chaque node)
sudo crictl rmi --prune
```

---

## 11. Troubleshooting

### 11.1 Commandes de diagnostic

```bash
# État général du cluster
kubectl get nodes
kubectl top nodes
kubectl get pods --all-namespaces

# Pods en erreur
kubectl get pods -n amoona-prod | grep -v Running

# Détails d'un pod
kubectl describe pod POD_NAME -n amoona-prod

# Events récents
kubectl get events -n amoona-prod --sort-by='.lastTimestamp'

# Ressources utilisées
kubectl top pods -n amoona-prod
```

### 11.2 Problèmes courants

#### Pod en CrashLoopBackOff

```bash
# Voir les logs
kubectl logs POD_NAME -n amoona-prod --previous

# Causes fréquentes :
# - Secret manquant
# - Configuration incorrecte
# - Dépendance non disponible (DB, etc.)
```

#### Pod en Pending

```bash
# Voir les events
kubectl describe pod POD_NAME -n amoona-prod

# Causes fréquentes :
# - Ressources insuffisantes (CPU/RAM)
# - PVC non bound
# - Node selector ne match pas
```

#### Impossible de pull l'image

```bash
# Vérifier le secret docker-registry
kubectl get secret ghcr-secret -n amoona-prod -o yaml

# Recréer le secret
kubectl delete secret ghcr-secret -n amoona-prod
kubectl create secret docker-registry ghcr-secret \
    --docker-server=ghcr.io \
    --docker-username=USER \
    --docker-password=TOKEN \
    -n amoona-prod
```

#### Base de données inaccessible

```bash
# Vérifier que PostgreSQL fonctionne
kubectl exec -it deployment/postgres -n amoona-prod -- psql -U amoona -c "SELECT 1"

# Vérifier les NetworkPolicies
kubectl get networkpolicies -n amoona-prod

# Test de connectivité depuis l'API
kubectl exec -it deployment/amoona-api -n amoona-prod -- nc -zv postgres 5432
```

### 11.3 Reset complet

```bash
# ATTENTION : Supprime tout !
kubectl delete namespace amoona-prod
kubectl delete namespace amoona-dev

# Recréer
kubectl create namespace amoona-prod
kubectl create namespace amoona-dev

# Redéployer
kubectl apply -k k8s/overlays/prod
```

---

## 12. Contacts et ressources

### Équipe

| Rôle | Nom | Contact |
|------|-----|---------|
| Lead DevOps | - | - |
| Backend Dev | - | - |
| Frontend Dev | - | - |

### Liens utiles

| Ressource | URL |
|-----------|-----|
| Repository | https://github.com/hypnozSarl/amoona-deployer |
| Grafana | https://grafana.amoona.tech |
| ArgoCD | https://argocd.amoona.tech |
| API Docs | https://api.amoona.tech/swagger-ui.html |

### Documentation externe

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [K3s Documentation](https://docs.k3s.io/)
- [Kustomize Documentation](https://kustomize.io/)
- [Linkerd Documentation](https://linkerd.io/2.14/overview/)
- [Vault Documentation](https://developer.hashicorp.com/vault/docs)

---

## Checklist de déploiement

### Nouveau serveur

- [ ] Serveur provisionné avec Ubuntu 22.04
- [ ] Accès SSH configuré
- [ ] K3s ou kubeadm installé
- [ ] kubectl configuré
- [ ] Storage class configuré
- [ ] Repository cloné

### Configuration

- [ ] Namespaces créés
- [ ] Secret GHCR créé
- [ ] Secrets générés
- [ ] DNS configuré

### Déploiement

- [ ] Infrastructure déployée
- [ ] Applications déployées
- [ ] Ingress configuré
- [ ] Certificats TLS actifs

### Sécurité

- [ ] Linkerd installé (mTLS)
- [ ] Trivy déployé
- [ ] Falco déployé
- [ ] NetworkPolicies appliquées
- [ ] Vault configuré (si production)

### Monitoring

- [ ] Grafana accessible
- [ ] Prometheus collecte les métriques
- [ ] Alertes configurées
- [ ] Logs centralisés (ELK)

---

*Dernière mise à jour : Décembre 2024*
*Version : 2.0.0*
