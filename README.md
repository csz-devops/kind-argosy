# Kind Argo CD GitOps Setup

A comprehensive GitOps setup using Argo CD with Kind cluster, featuring self-management, custom Helm version, and comprehensive monitoring.

## 🎯 Requirements Met

This setup fulfills all three requirements:

1. ✅ **Argo CD Self-Management**: Argo CD manages its own configurations and lifecycle
2. ✅ **Prometheus Monitoring**: Complete monitoring stack with dashboards and alerts for Argo CD
3. ✅ **Custom Helm Version**: Replaces the default Helm binary with Helm 3.12.3

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Kind Cluster  │    │   Argo CD       │    │   GitOps Repo   │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ Root App    │◄┼────┼►│ Self-Manage │ │    │ │ Applications│ │
│ │ (Bootstrap) │ │    │ │             │ │    │ │             │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ Argo CD     │◄┼────┼►│ Custom Helm │ │    │ │ Argo CD     │ │
│ │ App         │ │    │ │ 3.12.3      │ │    │ │ Config      │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ Monitoring  │◄┼────┼►│ Prometheus  │ │    │ │ Prometheus  │ │
│ │ App         │ │    │ │ + Grafana   │ │    │ │ + Alerts    │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/) - Kubernetes in Docker
- [kubectl](https://kubernetes.io/docs/tasks/tools/) - Kubernetes command line tool
- [Git](https://git-scm.com/) - Version control

### One-Command Setup

```bash
# Clone the repository
git clone <your-repo-url>
cd kind-argosy

# Run the setup script
./scripts/setup-gitops.sh
```

This script will:
1. Create a Kind cluster
2. Install Argo CD
3. Configure GitOps self-management
4. Set up monitoring
5. Start port forwarding

## 📁 Project Structure

```
kind-argosy/
├── cluster-setup/
│   ├── bootstrap.sh              # Basic cluster setup
│   ├── kind-config.yaml          # Kind cluster configuration
├── gitops/
│   ├── kustomization.yaml        # Kustomize configuration
│   └── apps/
│       ├── root-app.yaml         # Root application (bootstrap)
│       ├── argocd/
│       │   └── argocd-app.yaml   # Argo CD application (official Helm chart)
│       └── monitoring/
│           ├── prometheus-app.yaml    # Prometheus application
│           ├── argocd-servicemonitor.yaml # Service monitors
│           └── argocd-alerts.yaml     # Prometheus alert rules
└── scripts/
    ├── setup-gitops.sh           # Complete setup script
    └── verify-setup.sh           # Verify setup
```

## 🔧 Features

### 1. Argo CD Self-Management

The `root-app.yaml` creates a bootstrap application that manages all other applications:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/csz-devops/kind-argosy.git
    path: gitops/apps
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Benefits:**
- Argo CD manages its own configuration
- Automated sync and self-healing
- Declarative GitOps approach

### 2. Custom Helm Version

The Argo CD application uses the [official Argo CD Helm chart](https://github.com/argoproj/argo-helm) with custom Helm version configuration:

```yaml
repoServer:
  extraInitContainers:
    - name: install-helm
      image: alpine:3.18
      command:
        - sh
        - -c
        - |
          wget -O /helm.tar.gz https://get.helm.sh/helm-v3.12.3-linux-amd64.tar.gz
          tar -xzf /helm.tar.gz
          cp linux-amd64/helm /shared/helm
          chmod +x /shared/helm
          /shared/helm version
      volumeMounts:
        - name: helm-volume
          mountPath: /shared
  
  extraVolumeMounts:
    - name: helm-volume
      mountPath: /usr/local/bin/helm
      subPath: helm
  
  extraVolumes:
    - name: helm-volume
      emptyDir: {}
```

**Benefits:**
- Uses official Argo CD Helm chart for better compatibility
- Built-in Helm version management through chart configuration
- Easy to upgrade/downgrade by modifying chart values
- Official support and maintenance

### 3. Comprehensive Monitoring

#### Prometheus Configuration

The `prometheus-app.yaml` deploys:
- Prometheus with Argo CD metrics collection
- Grafana with pre-configured Argo CD dashboards
- AlertManager for notifications

#### Service Monitors

The `argocd-servicemonitor.yaml` configures monitoring for:
- Argo CD Server
- Argo CD Repo Server  
- Argo CD Application Controller

#### Alert Rules

The `argocd-alerts.yaml` includes alerts for:
- Service availability
- Application sync failures
- Resource usage (CPU/Memory)
- Repository connection issues

## 📊 Monitoring Dashboards

### Grafana Dashboards

After setup, access Grafana at `http://localhost:31000` (admin/admin123):

1. **Argo CD Overview Dashboard** (ID: 14584)
   - Application health status
   - Sync status overview
   - Resource usage metrics

2. **Argo CD Applications Dashboard** (ID: 14584)
   - Detailed application metrics
   - Sync duration analysis
   - Error rate monitoring

### Prometheus Metrics

Key metrics available:
- `argocd_app_sync_total` - Sync operations count
- `argocd_app_health_status` - Application health
- `argocd_repo_connection_state` - Repository status
- `argocd_app_sync_duration_seconds` - Sync duration

## 🚨 Alerts

The setup includes comprehensive alerts:

| Alert | Description | Severity |
|-------|-------------|----------|
| `ArgoCDServerDown` | Argo CD server unavailable | Critical |
| `ArgoCDApplicationSyncFailed` | Application sync failures | Warning |
| `ArgoCDApplicationUnhealthy` | Applications in unhealthy state | Warning |
| `ArgoCDHighMemoryUsage` | High memory usage (>80%) | Warning |
| `ArgoCDHighCPUUsage` | High CPU usage (>80%) | Warning |

## 🔄 GitOps Workflow

1. **Initial Setup**: `setup-gitops.sh` creates cluster and deploys Argo CD
2. **Bootstrap**: Root application syncs and creates other applications
3. **Self-Management**: Argo CD manages its own configuration
4. **Monitoring**: Prometheus and Grafana provide observability
5. **Continuous Sync**: Changes to Git automatically sync to cluster

## 🛠️ Customization

### Adding New Applications

1. Create application YAML in `gitops/apps/`
2. Add to `gitops/kustomization.yaml`
3. Commit and push to Git
4. Argo CD will automatically sync

### Modifying Helm Version

Edit `gitops/apps/argocd/argocd-app.yaml` and update the Helm version in the `repoServer.extraInitContainers` section:
```yaml
repoServer:
  extraInitContainers:
    - name: install-helm
      command:
        - sh
        - -c
        - |
          wget -O /helm.tar.gz https://get.helm.sh/helm-v<version>-linux-amd64.tar.gz
          # ... rest of the command
```

### Adding Custom Alerts

Edit `gitops/apps/monitoring/argocd-alerts.yaml` and add new alert rules.

## 🔍 Troubleshooting

### Common Issues

1. **Argo CD not syncing**
   ```bash
   kubectl get applications -n argocd
   kubectl describe application root-app -n argocd
   ```

2. **Prometheus not collecting metrics**
   ```bash
   kubectl get servicemonitors -n monitoring
   kubectl get pods -n monitoring
   ```

3. **Custom Helm not working**
   ```bash
   kubectl logs -n argocd deployment/argocd-repo-server -c install-helm
   ```

### Verification Commands

```bash
# Check Argo CD status
kubectl get pods -n argocd

# Check applications
kubectl get applications -n argocd

# Check monitoring
kubectl get pods -n monitoring

# Check Helm version in Argo CD
kubectl exec -n argocd deployment/argocd-repo-server -- helm version
```

## 📚 References

- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [Argo CD Helm Integration](https://argo-cd.readthedocs.io/en/stable/user-guide/helm/)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [Kind Documentation](https://kind.sigs.k8s.io/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with the setup script
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
