# Amoona - Quick Start Guide

> Guide rapide pour déployer l'infrastructure en moins de 30 minutes

## TL;DR - Commandes essentielles

```bash
# 1. Installer K3s sur le serveur
curl -sfL https://get.k3s.io | sh -s - --disable traefik
mkdir -p ~/.kube && sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config

# 2. Cloner et configurer
git clone https://github.com/hypnozSarl/amoona-deployer.git && cd amoona-deployer
git checkout securite

# 3. Créer namespaces et secrets
kubectl create namespace amoona-prod
kubectl create secret docker-registry ghcr-secret \
    --docker-server=ghcr.io \
    --docker-username=YOUR_USER \
    --docker-password=YOUR_TOKEN \
    -n amoona-prod

# 4. Générer et appliquer les secrets
./scripts/generate-secrets.sh prod

# 5. Déployer tout
kubectl apply -k k8s/overlays/prod

# 6. Vérifier
kubectl get pods -n amoona-prod -w
```

---

## Commandes de maintenance quotidienne

### Vérifier l'état

```bash
# État des pods
kubectl get pods -n amoona-prod

# État des services
kubectl get svc -n amoona-prod

# Ressources utilisées
kubectl top pods -n amoona-prod

# Logs en temps réel
kubectl logs -f deployment/amoona-api -n amoona-prod
```

### Redémarrer un service

```bash
# Redémarrer l'API
kubectl rollout restart deployment/amoona-api -n amoona-prod

# Redémarrer le frontend
kubectl rollout restart deployment/amoona-front -n amoona-prod

# Redémarrer tout
kubectl rollout restart deployment -n amoona-prod
```

### Mettre à jour une image

```bash
# API
kubectl set image deployment/amoona-api amoona-api=ghcr.io/hypnozsarl/amoona-api:NEW_TAG -n amoona-prod

# Frontend
kubectl set image deployment/amoona-front amoona-front=ghcr.io/hypnozsarl/amoona-front:NEW_TAG -n amoona-prod
```

### Rollback

```bash
kubectl rollout undo deployment/amoona-api -n amoona-prod
```

### Scaler

```bash
kubectl scale deployment/amoona-api --replicas=3 -n amoona-prod
```

---

## Accès aux services

| Service | Commande | URL |
|---------|----------|-----|
| Grafana | `kubectl port-forward svc/grafana 3000:3000 -n amoona-prod` | http://localhost:3000 |
| Prometheus | `kubectl port-forward svc/prometheus 9090:9090 -n amoona-prod` | http://localhost:9090 |
| Kibana | `kubectl port-forward svc/kibana 5601:5601 -n amoona-prod` | http://localhost:5601 |
| MinIO | `kubectl port-forward svc/minio 9001:9001 -n amoona-prod` | http://localhost:9001 |
| ArgoCD | `kubectl port-forward svc/argocd-server 8080:443 -n argocd` | https://localhost:8080 |

---

## Mots de passe

```bash
# Grafana
kubectl get secret grafana-secret -n amoona-prod -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' | base64 -d && echo

# PostgreSQL
kubectl get secret postgres-secret -n amoona-prod -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d && echo

# ArgoCD
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d && echo
```

---

## Troubleshooting rapide

```bash
# Pod qui crash ?
kubectl logs POD_NAME -n amoona-prod --previous
kubectl describe pod POD_NAME -n amoona-prod

# Connectivité DB ?
kubectl exec -it deployment/amoona-api -n amoona-prod -- nc -zv postgres 5432

# Events récents
kubectl get events -n amoona-prod --sort-by='.lastTimestamp' | tail -20

# Ressources insuffisantes ?
kubectl describe nodes | grep -A 5 "Allocated resources"
```

---

## Backup rapide

```bash
# PostgreSQL
kubectl exec deployment/postgres -n amoona-prod -- pg_dump -U amoona amoona_db > backup.sql

# Secrets
kubectl get secrets -n amoona-prod -o yaml > secrets-backup.yaml
```

---

## Contacts urgents

- **Repository** : https://github.com/hypnozSarl/amoona-deployer
- **Documentation complète** : [INFRASTRUCTURE_GUIDE.md](./INFRASTRUCTURE_GUIDE.md)
