# GitHub Actions Runner - Runner Definitions

This directory contains runner definitions for GitHub Actions Runner Controller using the **official GitHub-supported ARC**.

## Architecture

**IMPORTANT**: The GitHub Actions Runner Controller (`gha-runner-scale-set-controller`) is managed by a separate Terraform project. This repository only manages runner definitions.

- **Controller**: `gha-runner-scale-set-controller` (managed by Terraform - not in this repo)
- **Runner Definitions**: `AutoscalingRunnerSet` (actions.github.com/v1beta1) - managed here
- **Architecture**: Listener-based with ephemeral runners
- **Repository**: https://github.com/actions/actions-runner-controller

## Documentation

For complete documentation, see:
- [GitHub Runner Overview](../../docs/GITHUB_RUNNER.md)
- [Official ARC Documentation](../../docs/github-runner/OFFICIAL_ARC.md)
- [Migration Guide](../../docs/github-runner/MIGRATION_TO_OFFICIAL_ARC.md)
- [GitHub Official Docs](https://docs.github.com/en/actions/tutorials/use-actions-runner-controller)

## Quick Start

### Prerequisites

**The controller (`gha-runner-scale-set-controller`) must already be deployed.** The controller is managed by a separate Terraform project, not this repository. This repository only manages runner definitions.

### 1. Set Up Authentication

**NOTE**: Authentication secrets should already exist if the controller was deployed via Terraform. If not, you may need to create them manually.

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

### 2. Deploy Runner Definitions

Use the overlay configuration in `overlays/nprd-apps/` for cluster-specific settings.

The overlay contains:
- `autoscalingrunnerset.yaml` - AutoscalingRunnerSet CRD resource (runner definition)

Fleet will deploy this to the target cluster when the GitRepo syncs.

## Configuration

### Runner Definitions

This repository manages runner definitions using `AutoscalingRunnerSet` CRD resources. The runner definitions specify:
- Organization/Repository configuration
- Runner group assignment
- Scaling parameters (min/max runners)
- Labels
- Resource requirements
- Runner pod templates

The controller (managed by Terraform) watches for these definitions and creates the necessary listeners and ephemeral runners.

## Key Features

- ✅ **Official GitHub Support**: Maintained by GitHub
- ✅ **Ephemeral Runners**: Automatically clean up after jobs
- ✅ **Built-in Scaling**: No separate autoscaler needed
- ✅ **Multiple Labels**: Supports multiple runner labels
- ✅ **Runner Groups**: Full support for runner groups
- ✅ **Efficient Resource Usage**: Better than community version

## Troubleshooting

### Check Controller Status

**NOTE**: Controller is managed by Terraform. Check with the Terraform project maintainers if issues occur.

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
