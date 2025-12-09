# Guide Complet de Deploiement Kubernetes

## Spring Boot + Angular + PostgreSQL + Redis + MinIO + Grafana + Prometheus + Elasticsearch

---

## Table des Matieres

1. [Prerequis](#prerequis)
2. [Installation du Cluster Kubernetes](#installation-kubernetes)
3. [Configuration du Stockage Persistant](#stockage)
4. [Deploiement des Services de Base de Donnees](#databases)
5. [Deploiement des Services de Monitoring](#monitoring)
6. [Deploiement des Applications](#applications)
7. [Configuration Ingress et Sous-domaines](#ingress)
8. [Tests et Validation](#tests)
9. [Maintenance et Operations](#maintenance)
10. [Depannage](#depannage)

---

## 1. Prerequis

### Infrastructure Requise

```bash
# Configuration minimale recommandee
- CPU: 4 cores minimum (8 recommande)
- RAM: 8 GB minimum (16 recommande)
- Disk: 100 GB SSD
- OS: Ubuntu 22.04 LTS ou similaire
```

### Installation des Outils

```bash
# Mise a jour du systeme
sudo apt update && sudo apt upgrade -y

# Installation de Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Installation de kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verification
kubectl version --client
```

---

## 2. Installation du Cluster Kubernetes

### Option A: K3s (Recommande)

```bash
# Installation de K3s (Kubernetes leger)
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644

# Configuration du kubeconfig
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config

# Verification
kubectl get nodes
kubectl cluster-info
```

### Option B: MicroK8s

```bash
# Installation de MicroK8s
sudo snap install microk8s --classic
sudo usermod -a -G microk8s $USER
newgrp microk8s

# Activer les addons essentiels
microk8s enable dns storage ingress

# Alias kubectl
alias kubectl='microk8s kubectl'
```

---

## 3. Configuration du Stockage

### Structure Kustomize

Ce projet utilise Kustomize pour gerer les configurations:

```
k8s/
├── base/           # Configurations de base
│   ├── infra/      # PostgreSQL, Redis, MinIO, Elasticsearch
│   └── monitoring/ # Prometheus, Grafana
└── overlays/
    ├── dev/        # Surcharges pour dev
    └── prod/       # Surcharges pour prod
```

### Deploiement avec Kustomize

```bash
# Valider les manifestes
kubectl kustomize k8s/overlays/dev

# Appliquer
kubectl apply -k k8s/overlays/dev

# Ou utiliser le script
./scripts/deploy-all.sh dev
```

---

## 4. Services de Base de Donnees

### PostgreSQL 16

**Localisation**: `k8s/base/infra/postgres/`

Composants:
- StatefulSet avec PVC
- Service ClusterIP
- Secret pour les credentials

```bash
# Verifier PostgreSQL
kubectl get pods -n amoona-dev -l app=postgres

# Test de connexion
kubectl exec -it -n amoona-dev postgres-0 -- psql -U amoona -d amoona_db -c "SELECT version();"
```

### Redis 7

**Localisation**: `k8s/base/infra/redis/`

Composants:
- Deployment
- ConfigMap avec redis.conf
- Service ClusterIP

```bash
# Verifier Redis
kubectl exec -it -n amoona-dev deploy/redis -- redis-cli ping
# Reponse attendue: PONG
```

### MinIO

**Localisation**: `k8s/base/infra/minio/`

Composants:
- Deployment avec PVC
- Secret pour credentials
- Service (API + Console)

```bash
# Verifier MinIO
kubectl get pods -n amoona-dev -l app=minio
kubectl logs -n amoona-dev -l app=minio
```

### Elasticsearch 8

**Localisation**: `k8s/base/infra/elasticsearch/`

Composants:
- StatefulSet avec PVC
- Init containers pour permissions
- Service ClusterIP

```bash
# Verifier Elasticsearch
kubectl port-forward -n amoona-dev svc/elasticsearch 9200:9200 &
curl http://localhost:9200
```

---

## 5. Services de Monitoring

### Prometheus

**Localisation**: `k8s/base/monitoring/prometheus/`

Configuration:
- Scrape configs pour tous les services
- RBAC pour acces cluster
- Retention 15 jours

```bash
# Acces Prometheus
kubectl port-forward -n amoona-dev svc/prometheus 9090:9090 &
# Ouvrir http://localhost:9090
```

### Grafana

**Localisation**: `k8s/base/monitoring/grafana/`

Configuration:
- Datasource Prometheus pre-configure
- Dashboard infrastructure inclus

```bash
# Acces Grafana
kubectl port-forward -n amoona-dev svc/grafana 3000:3000 &
# Ouvrir http://localhost:3000
# Login: admin / (voir secret)
```

**Dashboards recommandes a importer:**
- ID 6417: Kubernetes Cluster
- ID 315: Kubernetes Overview
- ID 9628: PostgreSQL
- ID 11835: Redis

---

## 6. Deploiement des Applications

### Backend Spring Boot

1. **Creer la structure** dans `k8s/base/apps/backend/`:

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  labels:
    app: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/actuator/prometheus"
    spec:
      containers:
        - name: backend
          image: your-registry/backend:latest
          ports:
            - containerPort: 8080
          env:
            - name: SPRING_PROFILES_ACTIVE
              value: "prod"
            - name: SPRING_DATASOURCE_URL
              value: "jdbc:postgresql://postgres:5432/amoona_db"
            - name: SPRING_REDIS_HOST
              value: "redis"
          envFrom:
            - secretRef:
                name: backend-secret
          resources:
            requests:
              memory: "512Mi"
              cpu: "500m"
            limits:
              memory: "1Gi"
              cpu: "1000m"
          livenessProbe:
            httpGet:
              path: /actuator/health/liveness
              port: 8080
            initialDelaySeconds: 60
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /actuator/health/readiness
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 5
```

2. **Configuration Spring Boot** (application-prod.yml):

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus,metrics
  endpoint:
    health:
      probes:
        enabled: true
  metrics:
    export:
      prometheus:
        enabled: true
```

### Frontend Angular

1. **Creer la structure** dans `k8s/base/apps/frontend/`:

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    app: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
        - name: frontend
          image: your-registry/frontend:latest
          ports:
            - containerPort: 80
          resources:
            requests:
              memory: "64Mi"
              cpu: "50m"
            limits:
              memory: "128Mi"
              cpu: "100m"
          livenessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 10
            periodSeconds: 10
```

---

## 7. Configuration Ingress

### Ingress NGINX

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: amoona-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - host: app.amoona.tech
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 80
    - host: api.amoona.tech
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: backend
                port:
                  number: 8080
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

### SSL avec Cert-Manager

```bash
# Installer cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Creer ClusterIssuer
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
EOF
```

---

## 8. Tests et Validation

### Script de Test

```bash
./scripts/test-all-services.sh
```

### Tests Manuels

```bash
# Test PostgreSQL
kubectl exec -n amoona-dev postgres-0 -- pg_isready -U amoona

# Test Redis
kubectl exec -n amoona-dev deploy/redis -- redis-cli ping

# Test MinIO
kubectl exec -n amoona-dev deploy/minio -- curl -s http://localhost:9000/minio/health/live

# Test Prometheus
kubectl exec -n amoona-dev deploy/prometheus -- wget -qO- http://localhost:9090/-/ready

# Test Grafana
kubectl exec -n amoona-dev deploy/grafana -- wget -qO- http://localhost:3000/api/health
```

---

## 9. Maintenance

### Mise a jour des Applications

```bash
# Mise a jour du backend
kubectl set image deployment/backend backend=your-registry/backend:v1.1.0 -n amoona-dev
kubectl rollout status deployment/backend -n amoona-dev

# Rollback si necessaire
kubectl rollout undo deployment/backend -n amoona-dev
```

### Scaling

```bash
# Scaler le backend
kubectl scale deployment/backend --replicas=5 -n amoona-dev

# Autoscaling
kubectl autoscale deployment/backend --min=2 --max=10 --cpu-percent=80 -n amoona-dev
```

### Backup PostgreSQL

```bash
# Backup
kubectl exec -n amoona-dev postgres-0 -- pg_dump -U amoona amoona_db > backup.sql

# Restore
kubectl exec -i -n amoona-dev postgres-0 -- psql -U amoona amoona_db < backup.sql
```

---

## 10. Depannage

Voir le guide complet: [kubernetes-commands-troubleshooting.md](kubernetes-commands-troubleshooting.md)

### Problemes Courants

**Pod en CrashLoopBackOff:**
```bash
kubectl logs -n amoona-dev <pod-name>
kubectl describe pod -n amoona-dev <pod-name>
kubectl get events -n amoona-dev --sort-by='.lastTimestamp'
```

**Problemes de Stockage:**
```bash
kubectl get pv,pvc -n amoona-dev
kubectl describe pvc -n amoona-dev
```

**Problemes Reseau:**
```bash
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup postgres.amoona-dev.svc.cluster.local
```

---

## Ressources Supplementaires

- [Kubernetes Official Docs](https://kubernetes.io/docs/)
- [Kustomize Documentation](https://kustomize.io/)
- [Spring Boot Actuator](https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
