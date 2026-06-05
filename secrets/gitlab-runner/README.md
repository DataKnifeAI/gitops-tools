# GitLab Runner Secrets

This directory contains example secret configurations for GitLab Runner.

## Obtaining Runner Authentication Token

Registration tokens are deprecated and removed in GitLab 18+. Use the new workflow:

1. Go to your GitLab project, group, or Admin Area → Runners
2. Click **New runner** (or create via API)
3. Configure runner settings (tags, locked, etc.) in the UI
4. Copy the **runner authentication token** (starts with `glrt-`)

### Project-level Runner

1. Go to your GitLab project
2. Navigate to **Settings** → **CI/CD** → **Runners**
3. Click **New runner** and copy the authentication token

### Group-level Runner

1. Go to your GitLab group
2. Navigate to **Settings** → **CI/CD** → **Runners**
3. Click **New runner** and copy the authentication token

### Instance-level Runner

1. Go to **Admin Area** → **Overview** → **Runners**
2. Click **New runner** and copy the authentication token

## Creating the Secret

```bash
kubectl create secret generic gitlab-runner-secret \
  --from-literal=runner-registration-token="" \
  --from-literal=runner-token='glrt-<YOUR_RUNNER_AUTH_TOKEN>' \
  -n managed-cicd
```

Or use the setup script:

```bash
RUNNER_TOKEN=glrt-xxx ./scripts/runner-setup.sh gitlab
```

## Security Notes

- **Never commit actual tokens to git**
- Secrets are encrypted at rest in Kubernetes
- Use RBAC to restrict access to secrets
- Rotate tokens regularly
- Use project or group-level tokens when possible (more restrictive than instance-level)
