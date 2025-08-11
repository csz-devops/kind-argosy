# Helm Version Management with Official Argo CD Helm Chart

## Overview

This document explains how to manage Helm versions in Argo CD using the [official Argo CD Helm chart](https://github.com/argoproj/argo-helm) from the [Argo Helm repository](https://github.com/argoproj/argo-helm).

## 🎯 Why Use the Official Helm Chart?

The official Argo CD Helm chart provides several advantages over manual manifest management:

1. **Built-in Helm Version Control**: Proper Helm version management through chart configuration
2. **Official Support**: Maintained by the Argo CD team
3. **Better Configuration**: More flexible configuration options
4. **Version Compatibility**: Ensures compatibility between Argo CD and Helm versions
5. **Simpler Updates**: No need for custom patches

## 🔧 Helm Version Management Methods

### Method 1: Using `extraInitContainers` (Recommended)

The official chart supports custom Helm versions through the `repoServer.extraInitContainers` configuration:

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
  
  env:
    - name: HELM_VERSION
      value: "v3.12.3"
```

### Method 2: Using Custom Image

You can also use a custom image with the desired Helm version:

```yaml
repoServer:
  image:
    repository: your-registry/argocd
    tag: v2.8.0-helm-3.12.3
```

### Method 3: Using Helm Plugins

For additional Helm functionality, you can install plugins:

```yaml
repoServer:
  extraInitContainers:
    - name: install-helm-plugins
      image: alpine:3.18
      command:
        - sh
        - -c
        - |
          # Install Helm
          wget -O /helm.tar.gz https://get.helm.sh/helm-v3.12.3-linux-amd64.tar.gz
          tar -xzf /helm.tar.gz
          cp linux-amd64/helm /shared/helm
          chmod +x /shared/helm
          
          # Install plugins
          /shared/helm plugin install https://github.com/hayorov/helm-gcs.git
          /shared/helm plugin install https://github.com/helm/helm-s3.git
      volumeMounts:
        - name: helm-volume
          mountPath: /shared
```

## 📋 How to Update Helm Version

### Step 1: Modify the Helm Chart Values

Update the Helm version in your Argo CD application configuration:

```yaml
# In gitops/apps/argocd/argocd-app.yaml
repoServer:
  extraInitContainers:
    - name: install-helm
      image: alpine:3.18
      command:
        - sh
        - -c
        - |
          # Change version here
          wget -O /helm.tar.gz https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz
          tar -xzf /helm.tar.gz
          cp linux-amd64/helm /shared/helm
          chmod +x /shared/helm
          /shared/helm version
```

### Step 2: Update Environment Variable

Also update the environment variable:

```yaml
repoServer:
  env:
    - name: HELM_VERSION
      value: "v3.13.0"  # Update this
```

### Step 3: Commit and Push

```bash
git add gitops/apps/argocd/argocd-app.yaml
git commit -m "Update Helm to v3.13.0"
git push
```

### Step 4: Argo CD Automatically Syncs

Argo CD will:
1. Detect the change in Git
2. Apply the updated Helm chart values
3. Restart the repo-server pod
4. Download and install the new Helm version

## 🔍 Verification Commands

### Check Current Helm Version

```bash
# Check Helm version in Argo CD repo-server
kubectl exec -n argocd deployment/argocd-repo-server -- helm version

# Check pod logs to see installation
kubectl logs -n argocd deployment/argocd-repo-server -c install-helm

# Check environment variable
kubectl exec -n argocd deployment/argocd-repo-server -- env | grep HELM_VERSION
```

### Test Helm Functionality

```bash
# Test Helm repo operations
kubectl exec -n argocd deployment/argocd-repo-server -- helm repo list

# Test Helm template operations
kubectl exec -n argocd deployment/argocd-repo-server -- helm template test . --dry-run
```

## 🚀 Available Helm Versions

You can use any Helm version available at `https://get.helm.sh/`:

- **Helm 3.12.x**: Stable, widely used
- **Helm 3.13.x**: Latest stable
- **Helm 3.14.x**: Latest features
- **Helm 4.x.x**: Future releases

### Version Compatibility

| Argo CD Version | Recommended Helm Version | Notes |
|----------------|-------------------------|-------|
| 2.8.x          | 3.12.x - 3.14.x        | Stable |
| 2.9.x          | 3.12.x - 3.14.x        | Stable |
| 2.10.x         | 3.12.x - 3.14.x        | Stable |

## 🛠️ Advanced Configuration

### Custom Helm Configuration

You can add custom Helm configuration:

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
          
          # Create Helm config directory
          mkdir -p /shared/.config/helm
          
          # Add custom Helm repositories
          /shared/helm repo add stable https://charts.helm.sh/stable
          /shared/helm repo add bitnami https://charts.bitnami.com/bitnami
          
          # Update repositories
          /shared/helm repo update
      volumeMounts:
        - name: helm-volume
          mountPath: /shared
        - name: helm-config
          mountPath: /shared/.config/helm
  
  extraVolumes:
    - name: helm-volume
      emptyDir: {}
    - name: helm-config
      emptyDir: {}
```

### Persistent Helm Cache

For better performance, you can use persistent storage for Helm cache:

```yaml
repoServer:
  extraVolumes:
    - name: helm-cache
      persistentVolumeClaim:
        claimName: argocd-helm-cache
  
  extraVolumeMounts:
    - name: helm-cache
      mountPath: /shared/.cache/helm
```

## 🔧 Troubleshooting

### Common Issues

1. **Helm Version Not Updated**
   ```bash
   # Check if the init container completed successfully
   kubectl logs -n argocd deployment/argocd-repo-server -c install-helm
   
   # Check if the volume mount is correct
   kubectl exec -n argocd deployment/argocd-repo-server -- ls -la /usr/local/bin/helm
   ```

2. **Helm Plugin Issues**
   ```bash
   # Check plugin installation
   kubectl exec -n argocd deployment/argocd-repo-server -- helm plugin list
   
   # Check plugin logs
   kubectl logs -n argocd deployment/argocd-repo-server -c install-helm-plugins
   ```

3. **Permission Issues**
   ```bash
   # Check file permissions
   kubectl exec -n argocd deployment/argocd-repo-server -- ls -la /usr/local/bin/helm
   
   # Fix permissions if needed
   kubectl exec -n argocd deployment/argocd-repo-server -- chmod +x /usr/local/bin/helm
   ```

### Debug Commands

```bash
# Get detailed pod information
kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-repo-server

# Check all containers in the pod
kubectl get pod -n argocd -l app.kubernetes.io/name=argocd-repo-server -o jsonpath='{.items[0].spec.containers[*].name}'

# Check init containers
kubectl get pod -n argocd -l app.kubernetes.io/name=argocd-repo-server -o jsonpath='{.items[0].spec.initContainers[*].name}'
```

## 📚 References

- [Official Argo CD Helm Chart](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd)
- [Argo CD Helm Documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/helm/)
- [Helm Official Releases](https://github.com/helm/helm/releases)
- [Argo Helm Repository](https://github.com/argoproj/argo-helm)

## 🎯 Best Practices

1. **Use Official Chart**: Always use the official Argo CD Helm chart
2. **Version Compatibility**: Ensure Helm version is compatible with Argo CD version
3. **Test Changes**: Test Helm version updates in a non-production environment
4. **Document Changes**: Document any custom Helm configurations
5. **Monitor Logs**: Regularly check Argo CD logs for Helm-related issues
6. **Backup Configuration**: Keep backups of your Helm chart values
