#!/bin/bash
# Script to initialize and configure HashiCorp Vault for Amoona
# Usage: ./scripts/init-vault.sh [namespace]

set -e

NAMESPACE=${1:-amoona-prod}
VAULT_NAMESPACE="vault"

echo "============================================="
echo "Initializing Vault for namespace: $NAMESPACE"
echo "============================================="

# Wait for Vault to be ready
echo "Waiting for Vault pod to be ready..."
kubectl wait --for=condition=ready pod -l app=vault -n $VAULT_NAMESPACE --timeout=300s

# Check if Vault is already initialized
VAULT_POD=$(kubectl get pod -l app=vault,component=server -n $VAULT_NAMESPACE -o jsonpath='{.items[0].metadata.name}')
INIT_STATUS=$(kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault status -format=json 2>/dev/null | jq -r '.initialized' || echo "false")

if [ "$INIT_STATUS" == "false" ]; then
    echo "Initializing Vault..."

    # Initialize Vault with 5 key shares and 3 key threshold
    INIT_OUTPUT=$(kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault operator init -key-shares=5 -key-threshold=3 -format=json)

    # Extract keys and root token
    echo "$INIT_OUTPUT" > vault-init-keys.json

    ROOT_TOKEN=$(echo "$INIT_OUTPUT" | jq -r '.root_token')
    UNSEAL_KEY_1=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[0]')
    UNSEAL_KEY_2=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[1]')
    UNSEAL_KEY_3=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[2]')

    echo ""
    echo "========================================="
    echo "IMPORTANT: Save these keys securely!"
    echo "========================================="
    echo "Root Token: $ROOT_TOKEN"
    echo ""
    echo "Unseal Keys saved to: vault-init-keys.json"
    echo "DELETE this file after storing keys securely!"
    echo "========================================="
    echo ""

    # Unseal Vault
    echo "Unsealing Vault..."
    kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault operator unseal $UNSEAL_KEY_1
    kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault operator unseal $UNSEAL_KEY_2
    kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault operator unseal $UNSEAL_KEY_3

    echo "Vault unsealed successfully!"
else
    echo "Vault is already initialized."
    echo "Please provide the root token:"
    read -s ROOT_TOKEN

    # Check if sealed
    SEALED=$(kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault status -format=json 2>/dev/null | jq -r '.sealed')
    if [ "$SEALED" == "true" ]; then
        echo "Vault is sealed. Please provide unseal keys:"
        for i in 1 2 3; do
            echo "Unseal key $i:"
            read -s UNSEAL_KEY
            kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault operator unseal $UNSEAL_KEY
        done
    fi
fi

# Login to Vault
echo "Logging into Vault..."
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault login $ROOT_TOKEN

# Enable KV secrets engine
echo "Enabling KV secrets engine..."
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault secrets enable -path=secret kv-v2 2>/dev/null || echo "KV engine already enabled"

# Enable Kubernetes auth method
echo "Enabling Kubernetes auth method..."
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault auth enable kubernetes 2>/dev/null || echo "Kubernetes auth already enabled"

# Configure Kubernetes auth
echo "Configuring Kubernetes auth..."
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- sh -c '
vault write auth/kubernetes/config \
    kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"
'

# Create secrets for the application
echo "Creating secrets in Vault..."

# Generate passwords if not provided
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-$(openssl rand -base64 32)}
REDIS_PASSWORD=${REDIS_PASSWORD:-$(openssl rand -base64 32)}
MINIO_PASSWORD=${MINIO_PASSWORD:-$(openssl rand -base64 32)}
GRAFANA_PASSWORD=${GRAFANA_PASSWORD:-$(openssl rand -base64 32)}
ELASTIC_PASSWORD=${ELASTIC_PASSWORD:-$(openssl rand -base64 32)}
JWT_SECRET=${JWT_SECRET:-$(openssl rand -base64 64)}

# Store secrets in Vault
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault kv put secret/amoona/database \
    username="amoona" \
    password="$POSTGRES_PASSWORD" \
    url="jdbc:postgresql://postgres.$NAMESPACE.svc.cluster.local:5432/amoona_db"

kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault kv put secret/amoona/redis \
    host="redis.$NAMESPACE.svc.cluster.local" \
    port="6379" \
    password="$REDIS_PASSWORD"

kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault kv put secret/amoona/minio \
    endpoint="http://minio.$NAMESPACE.svc.cluster.local:9000" \
    access_key="minio-admin" \
    secret_key="$MINIO_PASSWORD"

kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault kv put secret/amoona/jwt \
    secret="$JWT_SECRET"

kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault kv put secret/amoona/elasticsearch \
    password="$ELASTIC_PASSWORD"

kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault kv put secret/amoona/grafana \
    admin_password="$GRAFANA_PASSWORD"

# Create policy for amoona-api
echo "Creating Vault policy for amoona-api..."
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- sh -c 'cat <<EOF | vault policy write amoona-api -
path "secret/data/amoona/*" {
  capabilities = ["read"]
}
EOF'

# Create Kubernetes auth role for amoona-api
echo "Creating Kubernetes auth role..."
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault write auth/kubernetes/role/amoona-api \
    bound_service_account_names=amoona-api \
    bound_service_account_namespaces=$NAMESPACE \
    policies=amoona-api \
    ttl=1h

echo ""
echo "============================================="
echo "Vault configuration complete!"
echo "============================================="
echo ""
echo "Secrets stored in Vault:"
echo "  - secret/amoona/database"
echo "  - secret/amoona/redis"
echo "  - secret/amoona/minio"
echo "  - secret/amoona/jwt"
echo "  - secret/amoona/elasticsearch"
echo "  - secret/amoona/grafana"
echo ""
echo "To use Vault in your deployments, add these annotations:"
echo '  vault.hashicorp.com/agent-inject: "true"'
echo '  vault.hashicorp.com/role: "amoona-api"'
echo '  vault.hashicorp.com/agent-inject-secret-database: "secret/data/amoona/database"'
echo ""
