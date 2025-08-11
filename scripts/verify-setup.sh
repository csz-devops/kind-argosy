#!/bin/bash

set -e

echo "🔍 Verifying Kind Argo CD GitOps Setup"
echo "======================================"

# Colors for output
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

# Check if cluster exists
if ! kind get clusters | grep -q "argosy-cluster"; then
    print_error "Kind cluster 'argosy-cluster' does not exist. Please run './setup.sh' first."
    exit 1
fi

# Check Argo CD pods
print_status "Checking Argo CD pods..."
if kubectl get pods -n argocd --no-headers | grep -v "Running\|Completed" | grep -q .; then
    print_warning "Some Argo CD pods are not running:"
    kubectl get pods -n argocd
else
    print_success "All Argo CD pods are running"
fi

# Check Argo CD applications
print_status "Checking Argo CD applications..."
if kubectl get applications -n argocd --no-headers | grep -v "Synced\|Healthy" | grep -q .; then
    print_warning "Some Argo CD applications are not healthy:"
    kubectl get applications -n argocd
else
    print_success "All Argo CD applications are healthy"
fi

# Check monitoring pods
print_status "Checking monitoring pods..."
if kubectl get pods -n monitoring --no-headers | grep -v "Running\|Completed" | grep -q .; then
    print_warning "Some monitoring pods are not running:"
    kubectl get pods -n monitoring
else
    print_success "All monitoring pods are running"
fi

# Check Prometheus targets
print_status "Checking Prometheus targets..."
if kubectl get servicemonitors -n monitoring | grep -q argocd; then
    print_success "Argo CD ServiceMonitors are configured"
else
    print_warning "Argo CD ServiceMonitors not found"
fi

# Check Helm version in Argo CD
print_status "Checking Helm version in Argo CD..."
HELM_VERSION=$(kubectl exec -n argocd deployment/argocd-repo-server -- helm version --short 2>/dev/null || echo "Helm not available")
if echo "$HELM_VERSION" | grep -q "v3.12.3"; then
    print_success "Custom Helm version (v3.12.3) is installed"
else
    print_warning "Custom Helm version not detected: $HELM_VERSION"
fi

# Check Argo CD metrics endpoint
print_status "Checking Argo CD metrics endpoint..."
if kubectl get svc -n argocd argocd-server -o jsonpath='{.spec.ports[?(@.name=="metrics")].port}' | grep -q "8083"; then
    print_success "Argo CD metrics endpoint is configured"
else
    print_warning "Argo CD metrics endpoint not found"
fi

# Display summary
echo
echo "📊 Summary:"
echo "==========="
echo "🔧 Argo CD Applications: $(kubectl get applications -n argocd --no-headers | wc -l | tr -d ' ')"
echo "📦 Argo CD Pods: $(kubectl get pods -n argocd --no-headers | wc -l | tr -d ' ')"
echo "📊 Monitoring Pods: $(kubectl get pods -n monitoring --no-headers | wc -l | tr -d ' ')"
echo "🚨 Alert Rules: $(kubectl get prometheusrules -n monitoring --no-headers | wc -l | tr -d ' ')"
echo
echo "✅ Verification complete!"
echo
echo "📋 Next steps:"
echo "1. Access Argo CD UI: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "2. Access Grafana: http://localhost:31000 (admin/admin123)"
echo "3. Access Prometheus: http://localhost:30000"
echo "4. Access AlertManager: http://localhost:32000"
