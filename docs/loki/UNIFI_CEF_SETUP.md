# UniFi CEF SIEM Integration Guide for Loki

Complete guide for configuring Loki Stack to accept UniFi logs in CEF (Common Event Format) SIEM format via syslog.

## Prerequisites

- Loki Stack is deployed and accessible
- Grafana is accessible at `https://grafana.dataknife.net`
- Vector syslog receiver is deployed (NodePort 30514)
- UniFi Network Application access (to configure SIEM integration)

## Architecture

```
UniFi Device → Syslog UDP (port 30514) → Vector Receiver → Parse CEF → Loki → Grafana
```

## Step 1: Verify Vector Syslog Receiver

1. **Check Vector Deployment**:
   ```bash
   kubectl get deployment vector-syslog -n managed-syslog
   kubectl get pods -n managed-syslog -l app=vector,component=syslog
   ```

2. **Check Syslog Service**:
   ```bash
   kubectl get svc vector-syslog -n managed-syslog
   # Should show NodePort 30514 for UDP port 514
   ```

3. **Check Vector Logs**:
   ```bash
   kubectl logs -n managed-syslog -l app=vector,component=syslog
   ```

## Step 2: Configure UniFi Network Application

1. **Log in to UniFi Network Application**

2. **Navigate to SIEM Integration**:
   - Go to **Settings** → **System Logs**
   - Scroll to **SIEM Integration** section

3. **Configure Syslog Server**:
   - **Enable SIEM Integration**: ✅ Yes
   - **Syslog Server**: `<node-ip>:30514`
     - Use any cluster node IP (worker nodes recommended)
     - Example: `192.168.14.113:30514`
   - **Format**: **CEF** (Common Event Format)
   - **Protocol**: UDP (default)

4. **Click**: **Apply Changes** or **Save**

## Step 3: Verify Log Ingestion

### Test Syslog Reception

Send a test CEF message to verify Vector is receiving syslog:

```bash
# Get a cluster node IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# Send test CEF message
echo 'CEF:0|Ubiquiti|UniFi|7.4.162|USG|Firewall Test|5|src=192.168.1.100 dst=192.168.1.200 act=block' | \
  nc -u $NODE_IP 30514
```

### Check Vector Logs

```bash
# Check Vector is receiving syslog
kubectl logs -n managed-syslog -l app=vector,component=syslog --tail=50

# Should show parsed CEF messages
```

### Query Logs in Grafana

1. **Log in to Grafana**:
   - URL: `https://grafana.dataknife.net`
   - Username: `admin`
   - Password: From `loki-credentials` secret

2. **Navigate to Explore**:
   - Click **Explore** in the left menu

3. **Query UniFi CEF Logs**:
   ```logql
   # All UniFi CEF logs
   {app="unifi-cef", format="cef"}
   
   # Filter by device vendor
   {app="unifi-cef", device_vendor="Ubiquiti"}
   
   # Filter by severity
   {app="unifi-cef"} | json | severity >= 5
   
   # Search for specific events
   {app="unifi-cef"} |= "Firewall"
   ```

## Step 4: Create Grafana Dashboards

### Basic UniFi CEF Dashboard

1. **Create New Dashboard**:
   - Go to **Dashboards** → **New Dashboard**

2. **Add Panels**:

   **Panel 1: Log Volume Over Time**
   ```logql
   sum(count_over_time({app="unifi-cef"}[5m]))
   ```

   **Panel 2: Logs by Device Product**
   ```logql
   sum by (device_product) (count_over_time({app="unifi-cef"}[5m]))
   ```

   **Panel 3: Logs by Severity**
   ```logql
   sum by (severity) (count_over_time({app="unifi-cef"}[5m]))
   ```

   **Panel 4: Recent UniFi Events**
   ```logql
   {app="unifi-cef"} | json
   ```

## CEF Field Mapping

Vector parses CEF format and extracts the following fields:

- `cef_version`: CEF version (typically "0")
- `device_vendor`: Device vendor (e.g., "Ubiquiti")
- `device_product`: Device product (e.g., "UniFi")
- `device_version`: Device version (e.g., "7.4.162")
- `signature_id`: Event signature ID (e.g., "USG")
- `cef_name`: Event name (e.g., "Firewall")
- `severity`: Severity level (0-10)
- Extension fields: Parsed from CEF extension (e.g., `src`, `dst`, `act`)

