# Quick Start: Deploy Runners

## Prerequisites

You need:
1. **GitHub Organization Token** - PAT with `repo` and `admin:org` scopes
2. **GitLab Group Token** - Registration token from RaaS group
3. **GitLab URL** - Your GitLab instance URL (e.g., https://gitlab.com)

## Step 1: Get Tokens

### GitHub Token
```bash
# Go to: https://github.com/settings/tokens
# Create token with 'repo' and 'admin:org' scopes
# Copy the token
```

### GitLab Token
```bash
# Go to your GitLab RaaS group
# Settings → CI/CD → Runners
# Copy the group runner registration token
```

## Step 2: Create Secrets in Kubernetes

Run the setup script with your tokens:

```bash
# Option 1: Interactive
./scripts/setup-runners.sh

# Option 2: Non-interactive with arguments
./scripts/create-secrets.sh <github-token> <gitlab-token> <gitlab-url>

# Option 3: Using environment variables
export GITHUB_TOKEN="your-github-token"
export GITLAB_TOKEN="your-gitlab-token"
export GITLAB_URL="https://gitlab.com"
./scripts/create-secrets.sh
```

## Step 3: Update Configuration

1. **GitHub Runner**: Edit `github-runner/base/runnerdeployment.yaml`
   - Replace `<YOUR_GITHUB_ORG>` with your organization name

2. **GitLab Runner**: Edit `gitlab-runner/base/gitlab-runner-helmchart.yaml`
   - Set `gitlabUrl` to your GitLab instance URL
   - Extract token from secret and set `runnerRegistrationToken`:
     ```bash
     kubectl get secret gitlab-runner-secret -n managed-cicd \
       -o jsonpath='{.data.runner-registration-token}' | base64 -d
     ```

## Step 4: Commit and Push

```bash
git add .
git commit -m "feat: configure GitHub and GitLab runners for organization/group level"
git push
```

Fleet will automatically deploy the runners!

## Verify Deployment

```bash
# Check GitHub runner controller
kubectl get pods -n actions-runner-system
kubectl get runnerdeployment -n managed-cicd

# Check GitLab runner
kubectl get pods -n managed-cicd -l app=gitlab-runner
```
