# Kubernetes Amoona Deployment

<div align="center">

![Kubernetes](https://img.shields.io/badge/kubernetes-v1.28+-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![Spring Boot](https://img.shields.io/badge/Spring_Boot-3.2+-6DB33F?style=for-the-badge&logo=spring-boot&logoColor=white)
![Angular](https://img.shields.io/badge/Angular-20+-DD0031?style=for-the-badge&logo=angular&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-316192?style=for-the-badge&logo=postgresql&logoColor=white)
![Security Score](https://img.shields.io/badge/Security_Score-10%2F10-brightgreen?style=for-the-badge)

**Infrastructure Kubernetes production-ready pour applications Spring Boot + Angular**

[Documentation Complète](docs/INFRASTRUCTURE_GUIDE.md) | [Quick Start](docs/QUICKSTART.md) | [Commandes](docs/COMMANDS_REFERENCE.md)

</div>

---

## À Propos

Infrastructure Kubernetes **enterprise-grade** avec sécurité avancée :

- **mTLS** automatique via Linkerd
- **Scan de vulnérabilités** continu avec Trivy
- **Détection d'intrusions** runtime avec Falco
- **Gestion des secrets** avec HashiCorp Vault
- **NetworkPolicies** pour isolation réseau

## Quick Start (5 minutes)

```bash
# 1. Installer K3s
curl -sfL https://get.k3s.io | sh -s - --disable traefik
mkdir -p ~/.kube && sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config

# 2. Cloner le repo
git clone https://github.com/hypnozSarl/amoona-deployer.git && cd amoona-deployer

# 3. Configurer les accès
kubectl create namespace amoona-prod
kubectl create secret docker-registry ghcr-secret \
    --docker-server=ghcr.io \
    --docker-username=YOUR_USER \
    --docker-password=YOUR_TOKEN \
    -n amoona-prod

# 4. Générer les secrets et déployer
./scripts/generate-secrets.sh prod
kubectl apply -k k8s/overlays/prod

# 5. Vérifier
kubectl get pods -n amoona-prod
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         INTERNET                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────▼─────────┐
                    │  Ingress + TLS    │
                    │  (cert-manager)   │
                    └─────────┬─────────┘
                              │
         ┌────────────────────┼────────────────────┐
         │                    │                    │
    ┌────▼────┐         ┌─────▼────┐         ┌────▼────┐
    │ Frontend│         │   API    │         │ Grafana │
    │ Angular │◄───────►│  Spring  │         │Monitoring│
    └─────────┘  mTLS   └────┬─────┘         └─────────┘
                             │ mTLS
       ┌─────────────────────┼─────────────────────┐
       │          │          │          │          │
  ┌────▼──┐  ┌────▼──┐  ┌────▼──┐  ┌────▼───┐  ┌───▼────┐
  │Postgres│  │ Redis │  │ MinIO │  │Elastic │  │Logstash│
  └────────┘  └───────┘  └───────┘  └────────┘  └────────┘
```

## Services Inclus

| Service | Version | Description |
|---------|---------|-------------|
| **Applications** |||
| amoona-api | Spring Boot 3.2 | Backend API REST |
| amoona-front | Angular 20 | Frontend SPA |
| **Infrastructure** |||
| PostgreSQL | 16 | Base de données |
| Redis | 7 | Cache & sessions |
| MinIO | Latest | Stockage S3 |
| **Observabilité** |||
| Prometheus | 2.47 | Métriques |
| Grafana | 10.2 | Dashboards |
| Elasticsearch | 8.11 | Logs |
| Logstash | 8.11 | Ingestion logs |
| Kibana | 8.11 | Visualisation logs |
| **Sécurité** |||
| Vault | 1.15 | Gestion secrets |
| Linkerd | 2.14 | Service mesh (mTLS) |
| Trivy | 0.48 | Scan vulnérabilités |
| Falco | 0.37 | Détection intrusions |

## Documentation

| Document | Description |
|----------|-------------|
| **[Infrastructure Guide](docs/INFRASTRUCTURE_GUIDE.md)** | Guide complet de A à Z |
| [Quick Start](docs/QUICKSTART.md) | Démarrage rapide |
| [Commandes](docs/COMMANDS_REFERENCE.md) | Référence des commandes |

## Structure du Projet

```
amoona-deployer/
├── k8s/
│   ├── base/                    # Configurations de base
│   │   ├── apps/                # amoona-api, amoona-front
│   │   ├── infra/               # postgres, redis, minio, elk, vault
│   │   ├── monitoring/          # prometheus, grafana
│   │   ├── security/            # NetworkPolicies
│   │   ├── service-mesh/        # Linkerd mTLS
│   │   ├── security-scanning/   # Trivy
│   │   └── audit-logging/       # Falco
│   └── overlays/
│       ├── dev/                 # Overlay développement
│       └── prod/                # Overlay production
├── scripts/
│   ├── generate-secrets.sh      # Génération secrets
│   ├── init-vault.sh            # Initialisation Vault
│   └── install-linkerd.sh       # Installation Linkerd
└── docs/
    ├── INFRASTRUCTURE_GUIDE.md  # Guide complet
    ├── QUICKSTART.md            # Démarrage rapide
    └── COMMANDS_REFERENCE.md    # Commandes
```

## Sécurité (Score 10/10)

| Composant | Status | Description |
|-----------|--------|-------------|
| Secrets | ✅ | Vault + templates (pas de secrets en clair) |
| Chiffrement | ✅ | mTLS automatique via Linkerd |
| Réseau | ✅ | NetworkPolicies (default-deny) |
| Conteneurs | ✅ | Non-privilégiés, readOnlyRootFilesystem |
| Scan Images | ✅ | Trivy Operator continu |
| Audit | ✅ | Falco + K8s audit logs |
| Auth services | ✅ | Elasticsearch, Redis avec mots de passe |

## Scripts Disponibles

```bash
# Génération des secrets
./scripts/generate-secrets.sh [dev|prod]

# Installation Linkerd (mTLS)
./scripts/install-linkerd.sh

# Initialisation Vault
./scripts/init-vault.sh [namespace]
```

## Accès aux Services (port-forward)

```bash
# Grafana (monitoring)
kubectl port-forward svc/grafana 3000:3000 -n amoona-prod

# Prometheus (métriques)
kubectl port-forward svc/prometheus 9090:9090 -n amoona-prod

# Kibana (logs)
kubectl port-forward svc/kibana 5601:5601 -n amoona-prod

# MinIO (stockage)
kubectl port-forward svc/minio 9001:9001 -n amoona-prod
```

## Récupération des Mots de Passe

```bash
# Grafana
kubectl get secret grafana-secret -n amoona-prod -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' | base64 -d

# PostgreSQL
kubectl get secret postgres-secret -n amoona-prod -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d

# MinIO
kubectl get secret minio-secret -n amoona-prod -o jsonpath='{.data.MINIO_ROOT_PASSWORD}' | base64 -d
```

## Prérequis

| Ressource | Minimum | Recommandé |
|-----------|---------|------------|
| CPU | 4 cores | 8+ cores |
| RAM | 16 GB | 32+ GB |
| Stockage | 100 GB SSD | 500+ GB NVMe |
| OS | Ubuntu 22.04 | Ubuntu 22.04 |

## Contribution

Les contributions sont bienvenues ! Voir les issues ouvertes.

## Licence

MIT License

---

<div align="center">

**[Documentation Complète](docs/INFRASTRUCTURE_GUIDE.md)** | **[Quick Start](docs/QUICKSTART.md)** | **[Commandes](docs/COMMANDS_REFERENCE.md)**

</div>
