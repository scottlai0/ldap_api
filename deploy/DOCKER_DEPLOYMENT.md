# Docker Deployment

The app runs fine in Docker. The one thing that doesn't work out of the box is Windows Authentication: the container isn't domain-joined, so Kerberos authentication needs a keytab file instead of the machine's own credentials. LDAP queries, connection pooling, and the API endpoints work as-is.

## Quick Start

**Basic deployment (no Kerberos)** — fine for local development:

```bash
# 1. Build and run
cd deploy
docker-compose up -d

# 2. Test
curl http://localhost:5000/
```

**Full deployment (with Kerberos):**

```bash
# 1. Create keytab
.\deploy\create-keytab.ps1

# 2. Create krb5.conf
cp deploy/krb5.conf.example deploy/krb5.conf
# Edit deploy/krb5.conf with your domain details

# 3. Move keytab
mv app.keytab deploy/app.keytab

# 4. Uncomment volumes in docker-compose.yml
# Edit deploy/docker-compose.yml:
#   volumes:
#     - ./krb5.conf:/etc/krb5.conf:ro
#     - ./app.keytab:/app/keytab:ro

# 5. Deploy
cd deploy
docker-compose up -d

# 6. Test
curl http://localhost:5000/health
```

Details on each step are in the Windows Authentication section below.

## Image and Compose File

The Dockerfile installs the Kerberos client libraries, copies the app, and runs it under Gunicorn:

```dockerfile
FROM python:3.12-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    libkrb5-dev \
    krb5-user \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install production WSGI server
RUN pip install gunicorn

# Copy application files
COPY app.py .
COPY .env .

# Expose port
EXPOSE 5000

# Run with Gunicorn
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "app:app"]
```

```yaml
version: '3.8'

services:
  ldap-auth:
    build: .
    ports:
      - "5000:5000"
    environment:
      - LDAP_SERVER=ldap://your-dc.domain.com
      - LDAP_BASE_DN=DC=domain,DC=com
      - LDAP_POOL_SIZE=10
      - LDAP_POOL_KEEPALIVE=300
      - FLASK_DEBUG=False
    volumes:
      - ./krb5.conf:/etc/krb5.conf:ro  # Kerberos configuration
      - ./keytab:/app/keytab:ro        # Kerberos keytab (if using)
    networks:
      - corporate-network
    restart: unless-stopped

networks:
  corporate-network:
    driver: bridge
```

Build and run:

```bash
# Build the image
docker build -t ldap-auth-app .

# Run the container
docker run -d \
  -p 5000:5000 \
  -e LDAP_SERVER=ldap://dc.domain.com \
  -e LDAP_BASE_DN=DC=domain,DC=com \
  --name ldap-auth \
  ldap-auth-app

# Or use docker-compose
docker-compose up -d
```

## Windows Authentication in Docker

Windows Authentication (SSPI/Kerberos) needs a domain-joined machine or a Kerberos keytab file. A container is neither, so there are three ways to handle it.

**Kerberos keytab (recommended for Docker).** This is the only option that gives real Windows Authentication without joining anything to the domain.

Step 1 — create a service account if you don't have one. See [`KEYTAB_GUIDE.md`](KEYTAB_GUIDE.md) for detailed instructions. Quick method:

```powershell
# On Domain Controller or with AD tools
New-ADUser -Name "svc-ldap-app" `
           -UserPrincipalName "svc-ldap-app@domain.com" `
           -AccountPassword (Read-Host -AsSecureString) `
           -Enabled $true `
           -PasswordNeverExpires $true
```

Step 2 — generate the keytab. Use the automated script:

```powershell
# Run as Administrator
.\deploy\create-keytab.ps1
```

The script checks for RSAT tools and offers to install them if missing. Or create it manually:

```powershell
# On domain-joined Windows machine
ktpass -princ HTTP/ldap-app.domain.com@DOMAIN.COM `
       -mapuser svc-ldap-app@domain.com `
       -pass "YourPassword" `
       -out app.keytab `
       -ptype KRB5_NT_PRINCIPAL `
       -crypto AES256-SHA1
```

Step 3 — create the Kerberos configuration. Copy the example and edit it with your domain details:

```bash
# Copy the example file
cp deploy/krb5.conf.example deploy/krb5.conf
```

```ini
[libdefaults]
    default_realm = YOURDOMAIN.COM
    dns_lookup_realm = false
    dns_lookup_kdc = true
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true

[realms]
    YOURDOMAIN.COM = {
        kdc = dc01.yourdomain.com
        admin_server = dc01.yourdomain.com
        default_domain = yourdomain.com
    }

