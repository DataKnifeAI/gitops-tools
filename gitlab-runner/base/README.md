# GitLab Runner

This directory contains the base configuration for deploying GitLab Runner with Kubernetes executor to Kubernetes clusters.

## Overview

GitLab Runner executes GitLab CI/CD jobs in Kubernetes pods. Each job runs in a separate pod, providing isolation and scalability.

## Architecture

- **Runner Pod**: The main GitLab Runner pod that polls GitLab for jobs
- **Job Pods**: Ephemeral pods created for each CI/CD job
- **Kubernetes Executor**: Uses Kubernetes API to create and manage job pods

## Prerequisites

1. **GitLab Instance**: Access to a GitLab instance (GitLab.com or self-hosted)
2. **Runner Registration Token**: Obtain a registration token from your GitLab project, group, or instance
3. **Kubernetes Cluster**: Access to a Kubernetes cluster with:
   - RBAC enabled
   - Ability to create pods and services

## Installation

### Step 1: Obtain Runner Registration Token

**For Project-level Runner:**
1. Go to your GitLab project
2. Navigate to **Settings** → **CI/CD** → **Runners**
3. Expand **Expand runners settings**
4. Copy the **Registration token**

**For Group-level Runner:**
1. Go to your GitLab group
2. Navigate to **Settings** → **CI/CD** → **Runners**
3. Copy the **Registration token**

**For Instance-level Runner:**
1. Go to **Admin Area** → **Overview** → **Runners**
2. Copy the **Registration token**

### Step 2: Create Runner Token Secret

Create a Kubernetes secret with the runner token:

```bash
# Create secret with runner registration token
kubectl create secret generic gitlab-runner-secret \
  --from-literal=runner-registration-token='<YOUR_RUNNER_TOKEN>' \
  -n managed-cicd
```

Alternatively, you can update the HelmChart to use the token directly (not recommended for production).

### Step 3: Update Configuration

Update `gitlab-runner-helmchart.yaml` with:
- `gitlabUrl`: Your GitLab instance URL (e.g., `https://gitlab.com` or `https://gitlab.example.com`)
- `runnerRegistrationToken`: Set to your runner token (or use Fleet HelmChartConfig to inject from secret)

To use the secret, you can:
1. Use Fleet HelmChartConfig to inject the token from the secret
2. Or manually extract and set the token:
   ```bash
   kubectl get secret gitlab-runner-secret -n managed-cicd -o jsonpath='{.data.runner-registration-token}' | base64 -d
   ```

### Step 4: Deploy Runner

The runner will be deployed automatically by Fleet when:
1. The namespace `managed-cicd` exists
2. The runner token secret exists (if using secret)
3. Fleet syncs the GitRepo

Monitor deployment:
```bash
kubectl get pods -n managed-cicd -l app=gitlab-runner
kubectl get helmchart -n managed-cicd
```

### Step 5: Verify Runner Registration

1. Go to your GitLab project/group/instance settings
2. Navigate to **Runners** section
3. Verify the runner appears and is active (green circle)

## Configuration

### Runner Resources

The runner pod resources are configured in `gitlab-runner-helmchart.yaml`. Adjust CPU and memory limits as needed.

### Job Pod Resources

Job pod resources are configured in the `runners.config` section:
- `cpu_limit`: Maximum CPU for job pods
- `memory_limit`: Maximum memory for job pods
- `cpu_request`: CPU request for job pods
- `memory_request`: Memory request for job pods

### Scaling and Concurrent Jobs

**Job Pod Scaling:**
- GitLab Runner with Kubernetes executor creates a **new pod for each CI/CD job**
- Jobs run in parallel based on the `concurrent` setting
- This provides automatic scaling of job execution capacity
- Set `concurrent` to control how many jobs can run simultaneously (default: 4)

**Runner Pod Scaling:**
- The GitLab Runner pod itself is a single instance that polls for jobs
- For high availability, you can run multiple runner pods (increase HelmChart replicas)
- Each runner pod can handle up to `concurrent` jobs simultaneously

**Example Scaling Scenarios:**
- `concurrent: 4` with 1 runner pod = up to 4 parallel jobs
- `concurrent: 4` with 2 runner pods = up to 8 parallel jobs
- `concurrent: 10` with 1 runner pod = up to 10 parallel jobs

**Note:** The runner pod itself doesn't auto-scale, but job pods are created on-demand. Adjust `concurrent` based on your cluster capacity and job requirements.

### Kubernetes Executor Settings

The Kubernetes executor configuration is in `runners.config`:
- `namespace`: Namespace where job pods are created
- `image`: Default Docker image for jobs (can be overridden in `.gitlab-ci.yml`)
- `privileged`: Whether to run pods in privileged mode (default: false)

### Cache Configuration

Cache is configured to use Kubernetes volumes:
- `cacheType: kubernetes`: Uses Kubernetes volumes for cache
- `cachePath: /cache`: Cache mount path
- `cacheShared: true`: Share cache between jobs

## Security Considerations

- **Token Security**: Store runner tokens in Kubernetes secrets (encrypted at rest)
- **RBAC**: The runner requires RBAC permissions to create and manage pods
- **Privileged Mode**: Avoid running jobs in privileged mode unless necessary
- **Resource Limits**: Always set resource limits on job pods to prevent resource exhaustion
- **Network Policies**: Consider implementing network policies to restrict job pod network access

## Troubleshooting

**Runner not starting:**
```bash
# Check runner logs
kubectl logs -n managed-cicd -l app=gitlab-runner

# Verify secret exists
kubectl get secret gitlab-runner-secret -n managed-cicd

# Check RBAC permissions
kubectl get clusterrolebinding | grep gitlab-runner
```

**Runner not registering:**
```bash
# Check runner pod logs for registration errors
kubectl logs -n managed-cicd -l app=gitlab-runner | grep -i "register"

# Verify GitLab URL is correct and accessible
# Verify runner token is correct
```

**Jobs not running:**
```bash
# Check for job pods
kubectl get pods -n managed-cicd

# Check runner logs for job execution errors
kubectl logs -n managed-cicd -l app=gitlab-runner | grep -i "job"

# Verify Kubernetes executor permissions
kubectl auth can-i create pods --namespace=managed-cicd
```

**Job pods failing:**
```bash
# Check job pod logs
kubectl logs -n managed-cicd <job-pod-name>

# Check job pod events
kubectl describe pod <job-pod-name> -n managed-cicd
```

## References

- [GitLab Runner Kubernetes Executor Documentation](https://docs.gitlab.com/runner/executors/kubernetes/)
- [GitLab Runner Helm Chart](https://docs.gitlab.com/runner/install/kubernetes.html)
- [GitLab Runner Configuration](https://docs.gitlab.com/runner/configuration/)
