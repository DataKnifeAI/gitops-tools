# Prometheus Base Configuration

This directory contains the base configuration for deploying the Prometheus monitoring stack.

## Overview

The Prometheus Stack provides comprehensive metrics monitoring for Kubernetes clusters:

- **Prometheus**: Metrics collection and storage
- **Alertmanager**: Alert management and routing
- **node-exporter**: Node-level metrics (CPU, memory, disk, network)
- **kube-state-metrics**: Cluster state metrics (Deployments, Pods, Services, etc.)
- **Prometheus Operator**: Manages Prometheus and ServiceMonitor/PodMonitor CRDs

## Components

### Prometheus

Metrics collection and storage system:
- **Retention**: 15 days (configurable)
- **Storage**: 100Gi PVC (configurable)
- **Replicas**: 1 (for HA, increase replicas)
- **Discovery**: Automatically discovers ServiceMonitors and PodMonitors

### Alertmanager

Alert management and routing:
- **Retention**: 120 hours (5 days)
- **Storage**: 10Gi PVC
- **Replicas**: 1

### node-exporter

DaemonSet that collects node-level metrics:
- **Metrics**: CPU, memory, disk I/O, network, filesystem
- **Collection**: One pod per node

### kube-state-metrics

Exposes cluster state as metrics:
- **Metrics**: Deployment status, Pod phases, Service endpoints, etc.
- **Usage**: Essential for Kubernetes monitoring dashboards

### Prometheus Operator

Manages Prometheus deployments and CRDs:
- **CRDs**: ServiceMonitor, PodMonitor, PrometheusRule, AlertmanagerConfig
- **Features**: Automatic target discovery and configuration

## Structure

```
prometheus/
├── base/                          # Base Prometheus configuration
│   ├── fleet.yaml                # Base Fleet config
│   ├── kustomization.yaml        # Kustomize base
│   ├── namespace.yaml            # Namespace definition
│   ├── prometheus-helmchart.yaml # Prometheus Stack Helm chart
│   └── README.md                 # This file
└── overlays/
    └── nprd-apps/                 # nprd-apps cluster overlay
        ├── fleet.yaml            # Cluster-specific Fleet config
        ├── kustomization.yaml   # Kustomize overlay
        └── prometheus-helmchart.yaml  # Override base values
```

## Deployment

### Prerequisites

1. **Namespace**: The `managed-syslog` namespace will be created automatically
2. **Fleet GitRepo**: Configured to monitor the `prometheus/overlays/nprd-apps` path
3. **Grafana**: Already deployed in the Loki stack (Grafana is disabled in this chart)

### Base Configuration

The base configuration provides:
- Standard Prometheus setup with 15-day retention
- 100Gi storage for metrics
- node-exporter and kube-state-metrics enabled
- Default Kubernetes alerting rules enabled

## Customization

### Storage

To change storage size, override in overlay:
```yaml
prometheus:
  prometheusSpec:
    storageSpec:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 200Gi  # Custom size
```

### Retention

To change retention period:
```yaml
prometheus:
  prometheusSpec:
    retention: 30d  # 30 days
```

### Resource Limits

To adjust resource limits:
```yaml
prometheus:
  prometheusSpec:
    resources:
      requests:
        cpu: 1000m
        memory: 4Gi
      limits:
        cpu: 4000m
        memory: 8Gi
```

## ServiceMonitors and PodMonitors

The Prometheus Operator automatically discovers metrics targets via:

- **ServiceMonitor**: Scrapes metrics from services
- **PodMonitor**: Scrapes metrics from pods

Example ServiceMonitor:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
  namespace: my-namespace
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
  - port: metrics
    interval: 30s
```

## Integration with Grafana

Grafana is already deployed in the Loki stack. To add Prometheus datasource, update the Grafana Helm chart configuration in the Loki overlay to include both Loki and Prometheus datasources.

## Documentation

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator)
- [kube-prometheus-stack Helm Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [ServiceMonitor CRD](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api.md#servicemonitor)
- [PrometheusRule CRD](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api.md#prometheusrule)