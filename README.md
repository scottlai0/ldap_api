# Flask LDAP Authentication App

Flask application that authenticates users via Kerberos/Windows Authentication and retrieves user information from Active Directory over LDAP.

## Overview

The app handles Kerberos/Windows Authentication (SSPI), pulls the full LDAP user profile (93 attributes per user), pools LDAP connections for performance, and ships with input validation, structured error handling, a `/health` monitoring endpoint, and a unit test suite.

**Performance:** ~50 requests/second, supports up to 200 concurrent users.

## Deployment Options

Run it under IIS or in Docker. IIS is the simplest option on Windows: it authenticates the caller via Windows Authentication, so no keytab is needed. Docker runs anywhere (Linux, Windows, macOS, Kubernetes) but Kerberos requires a keytab for the service account.

See [`deploy/`](deploy/) for deployment guides.

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
Returns detailed user information with **all LDAP attributes** from Active Directory. See [`docs/LDAP_ATTRIBUTES.md`](docs/LDAP_ATTRIBUTES.md) for the attribute list.

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
.\deploy\create-keytab.ps1

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

## Testing

```bash
# Run all tests
pytest tests/

# Or using unittest
python -m unittest tests/test_app.py

# With verbose output
python tests/test_app.py
```

Tests cover username sanitization and validation, API endpoint responses, error handling and HTTP status codes, SQL/LDAP injection prevention, connection pooling, and JSON response formats. For a full readiness review (security fixes, test coverage, remaining gaps), see [`docs/PRODUCTION_READINESS_ASSESSMENT.md`](docs/PRODUCTION_READINESS_ASSESSMENT.md).

## Architecture

The request flow differs by deployment mode. Under IIS, the browser authenticates to IIS through Windows Authentication (Kerberos or NTLM); IIS sets `REMOTE_USER`, the Flask app reads it, queries Active Directory over LDAP, and returns the user data. In Docker, the container authenticates itself: it reads a mounted keytab, obtains a Kerberos ticket from the KDC, and uses that ticket to query LDAP.

The layout of the repo is documented in [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md). The stack is Flask for the web layer, ldap3 as the LDAP client, Kerberos for authentication, and Active Directory as the user directory (LDAP + Kerberos).

## Security

### Best Practices

- Always use HTTPS in production
- Ensure proper firewall rules
- Use dedicated service accounts (not personal accounts)
- Rotate keytabs every 90-180 days
- Never commit keytabs to version control
- Use secrets management (Kubernetes secrets, Azure Key Vault)
- Enable logging and monitoring
- Validate all user inputs

### Security Features

- Input validation and sanitization
- LDAP injection prevention
- SQL injection prevention (if using database)
- Comprehensive error handling
- Secure logging (no sensitive data)
- Connection pooling with timeouts

## Troubleshooting

Check the application logs first (`docker-compose logs -f` for Docker). Common issues:

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
