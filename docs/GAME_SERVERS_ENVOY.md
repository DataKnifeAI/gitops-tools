# Game servers: Envoy Gateway + kube-vip (moved to game repos)

Satisfactory and Windrose **Envoy Gateway** manifests (**`Gateway`**, **`EnvoyProxy`**, **`TCPRoute`/`UDPRoute`**, ClusterIP backend `Service`s) are maintained **in each game repository** under **`deploy/envoy/`**, not in this GitOps repo. Apply manually when needed, for example:

```bash
kubectl apply -k deploy/envoy/
```

(from a clone of **`DataKnifeAI/satisfactory-server-k8s`** or **`DataKnifeAI/windrose-server-k8s`**, after `kubectl apply -k deploy/` or your overlay for the workload).

## DNS and ports (DataKnife reference)

| Hostname | Example VIP | Client ports |
|----------|-------------|----------------|
| `satisfactory.dataknife.net` | `192.168.14.185` (edit in repo) | **7777** UDP+TCP, **7778** TCP |
| `windrose.dataknife.net` | `192.168.14.186` (edit in repo) | **7777** TCP+UDP, **8780** TCP (Windrose+) |

VIP addresses must sit inside the cluster **kube-vip** pool (`kube-vip` namespace, ConfigMap **`kubevip`**, key **`range-global`**).

## kube-vip note

For **TCP+UDP** `Gateway` resources, use a per-Gateway **`EnvoyProxy`** with **`loadBalancerIP`** matching **`Gateway.spec.addresses`** and **`externalTrafficPolicy: Cluster`** so kube-vip fills **`status.loadBalancer.ingress`** (L2 bind on `eth0`), not **`externalIPs`-only**. See **`docs/KUBERNETES.md`** in each game repo.

## Firewall

Allow the VIPs (or the kube-vip pool) for **UDP+TCP 7777**, **TCP 7778**, **TCP 8780** as needed.
