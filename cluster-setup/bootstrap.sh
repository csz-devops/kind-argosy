#!/bin/bash
# Bootstrap script for Kind cluster with Argo CD GitOps

set -e

# Create Kind cluster
echo "Creating Kind cluster..."
kind create cluster --name argosy-cluster --config kind-config.yaml

# Wait for cluster to be ready
echo "Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Install Argo CD
echo "Installing Argo CD..."
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for Argo CD to be ready
echo "Waiting for Argo CD to be ready..."
kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=300s

# Get Argo CD admin password
echo "Argo CD admin password:"
ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo

# Port forward Argo CD UI
echo "To access Argo CD UI, run: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "Argo CD UI will be available at: http://localhost:8080"
echo "Username: admin"
echo "Password: $ADMIN_PASSWORD"
echo
echo "To get admin password again, run: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo
echo "Kind cluster and Argo CD setup complete!"
