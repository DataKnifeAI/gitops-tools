# GitOps Tools

GitOps repository for deploying managed Kubernetes tools to the `nprd-apps` cluster.

> **Note**: This project is built with [Cursor](https://cursor.sh) and Composer mode.

## Overview

This repository contains Kubernetes manifests and configurations for deploying managed tools in a dedicated namespace on the `nprd-apps` cluster.

## Tools

- **Harbor**: Container image registry and management platform

## Structure

```
.
├── README.md
├── harbor/
│   └── namespace: nprd-apps/managed-tools
└── ...
```

## Cluster Information

- **Cluster**: nprd-apps
- **Namespace**: managed-tools (dedicated namespace for managed tools)

## Usage

This repository follows GitOps principles. Changes to manifests in this repository will be automatically applied to the cluster by your GitOps operator (e.g., ArgoCD, Flux).

## Contributing

1. Make changes to manifests in the appropriate tool directory
2. Commit and push changes
3. The GitOps operator will automatically sync changes to the cluster
