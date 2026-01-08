# Deployment Guide

This guide walks you through deploying GitHub and GitLab runners to your cluster.

## Prerequisites

1. **Kubernetes cluster** with:
   - `kubectl` configured and accessible
   - Rancher Fleet or another GitOps operator installed
   - RBAC enabled
   - Sufficient resources for runners

2. **GitHub Access** (for GitHub Runner):
   - GitHub Personal Access Token (PAT) with `repo` scope, OR
   - GitHub App credentials

3. **GitLab Access** (for GitLab Runner):
   - GitLab instance URL
   - Runner registration token

## Deployment Steps

### Step 1: Create Required Namespaces

```bash
# Create managed-cicd namespace (if it doesn't exist)
kubectl create namespace managed-cicd --dry-run=client -o yaml | kubectl apply -f -

# The actions-runner-system namespace will be created by Helm
```

### Step 2: Create GitHub Authentication Secret

**Option A: Using the script (Recommended)**

```bash
./scripts/create-github-runner-secret.sh
```

**Option B: Manual creation**

```bash
# Create namespace
kubectl create namespace actions-runner-system

# Create secret with PAT
kubectl create secret generic actions-runner-controller \
  --from-literal=github_token='<YOUR_GITHUB_PAT>' \
  -n actions-runner-system
```

### Step 3: Create GitLab Runner Token Secret

**Option A: Using the script (Recommended)**

```bash
./scripts/create-gitlab-runner-secret.sh
```

**Option B: Manual creation**

```bash
kubectl create secret generic gitlab-runner-secret \
  --from-literal=runner-registration-token='<YOUR_GITLAB_RUNNER_TOKEN>' \
  -n managed-cicd
```

### Step 4: Update Configuration Files

**GitHub Runner:**

1. Edit `github-runner/base/runnerdeployment.yaml`:
   - Update `repository: <YOUR_GITHUB_ORG>/<YOUR_REPO>`
   - Or change to `organization: <YOUR_GITHUB_ORG>` for org-level runners

2. (Optional) Adjust autoscaling in `github-runner/base/horizontalrunnerautoscaler.yaml`:
   - `minReplicas`: Minimum number of runners (default: 1)
   - `maxReplicas`: Maximum number of runners (default: 10)
   - `scaleUpThreshold`: When to scale up (default: 0.75 = 75% busy)
   - `scaleDownThreshold`: When to scale down (default: 0.25 = 25% busy)

**GitLab Runner:**

1. Edit `gitlab-runner/base/gitlab-runner-helmchart.yaml`:
   - Update `gitlabUrl: https://gitlab.com` (or your GitLab instance URL)
   - Extract and set `runnerRegistrationToken` from secret:
     ```bash
     kubectl get secret gitlab-runner-secret -n managed-cicd \
       -o jsonpath='{.data.runner-registration-token}' | base64 -d
     ```
   - Or use Fleet HelmChartConfig to inject from secret (recommended)

2. (Optional) Adjust `concurrent` setting for more parallel jobs:
   - Current: `concurrent: 4` (4 parallel jobs)
   - Increase for more capacity (e.g., `concurrent: 10`)

### Step 5: Configure Fleet GitRepo

Ensure your Fleet GitRepo is monitoring the appropriate paths:

**Option 1: Monitor overlay directories (Recommended)**

```yaml
apiVersion: fleet.cattle.io/v1alpha1
kind: GitRepo
metadata:
  name: gitops-tools
  namespace: fleet-default
spec:
  repo: <YOUR_REPO_URL>
  branch: main
  paths:
    - github-runner/overlays/nprd-apps
    - gitlab-runner/overlays/nprd-apps
```

**Option 2: Monitor root directory**

```yaml
apiVersion: fleet.cattle.io/v1alpha1
kind: GitRepo
metadata:
  name: gitops-tools
  namespace: fleet-default
spec:
  repo: <YOUR_REPO_URL>
  branch: main
  # No paths specified - Fleet will create bundles for each directory
```

### Step 6: Update Fleet Cluster Targeting

Edit the `fleet.yaml` files in the overlay directories to match your cluster labels:

```bash
# Find your cluster labels
kubectl get clusters.management.cattle.io -o yaml | grep -A 10 labels

# Update fleet.yaml files:
# - github-runner/overlays/nprd-apps/fleet.yaml
# - gitlab-runner/overlays/nprd-apps/fleet.yaml
```

