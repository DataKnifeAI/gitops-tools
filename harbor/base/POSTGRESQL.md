# PostgreSQL Database for Harbor

This directory contains the CloudNativePG PostgreSQL cluster configuration for Harbor.

## Overview

Harbor requires a PostgreSQL database, which is deployed using the [CloudNativePG operator](https://cloudnative-pg.io/docs/1.28/). CloudNativePG provides:

- High Availability with automatic failover
- Connection pooling with PgBouncer
- Automated backups and recovery
- Declarative database management

## Files

- `postgresql-cluster.yaml` - CloudNativePG Cluster resource
- `postgresql-credentials.yaml` - Secret for database credentials
- `postgresql-database.yaml` - Database resource (ensures `registry` database exists)

## Cluster Configuration

The PostgreSQL cluster is configured with:

- **Cluster Name**: `harbor-postgresql`
- **Namespace**: `managed-tools`
- **Instances**: 2 (1 primary + 1 replica for HA)
- **PostgreSQL Version**: 16.2
- **Database Name**: `registry`
- **Database Owner**: `harbor`
- **Storage**: 20Gi (adjustable)
- **Connection Pooling**: Enabled with PgBouncer

## Services Created by CloudNativePG

CloudNativePG automatically creates Kubernetes services:

- `harbor-postgresql-rw` - Read-write service (connects to primary)
- `harbor-postgresql-ro` - Read-only service (connects to replicas)
- `harbor-postgresql-r` - Replica service
- `harbor-postgresql-pooler-rw` - PgBouncer pooler for read-write (if enabled)

Harbor is configured to use `harbor-postgresql-rw` for database connections.

## Credentials

The `harbor-postgresql-credentials` secret contains the password for the `harbor` database owner user.

**Important**: The password in `harbor-postgresql-credentials` must match the `databasePassword` in the `harbor-credentials` secret, as Harbor reads the password from `harbor-credentials`.

### Setting Up Credentials

1. **Update the PostgreSQL credentials secret:**
   ```bash
   # Edit the password in postgresql-credentials.yaml
   # Or create/update the secret directly:
   kubectl create secret generic harbor-postgresql-credentials \
     --from-literal=password='<your-password>' \
     -n managed-tools \
     --dry-run=client -o yaml | kubectl apply -f -
   ```

2. **Ensure Harbor credentials secret has matching password:**
   ```bash
   # The databasePassword must match the password in harbor-postgresql-credentials
   kubectl create secret generic harbor-credentials \
     --from-literal=harborAdminPassword='<harbor-admin-password>' \
     --from-literal=databasePassword='<same-password-as-postgresql>' \
     --from-literal=redisPassword='' \
     -n managed-tools \
     --dry-run=client -o yaml | kubectl apply -f -
   ```

## Deployment

The PostgreSQL cluster is deployed automatically by Fleet along with Harbor:

1. Fleet syncs the GitRepo
2. CloudNativePG operator creates the PostgreSQL cluster
3. Database `registry` is created with owner `harbor`
4. Harbor connects to the database using the `harbor-postgresql-rw` service

## Monitoring

Check cluster status:
```bash
# Check cluster status
kubectl get cluster harbor-postgresql -n managed-tools

# Check cluster details
kubectl describe cluster harbor-postgresql -n managed-tools

# Check pods
kubectl get pods -n managed-tools -l cnpg.io/cluster=harbor-postgresql

# Check services
kubectl get svc -n managed-tools | grep harbor-postgresql

# Check database
kubectl get database registry -n managed-tools
```

## Connection Details

- **Host**: `harbor-postgresql-rw.managed-tools.svc.cluster.local` (or `harbor-postgresql-rw` from same namespace)
- **Port**: `5432`
- **Database**: `registry`
- **Username**: `harbor`
- **Password**: From `harbor-credentials` secret, key `databasePassword`

## High Availability

The cluster is configured with:
- 2 instances (1 primary + 1 replica)
- Synchronous replication (1 sync replica)
- Automatic failover
- Connection pooling with PgBouncer

## Backup and Recovery

CloudNativePG supports:
- Volume snapshots (if storage class supports it)
- WAL archiving
- Point-in-time recovery (PITR)

Configure backups by adding a `Backup` or `ScheduledBackup` resource. See [CloudNativePG Backup documentation](https://cloudnative-pg.io/docs/1.28/backup/) for details.

## Troubleshooting

**Cluster not starting:**
```bash
kubectl describe cluster harbor-postgresql -n managed-tools
kubectl logs -n managed-tools -l cnpg.io/cluster=harbor-postgresql
```

**Connection issues:**
```bash
# Verify service exists
kubectl get svc harbor-postgresql-rw -n managed-tools

# Test connection from a pod
kubectl run -it --rm psql-test --image=postgres:16 --restart=Never -- \
  psql -h harbor-postgresql-rw -U harbor -d registry
```

**Password mismatch:**
- Ensure `harbor-postgresql-credentials.password` matches `harbor-credentials.databasePassword`
- Update both secrets if needed

## References

- [CloudNativePG Documentation](https://cloudnative-pg.io/docs/1.28/)
- [Harbor HA Helm Documentation](https://goharbor.io/docs/1.10/install-config/harbor-ha-helm/)
