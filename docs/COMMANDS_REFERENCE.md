# Référence des commandes - Amoona Infrastructure

## 📋 Index

- [Installation](#installation)
- [Déploiement](#déploiement)
- [Gestion des pods](#gestion-des-pods)
- [Secrets](#secrets)
- [Logs](#logs)
- [Monitoring](#monitoring)
- [Sécurité](#sécurité)
- [Base de données](#base-de-données)
- [Maintenance](#maintenance)

---

## Installation

### K3s (serveur unique)

```bash
# Installation
curl -sfL https://get.k3s.io | sh -s - --disable traefik --write-kubeconfig-mode 644

# Configuration kubectl
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Vérification
kubectl get nodes
```

### Outils CLI

```bash
# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Linkerd
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install | sh

# GitHub CLI
sudo apt install gh
```

---

## Déploiement

### Déploiement complet

```bash
# Environnement dev
kubectl apply -k k8s/overlays/dev

# Environnement prod
kubectl apply -k k8s/overlays/prod

# Composant spécifique
kubectl apply -k k8s/base/infra/postgres
kubectl apply -k k8s/base/apps/amoona-api
```

### Mise à jour d'image

```bash
# Via kubectl
kubectl set image deployment/amoona-api \
    amoona-api=ghcr.io/hypnozsarl/amoona-api:TAG \
    -n amoona-prod

# Via kustomize
cd k8s/overlays/prod/apps/amoona-api
kustomize edit set image ghcr.io/hypnozsarl/amoona-api:TAG
kubectl apply -k .
```

### Rollback

```bash
# Historique
kubectl rollout history deployment/amoona-api -n amoona-prod

# Rollback dernière version
kubectl rollout undo deployment/amoona-api -n amoona-prod

# Rollback version spécifique
kubectl rollout undo deployment/amoona-api --to-revision=2 -n amoona-prod
```

### Scaling

```bash
# Manuel
kubectl scale deployment/amoona-api --replicas=5 -n amoona-prod

# Voir HPA
kubectl get hpa -n amoona-prod

# Modifier HPA
kubectl patch hpa amoona-api-hpa -n amoona-prod \
    -p '{"spec":{"maxReplicas":10}}'
```

---

## Gestion des pods

### Visualisation

```bash
# Tous les pods
kubectl get pods -n amoona-prod

# Avec plus de détails
kubectl get pods -n amoona-prod -o wide

# En temps réel
kubectl get pods -n amoona-prod -w

# Pods en erreur
kubectl get pods -n amoona-prod | grep -v Running
```

### Informations détaillées

```bash
# Describe
kubectl describe pod POD_NAME -n amoona-prod

# YAML complet
kubectl get pod POD_NAME -n amoona-prod -o yaml

# Ressources utilisées
kubectl top pods -n amoona-prod
```

### Actions sur les pods

```bash
# Supprimer un pod (sera recréé)
kubectl delete pod POD_NAME -n amoona-prod

# Supprimer pods en erreur
kubectl delete pods --field-selector status.phase=Failed -n amoona-prod

# Redémarrer tous les pods d'un deployment
kubectl rollout restart deployment/amoona-api -n amoona-prod
```

### Exécution dans un pod

```bash
# Shell interactif
kubectl exec -it POD_NAME -n amoona-prod -- /bin/sh

# Commande unique
kubectl exec POD_NAME -n amoona-prod -- ls -la

# Dans un deployment
kubectl exec -it deployment/amoona-api -n amoona-prod -- /bin/sh
```

---

## Secrets

### Génération

```bash
# Script automatique
./scripts/generate-secrets.sh dev
./scripts/generate-secrets.sh prod
```

### Visualisation

```bash
# Lister les secrets
kubectl get secrets -n amoona-prod

# Voir un secret (encodé base64)
kubectl get secret postgres-secret -n amoona-prod -o yaml

# Décoder un secret
kubectl get secret postgres-secret -n amoona-prod \
    -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d && echo
```

### Création manuelle

```bash
# Secret générique
kubectl create secret generic my-secret \
    --from-literal=username=admin \
    --from-literal=password=secret123 \
    -n amoona-prod

# Secret depuis fichier
kubectl create secret generic my-secret \
    --from-file=./secret.txt \
    -n amoona-prod

# Secret Docker registry
kubectl create secret docker-registry ghcr-secret \
    --docker-server=ghcr.io \
    --docker-username=USER \
    --docker-password=TOKEN \
    -n amoona-prod
```

### Vault

```bash
# Initialiser Vault
./scripts/init-vault.sh amoona-prod

# Accéder à Vault
kubectl exec -it vault-0 -n vault -- vault login

# Lire un secret
kubectl exec -it vault-0 -n vault -- vault kv get secret/amoona/database

# Écrire un secret
kubectl exec -it vault-0 -n vault -- vault kv put secret/amoona/database password="newpassword"
```

---

## Logs

### Logs basiques

```bash
# Logs d'un pod
kubectl logs POD_NAME -n amoona-prod

# Logs en temps réel
kubectl logs -f POD_NAME -n amoona-prod

# Logs du pod précédent (après crash)
kubectl logs POD_NAME -n amoona-prod --previous

# Dernières N lignes
kubectl logs POD_NAME -n amoona-prod --tail=100
```

### Logs avancés

```bash
# Tous les pods d'un deployment
kubectl logs -l app=amoona-api -n amoona-prod

# Tous les conteneurs
kubectl logs POD_NAME -n amoona-prod --all-containers

# Depuis une date
kubectl logs POD_NAME -n amoona-prod --since=1h
kubectl logs POD_NAME -n amoona-prod --since-time="2024-01-01T00:00:00Z"
```

### Stern (recommandé)

```bash
# Installation
brew install stern  # macOS
# ou
go install github.com/stern/stern@latest

# Usage
stern amoona-api -n amoona-prod
stern "amoona-*" -n amoona-prod
stern . -n amoona-prod  # tous les pods
```

---

## Monitoring

### Accès aux dashboards

```bash
# Grafana
kubectl port-forward svc/grafana 3000:3000 -n amoona-prod

# Prometheus
kubectl port-forward svc/prometheus 9090:9090 -n amoona-prod

# Kibana
kubectl port-forward svc/kibana 5601:5601 -n amoona-prod

# Alertmanager
kubectl port-forward svc/alertmanager 9093:9093 -n amoona-prod
```

### Métriques

```bash
# Ressources nodes
kubectl top nodes

# Ressources pods
kubectl top pods -n amoona-prod

# Ressources par conteneur
kubectl top pods -n amoona-prod --containers
```

### Events

```bash
# Events récents
kubectl get events -n amoona-prod --sort-by='.lastTimestamp'

# Events d'un pod
kubectl describe pod POD_NAME -n amoona-prod | grep -A 20 Events
```

---

## Sécurité

### Linkerd (mTLS)

```bash
# Installation
./scripts/install-linkerd.sh

# Vérification
linkerd check

# Dashboard
linkerd viz dashboard &

# Vérifier mTLS
linkerd viz edges deployment -n amoona-prod

# Stats de trafic
linkerd viz stat deployment -n amoona-prod
```

### Trivy (scan vulnérabilités)

```bash
# Voir les rapports
kubectl get vulnerabilityreports -n amoona-prod

# Détails d'un rapport
kubectl describe vulnerabilityreport REPORT_NAME -n amoona-prod

# Scan manuel d'une image
trivy image ghcr.io/hypnozsarl/amoona-api:latest
```

### Falco (détection intrusions)

```bash
# Logs Falco
kubectl logs -l app=falco -n falco -f

# Alertes critiques
kubectl logs -l app=falco -n falco | grep CRITICAL
```

### NetworkPolicies

```bash
# Lister
kubectl get networkpolicies -n amoona-prod

# Détails
kubectl describe networkpolicy allow-api-from-frontend -n amoona-prod

# Tester connectivité
kubectl exec -it deployment/amoona-api -n amoona-prod -- nc -zv postgres 5432
```

---

## Base de données

### PostgreSQL

```bash
# Connexion psql
kubectl exec -it deployment/postgres -n amoona-prod -- psql -U amoona amoona_db

# Requête directe
kubectl exec deployment/postgres -n amoona-prod -- psql -U amoona -c "SELECT * FROM users LIMIT 5"

# Backup
kubectl exec deployment/postgres -n amoona-prod -- pg_dump -U amoona amoona_db > backup.sql

# Restore
kubectl exec -i deployment/postgres -n amoona-prod -- psql -U amoona amoona_db < backup.sql

# Liste des tables
kubectl exec deployment/postgres -n amoona-prod -- psql -U amoona -c "\dt"
```

### Redis

```bash
# Connexion redis-cli
kubectl exec -it deployment/redis -n amoona-prod -- redis-cli

# Avec mot de passe
kubectl exec -it deployment/redis -n amoona-prod -- redis-cli -a PASSWORD

# Commandes Redis
kubectl exec deployment/redis -n amoona-prod -- redis-cli PING
kubectl exec deployment/redis -n amoona-prod -- redis-cli INFO
kubectl exec deployment/redis -n amoona-prod -- redis-cli KEYS "*"
```

### Elasticsearch

```bash
# Santé du cluster
kubectl exec deployment/elasticsearch -n amoona-prod -- \
    curl -s -u elastic:PASSWORD localhost:9200/_cluster/health | jq

# Liste des indices
kubectl exec deployment/elasticsearch -n amoona-prod -- \
    curl -s -u elastic:PASSWORD localhost:9200/_cat/indices

# Stats
kubectl exec deployment/elasticsearch -n amoona-prod -- \
    curl -s -u elastic:PASSWORD localhost:9200/_stats | jq
```

---

## Maintenance

### Nettoyage

```bash
# Pods en erreur
kubectl delete pods --field-selector status.phase=Failed -n amoona-prod

# Pods terminés
kubectl delete pods --field-selector status.phase=Succeeded -n amoona-prod

# Anciennes ReplicaSets
kubectl delete rs -n amoona-prod $(kubectl get rs -n amoona-prod -o jsonpath='{.items[?(@.spec.replicas==0)].metadata.name}')

# PVC non utilisés
kubectl get pvc -n amoona-prod | grep -v Bound
```

### Backup

```bash
# Tous les secrets
kubectl get secrets -n amoona-prod -o yaml > secrets-backup.yaml

# Tous les ConfigMaps
kubectl get configmaps -n amoona-prod -o yaml > configmaps-backup.yaml

# Tous les deployments
kubectl get deployments -n amoona-prod -o yaml > deployments-backup.yaml

# Export complet namespace
kubectl get all -n amoona-prod -o yaml > namespace-backup.yaml
```

### Diagnostic

```bash
# État du cluster
kubectl cluster-info
kubectl get nodes -o wide
kubectl get componentstatuses

# Capacité du cluster
kubectl describe nodes | grep -A 5 "Allocated resources"

# Pods par node
kubectl get pods -A -o wide | awk '{print $8}' | sort | uniq -c
```

---

## Alias utiles

Ajoutez à votre `~/.bashrc` ou `~/.zshrc` :

```bash
# Kubernetes
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgd='kubectl get deployments'
alias kga='kubectl get all'
alias kdp='kubectl describe pod'
alias kl='kubectl logs -f'
alias ke='kubectl exec -it'

# Namespaces fréquents
alias kprod='kubectl -n amoona-prod'
alias kdev='kubectl -n amoona-dev'

# Commandes pratiques
alias kwatch='kubectl get pods -w'
alias klogs='kubectl logs -f --tail=100'
alias krestart='kubectl rollout restart deployment'

# Port-forwards
alias grafana='kubectl port-forward svc/grafana 3000:3000 -n amoona-prod'
alias prometheus='kubectl port-forward svc/prometheus 9090:9090 -n amoona-prod'
alias kibana='kubectl port-forward svc/kibana 5601:5601 -n amoona-prod'
```

---

*Dernière mise à jour : Décembre 2024*
