# Templates Kubernetes

Templates prêts à l'emploi pour déployer rapidement différents types de services.

## Templates Disponibles

| Template | Description | Usage |
|----------|-------------|-------|
| `backend-api/` | API REST (Spring Boot, Node.js, Python) | Services backend avec HPA |
| `frontend-web/` | Application web (Angular, React, Vue) | Sites statiques avec Nginx |
| `database/` | Base de données (PostgreSQL, MySQL) | StatefulSet avec persistance |
| `cache-queue/` | Cache/Queue (Redis, RabbitMQ) | Services de cache/messaging |
| `worker/` | Worker/Job processor | Services de traitement async |
| `microservice/` | Microservice générique | Service HTTP simple |

## Utilisation

### Méthode 1: Script Automatique (Recommandé)

```bash
./scripts/create-service.sh mon-service
```

Le script vous guide interactivement pour créer un nouveau service.

### Méthode 2: Copie Manuelle

```bash
# 1. Copier le template
cp -r k8s/templates/backend-api k8s/base/apps/mon-api

# 2. Remplacer les variables
cd k8s/base/apps/mon-api
sed -i 's/{{SERVICE_NAME}}/mon-api/g' *.yaml
sed -i 's/{{IMAGE}}/mon-registry\/mon-api:v1.0.0/g' *.yaml
sed -i 's/{{PORT}}/8080/g' *.yaml
sed -i 's/{{REPLICAS}}/2/g' *.yaml
sed -i 's/{{MEMORY_REQUEST}}/256Mi/g' *.yaml
sed -i 's/{{MEMORY_LIMIT}}/512Mi/g' *.yaml
sed -i 's/{{CPU_REQUEST}}/100m/g' *.yaml
sed -i 's/{{CPU_LIMIT}}/500m/g' *.yaml
sed -i 's/{{MIN_REPLICAS}}/2/g' *.yaml
sed -i 's/{{MAX_REPLICAS}}/10/g' *.yaml

# 3. Ajouter au kustomization
echo "  - mon-api" >> k8s/base/apps/kustomization.yaml

# 4. Commit et push
git add k8s/base/apps/mon-api/
git commit -m "feat: add mon-api service"
git push origin main
```

## Variables de Template

### Variables Communes

| Variable | Description | Exemple |
|----------|-------------|---------|
| `{{SERVICE_NAME}}` | Nom du service | `mon-api` |
| `{{IMAGE}}` | Image Docker | `nginx:alpine` |
| `{{PORT}}` | Port du conteneur | `8080` |
| `{{REPLICAS}}` | Nombre de replicas | `2` |

### Variables de Ressources

| Variable | Description | Exemple |
|----------|-------------|---------|
| `{{MEMORY_REQUEST}}` | Mémoire demandée | `256Mi` |
| `{{MEMORY_LIMIT}}` | Limite mémoire | `512Mi` |
| `{{CPU_REQUEST}}` | CPU demandé | `100m` |
| `{{CPU_LIMIT}}` | Limite CPU | `500m` |

### Variables HPA (backend-api)

| Variable | Description | Exemple |
|----------|-------------|---------|
| `{{MIN_REPLICAS}}` | Replicas minimum | `2` |
| `{{MAX_REPLICAS}}` | Replicas maximum | `10` |

### Variables Database

| Variable | Description | Exemple |
|----------|-------------|---------|
| `{{STORAGE_SIZE}}` | Taille du stockage | `10Gi` |
| `{{DB_USER}}` | Utilisateur DB | `admin` |
| `{{DB_PASSWORD}}` | Mot de passe DB | `secret` |
| `{{DB_NAME}}` | Nom de la DB | `mydb` |

### Variables Cache/Queue

| Variable | Description | Exemple |
|----------|-------------|---------|
| `{{MAX_MEMORY}}` | Mémoire max Redis | `256mb` |

### Variables Worker

| Variable | Description | Exemple |
|----------|-------------|---------|
| `{{CONCURRENCY}}` | Workers parallèles | `4` |
| `{{QUEUE_NAME}}` | Nom de la queue | `default` |

### Variables Frontend

| Variable | Description | Exemple |
|----------|-------------|---------|
| `{{API_SERVICE}}` | Service API backend | `api` |
| `{{API_PORT}}` | Port API | `8080` |

