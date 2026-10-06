# Deployment Guide

This guide walks you through deploying Harbor and the GitLab runner to your cluster.

## Prerequisites

1. **Kubernetes cluster** with:
   - `kubectl` configured and accessible
   - Rancher Fleet or another GitOps operator installed
   - RBAC enabled
   - Sufficient resources for runners

2. **GitLab Access** (for GitLab Runner):
   - GitLab instance URL
   - Runner authentication token (`glrt-*`, created via GitLab UI)

## Quick Start

### Step 1: Get Token

**GitLab Token:**
1. Go to your GitLab RaaS group
2. Settings → CI/CD → Runners → New runner
3. Copy the runner authentication token (starts with `glrt-`)

### Step 2: Create Secrets

Run the setup script:

```bash
# Interactive mode
./scripts/runner-setup.sh

# OR non-interactive mode
GITLAB_TOKEN=<token> GITLAB_URL=<url> ./scripts/runner-setup.sh gitlab
```

### Step 3: Update Configuration

1. **GitLab Runner**: Edit `gitlab-runner/base/gitlab-runner-helmchart.yaml`
   - Set `gitlabUrl` to your GitLab instance URL
   - Use `./scripts/runner-config.sh` to update token via HelmChartConfig

### Step 4: Commit and Push

```bash
git add .
git commit -m "feat: configure gitlab runner"
git push
```

Fleet will automatically deploy!

## Detailed Deployment Steps

### Step 1: Create Required Namespaces

```bash
# Create managed-cicd namespace (if it doesn't exist)
kubectl create namespace managed-cicd --dry-run=client -o yaml | kubectl apply -f -
```

### Step 2: Create GitLab Runner Token Secret

**Option A: Using the script (Recommended)**

```bash
./scripts/runner-setup.sh gitlab
```

**Option B: Manual creation**

```bash
kubectl create secret generic gitlab-runner-secret \
  --from-literal=runner-registration-token="" \
  --from-literal=runner-token='glrt-<YOUR_RUNNER_AUTH_TOKEN>' \
  -n managed-cicd
```

### Step 3: Update Configuration Files

1. Edit `gitlab-runner/base/gitlab-runner-helmchart.yaml`:
   - Update `gitlabUrl: https://gitlab.com` (or your GitLab instance URL)

2. Update token in Kubernetes secret (recommended - token never goes to git):
   ```bash
   RUNNER_TOKEN=glrt-xxx ./scripts/runner-setup.sh gitlab
   # or update existing secret:
   ./scripts/runner-config.sh
   ```

3. (Optional) Adjust `concurrent` setting for more parallel jobs:
   - Current: `concurrent: 4` (4 parallel jobs)
   - Increase for more capacity (e.g., `concurrent: 10`)

### Step 4: Configure Fleet GitRepo

Ensure your Fleet GitRepo is monitoring the appropriate paths:

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
    - gitlab-runner/overlays/nprd-apps
    - harbor/overlays/nprd-apps
```

### Step 5: Update Fleet Cluster Targeting

Edit the `fleet.yaml` files in the overlay directories to match your cluster labels:

```bash
# Find your cluster labels
kubectl get clusters.management.cattle.io -o yaml | grep -A 10 labels

# Update fleet.yaml files:
# - gitlab-runner/overlays/nprd-apps/fleet.yaml
# - harbor/overlays/nprd-apps/fleet.yaml
```

Uncomment and set the appropriate label, for example:
```yaml
targetCustomizations:
  - name: nprd-apps
    clusterSelector:
      matchLabels:
        managed.cattle.io/cluster-name: nprd-apps
```

### Step 6: Commit and Push Changes

```bash
# Commit your configuration changes
git add .
git commit -m "feat: configure gitlab runner and Harbor for deployment"
git push
```

### Step 7: Monitor Deployment

**Check Fleet Status:**

```bash
# Check GitRepo sync status
kubectl get gitrepo -n fleet-default
kubectl describe gitrepo <your-gitrepo-name> -n fleet-default

# Check Bundle status
kubectl get bundle -n fleet-default
kubectl describe bundle <bundle-name> -n fleet-default
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

### Step 8: Verify Runners are Active

1. Go to your GitLab project/group/instance
2. Navigate to **Settings** → **CI/CD** → **Runners**
3. Verify runner appears with green circle (active)
4. Test by running a CI/CD pipeline

## Token Setup Details

### GitLab Group Runner Token (RaaS Group)

1. Go to your GitLab instance
2. Navigate to the **RaaS** group
3. Go to **Settings** → **CI/CD** → **Runners**
4. Click **New runner** and configure runner settings
5. Copy the runner authentication token (starts with `glrt-`)

**Note:** If you don't see group runners, you may need to:
- Ensure you have Maintainer/Owner permissions on the group
- Or create an instance-level runner from Admin Area → Runners

## Troubleshooting

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

1. **Configure runner tags** for job targeting
2. **Adjust resource limits** based on your workload requirements
3. **Monitor autoscaling behavior** and tune thresholds if needed
4. **Set up monitoring/alerting** for runner health
5. **Review security settings** (network policies, RBAC, etc.)

## Additional Resources

- [GitLab Runner Kubernetes Executor Docs](https://docs.gitlab.com/runner/executors/kubernetes/)
- [Fleet Documentation](https://fleet.rancher.io/)
