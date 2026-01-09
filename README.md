# GitOps Tools

GitOps repository for deploying managed Kubernetes tools to the `nprd-apps` cluster using Rancher Fleet.

## Quick Start

1. **Generate TLS certificate**: `./scripts/generate-wildcard-cert.sh`
2. **Create secrets**: `./scripts/create-harbor-secrets.sh`
3. **Deploy via Fleet**: Configure GitRepo to monitor `harbor/`

See [docs/QUICK_START.md](docs/QUICK_START.md) for detailed setup instructions.

## Tools

- **Harbor**: Container image registry with DockerHub proxy cache
- **GitHub Runner**: GitHub Actions self-hosted runners
- **GitLab Runner**: GitLab CI/CD runners

## Structure

```
.
├── harbor/          # Harbor registry deployment
├── github-runner/   # GitHub Actions runners
├── gitlab-runner/   # GitLab CI/CD runners
├── scripts/         # Setup and utility scripts
├── secrets/         # Secret templates and examples
└── docs/            # Detailed documentation
```

## Documentation

- [Quick Start Guide](docs/QUICK_START.md) - Initial setup and deployment
- [Deployment Guide](docs/DEPLOYMENT.md) - Detailed deployment instructions
- [Harbor Setup](docs/HARBOR_SETUP.md) - Harbor registry and proxy cache configuration
- [Setup Tokens](docs/SETUP_TOKENS.md) - Token management for runners
- [GitHub Organization Setup](docs/GITHUB_ORG_SETUP.md) - GitHub organization configuration
- [Changelog](docs/CHANGELOG.md) - Version history

## Cluster Information

- **Cluster**: nprd-apps
- **Namespace**: managed-tools

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.
