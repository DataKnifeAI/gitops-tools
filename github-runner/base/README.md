# GitHub Actions Runner Controller

This directory contains the base configuration for deploying the GitHub Actions Runner Controller (ARC) to Kubernetes clusters.

## Overview

The GitHub Actions Runner Controller is a Kubernetes operator that manages self-hosted GitHub Actions runners. It allows you to run GitHub Actions workflows on your own Kubernetes infrastructure.

## Architecture

- **Controller**: The ARC controller manages runner pods and scales them based on workflow demand
- **Runner Pods**: Ephemeral pods that execute GitHub Actions workflows
- **Authentication**: Uses GitHub Personal Access Token (PAT) or GitHub App for authentication

## Prerequisites

1. **GitHub Authentication**: You need either:
   - A GitHub Personal Access Token (PAT) with `repo` scope
   - A GitHub App with appropriate permissions
   
2. **Kubernetes Cluster**: Access to a Kubernetes cluster with:
   - RBAC enabled
   - Ability to create namespaces, service accounts, and pods

## Installation

### Step 1: Create GitHub Authentication Secret

Before deploying the controller, you must create a secret containing your GitHub token.

**Option A: Using kubectl (Recommended for PAT)**

```bash
# Create the secret in the actions-runner-system namespace
kubectl create namespace actions-runner-system

# Create secret with GitHub Personal Access Token
kubectl create secret generic actions-runner-controller \
  --from-literal=github_token='<YOUR_GITHUB_PAT>' \
  -n actions-runner-system
```

**Option B: Using GitHub App**

If using a GitHub App, create a secret with the app credentials:

```bash
kubectl create secret generic actions-runner-controller \
  --from-literal=github_app_id='<APP_ID>' \
  --from-literal=github_app_installation_id='<INSTALLATION_ID>' \
  --from-literal=github_app_private_key='<PRIVATE_KEY>' \
  -n actions-runner-system
```

**Option C: Update HelmChart to create secret**

Alternatively, you can set `authSecret.create: true` in the HelmChart and provide the token via Fleet HelmChartConfig or update the values directly.

### Step 2: Deploy Controller

The controller will be deployed automatically by Fleet when:
1. The namespace `actions-runner-system` exists (or will be created by Helm)
2. The authentication secret exists
3. Fleet syncs the GitRepo

Monitor deployment:
```bash
kubectl get pods -n actions-runner-system
kubectl get helmchart -n managed-cicd
```

### Step 3: Deploy RunnerDeployment

After the controller is running, create a RunnerDeployment to manage runners:

```yaml
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: github-runner-deployment
  namespace: managed-cicd
spec:
  replicas: 1  # Will be managed by HorizontalRunnerAutoscaler if using autoscaling
  template:
    spec:
      repository: <YOUR_GITHUB_ORG>/<YOUR_REPO>
      # Or use organization-level runners:
      # organization: <YOUR_GITHUB_ORG>
```

### Step 4: Enable Autoscaling (Optional but Recommended)

Create a `HorizontalRunnerAutoscaler` to enable automatic scaling:

```bash
# Edit the example file with your configuration
kubectl apply -f github-runner/base/horizontalrunnerautoscaler-example.yaml
```

This will automatically scale runners based on workflow demand. See `horizontalrunnerautoscaler-example.yaml` for configuration options.

## Configuration

### Controller Resources

The controller resources are configured in `github-runner-controller-helmchart.yaml`. Adjust CPU and memory limits as needed for your cluster.

### Runner Configuration

Runner pods are configured via RunnerDeployment or RunnerSet resources. Common configurations:

- **Repository-level runners**: Attached to a specific repository
- **Organization-level runners**: Available to all repos in an organization
- **Enterprise-level runners**: Available across an enterprise

### Scaling

The controller supports autoscaling via `HorizontalRunnerAutoscaler` (HRA). This allows runners to scale up and down based on workflow demand.

**Basic RunnerDeployment (Fixed Replicas):**
- Set `replicas` in RunnerDeployment for a fixed number of runners
- Runners are always available but may be idle

**Autoscaling with HorizontalRunnerAutoscaler (Recommended):**
- Create a `HorizontalRunnerAutoscaler` resource that references your RunnerDeployment
- Scales based on:
  - **PercentageRunnersBusy**: Percentage of runners currently executing workflows
  - **TotalNumberOfQueuedAndInProgressWorkflowRuns**: Total queued/in-progress workflows
  - **NumberOfQueuedAndInProgressWorkflowRuns**: Per-repository queued workflows

See `horizontalrunnerautoscaler-example.yaml` for a complete autoscaling configuration.

**Example Autoscaling Configuration:**
```yaml
apiVersion: actions.summerwind.dev/v1alpha1
kind: HorizontalRunnerAutoscaler
metadata:
  name: github-runner-autoscaler
spec:
  scaleTargetRef:
    name: github-runner-deployment
  minReplicas: 1
  maxReplicas: 10
  metrics:
    - type: PercentageRunnersBusy
      scaleUpThreshold: "0.75"
      scaleDownThreshold: "0.25"
```

This will:
- Scale up when 75% of runners are busy
- Scale down when less than 25% are busy
- Maintain between 1-10 runner replicas

## Security Considerations

- **Token Security**: Store GitHub tokens in Kubernetes secrets (encrypted at rest)
- **RBAC**: The controller requires RBAC permissions to create and manage pods
- **Network Policies**: Consider implementing network policies to restrict runner pod network access
- **Resource Limits**: Always set resource limits on runner pods to prevent resource exhaustion

## Troubleshooting

**Controller not starting:**
```bash
# Check controller logs
kubectl logs -n actions-runner-system -l app=actions-runner-controller

# Verify secret exists
kubectl get secret actions-runner-controller -n actions-runner-system

# Check RBAC permissions
kubectl get clusterrolebinding | grep actions-runner-controller
```

**Runners not being created:**
```bash
# Check RunnerDeployment status
kubectl get runnerdeployment -n managed-cicd
kubectl describe runnerdeployment <name> -n managed-cicd

# Check for runner pods
kubectl get pods -n managed-cicd -l runner-deployment-name=<name>

# Check controller logs for errors
kubectl logs -n actions-runner-system -l app=actions-runner-controller | grep -i error
```

**Authentication issues:**
```bash
# Verify token is valid
kubectl get secret actions-runner-controller -n actions-runner-system -o jsonpath='{.data.github_token}' | base64 -d

# Test GitHub API access (from a pod with the token)
```

## References

- [GitHub Actions Runner Controller Documentation](https://github.com/actions/actions-runner-controller)
- [ARC Helm Chart](https://github.com/actions/actions-runner-controller/tree/master/charts/actions-runner-controller)
