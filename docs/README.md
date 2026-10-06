# GitOps Tools Documentation

This directory contains comprehensive documentation for all tools and services managed in this GitOps repository.

## Documentation Index

### GitLab Runner
- **[GitLab Runner Base Configuration](../gitlab-runner/base/README.md)** - GitLab CI/CD runner setup, configuration, and Harbor integration

### Harbor
- **[Harbor Documentation](HARBOR.md)** - Harbor container registry setup and configuration

### Grafana Stack (Loki, Promtail, Vector)
- **[Grafana Stack Documentation](grafana/README.md)** - Overview, RustFS, Fleet troubleshooting, UniFi CEF
- **[RustFS Loki Setup](grafana/RUSTFS_LOKI_SETUP.md)** - RustFS on TrueNAS for Loki S3 storage
- **[UniFi CEF Setup](grafana/UNIFI_CEF_SETUP.md)** - UniFi CEF syslog integration

### Fleet
- **[Fleet Sync](FLEET_SYNC.md)** - Agent registration and bundle sync troubleshooting
- **[Fleet Structure](FLEET_STRUCTURE.md)** - GitOps paths and overlay pattern

### General
- **[Deployment Guide](DEPLOYMENT.md)** - General deployment procedures
- **[Changelog](CHANGELOG.md)** - Project changelog

## Quick Links

- [Main Repository README](../README.md)
- [Contributing Guide](../CONTRIBUTING.md)
- [Code of Conduct](../CODE_OF_CONDUCT.md)

## Repository Structure

```
.
├── docs/                      # Documentation (this directory)
├── gitlab-runner/            # GitLab Runner
├── harbor/                   # Harbor container registry
├── grafana/                  # Grafana Stack (Loki + Promtail + Grafana)
└── secrets/                  # Secret templates and examples
```

