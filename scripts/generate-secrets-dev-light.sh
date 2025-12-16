#!/bin/bash
# =============================================================================
# Script de génération des secrets pour l'environnement dev-light
# =============================================================================
# Usage: ./scripts/generate-secrets-dev-light.sh
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OVERLAY_DIR="$PROJECT_ROOT/k8s/overlays/dev-light"

echo "========================================"
echo "  Génération des secrets (dev-light)"
echo "========================================"
echo ""

# Fonction pour générer un mot de passe
generate_password() {
    openssl rand -base64 32 | tr -d '\n' | tr -d '/' | tr -d '+' | cut -c1-32
}

# Fonction pour générer un secret JWT
generate_jwt_secret() {
    openssl rand -base64 64 | tr -d '\n' | tr -d '/' | tr -d '+'
}

# Fonction pour générer une clé de 16 caractères
generate_key_16() {
    openssl rand -base64 16 | tr -d '\n' | tr -d '/' | tr -d '+' | cut -c1-16
}

# Fonction pour générer une clé de 32 caractères
generate_key_32() {
    openssl rand -base64 32 | tr -d '\n' | tr -d '/' | tr -d '+' | cut -c1-32
}

# Générer tous les mots de passe
POSTGRES_PASSWORD=$(generate_password)
MINIO_PASSWORD=$(generate_password)
GRAFANA_PASSWORD=$(generate_password)
REDIS_PASSWORD=$(generate_password)
JWT_SECRET=$(generate_jwt_secret)
HARBOR_ADMIN_PASSWORD=$(generate_password)
HARBOR_DB_PASSWORD=$(generate_password)
HARBOR_CORE_KEY=$(generate_key_32)
HARBOR_SECRET_KEY=$(generate_key_16)
HARBOR_REGISTRY_SECRET=$(generate_password)

echo "Mots de passe générés."

# Créer le fichier secrets-patch.yaml
cat > "$OVERLAY_DIR/secrets-patch.yaml" << EOF
# Secrets générés automatiquement le $(date +%Y-%m-%d)
# NE PAS COMMITER CE FICHIER !
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
stringData:
  POSTGRES_PASSWORD: "$POSTGRES_PASSWORD"
  POSTGRES_USER: "amoona"
  POSTGRES_DB: "amoona_db"
---
apiVersion: v1
kind: Secret
metadata:
  name: minio-secret
stringData:
  MINIO_ROOT_USER: "minio-admin"
  MINIO_ROOT_PASSWORD: "$MINIO_PASSWORD"
---
apiVersion: v1
kind: Secret
metadata:
  name: grafana-secret
stringData:
  GF_SECURITY_ADMIN_USER: "admin"
  GF_SECURITY_ADMIN_PASSWORD: "$GRAFANA_PASSWORD"
---
apiVersion: v1
kind: Secret
metadata:
  name: redis-secret
stringData:
  REDIS_PASSWORD: "$REDIS_PASSWORD"
---
apiVersion: v1
kind: Secret
metadata:
  name: harbor-secret
stringData:
  HARBOR_ADMIN_PASSWORD: "$HARBOR_ADMIN_PASSWORD"
  HARBOR_DB_PASSWORD: "$HARBOR_DB_PASSWORD"
  CORE_KEY: "$HARBOR_CORE_KEY"
  SECRET_KEY: "$HARBOR_SECRET_KEY"
  REGISTRY_HTTP_SECRET: "$HARBOR_REGISTRY_SECRET"
EOF

echo "Créé: $OVERLAY_DIR/secrets-patch.yaml"

# Créer les secrets de l'API
cat > "$OVERLAY_DIR/apps/amoona-api/secrets.yaml" << EOF
# Secrets API générés automatiquement le $(date +%Y-%m-%d)
# NE PAS COMMITER CE FICHIER !
apiVersion: v1
kind: Secret
metadata:
  name: amoona-api-secrets
  labels:
    app: amoona-api
    environment: dev
type: Opaque
stringData:
  # Base de données
  DB_URL: "jdbc:postgresql://postgres.amoona-dev.svc.cluster.local:5432/amoona_db"
  DB_USER: "amoona"
  DB_PASSWORD: "$POSTGRES_PASSWORD"

  # Redis
  REDIS_HOST: "redis.amoona-dev.svc.cluster.local"
  REDIS_PORT: "6379"
  REDIS_PASSWORD: "$REDIS_PASSWORD"

  # MinIO
  MINIO_ENDPOINT: "http://minio.amoona-dev.svc.cluster.local:9000"
  MINIO_ACCESS_KEY: "minio-admin"
  MINIO_SECRET_KEY: "$MINIO_PASSWORD"

  # JWT
  JWT_SECRET: "$JWT_SECRET"
EOF

echo "Créé: $OVERLAY_DIR/apps/amoona-api/secrets.yaml"

# Afficher les mots de passe
echo ""
echo "========================================"
echo "  MOTS DE PASSE GÉNÉRÉS"
echo "========================================"
echo ""
echo "  SAUVEGARDEZ CES INFORMATIONS !"
echo ""
echo "----------------------------------------"
echo "  Services Infrastructure"
echo "----------------------------------------"
echo "  PostgreSQL:"
echo "    User: amoona"
echo "    Password: $POSTGRES_PASSWORD"
echo ""
echo "  Redis:"
echo "    Password: $REDIS_PASSWORD"
echo ""
echo "  MinIO:"
echo "    User: minio-admin"
echo "    Password: $MINIO_PASSWORD"
echo ""
echo "  Grafana:"
echo "    User: admin"
echo "    Password: $GRAFANA_PASSWORD"
echo ""
echo "----------------------------------------"
echo "  Harbor (Registry Docker)"
echo "----------------------------------------"
echo "  Admin:"
echo "    User: admin"
echo "    Password: $HARBOR_ADMIN_PASSWORD"
echo ""
echo "  Base de données Harbor:"
echo "    User: harbor"
echo "    Password: $HARBOR_DB_PASSWORD"
echo ""
echo "----------------------------------------"
echo "  Application"
echo "----------------------------------------"
echo "  JWT Secret: $JWT_SECRET"
echo ""
echo "========================================"
echo ""
echo "⚠️  IMPORTANT: Ces fichiers sont dans .gitignore"
echo "    Ne les commitez JAMAIS dans Git !"
echo ""