[domain_realm]
    .yourdomain.com = YOURDOMAIN.COM
    yourdomain.com = YOURDOMAIN.COM
```

Replace:
- `YOURDOMAIN.COM` → Your domain in uppercase (e.g., `COMPANY.COM`)
- `yourdomain.com` → Your domain in lowercase (e.g., `company.com`)
- `dc01.yourdomain.com` → Your domain controller hostname

To detect these values automatically (PowerShell):

```powershell
# Get your domain information
$domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
Write-Host "Domain (uppercase): $($domain.Name.ToUpper())"
Write-Host "Domain (lowercase): $($domain.Name)"
Write-Host "Domain Controller: $($domain.PdcRoleOwner.Name)"
```

Step 4 — move the keytab into the deploy folder:

```bash
# Move keytab to deploy folder
mv app.keytab deploy/app.keytab
```

Step 5 — uncomment the volume mounts in `deploy/docker-compose.yml`:

```yaml
volumes:
  - ./krb5.conf:/etc/krb5.conf:ro
  - ./app.keytab:/app/keytab:ro
```

Step 6 — point the app at the keytab by adding this to the environment section of `docker-compose.yml`:

```yaml
environment:
  - KRB5_KTNAME=/app/keytab
```

**Domain-join the Docker host.** The host must be domain-joined and the container runs with host networking. More complex overall:

```bash
docker run -d \
  --network host \
  -e LDAP_SERVER=ldap://dc.domain.com \
  ldap-auth-app
```

**Skip Windows auth (development only).** In development the app falls back to the current user:

```python
# In development mode, automatically uses current Windows user
username = getpass.getuser()
```

This runs in Docker but provides no actual authentication.

## Comparison: Docker vs IIS

LDAP queries and connection pooling behave the same in both. The differences are around Windows Authentication and infrastructure. IIS has native Windows Authentication with no extra configuration and fits corporate infrastructure directly, but it only runs on Windows and is harder to scale out. Docker runs anywhere and scales easily with Kubernetes, but Windows Authentication requires a keytab and krb5.conf, and corporate integration takes configuration work.

For a corporate intranet that relies on Windows Authentication, IIS is the simpler choice. Docker is a viable production option once Kerberos is configured, and it is the better fit when you need containerization, Kubernetes or cloud deployment, or multi-platform support. For development and testing, use Docker — it is easier to set up and doesn't touch AD.

## Production Deployment with Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ldap-auth
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ldap-auth
  template:
    metadata:
      labels:
        app: ldap-auth
    spec:
      containers:
      - name: ldap-auth
        image: ldap-auth-app:latest
        ports:
        - containerPort: 5000
        env:
        - name: LDAP_SERVER
          valueFrom:
            configMapKeyRef:
              name: ldap-config
              key: server
        - name: LDAP_BASE_DN
          valueFrom:
            configMapKeyRef:
              name: ldap-config
              key: base_dn
        volumeMounts:
        - name: krb5-config
          mountPath: /etc/krb5.conf
          subPath: krb5.conf
        - name: keytab
          mountPath: /app/keytab
          subPath: keytab
      volumes:
      - name: krb5-config
        configMap:
          name: krb5-config
      - name: keytab
        secret:
          secretName: kerberos-keytab
---
apiVersion: v1
kind: Service
metadata:
  name: ldap-auth-service
spec:
  selector:
    app: ldap-auth
  ports:
  - protocol: TCP
    port: 80
    targetPort: 5000
  type: LoadBalancer
```

## Health Checks in Docker

The `/health` endpoint works in Docker:

```yaml
# docker-compose.yml
services:
  ldap-auth:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

## Environment Variables in Docker

**From a .env file:**

```bash
docker run --env-file .env -p 5000:5000 ldap-auth-app
```

**Via docker-compose:**

```yaml
services:
  ldap-auth:
    env_file:
      - .env
```

**Using secrets (production):**

```yaml
services:
  ldap-auth:
    environment:
      - LDAP_SERVER=${LDAP_SERVER}
      - LDAP_BASE_DN=${LDAP_BASE_DN}
    secrets:
      - ldap_credentials
```

## Performance in Docker

Docker matches IIS once connection pooling is enabled, and uses a bit less memory:

| Metric | Docker | IIS |
|--------|--------|-----|
| Requests/sec | ~50 | ~50 |
| Response Time | 200-300ms | 200-300ms |
| Memory Usage | ~100MB | ~150MB |
| CPU Usage | Low | Low |
