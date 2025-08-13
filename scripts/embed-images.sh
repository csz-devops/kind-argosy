#!/bin/bash

# Script to embed images into markdown using base64 encoding

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

# Function to convert image to base64 and generate markdown
embed_image() {
    local image_path="$1"
    local image_name="$2"
    local alt_text="$3"
    
    if [ ! -f "$image_path" ]; then
        print_error "Image file not found: $image_path"
        return 1
    fi
    
    print_status "Converting $image_name to base64..."
    
    # Get file extension
    local extension="${image_path##*.}"
    
    # Convert to base64
    local base64_data=$(base64 -i "$image_path")
    
    # Generate markdown
    echo "![$alt_text](data:image/$extension;base64,$base64_data)"
    echo
    echo "*$alt_text*"
    echo
}

# Main execution
main() {
    echo "Image Embedding Script"
    echo "====================="
    echo
    
    # Check if images directory exists
    if [ ! -d "docs/images" ]; then
        print_error "docs/images directory not found"
        exit 1
    fi
    
    # Create embedded images markdown
    print_status "Creating embedded images markdown..."
    
    cat > docs/embedded-images.md << 'EOF'
# Embedded Monitoring Screenshots

This file contains base64-encoded images embedded directly in markdown for self-contained documentation.

## Prometheus Alerts

EOF

    # Embed each image if it exists
    if [ -f "docs/images/prometheus-alerts.png" ]; then
        embed_image "docs/images/prometheus-alerts.png" "prometheus-alerts" "Prometheus alerts interface showing Argo CD component health status" >> docs/embedded-images.md
    else
        echo "![Prometheus Alerts](docs/images/prometheus-alerts.png)" >> docs/embedded-images.md
        echo "" >> docs/embedded-images.md
        echo "*Prometheus alerts interface showing Argo CD component health status*" >> docs/embedded-images.md
        echo "" >> docs/embedded-images.md
    fi
    
    cat >> docs/embedded-images.md << 'EOF'
## AlertManager Notifications

EOF

    if [ -f "docs/images/alertmanager.png" ]; then
        embed_image "docs/images/alertmanager.png" "alertmanager" "AlertManager interface displaying critical Argo CD alerts with severity levels" >> docs/embedded-images.md
    else
        echo "![AlertManager](docs/images/alertmanager.png)" >> docs/embedded-images.md
        echo "" >> docs/embedded-images.md
        echo "*AlertManager interface displaying critical Argo CD alerts with severity levels*" >> docs/embedded-images.md
        echo "" >> docs/embedded-images.md
    fi
    
    cat >> docs/embedded-images.md << 'EOF'
## Grafana Dashboards

EOF

    if [ -f "docs/images/grafana-alertmanager-dashboard.png" ]; then
        embed_image "docs/images/grafana-alertmanager-dashboard.png" "grafana-dashboard" "Grafana dashboard showing AlertManager alert counts and notification rates" >> docs/embedded-images.md
    else
        echo "![Grafana AlertManager Dashboard](docs/images/grafana-alertmanager-dashboard.png)" >> docs/embedded-images.md
        echo "" >> docs/embedded-images.md
        echo "*Grafana dashboard showing AlertManager alert counts and notification rates*" >> docs/embedded-images.md
        echo "" >> docs/embedded-images.md
    fi
    
    cat >> docs/embedded-images.md << 'EOF'
## Prometheus Rules

EOF

    if [ -f "docs/images/prometheus-rules.png" ]; then
        embed_image "docs/images/prometheus-rules.png" "prometheus-rules" "Prometheus rules interface showing configured Argo CD alert rules and their status" >> docs/embedded-images.md
    else
        echo "![Prometheus Rules](docs/images/prometheus-rules.png)" >> docs/embedded-images.md
        echo "" >> docs/embedded-images.md
        echo "*Prometheus rules interface showing configured Argo CD alert rules and their status*" >> docs/embedded-images.md
        echo "" >> docs/embedded-images.md
    fi
    
    print_success "Embedded images markdown created: docs/embedded-images.md"
    print_status "You can now copy the embedded image sections from this file into your README.md"
}

main "$@"
