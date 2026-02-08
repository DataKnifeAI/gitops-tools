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

| Cluster          | Promtail Loki URL                       | Prometheus Storage   |
|------------------|-----------------------------------------|----------------------|
| nprd-apps        | `http://loki-distributor:3100` (in-cluster) | truenas-csi-nfs 50Gi |
| poc-apps         | `https://loki.dataknife.net` (remote)   | default 50Gi         |
| prd-apps         | `https://loki.dataknife.net` (remote)   | default 50Gi         |
| rancher-manager  | `https://loki.dataknife.net` (remote)   | default 50Gi         |

## Fleet Paths

Fleet GitRepo monitors:
- `monitoring/overlays/nprd-apps`
- `monitoring/overlays/poc-apps`
- `monitoring/overlays/prd-apps`
- `monitoring/overlays/rancher-manager`

Add new cluster overlays by creating `monitoring/overlays/<cluster-name>/` and adding the path to `fleet-gitrepo.yaml`.
