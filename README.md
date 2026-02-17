# Flask LDAP Authentication App

A production-ready Flask application that authenticates users via Kerberos/Windows Authentication and retrieves comprehensive user information from Active Directory LDAP.

## Overview

Enterprise-grade authentication with full LDAP integration:
- ✅ Kerberos/Windows Authentication (SSPI)
- ✅ Complete LDAP user profile retrieval (93 attributes)
- ✅ Connection pooling for high performance
- ✅ Docker and Kubernetes support
- ✅ Comprehensive security (input validation, logging, error handling)
- ✅ Production-ready with unit tests
- ✅ Health monitoring endpoint

**Performance:** ~50 requests/second, supports up to 200 concurrent users

## Deployment Options

### Option 1: Windows IIS (Recommended for Corporate)
- ✅ Automatic Windows Authentication
- ✅ No keytab needed
- ✅ Simplest setup
- ❌ Windows-only

### Option 2: Docker/Kubernetes (Cloud-Ready)
- ✅ Platform-independent (Linux, Windows, macOS)
- ✅ Cloud and Kubernetes ready
- ✅ Highly scalable
- ⚠️ Requires keytab setup

See [`deploy/`](deploy/) for deployment guides.

---

## Quick Start

### Local Development (Windows)

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Configure environment
copy .env.example .env
# Edit .env with your LDAP server details
# Need help? See docs/LDAP_SERVER_DETECTION.md

# 3. Run application
python app.py
```

**Finding Your LDAP Server:**
```powershell
# Quick detection (PowerShell)
$d = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
Write-Host "LDAP_SERVER=ldap://$($d.PdcRoleOwner.Name)"
Write-Host "LDAP_BASE_DN=DC=$($d.Name -replace '\.',',DC=')"
```

See [`docs/LDAP_SERVER_DETECTION.md`](docs/LDAP_SERVER_DETECTION.md) for detailed instructions.

Visit `http://localhost:5000`

### Docker Deployment

```bash
# 1. Create keytab (one-time setup)
.\deploy\create-keytab.ps1

# 2. Deploy
cd deploy
docker-compose up -d
```

See [`deploy/DOCKER_DEPLOYMENT.md`](deploy/DOCKER_DEPLOYMENT.md) for detailed instructions.

---

## Configuration

### Environment Variables

Edit `.env` (copy from `.env.example`):

```bash
# LDAP Server (REQUIRED)
LDAP_SERVER=ldap://your-dc.domain.com
LDAP_BASE_DN=DC=domain,DC=com

# Connection Pool (optional)
LDAP_POOL_SIZE=10
LDAP_POOL_KEEPALIVE=300

# Logging (optional)
LOG_LEVEL=INFO

# Flask (optional)
FLASK_DEBUG=False
```

**Don't know your LDAP server?** See [`docs/LDAP_SERVER_DETECTION.md`](docs/LDAP_SERVER_DETECTION.md)

See [`.env.example`](.env.example) for all available options.

---

## API Endpoints

### `GET /`
Returns basic authenticated user information.

**Response:**
```json
{
  "username": "jdoe",
  "domain": "CORP",
  "authenticated": true
}
```

### `GET /api/user`
Returns detailed user information with **all LDAP attributes** from Active Directory.

**Behavior:**
- **Production (IIS/Docker)**: Gets username from Windows/Kerberos Authentication
- **Development**: Uses current Windows username

**Response:**
```json
{
  "user": {
    "username": "jdoe",
    "domain": "CORP",
    "full_name": "CORP\\jdoe"
  },
  "authenticated": true,
  "auth_type": "Negotiate",
  "ldap_attributes": {
    "sAMAccountName": "jdoe",
    "displayName": "John Doe",
    "mail": "jdoe@company.com",
    "department": "Engineering",
    "title": "Senior Engineer",
    "employeeID": "12345",
    "telephoneNumber": "+1 555-1234",
    "memberOf": ["CN=Group1,...", "CN=Group2,..."],
    ... (93 total attributes)
  }
}
```

### `GET /api/user/<username>`
Returns LDAP information for a specific username.

**Example:** `/api/user/jdoe`

**Response:**
```json
{
  "success": true,
  "username": "jdoe",
  "data": {
    "sAMAccountName": "jdoe",
    "displayName": "John Doe",
    ... (all LDAP attributes)
  }
}
```

### `GET /health`
Health check endpoint for monitoring.

**Response:**
```json
{
  "status": "healthy",
  "ldap_connection": "ok"
}
```

---

## Deployment Guides

### Windows IIS Deployment

1. **Install IIS with Windows Authentication:**
   - Server Manager → Add Roles and Features
   - Install IIS with Windows Authentication module

2. **Install wfastcgi:**
   ```bash
   pip install wfastcgi
   wfastcgi-enable
   ```

3. **Configure IIS:**
   - Create new website/application
   - **Enable Windows Authentication**
   - **Disable Anonymous Authentication**
   - Configure FastCGI to use Python

