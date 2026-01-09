# Token Setup Guide

This guide helps you obtain the necessary tokens for GitHub and GitLab runners.

## GitHub Organization Runner Token

For organization-level runners, you need a GitHub Personal Access Token (PAT) or GitHub App.

### Option 1: Personal Access Token (Recommended for quick setup)

1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Give it a name (e.g., "Kubernetes Runner Controller")
4. Select scopes:
   - ✅ `repo` (Full control of private repositories)
   - ✅ `admin:org` (if managing organization runners)
5. Click "Generate token"
6. **Copy the token immediately** (you won't see it again)

### Option 2: GitHub App (Recommended for organizations)

1. Go to your organization → Settings → Developer settings → GitHub Apps
2. Click "New GitHub App"
3. Configure:
   - Name: "Kubernetes Runner Controller"
   - Homepage URL: Your organization URL
   - Permissions:
     - Actions: Read and write
     - Metadata: Read-only
4. Generate a private key
5. Install the app on your organization
6. Note the App ID, Installation ID, and save the private key

## GitLab Group Runner Token (RaaS Group)

1. Go to your GitLab instance
2. Navigate to the **RaaS** group
3. Go to **Settings** → **CI/CD**
4. Expand **Runners** section
5. Under **Group runners**, find the registration token
6. Copy the token

**Note:** If you don't see group runners, you may need to:
- Ensure you have Maintainer/Owner permissions on the group
- Or use an instance-level runner token from Admin Area

## Creating Secrets

Once you have the tokens, create the secrets:

### Using the script (Recommended):

```bash
# Interactive mode
./scripts/setup-runners.sh

# OR non-interactive mode
GITHUB_TOKEN=<your-token> \
GITLAB_TOKEN=<your-token> \
GITLAB_URL=https://gitlab.com \
./scripts/create-secrets.sh
```

### Manual creation:

```bash
# GitHub secret
kubectl create secret generic actions-runner-controller \
  --from-literal=github_token='<YOUR_GITHUB_PAT>' \
  -n actions-runner-system

# GitLab secret
kubectl create secret generic gitlab-runner-secret \
  --from-literal=runner-registration-token='<YOUR_GITLAB_TOKEN>' \
  -n managed-cicd
```

## Next Steps

After creating secrets:
1. Update `github-runner/base/runnerdeployment.yaml` with your GitHub organization name
2. Update `gitlab-runner/base/gitlab-runner-helmchart.yaml` with GitLab URL and token
3. Commit and push changes
4. Fleet will deploy the runners automatically
