# Monitoring Base (Reference)

Base configuration for Promtail and Prometheus. Deployed via cluster-specific overlays.

## Components

- **Promtail**: Log collection agent (DaemonSet), pushes to Loki
- **Prometheus**: Metrics (kube-prometheus-stack: Prometheus, node-exporter, kube-state-metrics)

## Overlays

Each overlay customizes:
- Fleet cluster targeting
- Loki URL for Promtail (in-cluster vs remote)
- Storage class and resources for Prometheus
- Log path for container runtime (RKE2/containerd vs Docker)
