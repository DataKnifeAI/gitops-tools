# Monitoring (Promtail + Prometheus)

Promtail and Prometheus deployed as a separate Fleet bundle from the Grafana stack. Enables per-cluster control over log and metrics collection.

## Structure

```
monitoring/
├── base/                    # Reference configuration
│   ├── promtail-helmchart.yaml
│   ├── prometheus-helmchart.yaml
│   └── namespace.yaml
└── overlays/
    ├── nprd-apps/           # Loki in-cluster, RKE2/containerd
    ├── poc-apps/            # Loki remote (nprd-apps via ingress)
    ├── prd-apps/            # Loki remote (nprd-apps via ingress)
    └── rancher-manager/     # Loki remote (nprd-apps via ingress)
```

## Cluster Overlays

| Cluster          | Namespace  | Promtail Loki URL                       | Prometheus Storage   |
|------------------|------------|-----------------------------------------|----------------------|
| nprd-apps        | grafana    | `http://loki-distributor:3100` (in-cluster) | truenas-csi-nfs 50Gi |
| poc-apps         | monitoring | `https://loki.dataknife.net` (remote)   | default 50Gi         |
| prd-apps         | monitoring | `https://loki.dataknife.net` (remote)   | default 50Gi         |
| rancher-manager  | grafana    | `https://loki.dataknife.net` (remote)   | default 50Gi         |

poc-apps and prd-apps use `monitoring` namespace to avoid conflicts with orphaned grafana/loki HelmCharts.

## Fleet GitRepos

Monitoring uses **separate GitRepos per cluster** (see [FLEET_STRUCTURE.md](../docs/FLEET_STRUCTURE.md)):

| GitRepo | Cluster | Path |
|---------|---------|------|
| gitops-tools-nprd-apps | nprd-apps | monitoring/overlays/nprd-apps |
| gitops-tools-poc-apps | poc-apps | monitoring/overlays/poc-apps |
| gitops-tools-prd-apps | prd-apps | monitoring/overlays/prd-apps |

**Apply poc-apps/prd-apps GitRepos** (one-time, from rancher-manager context):

```bash
# From repo root
kubectl --context rancher-manager apply -f fleet-gitrepo-poc-apps.yaml
kubectl --context rancher-manager apply -f fleet-gitrepo-prd-apps.yaml
```

Add new cluster overlays by creating `monitoring/overlays/<cluster-name>/` and a corresponding `fleet-gitrepo-<cluster>.yaml`.