## Common CEF Events from UniFi

UniFi sends various event types in CEF format:

- **Authentication Events**: User logins, logouts
- **Network Events**: Device connections, disconnections
- **Firewall Events**: Blocked connections, port scans
- **System Events**: Device status changes, updates

### Example LogQL Queries

```logql
# All authentication events
{app="unifi-cef"} | json | deviceEventClassId="authentication"

# Firewall blocks
{app="unifi-cef"} | json | cef_name="Firewall" AND severity >= 5

# User connections
{app="unifi-cef"} | json | deviceEventClassId="connection"

# High severity events
{app="unifi-cef"} | json | severity >= 7

# Events from specific source IP
{app="unifi-cef"} | json | src="192.168.1.100"
```

## Troubleshooting

### Vector Not Receiving Logs

1. **Check Vector Pod Status**:
   ```bash
   kubectl get pods -n managed-syslog -l app=vector,component=syslog
   kubectl describe pod -n managed-syslog -l app=vector,component=syslog
   ```

2. **Check Vector Logs**:
   ```bash
   kubectl logs -n managed-syslog -l app=vector,component=syslog
   ```

3. **Verify Service**:
   ```bash
   kubectl get svc vector-syslog -n managed-syslog
   kubectl describe svc vector-syslog -n managed-syslog
   ```

4. **Test UDP Port**:
   ```bash
   # From a node, test if port is listening
   nc -u -v localhost 514
   ```

### Logs Not Appearing in Loki

1. **Check Vector Configuration**:
   ```bash
   kubectl get configmap vector-config -n managed-syslog -o yaml
   ```

2. **Verify Loki Endpoint**:
   ```bash
   # Check if Loki service is accessible
   kubectl get svc loki -n managed-syslog
   kubectl port-forward -n managed-syslog svc/loki 3100:3100
   curl http://localhost:3100/ready
   ```

3. **Check Loki Logs**:
   ```bash
   kubectl logs -n managed-syslog -l app=loki
   ```

### Firewall Issues

Ensure firewall rules allow UDP traffic on port 30514:

```bash
# If using firewall, allow UDP port 30514
# Example for UFW:
sudo ufw allow 30514/udp

# Example for firewalld:
sudo firewall-cmd --add-port=30514/udp --permanent
sudo firewall-cmd --reload
```

### CEF Parsing Issues

If CEF fields are not being parsed correctly:

1. **Check Vector Logs** for parsing errors:
   ```bash
   kubectl logs -n managed-syslog -l app=vector,component=syslog | grep -i error
   ```

2. **Verify CEF Format**:
   - UniFi should send CEF format when "Format: CEF" is selected
   - Test with sample message (see Step 3)

3. **Check Raw Messages**:
   ```logql
   # View raw messages before parsing
   {app="unifi-cef"} | line_format "{{.message}}"
   ```

## Node IPs for UniFi Configuration

**Recommended (Worker Nodes):**
- Check with: `kubectl get nodes -o wide`
- Use any worker node InternalIP with port 30514

**Alternative (Control Plane Nodes):**
- Can also use control plane node IPs if needed

## Comparison with Graylog

| Feature | Graylog | Loki + Vector |
|---------|---------|---------------|
| Syslog Input | Built-in | Vector receiver |
| CEF Parsing | Built-in codec | Vector remap transform |
| Query Language | Graylog Query | LogQL |
| Storage | OpenSearch | Loki (more efficient) |
| Visualization | Graylog UI | Grafana |

## Migration from Graylog

When migrating from Graylog:

1. **Deploy Loki Stack** with Vector syslog receiver
2. **Configure UniFi** to point to new NodePort (30514)
3. **Verify Log Ingestion** in Grafana
4. **Export Important Logs** from Graylog before decommissioning
5. **Update Dashboards** to use LogQL instead of Graylog queries

## Documentation

- [Vector Documentation](https://vector.dev/docs/)
- [Vector Syslog Source](https://vector.dev/docs/reference/configuration/sources/syslog/)
- [Vector Remap Transform](https://vector.dev/docs/reference/vrl/)
- [Loki LogQL](https://grafana.com/docs/loki/latest/logql/)
- [UniFi SIEM Integration](https://help.ui.com/hc/en-us/articles/33349041044119-UniFi-System-Logs-SIEM-Integration)
