# Deployment Guide

This folder contains deployment configurations for the LDAP Authentication application.

## Files

### Core Deployment
- **`Dockerfile`** - Docker image definition
- **`docker-compose.yml`** - Docker Compose configuration
- **`kubernetes.yml`** - Kubernetes deployment manifests
- **`requirements-docker.txt`** - Docker-specific Python dependencies
- **`.dockerignore`** - Files to exclude from Docker build

### Kerberos/Authentication
- **`create-keytab-simple.ps1`** - **Recommended** - Simple keytab creation script
- **`create-keytab.ps1`** - Full-featured keytab creation (requires RSAT)
- **`krb5.conf.example`** - Kerberos configuration template

### Documentation
- **`README.md`** - This file (deployment overview)
- **`DOCKER_DEPLOYMENT.md`** - Complete Docker deployment guide
- **`KEYTAB_GUIDE.md`** - Comprehensive keytab guide

### Testing
- **`test-docker.sh`** - Docker deployment testing script

---

## Quick Start

### Docker Deployment

```bash
# 1. Create keytab (one-time setup)
.\create-keytab-simple.ps1

# 2. Build and run
docker-compose up -d

# 3. Check status
docker-compose ps
docker-compose logs -f
```

### Kubernetes Deployment

```bash
# 1. Create keytab secret
kubectl create secret generic kerberos-keytab --from-file=keytab=./app.keytab

# 2. Deploy
kubectl apply -f kubernetes.yml

# 3. Check status
kubectl get pods -l app=ldap-auth
kubectl logs -l app=ldap-auth -f
```

---

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

1. **Create keytab using the automated script:**
   ```powershell
   # Run as Administrator
   .\create-keytab.ps1
   ```
   
   The script will:
   - Check if RSAT tools are installed
   - Offer to install RSAT automatically if missing
   - Guide you through keytab creation

2. **Configure Kerberos:**
   ```bash
   # Copy and edit krb5.conf
   cp krb5.conf.example krb5.conf
   # Update with your domain details
   ```

3. **Mount in container:**
   - Docker: Already configured in `docker-compose.yml`
   - Kubernetes: Create secret and mount (see `kubernetes.yml`)

See [`KEYTAB_GUIDE.md`](KEYTAB_GUIDE.md) for detailed instructions.

---

## Health Checks

All deployments include health checks on `/health` endpoint:

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

---

## Scaling

### Docker Compose

```bash
# Scale to 3 instances
docker-compose up -d --scale ldap-auth=3
```

### Kubernetes

```bash
# Manual scaling
kubectl scale deployment ldap-auth --replicas=5

# Auto-scaling (HPA included in kubernetes.yml)
kubectl get hpa ldap-auth-hpa
```

---

## Monitoring

### Logs

**Docker:**
```bash
docker-compose logs -f ldap-auth
```

**Kubernetes:**
```bash
kubectl logs -l app=ldap-auth -f
```

### Metrics

Access endpoints:
- Health: `http://localhost:5000/health`
- User API: `http://localhost:5000/api/user`

---

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

See [`KEYTAB_GUIDE.md`](KEYTAB_GUIDE.md) for more troubleshooting.

---

## Production Checklist

### Configuration
- [ ] Set `FLASK_DEBUG=False`
- [ ] Configure proper LDAP server
- [ ] Set up Kerberos keytab
- [ ] Configure resource limits
- [ ] Set appropriate pool size

### Security
- [ ] Use HTTPS/TLS (via reverse proxy)
- [ ] Rotate keytabs every 90-180 days
- [ ] Store keytabs in secrets management
- [ ] Never commit keytabs to version control
- [ ] Set proper file permissions (600)

### Monitoring
- [ ] Set up monitoring/alerting
- [ ] Configure logging aggregation
- [ ] Test health checks
- [ ] Set up backup/recovery

### Testing
- [ ] Load test the application
- [ ] Test failover scenarios
- [ ] Verify LDAP connectivity
- [ ] Test Kerberos authentication

---

## Security Best Practices

### Container Security
- ✅ Non-root user in container
- ✅ Read-only volumes for configs
- ✅ Resource limits configured
- ✅ Health checks enabled
- ✅ Minimal base image (Python slim)

### Kerberos Security
- ✅ Dedicated service account
- ✅ Keytab stored in secrets
- ✅ Read-only keytab mount
- ⚠️ Rotate keytabs regularly (90-180 days)
- ⚠️ Never commit keytabs to git

### Network Security
- ⚠️ Use HTTPS in production (reverse proxy)
- ⚠️ Configure proper firewall rules
- ⚠️ Limit LDAP access to necessary ports

---

## Documentation

For detailed information, see:

- **[`DOCKER_DEPLOYMENT.md`](DOCKER_DEPLOYMENT.md)** - Complete Docker deployment guide
- **[`KEYTAB_GUIDE.md`](KEYTAB_GUIDE.md)** - Keytab creation and troubleshooting
- **[`../docs/PRODUCTION_READINESS_ASSESSMENT.md`](../docs/PRODUCTION_READINESS_ASSESSMENT.md)** - Production readiness checklist
- **[`../README.md`](../README.md)** - Application documentation
- **[`../PROJECT_STRUCTURE.md`](../PROJECT_STRUCTURE.md)** - Project structure overview

---

## Support

For issues or questions:
1. Check the documentation above
2. Review logs: `docker-compose logs -f` or `kubectl logs -f`
3. Test health endpoint: `curl http://localhost:5000/health`
4. See [`KEYTAB_GUIDE.md`](KEYTAB_GUIDE.md) for authentication issues
