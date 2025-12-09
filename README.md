# Kubernetes Amoona Deployment

<div align="center">

![Kubernetes](https://img.shields.io/badge/kubernetes-v1.28+-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![Spring Boot](https://img.shields.io/badge/Spring_Boot-3.2+-6DB33F?style=for-the-badge&logo=spring-boot&logoColor=white)
![Angular](https://img.shields.io/badge/Angular-20+-DD0031?style=for-the-badge&logo=angular&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-316192?style=for-the-badge&logo=postgresql&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-green?style=for-the-badge)

**Infrastructure Kubernetes complete pour applications Spring Boot + Angular**

[Documentation](docs/) | [Quick Start](QUICK_START.md) | [Report Bug](../../issues) | [Request Feature](../../issues)

</div>

---

## A Propos

Ce projet fournit une infrastructure Kubernetes **production-ready** complete pour deployer des applications modernes (Spring Boot + Angular) avec tous les services necessaires.

**Deployez votre infrastructure complete en 10 minutes!**

## Fonctionnalites Principales

- **Stack complete**: PostgreSQL, Redis, MinIO, Prometheus, Grafana, Elasticsearch
- **Scripts automatises**: Deploiement en un clic
- **Documentation exhaustive**: Guide complet avec exemples testes
- **Production-ready**: SSL, monitoring, backups, scaling
- **Best practices**: Security, performance, maintainability
- **Kustomize**: Overlays pour dev et prod

## Demarrage Rapide

```bash
# Clone et installation
git clone https://github.com/votre-username/amoona-deployer.git
cd amoona-deployer
chmod +x scripts/*.sh

# Deploiement complet
./scripts/deploy-all.sh dev

# Verification
./scripts/test-all-services.sh
```

Voir le **[Guide de Demarrage Rapide Complet](QUICK_START.md)**

## Architecture

```
                    Ingress Controller (SSL/TLS)
    +------------------+------------------+------------------+
    |                  |                  |                  |
+---v----+        +----v---+        +-----v----+       +-----v----+
|Frontend|        |Backend |        | Grafana  |       |  MinIO   |
| Angular|        | Spring |        |Monitoring|       | Console  |
+--------+        +----+---+        +----------+       +----------+
                       |
        +--------------+---------------+---------------+
        |              |               |               |
   +----v---+    +-----v----+    +-----v----+    +-----v------+
   |Postgres|    |  Redis   |    |  MinIO   |    | Prometheus |
   +--------+    +----------+    +----------+    +------------+
```

## Services Inclus

| Service | Version | Description |
|---------|---------|-------------|
| PostgreSQL | 16 | Base de donnees relationnelle |
| Redis | 7 | Cache et sessions |
| MinIO | Latest | Stockage S3-compatible |
| Prometheus | 2.47 | Metriques et monitoring |
| Grafana | 10.2 | Visualisation |
| Elasticsearch | 8.11 | Logs et recherche |

## Structure du Projet

```
.
├── k8s/
│   ├── base/
│   │   ├── apps/              # Backend/Frontend deployments
│   │   ├── infra/             # Infrastructure (DB, Redis, MinIO)
│   │   │   ├── postgres/
│   │   │   ├── redis/
│   │   │   ├── minio/
│   │   │   └── elasticsearch/
│   │   └── monitoring/        # Prometheus, Grafana
│   │       ├── prometheus/
│   │       └── grafana/
│   └── overlays/
│       ├── dev/               # Development environment
│       └── prod/              # Production environment
├── scripts/
│   ├── deploy-all.sh          # Deploiement automatise
│   ├── test-all-services.sh   # Tests de connectivite
│   └── init-git-repo.sh       # Initialisation Git
├── examples/
│   ├── spring-boot/           # Configuration Spring Boot
│   └── angular/               # Configuration Angular
├── docs/
│   ├── guide-kubernetes-deployment.md
│   └── kubernetes-commands-troubleshooting.md
├── QUICK_START.md
└── README.md
```

## Documentation

| Document | Description |
|----------|-------------|
| [Guide Principal](docs/guide-kubernetes-deployment.md) | Guide complet de deploiement |
| [Quick Start](QUICK_START.md) | Demarrage en 10 minutes |
| [Spring Boot](examples/spring-boot/README.md) | Configuration Spring Boot |
| [Angular](examples/angular/README.md) | Configuration Angular |
| [Depannage](docs/kubernetes-commands-troubleshooting.md) | Commandes et solutions |

## Prerequis

- **OS**: Ubuntu 22.04+ / Debian 11+ / macOS
- **CPU**: 4 cores minimum (8 recommande)
- **RAM**: 8 GB minimum (16 recommande)
- **Disk**: 100 GB SSD
- **Kubernetes**: K3s 1.28+ ou MicroK8s ou tout cluster K8s

## Installation

### 1. Installer Kubernetes (K3s)

```bash
curl -sfL https://get.k3s.io | sh -
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
```

### 2. Deployer l'Infrastructure

```bash
# Deployer en dev
./scripts/deploy-all.sh dev

# Ou deployer en prod (mettre a jour les secrets d'abord!)
./scripts/deploy-all.sh prod
```

### 3. Verifier le Deploiement

```bash
kubectl get pods -n amoona-dev
./scripts/test-all-services.sh
```

## Acces aux Services

| Service | URL | Credentials |
|---------|-----|-------------|
| Grafana | http://grafana.amoona.tech | admin / (voir secret) |
| Prometheus | http://prometheus.amoona.tech | - |
| MinIO Console | http://storage.amoona.tech | (voir secret) |

## Monitoring

- **Dashboards Grafana** pre-configures
- **Metriques Prometheus** pour tous les services
- **Health checks** automatiques
- **Alerting** configurable

## Deployer Vos Applications

### Backend Spring Boot

```bash
# Creer le deploiement dans k8s/base/apps/backend/
kubectl apply -k k8s/overlays/dev
```

Voir [examples/spring-boot/README.md](examples/spring-boot/README.md)

### Frontend Angular

```bash
# Creer le deploiement dans k8s/base/apps/frontend/
kubectl apply -k k8s/overlays/dev
```

Voir [examples/angular/README.md](examples/angular/README.md)

## Securite

**Important:** Avant tout deploiement en production:

1. Mettre a jour tous les secrets dans `k8s/overlays/prod/secrets-patch.yaml`
2. Activer SSL/TLS avec cert-manager
3. Configurer les NetworkPolicies
4. Utiliser un gestionnaire de secrets (Vault, Sealed Secrets)

## Contribution

Les contributions sont bienvenues! Voir [CONTRIBUTING.md](CONTRIBUTING.md)

## Licence

MIT License - Voir [LICENSE](LICENSE)

---
# Grafana credentials
kubectl get secret grafana-secret -n amoona-prod -o jsonpath='{.data.GF_SECURITY_ADMIN_USER}' | base64 -d && echo
kubectl get secret grafana-secret -n amoona-prod -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' | base64 -d && echo

# MinIO credentials
kubectl get secret minio-secret -n amoona-prod -o jsonpath='{.data.MINIO_ROOT_USER}' | base64 -d && echo
kubectl get secret minio-secret -n amoona-prod -o jsonpath='{.data.MINIO_ROOT_PASSWORD}' | base64 -d && echo

# PostgreSQL credentials
kubectl get secret postgres-secret -n amoona-prod -o jsonpath='{.data.POSTGRES_USER}' | base64 -d && echo
kubectl get secret postgres-secret -n amoona-prod -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d && echo

Ou pour voir tous les secrets d'un coup :

# Voir tout le contenu d'un secret (décodé)
kubectl get secret grafana-secret -n amoona-prod -o go-template='{{range $k,$v := .data}}{{$k}}: {{$v | base64decode}}{{"\n"}}{{end}}'

<div align="center">

Made with care for the Kubernetes community

</div>
