# GitHub Runner Secrets

This directory contains example secret configurations for GitHub Actions Runner Controller.

## Authentication Methods

The GitHub Actions Runner Controller supports two authentication methods:

### Method 1: Personal Access Token (PAT)

1. Create a GitHub Personal Access Token:
   - Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Generate a new token with `repo` scope
   - Copy the token

2. Create the secret:
   ```bash
   kubectl create namespace actions-runner-system
   kubectl create secret generic actions-runner-controller \
     --from-literal=github_token='<YOUR_GITHUB_PAT>' \
     -n actions-runner-system
   ```

### Method 2: GitHub App (Recommended for Organizations)

1. Create a GitHub App:
   - Go to your organization → Settings → Developer settings → GitHub Apps
   - Create a new app with appropriate permissions
   - Generate a private key
   - Install the app on your organization/repositories

2. Create the secret:
   ```bash
   kubectl create namespace actions-runner-system
   kubectl create secret generic actions-runner-controller \
     --from-literal=github_app_id='<APP_ID>' \
     --from-literal=github_app_installation_id='<INSTALLATION_ID>' \
     --from-literal=github_app_private_key='<PRIVATE_KEY>' \
     -n actions-runner-system
   ```

## Security Notes

- **Never commit actual tokens or keys to git**
- Secrets are encrypted at rest in Kubernetes
- Use RBAC to restrict access to secrets
- Rotate tokens/keys regularly
- Use GitHub Apps for better security and auditability in organizations
