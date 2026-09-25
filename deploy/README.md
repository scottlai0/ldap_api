# Deployment Guide

This folder contains deployment configurations for the LDAP Authentication application.

## Files

**Core deployment**
- **`Dockerfile`** - Docker image definition
- **`docker-compose.yml`** - Docker Compose configuration
- **`kubernetes.yml`** - Kubernetes deployment manifests
- **`requirements-docker.txt`** - Docker-specific Python dependencies
- **`.dockerignore`** - Files to exclude from Docker build

**Kerberos/authentication**
- **`create-keytab.ps1`** - Automated keytab creation (offers to install RSAT if missing)
- **`krb5.conf.example`** - Kerberos configuration template

**Testing**
- **`test-docker.sh`** - Docker deployment testing script

## Quick Start

**Docker:**

```bash
# 1. Create keytab (one-time setup)
.\create-keytab.ps1

# 2. Build and run
docker-compose up -d

# 3. Check status
docker-compose ps
docker-compose logs -f
```

**Kubernetes:**

```bash
# 1. Create keytab secret
kubectl create secret generic kerberos-keytab --from-file=keytab=./app.keytab

# 2. Deploy
kubectl apply -f kubernetes.yml

# 3. Check status
kubectl get pods -l app=ldap-auth
kubectl logs -l app=ldap-auth -f
```

## Configuration

### Environment Variables

Set these in `docker-compose.yml` or Kubernetes ConfigMap:

```bash
# Required
LDAP_SERVER=ldap://dc.domain.com
LDAP_BASE_DN=DC=domain,DC=com

# Optional (with defaults)
LDAP_POOL_SIZE=10
LDAP_POOL_KEEPALIVE=300
LOG_LEVEL=INFO
FLASK_DEBUG=False
```

### Kerberos Setup

**For Docker/Kubernetes deployments, you MUST create a keytab:**

1. **Create the keytab with the automated script** (run as Administrator):
   ```powershell
   .\create-keytab.ps1
   ```

   The script checks whether the RSAT tools are installed, offers to install them if missing, and walks you through keytab creation.

2. **Configure Kerberos:**
   ```bash
   # Copy and edit krb5.conf
   cp krb5.conf.example krb5.conf
   # Update with your domain details
   ```

3. **Mount it in the container.** Docker Compose is already configured in `docker-compose.yml`; for Kubernetes, create a secret and mount it (see `kubernetes.yml`).

See [`KEYTAB_GUIDE.md`](KEYTAB_GUIDE.md) for detailed instructions.

## Health Checks

All deployments include health checks on the `/health` endpoint:

```bash
# Test health
curl http://localhost:5000/health
```

Expected response:

```json
{
  "status": "healthy",
  "ldap_connection": "ok"
}
```

## Scaling

**Docker Compose:**

```bash
# Scale to 3 instances
docker-compose up -d --scale ldap-auth=3
```

**Kubernetes:**

```bash
# Manual scaling
kubectl scale deployment ldap-auth --replicas=5

# Auto-scaling (HPA included in kubernetes.yml)
kubectl get hpa ldap-auth-hpa
```

## Monitoring

**Logs**

Docker:
```bash
docker-compose logs -f ldap-auth
```

Kubernetes:
```bash
kubectl logs -l app=ldap-auth -f
```

**Metrics**

Watch the health endpoint (`http://localhost:5000/health`) and the user API (`http://localhost:5000/api/user`).

## Troubleshooting

### Container won't start

```bash
# Check logs
docker-compose logs ldap-auth

# Verify environment variables
docker exec ldap-auth env | grep LDAP
```

### LDAP connection fails

```bash
# Test LDAP connectivity
docker exec ldap-auth curl http://localhost:5000/health

# Check Kerberos configuration
docker exec ldap-auth cat /etc/krb5.conf

# Verify keytab
docker exec ldap-auth klist -k -t /app/keytab
```

### Kerberos authentication fails

```bash
# Test Kerberos ticket
docker exec ldap-auth kinit -kt /app/keytab HTTP/hostname@DOMAIN.COM
docker exec ldap-auth klist

# Check time sync (clock skew)
docker exec ldap-auth date
```

### Performance issues

```bash
# Check resource usage
docker stats ldap-auth

# Increase pool size
# Edit docker-compose.yml: LDAP_POOL_SIZE=20
docker-compose up -d
```

More detail in [`DOCKER_DEPLOYMENT.md`](DOCKER_DEPLOYMENT.md) (Docker) and [`KEYTAB_GUIDE.md`](KEYTAB_GUIDE.md) (Kerberos and authentication).

## Production Checklist

**Configuration**
- [ ] Set `FLASK_DEBUG=False`
- [ ] Configure proper LDAP server
- [ ] Set up Kerberos keytab
- [ ] Configure resource limits
- [ ] Set appropriate pool size

**Security**
- [ ] Use HTTPS/TLS (via reverse proxy)
- [ ] Rotate keytabs every 90-180 days
- [ ] Store keytabs in secrets management
- [ ] Never commit keytabs to version control
- [ ] Set proper file permissions (600)

**Monitoring**
- [ ] Set up monitoring/alerting
- [ ] Configure logging aggregation
- [ ] Test health checks
- [ ] Set up backup/recovery

**Testing**
- [ ] Load test the application
- [ ] Test failover scenarios
- [ ] Verify LDAP connectivity
- [ ] Test Kerberos authentication

## Security Best Practices

The configs in this folder already handle the container basics: non-root user, read-only volumes for configs, resource limits, health checks, and a minimal Python slim base image.

For Kerberos, use a dedicated service account, store the keytab in secrets management, and mount it read-only. Rotating the keytab every 90-180 days and keeping it out of git is on you.

On the network side, terminate HTTPS at a reverse proxy in production, configure proper firewall rules, and limit LDAP access to the necessary ports.