## Exemples Complets

### Backend API Spring Boot

```bash
cp -r k8s/templates/backend-api k8s/base/apps/user-service

cd k8s/base/apps/user-service
sed -i 's/{{SERVICE_NAME}}/user-service/g' *.yaml
sed -i 's|{{IMAGE}}|registry.amoona.tech/user-service:v1.0.0|g' *.yaml
sed -i 's/{{PORT}}/8080/g' *.yaml
sed -i 's/{{REPLICAS}}/3/g' *.yaml
sed -i 's/{{MEMORY_REQUEST}}/512Mi/g' *.yaml
sed -i 's/{{MEMORY_LIMIT}}/1Gi/g' *.yaml
sed -i 's/{{CPU_REQUEST}}/200m/g' *.yaml
sed -i 's/{{CPU_LIMIT}}/1000m/g' *.yaml
sed -i 's/{{MIN_REPLICAS}}/2/g' *.yaml
sed -i 's/{{MAX_REPLICAS}}/20/g' *.yaml
```

### Frontend Angular

```bash
cp -r k8s/templates/frontend-web k8s/base/apps/webapp

cd k8s/base/apps/webapp
sed -i 's/{{SERVICE_NAME}}/webapp/g' *.yaml
sed -i 's|{{IMAGE}}|registry.amoona.tech/webapp:v1.0.0|g' *.yaml
sed -i 's/{{REPLICAS}}/2/g' *.yaml
sed -i 's/{{API_SERVICE}}/api/g' *.yaml
sed -i 's/{{API_PORT}}/8080/g' *.yaml
```

### Base de Données PostgreSQL

```bash
cp -r k8s/templates/database k8s/base/apps/mydb

cd k8s/base/apps/mydb
sed -i 's/{{SERVICE_NAME}}/mydb/g' *.yaml
sed -i 's|{{IMAGE}}|postgres:16-alpine|g' *.yaml
sed -i 's/{{PORT}}/5432/g' *.yaml
sed -i 's/{{MEMORY_REQUEST}}/256Mi/g' *.yaml
sed -i 's/{{MEMORY_LIMIT}}/1Gi/g' *.yaml
sed -i 's/{{CPU_REQUEST}}/100m/g' *.yaml
sed -i 's/{{CPU_LIMIT}}/500m/g' *.yaml
sed -i 's/{{STORAGE_SIZE}}/20Gi/g' *.yaml
sed -i 's/{{DB_USER}}/admin/g' *.yaml
sed -i 's/{{DB_PASSWORD}}/changeme/g' *.yaml
sed -i 's/{{DB_NAME}}/myapp/g' *.yaml
```

### Cache Redis

```bash
cp -r k8s/templates/cache-queue k8s/base/apps/cache

cd k8s/base/apps/cache
sed -i 's/{{SERVICE_NAME}}/cache/g' *.yaml
sed -i 's|{{IMAGE}}|redis:7-alpine|g' *.yaml
sed -i 's/{{PORT}}/6379/g' *.yaml
sed -i 's/{{REPLICAS}}/1/g' *.yaml
sed -i 's/{{MEMORY_REQUEST}}/128Mi/g' *.yaml
sed -i 's/{{MEMORY_LIMIT}}/256Mi/g' *.yaml
sed -i 's/{{CPU_REQUEST}}/50m/g' *.yaml
sed -i 's/{{CPU_LIMIT}}/200m/g' *.yaml
sed -i 's/{{MAX_MEMORY}}/200mb/g' *.yaml
```

## Bonnes Pratiques

1. **Toujours définir les limites de ressources** pour éviter les problèmes de noisy neighbor
2. **Configurer les probes** (liveness/readiness) pour une meilleure résilience
3. **Utiliser des secrets** pour les données sensibles (mots de passe, clés API)
4. **Versionner les images** avec des tags spécifiques (pas `latest`)
5. **Activer le HPA** pour les services avec charge variable

## Support

Pour toute question, consultez:
- [GITOPS_QUICKSTART.md](../../GITOPS_QUICKSTART.md)
- [docs/gitops-guide.md](../../docs/gitops-guide.md)
