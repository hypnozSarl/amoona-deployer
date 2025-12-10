#!/bin/bash
# Script to generate Kubernetes secrets from templates
# Usage: ./scripts/generate-secrets.sh [dev|prod]

set -e

ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Generating secrets for environment: $ENVIRONMENT"

# Function to generate a random password
generate_password() {
    openssl rand -base64 32 | tr -d '\n'
}

# Function to generate a JWT secret (256 bits)
generate_jwt_secret() {
    openssl rand -base64 64 | tr -d '\n'
}

# Check if template files exist
OVERLAY_DIR="$PROJECT_ROOT/k8s/overlays/$ENVIRONMENT"
if [[ ! -d "$OVERLAY_DIR" ]]; then
    echo "Error: Overlay directory not found: $OVERLAY_DIR"
    exit 1
fi

# Generate passwords
POSTGRES_PASSWORD=$(generate_password)
MINIO_PASSWORD=$(generate_password)
GRAFANA_PASSWORD=$(generate_password)
REDIS_PASSWORD=$(generate_password)
JWT_SECRET=$(generate_jwt_secret)
ELASTIC_PASSWORD=$(generate_password)

echo "Generated secure passwords."

# Create secrets-patch.yaml
SECRETS_PATCH_OUTPUT="$OVERLAY_DIR/secrets-patch.yaml"

cat > "$SECRETS_PATCH_OUTPUT" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
stringData:
  POSTGRES_PASSWORD: "$POSTGRES_PASSWORD"
---
apiVersion: v1
kind: Secret
metadata:
  name: minio-secret
stringData:
  MINIO_ROOT_PASSWORD: "$MINIO_PASSWORD"
---
apiVersion: v1
kind: Secret
metadata:
  name: grafana-secret
stringData:
  GF_SECURITY_ADMIN_PASSWORD: "$GRAFANA_PASSWORD"
---
apiVersion: v1
kind: Secret
metadata:
  name: redis-secret
stringData:
  REDIS_PASSWORD: "$REDIS_PASSWORD"
EOF

    if [[ "$ENVIRONMENT" == "prod" ]]; then
        cat >> "$SECRETS_PATCH_OUTPUT" << EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: elasticsearch-secret
stringData:
  ELASTIC_PASSWORD: "$ELASTIC_PASSWORD"
EOF
    fi

echo "Created: $SECRETS_PATCH_OUTPUT"

# Create amoona-api secrets
API_SECRETS_DIR="$OVERLAY_DIR/apps/amoona-api"
API_SECRETS_TEMPLATE="$API_SECRETS_DIR/secrets.example.yaml"
API_SECRETS_OUTPUT="$API_SECRETS_DIR/secrets.yaml"

if [[ -f "$API_SECRETS_TEMPLATE" ]]; then
    NAMESPACE="amoona-$ENVIRONMENT"

    cat > "$API_SECRETS_OUTPUT" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: amoona-api-secrets
  labels:
    app: amoona-api
    app.kubernetes.io/name: amoona-api
    environment: $ENVIRONMENT
type: Opaque
stringData:
  # Database
  DB_URL: "jdbc:postgresql://postgres.$NAMESPACE.svc.cluster.local:5432/amoona_db"
  DB_USER: "amoona"
  DB_PASSWORD: "$POSTGRES_PASSWORD"

  # Redis
  REDIS_HOST: "redis.$NAMESPACE.svc.cluster.local"
  REDIS_PORT: "6379"
  REDIS_PASSWORD: "$REDIS_PASSWORD"

  # MinIO
  MINIO_ENDPOINT: "http://minio.$NAMESPACE.svc.cluster.local:9000"
  MINIO_ACCESS_KEY: "minio-admin"
  MINIO_SECRET_KEY: "$MINIO_PASSWORD"

  # JWT
  JWT_SECRET: "$JWT_SECRET"

  # Logstash
  LOGSTASH_HOST: "logstash.$NAMESPACE.svc.cluster.local"
  LOGSTASH_PORT: "5000"
EOF

    echo "Created: $API_SECRETS_OUTPUT"
fi

echo ""
echo "========================================="
echo "Secrets generated successfully!"
echo "========================================="
echo ""
echo "IMPORTANT: Store these passwords securely!"
echo ""
echo "Postgres Password: $POSTGRES_PASSWORD"
echo "MinIO Password:    $MINIO_PASSWORD"
echo "Grafana Password:  $GRAFANA_PASSWORD"
echo "Redis Password:    $REDIS_PASSWORD"
if [[ "$ENVIRONMENT" == "prod" ]]; then
    echo "Elastic Password:  $ELASTIC_PASSWORD"
fi
echo ""
echo "JWT Secret:        $JWT_SECRET"
echo ""
echo "These secrets are stored in:"
echo "  - $SECRETS_PATCH_OUTPUT"
echo "  - $API_SECRETS_OUTPUT"
echo ""
echo "WARNING: Do NOT commit these files to git!"
echo "They are already in .gitignore"
