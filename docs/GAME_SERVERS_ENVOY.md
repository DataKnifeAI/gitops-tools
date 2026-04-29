# Game servers: Envoy Gateway + kube-vip (prd-apps)

Satisfactory and Windrose use **fixed game ports** (7777 TCP/UDP, plus Satisfactory **7778 TCP** and optional Windrose **8780 TCP**). Envoy Gateway on **prd-apps** exposes them via **Gateway API** (`Gateway`, `TCPRoute`, `UDPRoute`) with **kube-vip** assigning a **LoadBalancer VIP per Gateway** (same pattern as `high-command-gateway`).

### kube-vip bind (EnvoyProxy + `loadBalancerIP`)

For `Gateway.spec.addresses` with **TCP and UDP** listeners, Envoy Gateway can materialize the Envoy `Service` using **`spec.externalIPs` only**, which **kube-vip does not ARP-bind** on the node. To get **`status.loadBalancer.ingress`** (so kube-vip programs **`spec.loadBalancerIP`** and binds on **`eth0`**), each game `Gateway` references a namespaced **`EnvoyProxy`** via **`spec.infrastructure.parametersRef`** that sets `provider.kubernetes.envoyService.loadBalancerIP` to the same VIP and **`externalTrafficPolicy: Cluster`** (Envoy pods may run on workers while kube-vip holds the VIP on control-plane nodes). See `envoyproxy-satisfactory.yaml` and `envoyproxy-windrose.yaml` in this overlay.

## Hostnames and DNS

Use these FQDNs (correct spelling **`satisfactory`**, not `satifactory`):

| Hostname | Points to | Ports (client) |
|----------|-------------|----------------|
| `satisfactory.dataknife.net` | VIP of `Gateway/satisfactory-gateway` | **7777 UDP**, **7777 TCP**, **7778 TCP** |
| `windrose.dataknife.net` | VIP of `Gateway/windrose-gateway` | **7777 TCP**, **7777 UDP**, **8780 TCP** (Windrose+ dashboard) |

**DNS:** create **A** (or **AAAA**) records for each hostname to the **Gateway VIP** (requested in `Gateway.spec.addresses` for kube-vip on prd-apps):

| Hostname | Requested VIP |
|----------|----------------|
| `satisfactory.dataknife.net` | `192.168.14.185` |
| `windrose.dataknife.net` | `192.168.14.186` |

Confirm programmed addresses after apply:

```bash
kubectl --context prd-apps get gateway -n game-servers \
  satisfactory-gateway windrose-gateway \
  -o custom-columns=NAME:.metadata.name,ADDRESS:.status.addresses[0].value,PROG:.status.conditions[?\(@.type==\"Programmed\"\)].status
```

Adjust the IPs if they collide with another workload; they must fall inside the **kube-vip** `range-global` ConfigMap (`kube-vip` namespace, key `range-global`).

Two hostnames require **two VIPs** because both games use **TCP 7777**; a single Gateway cannot attach two TCP listeners on the same port.

**Note:** UDP does not carry HTTP `Host` headers; clients typically connect by **IP or DNS name** that resolves to the VIP. TCP game traffic is the same unless you add TLS.

## GitOps layout

Fleet path: `game-servers-exposure/overlays/prd-apps` (see `fleet-gitrepo-prd-apps.yaml`).

- **`satisfactory-server-envoy` / `windrose-server-envoy`**: **ClusterIP** `Service`s with the same selectors as the game Deployments. Envoy routes to these (avoid relying on the original `LoadBalancer` Services, which may stay `<pending>` without MetalLB).
- **`Gateway` + `TCPRoute` / `UDPRoute`**: attach to `GatewayClass` **`envoy`** (`gateway.envoyproxy.io/gatewayclass-controller`).

## Verification

```bash
kubectl --context prd-apps describe gateway satisfactory-gateway -n game-servers
kubectl --context prd-apps describe gateway windrose-gateway -n game-servers
kubectl --context prd-apps get svc -n envoy-gateway-system | grep game-servers
```

Listeners should show **Programmed**; Envoy should create `Service` resources of type **LoadBalancer** with **`EXTERNAL-IP`** set by kube-vip.

## Firewall

Allow the two VIPs (or the whole kube-vip pool range) for **UDP+TCP 7777**, **TCP 7778**, **TCP 8780** from your LAN or VPN as needed.