Uncomment and set the appropriate label, for example:
```yaml
targetCustomizations:
  - name: nprd-apps
    clusterSelector:
      matchLabels:
        managed.cattle.io/cluster-name: nprd-apps
```

### Step 7: Commit and Push Changes

```bash
# Commit your configuration changes
git add .
git commit -m "feat: configure GitHub and GitLab runners for deployment"
git push
```

### Step 8: Monitor Deployment

**Check Fleet Status:**

```bash
# Check GitRepo sync status
kubectl get gitrepo -n fleet-default
kubectl describe gitrepo <your-gitrepo-name> -n fleet-default

# Check Bundle status
kubectl get bundle -n fleet-default
kubectl describe bundle <bundle-name> -n fleet-default
```

**Check GitHub Runner Controller:**

```bash
# Check controller pod
kubectl get pods -n actions-runner-system
kubectl logs -n actions-runner-system -l app=actions-runner-controller

# Check HelmChart
kubectl get helmchart -n managed-cicd
kubectl describe helmchart actions-runner-controller -n managed-cicd

# Check RunnerDeployment
kubectl get runnerdeployment -n managed-cicd
kubectl describe runnerdeployment github-runner-deployment -n managed-cicd

# Check HorizontalRunnerAutoscaler
kubectl get horizontalrunnerautoscaler -n managed-cicd
kubectl describe horizontalrunnerautoscaler github-runner-autoscaler -n managed-cicd

# Check runner pods
kubectl get pods -n managed-cicd -l runner-deployment-name=github-runner-deployment
```

**Check GitLab Runner:**

```bash
# Check runner pod
kubectl get pods -n managed-cicd -l app=gitlab-runner
kubectl logs -n managed-cicd -l app=gitlab-runner

# Check HelmChart
kubectl get helmchart -n managed-cicd
kubectl describe helmchart gitlab-runner -n managed-cicd
```

### Step 9: Verify Runners are Active

**GitHub Runner:**

1. Go to your GitHub repository
2. Navigate to **Settings** → **Actions** → **Runners**
3. Verify runners appear with status "Online"
4. Check that autoscaling is working by triggering a workflow

**GitLab Runner:**

1. Go to your GitLab project/group/instance
2. Navigate to **Settings** → **CI/CD** → **Runners**
3. Verify runner appears with green circle (active)
4. Test by running a CI/CD pipeline

## Troubleshooting

### GitHub Runner Issues

**Controller not starting:**
```bash
# Check secret exists
kubectl get secret actions-runner-controller -n actions-runner-system

# Check controller logs
kubectl logs -n actions-runner-system -l app=actions-runner-controller
```

**Runners not appearing:**
```bash
# Check RunnerDeployment status
kubectl describe runnerdeployment github-runner-deployment -n managed-cicd

# Check autoscaler status
kubectl describe horizontalrunnerautoscaler github-runner-autoscaler -n managed-cicd

# Check for runner pods
kubectl get pods -n managed-cicd -l runner-deployment-name=github-runner-deployment
```

### GitLab Runner Issues

**Runner not registering:**
```bash
# Check secret exists
kubectl get secret gitlab-runner-secret -n managed-cicd

# Check runner logs
kubectl logs -n managed-cicd -l app=gitlab-runner | grep -i register

# Verify GitLab URL is accessible
```

**Jobs not running:**
```bash
# Check runner pod logs
kubectl logs -n managed-cicd -l app=gitlab-runner

# Check for job pods
kubectl get pods -n managed-cicd

# Verify RBAC permissions
kubectl auth can-i create pods --namespace=managed-cicd
```

## Next Steps After Deployment

1. **Configure runner labels** (GitHub) or **tags** (GitLab) for workflow targeting
2. **Adjust resource limits** based on your workload requirements
3. **Monitor autoscaling behavior** and tune thresholds if needed
4. **Set up monitoring/alerting** for runner health
5. **Review security settings** (network policies, RBAC, etc.)

## Additional Resources

- [GitHub Actions Runner Controller Docs](https://github.com/actions/actions-runner-controller)
- [GitLab Runner Kubernetes Executor Docs](https://docs.gitlab.com/runner/executors/kubernetes/)
- [Fleet Documentation](https://fleet.rancher.io/)
