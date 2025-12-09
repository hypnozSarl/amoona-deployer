# Commandes Kubernetes et Guide de Depannage

## Commandes Essentielles

### Gestion des Pods

```bash
# Lister tous les pods
kubectl get pods -A
kubectl get pods -n amoona-dev

# Details d'un pod
kubectl describe pod <pod-name> -n amoona-dev

# Logs d'un pod
kubectl logs <pod-name> -n amoona-dev
kubectl logs -f <pod-name> -n amoona-dev           # Follow
kubectl logs <pod-name> -n amoona-dev --previous   # Pod precedent

# Shell dans un pod
kubectl exec -it <pod-name> -n amoona-dev -- /bin/sh
kubectl exec -it <pod-name> -n amoona-dev -- /bin/bash

# Supprimer un pod (sera recree par le deployment)
kubectl delete pod <pod-name> -n amoona-dev
```

### Gestion des Deployments

```bash
# Lister les deployments
kubectl get deployments -n amoona-dev

# Scaler
kubectl scale deployment/<name> --replicas=3 -n amoona-dev

# Mise a jour image
kubectl set image deployment/<name> <container>=<image>:<tag> -n amoona-dev

# Rollout status
kubectl rollout status deployment/<name> -n amoona-dev

# Historique des rollouts
kubectl rollout history deployment/<name> -n amoona-dev

# Rollback
kubectl rollout undo deployment/<name> -n amoona-dev
kubectl rollout undo deployment/<name> --to-revision=2 -n amoona-dev

# Redemarrer un deployment
kubectl rollout restart deployment/<name> -n amoona-dev
```

### Gestion des Services

```bash
# Lister les services
kubectl get svc -n amoona-dev

# Details d'un service
kubectl describe svc <name> -n amoona-dev

# Voir les endpoints
kubectl get endpoints <name> -n amoona-dev

# Port-forward
kubectl port-forward svc/<name> <local-port>:<remote-port> -n amoona-dev
```

### Gestion du Stockage

```bash
# Lister PV et PVC
kubectl get pv
kubectl get pvc -n amoona-dev

# Details
kubectl describe pv <name>
kubectl describe pvc <name> -n amoona-dev

# Supprimer un PVC
kubectl delete pvc <name> -n amoona-dev
```

### Gestion des Secrets et ConfigMaps

```bash
# Lister
kubectl get secrets -n amoona-dev
kubectl get configmaps -n amoona-dev

# Voir le contenu (decode base64)
kubectl get secret <name> -n amoona-dev -o jsonpath='{.data.<key>}' | base64 -d

# Creer un secret
kubectl create secret generic <name> --from-literal=key=value -n amoona-dev

# Editer
kubectl edit secret <name> -n amoona-dev
kubectl edit configmap <name> -n amoona-dev
```

### Diagnostic et Debug

```bash
# Evenements du cluster
kubectl get events -n amoona-dev --sort-by='.lastTimestamp'
kubectl get events -A --field-selector type=Warning

# Utilisation des ressources
kubectl top nodes
kubectl top pods -n amoona-dev

# Debug avec un pod temporaire
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- sh
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- bash
```

---

## Guide de Depannage

### Pod ne demarre pas (Pending)

**Symptome:** Pod reste en status `Pending`

**Causes possibles:**
1. Ressources insuffisantes
2. PVC non bound
3. Node selector/affinity non satisfait

**Diagnostic:**
```bash
kubectl describe pod <pod-name> -n amoona-dev
kubectl get events -n amoona-dev
kubectl get pvc -n amoona-dev
```

**Solutions:**
```bash
# Verifier les ressources disponibles
kubectl describe nodes | grep -A 5 "Allocated resources"

# Verifier les PVC
kubectl get pvc -n amoona-dev
kubectl describe pvc <pvc-name> -n amoona-dev
```

---

### Pod en CrashLoopBackOff

**Symptome:** Pod demarre puis crash en boucle

**Causes possibles:**
1. Erreur dans l'application
2. Configuration incorrecte
3. Dependances non disponibles

**Diagnostic:**
```bash
kubectl logs <pod-name> -n amoona-dev
kubectl logs <pod-name> -n amoona-dev --previous
kubectl describe pod <pod-name> -n amoona-dev
```

**Solutions:**
```bash
# Verifier les variables d'environnement
kubectl exec -it <pod-name> -n amoona-dev -- env

# Verifier la configuration
kubectl get configmap <name> -n amoona-dev -o yaml
kubectl get secret <name> -n amoona-dev -o yaml
```

---

### ImagePullBackOff

**Symptome:** Impossible de telecharger l'image

**Causes possibles:**
1. Image n'existe pas
2. Probleme d'authentification au registry
3. Nom d'image incorrect

**Diagnostic:**
```bash
kubectl describe pod <pod-name> -n amoona-dev | grep -A 10 Events
```

**Solutions:**
```bash
# Verifier l'image
docker pull <image-name>

# Creer/verifier le secret du registry
kubectl create secret docker-registry regcred \
  --docker-server=<registry> \
  --docker-username=<user> \
  --docker-password=<password> \
  -n amoona-dev
```

---

### Service inaccessible

