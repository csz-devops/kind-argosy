#!/bin/bash
# Script to setup Kind cluster with Argo CD GitOps

set -e

# Colors for nicer output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    
    # Install Argo CD using the official install manifest (minimal bootstrap)
    print_status "Installing Argo CD bootstrap..."
    # kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    helm repo add argo-cd https://argoproj.github.io/argo-helm
    helm repo update
    helm install argocd argo-cd/argo-cd --namespace argocd --create-namespace --version 8.2.7
    
    
    # Wait for Argo CD to be ready
    print_status "Waiting for Argo CD to be ready..."
    kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=300s
    kubectl wait --for=condition=Available deployment/argocd-repo-server -n argocd --timeout=300s
    
    # Wait for statefulset to be ready
    print_status "Waiting for Argo CD application controller..."
    kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-application-controller -n argocd --timeout=300s
    
    print_success "Argo CD bootstrap installed and ready"
}

# Get Argo CD admin password
get_admin_password() {
    print_status "Getting Argo CD admin password..."

    ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    echo
    print_success "Argo CD admin credentials:"
    echo "Username: admin"
    echo "Password: $ADMIN_PASSWORD"
    echo
}

# Apply GitOps configuration
apply_gitops() {
    print_status "Applying GitOps configuration..."
    
    kubectl apply -f gitops/apps/root-app.yaml
    
    print_status "Waiting for root application to sync..."
    timeout=300
    while [ $timeout -gt 0 ]; do
        SYNC_STATUS=$(kubectl get application root-app -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
        if [ "$SYNC_STATUS" = "Synced" ]; then
            print_success "Root application synced successfully"
            break
        fi
        print_status "Waiting for root application to sync... Status: $SYNC_STATUS ($timeout seconds remaining)"
        sleep 10
        timeout=$((timeout - 10))
    done
    
    if [ $timeout -le 0 ]; then
        print_warning "Root application sync timeout, continuing anyway..."
    fi
    
    print_success "GitOps configuration applied"
}



# Setup port forwarding for all services
setup_port_forwarding() {
    print_status "Setting up port forwarding for all services..."
    
    # Kill any existing port-forward processes
    pkill -f "kubectl port-forward" || true
    sleep 2
    
    # Start Argo CD port forwarding
    print_status "Starting Argo CD port forwarding..."
    kubectl port-forward svc/argocd-server -n argocd 8080:443 &
    ARGOCD_PID=$!
    
    # Wait for Argo CD port forwarding to establish
    sleep 3
    
    print_success "Argo CD UI: https://localhost:8080"
    
    # Wait for GitOps to sync monitoring applications
    print_status "Waiting for GitOps to sync monitoring applications..."
    timeout=300
    while [ $timeout -gt 0 ]; do
        if kubectl get namespace monitoring &> /dev/null; then
            print_success "Monitoring namespace created by GitOps"
            break
        fi
        print_status "Waiting for monitoring namespace... ($timeout seconds remaining)"
        sleep 10
        timeout=$((timeout - 10))
    done
    
    if [ $timeout -le 0 ]; then
        print_warning "Monitoring namespace not created, port forwarding may fail"
        return
    fi
    
    # Wait for at least one monitoring deployment to appear
    print_status "Waiting for monitoring deployments to appear..."
    timeout=180
    while [ $timeout -gt 0 ]; do
        if kubectl get deployment -n monitoring 2>/dev/null | grep -q "kube-prometheus-stack"; then
            print_success "Monitoring deployments found"
            break
        fi
        print_status "Waiting for monitoring deployments... ($timeout seconds remaining)"
        sleep 10
        timeout=$((timeout - 10))
    done
    
    if [ $timeout -le 0 ]; then
        print_warning "Monitoring deployments not found, port forwarding may fail"
    fi
    
    # Wait for monitoring services to be ready
    print_status "Waiting for monitoring services to be ready..."
    kubectl wait --for=condition=Available deployment/kube-prometheus-stack-prometheus -n monitoring --timeout=300s 2>/dev/null || print_warning "Prometheus not ready, port forwarding may fail"
    kubectl wait --for=condition=Available deployment/kube-prometheus-stack-grafana -n monitoring --timeout=300s 2>/dev/null || print_warning "Grafana not ready, port forwarding may fail"
    kubectl wait --for=condition=Available deployment/kube-prometheus-stack-alertmanager -n monitoring --timeout=300s 2>/dev/null || print_warning "AlertManager not ready, port forwarding may fail"
    
    # Start monitoring port forwarding
    print_status "Starting monitoring port forwarding..."
    
    # Start Prometheus port forwarding
    kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 30000:9090 &
    PROMETHEUS_PID=$!
    
    # Start Grafana port forwarding
    kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 31000:80 &
    GRAFANA_PID=$!
    
    # Start AlertManager port forwarding
    kubectl port-forward svc/kube-prometheus-stack-alertmanager -n monitoring 32000:9093 &
    ALERTMANAGER_PID=$!
    
    # Wait for port forwarding to establish
    sleep 5
    
    print_success "All services are now accessible:"
    print_success "Argo CD UI: https://localhost:8080"
    print_success "Prometheus: http://localhost:30000"
    print_success "Grafana: http://localhost:31000 (admin/admin123)"
    print_success "AlertManager: http://localhost:32000"
    
    # Store PIDs for cleanup
    echo $ARGOCD_PID > /tmp/argocd-pf.pid
    echo $PROMETHEUS_PID > /tmp/prometheus-pf.pid
    echo $GRAFANA_PID > /tmp/grafana-pf.pid
    echo $ALERTMANAGER_PID > /tmp/alertmanager-pf.pid
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
    verify_setup
    setup_port_forwarding
    
    echo
    echo "Setup complete!"
    echo "==============="
    echo
    echo "All services are now accessible:"
    echo "- Argo CD UI: https://localhost:8080 (admin / $ADMIN_PASSWORD)"
    echo "- Prometheus: http://localhost:30000"
    echo "- Grafana: http://localhost:31000 (admin/admin123)"
    echo "- AlertManager: http://localhost:32000"
    echo
    echo "Features enabled:"
    echo "- Argo CD self-management"
    echo "- Custom Helm version (3.12.3)"
    echo "- Prometheus monitoring with dashboards"
    echo "- ArgoCD status alerts"
    echo
    echo "Port forwarding is running in the background."
    echo "To stop port forwarding: pkill -f 'kubectl port-forward'"
    echo
}

# Run main function
main "$@"
