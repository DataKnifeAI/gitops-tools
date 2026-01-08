# GitLab Runner Secrets

This directory contains example secret configurations for GitLab Runner.

## Obtaining Runner Registration Token

### Project-level Runner

1. Go to your GitLab project
2. Navigate to **Settings** → **CI/CD** → **Runners**
3. Expand **Expand runners settings**
4. Copy the **Registration token**

### Group-level Runner

1. Go to your GitLab group
2. Navigate to **Settings** → **CI/CD** → **Runners**
3. Copy the **Registration token**

### Instance-level Runner

1. Go to **Admin Area** → **Overview** → **Runners**
2. Copy the **Registration token**

## Creating the Secret

```bash
kubectl create secret generic gitlab-runner-secret \
  --from-literal=runner-registration-token='<YOUR_RUNNER_TOKEN>' \
  -n managed-cicd
```

## Security Notes

- **Never commit actual tokens to git**
- Secrets are encrypted at rest in Kubernetes
- Use RBAC to restrict access to secrets
- Rotate tokens regularly
- Use project or group-level tokens when possible (more restrictive than instance-level)