4. **web.config example:**
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <configuration>
     <system.webServer>
       <handlers>
         <add name="Python FastCGI" path="*" verb="*" 
              modules="FastCgiModule" 
              scriptProcessor="C:\Python\python.exe|C:\Python\Lib\site-packages\wfastcgi.py" 
              resourceType="Unspecified" />
       </handlers>
       <security>
         <authentication>
           <windowsAuthentication enabled="true" />
           <anonymousAuthentication enabled="false" />
         </authentication>
       </security>
     </system.webServer>
   </configuration>
   ```

### Docker Deployment

See [`deploy/DOCKER_DEPLOYMENT.md`](deploy/DOCKER_DEPLOYMENT.md) for complete guide.

**Quick Start:**
```bash
# 1. Create keytab
.\deploy\create-keytab-simple.ps1

# 2. Deploy
cd deploy
docker-compose up -d
```

### Kubernetes Deployment

See [`deploy/kubernetes.yml`](deploy/kubernetes.yml) for manifest.

```bash
# Create keytab secret
kubectl create secret generic kerberos-keytab --from-file=keytab=./app.keytab

# Deploy
kubectl apply -f deploy/kubernetes.yml
```

---

## Testing

```bash
# Run all tests
pytest tests/

# Or using unittest
python -m unittest tests/test_app.py

# With verbose output
python tests/test_app.py
```

**Test Coverage:**
- Username sanitization and validation
- API endpoint responses
- Error handling and HTTP status codes
- Security (SQL/LDAP injection prevention)
- Connection pooling
- JSON response formats

---

## Architecture

### How It Works

#### Windows IIS Deployment
```
User Browser
    │
    ▼
IIS (Windows Authentication)
    │
    ├─ Kerberos/NTLM authentication
    ├─ Sets REMOTE_USER
    │
    ▼
Flask App
    │
    ├─ Reads REMOTE_USER
    ├─ Queries LDAP
    │
    ▼
Active Directory
    │
    └─ Returns user data
```

#### Docker Deployment
```
User Browser
    │
    ▼
Docker Container
    │
    ├─ Reads keytab
    ├─ Gets Kerberos ticket
    ├─ Authenticates to AD
    │
    ▼
Flask App
    │
    ├─ Queries LDAP
    │
    ▼
Active Directory
    │
    └─ Returns user data
```

### Key Components

- **Flask**: Web framework
- **ldap3**: LDAP client library
- **Kerberos**: Authentication protocol (cross-platform)
- **Active Directory**: User directory (LDAP + Kerberos)

---

## Security

### Best Practices

- ✅ Always use HTTPS in production
- ✅ Ensure proper firewall rules
- ✅ Use dedicated service accounts (not personal accounts)
- ✅ Rotate keytabs every 90-180 days
- ✅ Never commit keytabs to version control
- ✅ Use secrets management (Kubernetes secrets, Azure Key Vault)
- ✅ Enable logging and monitoring
- ✅ Validate all user inputs

### Security Features

- Input validation and sanitization
- LDAP injection prevention
- SQL injection prevention (if using database)
- Comprehensive error handling
- Secure logging (no sensitive data)
- Connection pooling with timeouts

---

## Documentation

- **Project Structure**: [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md)
- **LDAP Server Detection**: [`docs/LDAP_SERVER_DETECTION.md`](docs/LDAP_SERVER_DETECTION.md) - **Start here!**
- **Docker Deployment**: [`deploy/DOCKER_DEPLOYMENT.md`](deploy/DOCKER_DEPLOYMENT.md)
- **Keytab Guide**: [`deploy/KEYTAB_GUIDE.md`](deploy/KEYTAB_GUIDE.md)
- **LDAP Attributes**: [`docs/LDAP_ATTRIBUTES.md`](docs/LDAP_ATTRIBUTES.md)
- **Production Readiness**: [`docs/PRODUCTION_READINESS_ASSESSMENT.md`](docs/PRODUCTION_READINESS_ASSESSMENT.md)

---

## Troubleshooting

### Common Issues

**Issue: "No credentials were supplied"**
- **Cause**: Keytab not found or not configured
- **Solution**: Check `KRB5_KTNAME` environment variable and keytab file exists

**Issue: "LDAP connection failed"**
- **Cause**: Cannot reach LDAP server
- **Solution**: Check `LDAP_SERVER` setting and network connectivity

**Issue: "User not found in LDAP"**
- **Cause**: User doesn't exist or wrong base DN
- **Solution**: Verify `LDAP_BASE_DN` and user exists in AD

**Issue: "Clock skew too great"**
- **Cause**: Time difference between container and KDC
- **Solution**: Sync container time with host or use NTP

See [`deploy/KEYTAB_GUIDE.md`](deploy/KEYTAB_GUIDE.md) for more troubleshooting.

---

## Performance

- **Throughput**: ~50 requests/second
- **Concurrent Users**: Up to 200
- **Connection Pooling**: 10 connections (configurable)
- **Keepalive**: 300 seconds (configurable)

### Optimization Tips

1. Increase `LDAP_POOL_SIZE` for high traffic
2. Adjust `LDAP_POOL_KEEPALIVE` based on usage patterns
3. Use production WSGI server (Waitress/Gunicorn)
4. Enable caching for frequently accessed data
5. Monitor with `/health` endpoint

---
## Support

For issues or questions:
1. Check the documentation in [`docs/`](docs/) and [`deploy/`](deploy/)
2. Review the keytab guide for authentication issues
3. Check logs: `docker-compose logs -f` (Docker) or application logs
