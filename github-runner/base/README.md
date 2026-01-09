# GitHub Actions Runner Controller - Base Configuration

This directory contains base configurations for GitHub Actions Runner Controller using the **official GitHub-supported ARC**.

## Architecture

This setup uses the **official GitHub-supported Actions Runner Controller**:
- **Controller**: `gha-runner-scale-set-controller`
- **CRD**: `AutoscalingRunnerSet` (actions.github.com/v1beta1)
- **Architecture**: Listener-based with ephemeral runners
- **Repository**: https://github.com/actions/actions-runner-controller

## Documentation

For complete documentation, see:
- [GitHub Runner Overview](../../docs/GITHUB_RUNNER.md)
- [Official ARC Documentation](../../docs/github-runner/OFFICIAL_ARC.md)
- [Migration Guide](../../docs/github-runner/MIGRATION_TO_OFFICIAL_ARC.md)
- [GitHub Official Docs](https://docs.github.com/en/actions/tutorials/use-actions-runner-controller)

## Quick Start

### 1. Deploy Controller (if not already deployed)

The controller (`gha-runner-scale-set-controller`) must be deployed first. This is typically done at the cluster level.

### 2. Set Up Authentication

Official ARC requires authentication. Two options:

**Option A: GitHub App (Recommended)**

```bash
# Create GitHub App in organization settings
# Install on organization
# Get App ID, Installation ID, and private key

kubectl create secret generic github-app-secret \
  --from-literal=github_app_id='<APP_ID>' \
  --from-literal=github_app_installation_id='<INSTALLATION_ID>' \
  --from-literal=github_app_private_key='<PRIVATE_KEY>' \
  -n managed-cicd
```

**Option B: Personal Access Token (PAT)**

```bash
# Create PAT with admin:org scope
kubectl create secret generic github-pat-secret \
  --from-literal=github_token='<TOKEN>' \
  -n managed-cicd
```

### 3. Create AutoscalingRunnerSet

Use the overlay configuration in `overlays/nprd-apps/` for cluster-specific settings.

The overlay contains:
- `autoscalingrunnerset.yaml` - Direct CRD resource
- `gha-runner-scale-set-helmchart.yaml` - HelmChart for Fleet (recommended)

## Configuration

### Using HelmChart (Recommended for Fleet)

The `gha-runner-scale-set-helmchart.yaml` uses HelmChart resource for Fleet management.

### Using Direct AutoscalingRunnerSet

Alternatively, use `autoscalingrunnerset.yaml` for direct CRD deployment.

## Key Features

- ✅ **Official GitHub Support**: Maintained by GitHub
- ✅ **Ephemeral Runners**: Automatically clean up after jobs
- ✅ **Built-in Scaling**: No separate autoscaler needed
- ✅ **Multiple Labels**: Supports multiple runner labels
- ✅ **Runner Groups**: Full support for runner groups
- ✅ **Efficient Resource Usage**: Better than community version

## Troubleshooting

### Check Controller Status

```bash
kubectl get deployment -n actions-runner-system gha-runner-scale-set-controller-gha-rs-controller
```

### Check AutoscalingRunnerSet

```bash
kubectl get autoscalingrunnerset -n managed-cicd
kubectl describe autoscalingrunnerset <name> -n managed-cicd
```

### Check Listeners

```bash
kubectl get autoscalinglistener -n managed-cicd
kubectl logs -n managed-cicd -l app.kubernetes.io/name=gha-rs-listener
```

### Check Ephemeral Runners

```bash
kubectl get ephemeralrunner -n managed-cicd
```

### Controller Logs

```bash
kubectl logs -n actions-runner-system -l app.kubernetes.io/name=gha-rs-controller
```

## References

- [Official ARC Documentation](https://docs.github.com/en/actions/tutorials/use-actions-runner-controller)
- [Deploy Runner Scale Sets](https://docs.github.com/en/actions/tutorials/use-actions-runner-controller/deploy-runner-scale-sets)
- [Quickstart Guide](https://docs.github.com/en/actions/tutorials/quickstart-for-actions-runner-controller)
- [Authentication Guide](https://docs.github.com/en/actions/tutorials/use-actions-runner-controller/authenticate-to-the-api)
