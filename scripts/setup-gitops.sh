#!/bin/bash

set -e

echo "🚀 Setting up Kind cluster with Argo CD GitOps..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v kind &> /dev/null; then
        print_error "kind is not installed. Please install kind first."
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        print_warning "helm is not installed. It will be installed in the Argo CD container."
    fi
    
    print_success "Prerequisites check passed"
}

# Create Kind cluster
create_cluster() {
    print_status "Creating Kind cluster..."
    
    if kind get clusters | grep -q "argosy-cluster"; then
        print_warning "Cluster 'argosy-cluster' already exists. Deleting it..."
        kind delete cluster --name argosy-cluster
    fi
    
    kind create cluster --name argosy-cluster --config cluster-setup/kind-config.yaml
    print_success "Kind cluster created"
}

# Wait for cluster to be ready
wait_for_cluster() {
    print_status "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    print_success "Cluster is ready"
}



# Install Argo CD
install_argocd() {
    print_status "Installing Argo CD..."
    
    # Create namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Add Argo CD Helm repository
    helm repo add argo https://argoproj.github.io/argo-helm
    helm repo update
    
    # Install Argo CD with custom Helm v3.12.3 using official custom tooling
    print_status "Installing Argo CD with custom Helm v3.12.3..."
    helm install argocd argo/argo-cd \
        --namespace argocd \
        --values cluster-setup/argocd-values.yaml \
        --wait \
        --timeout 10m
    
    # Wait for Argo CD to be ready
    print_status "Waiting for Argo CD to be ready..."
    kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=300s
    kubectl wait --for=condition=Available deployment/argocd-repo-server -n argocd --timeout=300s
    
    # Wait for statefulset to be ready (using a different approach)
    print_status "Waiting for Argo CD application controller..."
    kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-application-controller -n argocd --timeout=300s
    
    print_success "Argo CD installed and ready"
    
    # Verify the Helm version
    print_status "Verifying Helm version..."
    sleep 10  # Give the init container time to complete
    HELM_VERSION=$(kubectl exec -n argocd deployment/argocd-repo-server -- helm version --short 2>/dev/null | head -1 || echo "unknown")
    print_success "Helm version in repo server: $HELM_VERSION"
}

# Override Helm version in Argo CD repo server


# Get Argo CD admin password
get_admin_password() {
    print_status "Getting Argo CD admin password..."
    
    # Get the password directly (no need to wait for secret)
    ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    echo
    print_success "Argo CD admin credentials:"
    echo "   Username: admin"
    echo "   Password: $ADMIN_PASSWORD"
    echo
}

# Apply GitOps configuration
apply_gitops() {
    print_status "Applying GitOps configuration..."
    
    # Apply the root application that will manage everything
    kubectl apply -f gitops/apps/root-app.yaml
    
    # Wait for the root app to be synced
    print_status "Waiting for root application to sync..."
    kubectl wait --for=condition=Available application/root-app -n argocd --timeout=300s
    
    print_success "GitOps configuration applied"
}

# Setup Argo CD access
setup_argocd_access() {
    print_status "Setting up Argo CD access..."
    
    print_success "Argo CD UI available at: https://localhost:8080"
    print_warning "To access Argo CD, run: kubectl port-forward svc/argocd-server -n argocd 8080:443"
}

# Verify setup
verify_setup() {
    print_status "Verifying setup..."
    
    # Check Argo CD applications
    echo
    print_status "Argo CD Applications:"
    kubectl get applications -n argocd
    
    # Check Argo CD pods
    echo
    print_status "Argo CD Pods:"
    kubectl get pods -n argocd
    
    # Check if root app is synced
    ROOT_APP_STATUS=$(kubectl get application root-app -n argocd -o jsonpath='{.status.sync.status}')
    if [ "$ROOT_APP_STATUS" = "Synced" ]; then
        print_success "Root application is synced"
    else
        print_warning "Root application status: $ROOT_APP_STATUS"
    fi
    
    print_success "Setup verification complete"
}

# Main execution
main() {
    echo "🎯 Argo CD GitOps Setup Script"
    echo "================================"
    echo
    
    check_prerequisites
    create_cluster
    wait_for_cluster
    install_argocd
    get_admin_password
    apply_gitops
    setup_argocd_access
    verify_setup
    
    echo
    echo "🎉 Setup complete!"
    echo "=================="
    echo
    echo "📋 Next steps:"
    echo "   1. Access Argo CD UI: kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "   2. Login with admin / $ADMIN_PASSWORD"
    echo "   3. Check the 'root-app' application"
    echo "   4. Monitor the sync status of all applications"
    echo
    echo "🔧 Features enabled:"
    echo "   ✅ Argo CD self-management"
    echo "   ✅ Custom Helm version (3.12.3)"
    echo "   ✅ Prometheus monitoring with dashboards"
    echo "   ✅ Comprehensive alerts"
    echo
    echo "📊 Monitoring (NodePort access):"
    echo "   - Prometheus: http://localhost:30000"
    echo "   - Grafana: http://localhost:31000 (admin/admin123)"
    echo "   - AlertManager: http://localhost:32000"
    echo
}

# Run main function
main "$@"
