#!/bin/bash

set -e

echo "🚀 Setting up port forwarding for monitoring services..."
echo "======================================================"

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

# Function to kill existing port-forward processes
kill_port_forward() {
    print_status "Stopping existing port-forward processes..."
    pkill -f "kubectl port-forward.*30000" || true
    pkill -f "kubectl port-forward.*31000" || true
    pkill -f "kubectl port-forward.*32000" || true
    sleep 2
}

# Function to start port forwarding
start_port_forward() {
    local service=$1
    local local_port=$2
    local target_port=$3
    local namespace=$4
    
    print_status "Starting port-forward for $service on port $local_port..."
    
    # Start port-forward in background
    kubectl port-forward svc/$service -n $namespace $local_port:$target_port &
    PF_PID=$!
    
    # Wait a moment for port forward to establish
    sleep 3
    
    print_success "$service port-forward started (PID: $PF_PID)"
}

# Main execution
main() {
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Kill existing port-forward processes
    kill_port_forward
    
    # Start Prometheus port-forward
    start_port_forward "kube-prometheus-stack-prometheus" 30000 9090 "monitoring"
    PROMETHEUS_PID=$PF_PID
    
    # Start Grafana port-forward
    start_port_forward "kube-prometheus-stack-grafana" 31000 80 "monitoring"
    GRAFANA_PID=$PF_PID
    
    # Start AlertManager port-forward
    start_port_forward "kube-prometheus-stack-alertmanager" 32000 9093 "monitoring"
    ALERTMANAGER_PID=$PF_PID
    
    echo
    print_success "Port forwarding setup complete!"
    echo
    echo "📊 Monitoring Services:"
    echo "   Prometheus: http://localhost:30000"
    echo "   Grafana: http://localhost:31000 (admin/admin123)"
    echo "   AlertManager: http://localhost:32000"
    echo
    echo "🔧 To stop port forwarding:"
    echo "   kill $PROMETHEUS_PID  # Prometheus"
    echo "   kill $GRAFANA_PID     # Grafana"
    echo "   kill $ALERTMANAGER_PID  # AlertManager"
    echo "   Or run: pkill -f 'kubectl port-forward'"
    echo
    echo "💡 The port-forward processes will continue running in the background."
    echo "   You can close this terminal and the services will remain accessible."
}

# Run main function
main "$@"