**Symptome:** Impossible de se connecter a un service

**Causes possibles:**
1. Service mal configure
2. Pods non ready
3. Probleme DNS

**Diagnostic:**
```bash
# Verifier le service
kubectl get svc <name> -n amoona-dev
kubectl get endpoints <name> -n amoona-dev

# Verifier les pods
kubectl get pods -n amoona-dev -l app=<label>

# Test DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup <service>.<namespace>.svc.cluster.local
```

**Solutions:**
```bash
# Verifier les labels
kubectl get svc <name> -n amoona-dev -o yaml | grep selector -A 5
kubectl get pods -n amoona-dev --show-labels

# Test de connexion
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl http://<service>:<port>
```

---

### Problemes de Stockage

**Symptome:** PVC en Pending ou erreurs de montage

**Causes possibles:**
1. StorageClass inexistante
2. Espace disque insuffisant
3. Permissions incorrectes

**Diagnostic:**
```bash
kubectl get pv,pvc -n amoona-dev
kubectl describe pvc <name> -n amoona-dev
kubectl get storageclass
```

**Solutions:**
```bash
# Verifier la StorageClass
kubectl get storageclass

# Verifier l'espace disque sur les nodes
kubectl get nodes -o wide
ssh <node> df -h

# Corriger les permissions (pour local-path)
sudo chown -R 1000:1000 /mnt/data/<service>
sudo chmod -R 755 /mnt/data/<service>
```

---

### Problemes PostgreSQL

**Symptome:** PostgreSQL ne demarre pas ou connexion refusee

**Diagnostic:**
```bash
kubectl logs -n amoona-dev -l app=postgres
kubectl exec -n amoona-dev postgres-0 -- pg_isready -U amoona
```

**Solutions:**
```bash
# Verifier les permissions du volume
kubectl exec -n amoona-dev postgres-0 -- ls -la /var/lib/postgresql/data

# Reinitialiser (ATTENTION: perte de donnees)
kubectl delete pvc postgres-data-postgres-0 -n amoona-dev
kubectl delete pod postgres-0 -n amoona-dev
```

---

### Problemes Redis

**Symptome:** Redis ne repond pas

**Diagnostic:**
```bash
kubectl logs -n amoona-dev -l app=redis
kubectl exec -n amoona-dev deploy/redis -- redis-cli ping
```

**Solutions:**
```bash
# Verifier la configuration
kubectl exec -n amoona-dev deploy/redis -- redis-cli CONFIG GET maxmemory

# Verifier la memoire
kubectl exec -n amoona-dev deploy/redis -- redis-cli INFO memory
```

---

### Problemes Elasticsearch

**Symptome:** Elasticsearch ne demarre pas

**Cause frequente:** vm.max_map_count trop bas

**Solutions:**
```bash
# Sur le node (temporaire)
sudo sysctl -w vm.max_map_count=262144

# Permanent
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Verifier la sante
kubectl port-forward -n amoona-dev svc/elasticsearch 9200:9200 &
curl http://localhost:9200/_cluster/health?pretty
```

---

### Problemes de Performance

**Symptome:** Applications lentes

**Diagnostic:**
```bash
# Utilisation des ressources
kubectl top pods -n amoona-dev
kubectl top nodes

# Verifier les limites
kubectl describe pod <pod> -n amoona-dev | grep -A 5 Limits
```

**Solutions:**
```bash
# Ajuster les ressources dans le deployment
kubectl edit deployment <name> -n amoona-dev

# Ajouter HPA
kubectl autoscale deployment <name> --min=2 --max=10 --cpu-percent=80 -n amoona-dev
```

---

## Commandes Utiles par Service

### PostgreSQL

```bash
# Connexion
kubectl exec -it -n amoona-dev postgres-0 -- psql -U amoona -d amoona_db

# Backup
kubectl exec -n amoona-dev postgres-0 -- pg_dump -U amoona amoona_db > backup.sql

# Restore
kubectl exec -i -n amoona-dev postgres-0 -- psql -U amoona amoona_db < backup.sql

# Stats
kubectl exec -n amoona-dev postgres-0 -- psql -U amoona -c "SELECT * FROM pg_stat_activity;"
```

### Redis

```bash
# CLI
kubectl exec -it -n amoona-dev deploy/redis -- redis-cli

# Stats
kubectl exec -n amoona-dev deploy/redis -- redis-cli INFO

# Flush (ATTENTION)
kubectl exec -n amoona-dev deploy/redis -- redis-cli FLUSHALL
```

### MinIO

```bash
# Logs
kubectl logs -n amoona-dev -l app=minio

# Health check
kubectl exec -n amoona-dev deploy/minio -- curl -s http://localhost:9000/minio/health/live
```

### Prometheus

```bash
# Reload config
kubectl exec -n amoona-dev deploy/prometheus -- kill -HUP 1

# Verifier les targets
kubectl port-forward -n amoona-dev svc/prometheus 9090:9090 &
curl http://localhost:9090/api/v1/targets
```

### Grafana

```bash
# Reset password admin
kubectl exec -n amoona-dev deploy/grafana -- grafana-cli admin reset-admin-password newpassword
```
