# Guide de Demarrage Rapide

Deployez votre infrastructure Kubernetes complete en 10 minutes!

## Installation Express

```bash
# 1. Cloner le projet
git clone https://github.com/votre-username/amoona-deployer.git
cd amoona-deployer

# 2. Rendre les scripts executables
chmod +x scripts/*.sh

# 3. Deployer tout
./scripts/deploy-all.sh dev

# 4. Verifier
./scripts/test-all-services.sh
```

## Prerequis Rapides

```bash
# Verifier que vous avez tout
which docker kubectl

# Si manquants, installer rapidement
curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

## Installation K3s (Recommande)

```bash
# Installer K3s (Kubernetes leger)
curl -sfL https://get.k3s.io | sh -

# Configurer kubectl
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config

# Verifier
kubectl get nodes
```

## Premier Deploiement

```bash
# 1. Creer les repertoires de donnees (si utilisation de local-storage)
sudo mkdir -p /mnt/data/{postgres,redis,minio,prometheus,grafana,elasticsearch}
sudo chmod -R 777 /mnt/data

# 2. Deployer avec Kustomize
./scripts/deploy-all.sh dev

# 3. Attendre que tout soit pret
kubectl wait --for=condition=ready pod --all -n amoona-dev --timeout=300s
```

## Verification Rapide

```bash
# Etat global
kubectl get all -n amoona-dev

# Pods en production
kubectl get pods -n amoona-dev

# Services
kubectl get svc -n amoona-dev
```

## Acces aux Services

### Port-Forwarding (Acces local)

```bash
# Grafana
kubectl port-forward -n amoona-dev svc/grafana 3000:3000 &

# Prometheus
kubectl port-forward -n amoona-dev svc/prometheus 9090:9090 &

# MinIO Console
kubectl port-forward -n amoona-dev svc/minio 9001:9001 &

# PostgreSQL
kubectl port-forward -n amoona-dev svc/postgres 5432:5432 &
```

### URLs d'Acces

| Service | URL | Identifiants |
|---------|-----|--------------|
| Grafana | http://localhost:3000 | admin / dev-grafana-password |
| Prometheus | http://localhost:9090 | - |
| MinIO Console | http://localhost:9001 | minio-admin / dev-minio-password |
| PostgreSQL | localhost:5432 | amoona / dev-postgres-password |

## Commandes Utiles

```bash
# Logs d'un service
kubectl logs -f -n amoona-dev -l app=postgres

# Shell dans un pod
kubectl exec -it -n amoona-dev deploy/postgres -- /bin/sh

# Redemarrer un service
kubectl rollout restart deployment/redis -n amoona-dev

# Scaler un service
kubectl scale deployment/redis --replicas=3 -n amoona-dev

# Etat d'un rollout
kubectl rollout status deployment/redis -n amoona-dev
```

## Depannage Express

### Pod ne demarre pas

```bash
# Voir les evenements
kubectl describe pod <pod-name> -n amoona-dev

# Voir les logs
kubectl logs <pod-name> -n amoona-dev

# Logs du conteneur precedent (si crash)
kubectl logs <pod-name> -n amoona-dev --previous
```

### Service inaccessible

```bash
# Verifier le service
kubectl get svc -n amoona-dev
kubectl get endpoints <service-name> -n amoona-dev

# Test DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup postgres.amoona-dev.svc.cluster.local

# Test de connexion
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl http://grafana:3000
```

### Problemes de stockage

```bash
# Verifier les PV/PVC
kubectl get pv,pvc -n amoona-dev

# Verifier l'espace disque
df -h /mnt/data

# Corriger les permissions
sudo chown -R 999:999 /mnt/data/postgres
sudo chmod -R 755 /mnt/data/*
```

## Deployer Votre Application

### Backend Spring Boot

```bash
# 1. Creer votre Dockerfile
cat > Dockerfile <<EOF
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
EOF

# 2. Builder l'image
docker build -t votre-registry/backend:latest .

# 3. Pusher l'image
docker push votre-registry/backend:latest

# 4. Creer le deployment K8s dans k8s/base/apps/backend/
# Voir examples/spring-boot/
```

### Frontend Angular

```bash
# 1. Creer votre Dockerfile
cat > Dockerfile <<EOF
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build -- --configuration production

FROM nginx:alpine
COPY --from=build /app/dist/*/browser /usr/share/nginx/html
EXPOSE 80
EOF

# 2. Builder et pusher
docker build -t votre-registry/frontend:latest .
docker push votre-registry/frontend:latest

# 3. Creer le deployment K8s dans k8s/base/apps/frontend/
# Voir examples/angular/
```

## Securiser en Production

```bash
# 1. Changer TOUS les mots de passe dans k8s/overlays/prod/secrets-patch.yaml
nano k8s/overlays/prod/secrets-patch.yaml

# 2. Deployer en prod
./scripts/deploy-all.sh prod

# 3. Activer SSL (avec cert-manager)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

## Prochaines Etapes

1. **Configurer le monitoring complet**
   - Importer les dashboards Grafana
   - Configurer les alertes Prometheus

2. **Deployer vos applications**
   - Suivre les exemples Spring Boot et Angular
   - Adapter les configurations a vos besoins

3. **Securiser**
   - Changer tous les mots de passe par defaut
   - Activer SSL/TLS
   - Configurer NetworkPolicies

4. **Automatiser**
   - Mettre en place CI/CD
   - Configurer les backups automatiques

## Ressources

- **Documentation complete**: [docs/guide-kubernetes-deployment.md](docs/guide-kubernetes-deployment.md)
- **Depannage**: [docs/kubernetes-commands-troubleshooting.md](docs/kubernetes-commands-troubleshooting.md)
- **Spring Boot**: [examples/spring-boot/README.md](examples/spring-boot/README.md)
- **Angular**: [examples/angular/README.md](examples/angular/README.md)

---

**Temps estime**: 10-15 minutes pour le deploiement complet

**Bon deploiement!**
