#!/bin/bash
# Script to install Linkerd service mesh
# Usage: ./scripts/install-linkerd.sh

set -e

echo "============================================="
echo "Installing Linkerd Service Mesh"
echo "============================================="

# Check if linkerd CLI is installed
if ! command -v linkerd &> /dev/null; then
    echo "Installing Linkerd CLI..."
    curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install | sh
    export PATH=$PATH:$HOME/.linkerd2/bin
    echo "export PATH=\$PATH:\$HOME/.linkerd2/bin" >> ~/.bashrc
fi

# Verify cluster is ready for Linkerd
echo "Checking cluster prerequisites..."
linkerd check --pre

# Install Linkerd CRDs
echo "Installing Linkerd CRDs..."
linkerd install --crds | kubectl apply -f -

# Install Linkerd control plane
echo "Installing Linkerd control plane..."
linkerd install | kubectl apply -f -

# Wait for control plane to be ready
echo "Waiting for Linkerd control plane..."
linkerd check

# Install Linkerd Viz extension (dashboard)
echo "Installing Linkerd Viz extension..."
linkerd viz install | kubectl apply -f -

# Wait for viz to be ready
echo "Waiting for Linkerd Viz..."
linkerd viz check

# Enable automatic proxy injection for amoona namespaces
echo "Enabling automatic proxy injection..."
kubectl annotate namespace amoona-dev linkerd.io/inject=enabled --overwrite 2>/dev/null || \
    kubectl create namespace amoona-dev && kubectl annotate namespace amoona-dev linkerd.io/inject=enabled

kubectl annotate namespace amoona-prod linkerd.io/inject=enabled --overwrite 2>/dev/null || \
    kubectl create namespace amoona-prod && kubectl annotate namespace amoona-prod linkerd.io/inject=enabled

# Apply mTLS policies
echo "Applying mTLS policies..."
kubectl apply -f k8s/base/service-mesh/mtls-policy.yaml

echo ""
echo "============================================="
echo "Linkerd installation complete!"
echo "============================================="
echo ""
echo "To access the dashboard:"
echo "  linkerd viz dashboard &"
echo ""
echo "To verify mTLS is working:"
echo "  linkerd viz edges deployment -n amoona-prod"
echo ""
echo "To restart deployments with proxy injection:"
echo "  kubectl rollout restart deployment -n amoona-prod"
echo ""
