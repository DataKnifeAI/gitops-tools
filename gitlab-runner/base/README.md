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
2. **Runner Authentication Token**: Obtain a `glrt-*` authentication token by creating a runner in GitLab UI
3. **Kubernetes Cluster**: Access to a Kubernetes cluster with:
   - RBAC enabled
   - Ability to create pods and services

## Installation

### Step 1: Obtain Runner Authentication Token

Registration tokens are deprecated. Create a runner in GitLab UI and copy the `glrt-*` authentication token.

**For Project-level Runner:**
1. Go to your GitLab project → **Settings** → **CI/CD** → **Runners**
2. Click **New runner** and copy the authentication token

**For Group-level Runner:**
1. Go to your GitLab group → **Settings** → **CI/CD** → **Runners**
2. Click **New runner** and copy the authentication token

**For Instance-level Runner:**
1. Go to **Admin Area** → **Overview** → **Runners**
2. Click **New runner** and copy the authentication token

### Step 2: Create Runner Token Secret

```bash
# Create secret with runner authentication token
kubectl create secret generic gitlab-runner-secret \
  --from-literal=runner-registration-token="" \
  --from-literal=runner-token='glrt-<YOUR_RUNNER_AUTH_TOKEN>' \
  -n managed-cicd
```

Or use the setup script:

```bash
RUNNER_TOKEN=glrt-xxx ./scripts/runner-setup.sh gitlab
```

### Step 3: Update Configuration

Update `gitlab-runner-helmchart.yaml` with:
- `gitlabUrl`: Your GitLab instance URL (e.g., `https://gitlab.com` or `https://gitlab.example.com`)

The runner token is referenced via `runners.secret: gitlab-runner-secret` (never committed to git).

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

### Harbor Registry Integration

Harbor is reachable at `harbor.dataknife.net` with a **public TLS chain** (for example Let’s Encrypt on ingress). Trust is **not** managed by GitOps in this overlay:

1. **Job pods** (BuildKit, registry login, and so on) use the **image default CA bundle**. We **do not** mount `/etc/docker/certs.d/harbor.dataknife.net` in job pods, so TLS is not tied to a stale custom CA file in the cluster.
2. **Node image pulls** for the runner manager use the chart default `registry.gitlab.com/gitlab-org/gitlab-runner`. Job images that point at Harbor rely on **RKE2/containerd default trust** for Harbor’s public TLS chain. No `harbor-ca-cert` secret or `containerd-harbor-cert-config` DaemonSet is deployed here.

If Harbor ever uses a **private CA** or a hostname that nodes do not trust by default, you would need an explicit trust story (for example install the issuing CA on nodes, or reintroduce a maintained `registries.yaml` / certs.d workflow that matches the live certificate).

#### Verification

**Test Harbor TLS from a job pod:**
```yaml
# In .gitlab-ci.yml
test_harbor:
  script:
    - docker login harbor.dataknife.net -u <username> -p <password>
    - docker pull harbor.dataknife.net/dockerhub/library/alpine:latest
```

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

**Harbor certificate errors:**

**Error: `tls: failed to verify certificate: x509: certificate signed by unknown authority`**

1. **Inside job pods** (push or pull to `harbor.dataknife.net`): Confirm Harbor presents a full chain trusted by public CAs, for example:
   ```bash
   openssl s_client -connect harbor.dataknife.net:443 -servername harbor.dataknife.net </dev/null
   ```

2. **Kubernetes image pulls** (`ErrImagePull` when starting the runner or a job pod): Confirm the same from a node, and that the node OS/RKE2 trust store is current. If nodes previously had a **custom** `registries.yaml` or `certs.d` entry for Harbor (for example from an old DaemonSet), remove or update those files so they do not pin a **wrong** `ca_file` that no longer matches the ingress certificate.

**Error: `missing client certificate tls.cert for key tls.key`**

This occurs when a volume under `/etc/docker/certs.d/` (or similar) exposes both `tls.crt` and `tls.key`. The client then expects a client certificate. For Harbor trust, use **only** a CA PEM (or rely on system trust and avoid custom cert mounts).

## References

- [GitLab Runner Kubernetes Executor Documentation](https://docs.gitlab.com/runner/executors/kubernetes/)
- [GitLab Runner Helm Chart](https://docs.gitlab.com/runner/install/kubernetes.html)
- [GitLab Runner Configuration](https://docs.gitlab.com/runner/configuration/)
