# Project Structure

## Overview
LDAP Authentication App with Kerberos support for Windows and Docker deployments.

## File Structure

```
.
├── app.py                          # Main Flask application
├── requirements.txt                # Python dependencies
├── .env.example                    # Environment variables template
├── .gitignore                      # Git ignore rules
├── README.md                       # Project documentation
├── PROJECT_STRUCTURE.md            # This file
│
├── deploy/                         # Deployment files
│   ├── Dockerfile                  # Docker image definition
│   ├── docker-compose.yml          # Docker Compose configuration
│   ├── requirements-docker.txt     # Docker-specific dependencies
│   ├── .dockerignore               # Docker ignore rules
│   ├── kubernetes.yml              # Kubernetes deployment config
│   ├── krb5.conf.example           # Kerberos configuration template
│   ├── create-keytab.ps1           # Automated keytab creation script
│   ├── test-docker.sh              # Docker testing script
│   ├── README.md                   # Deployment overview
│   ├── DOCKER_DEPLOYMENT.md        # Docker deployment guide
│   └── KEYTAB_GUIDE.md             # Keytab creation and usage guide
│
├── docs/                           # Documentation
│   ├── LDAP_SERVER_DETECTION.md    # 📖 LDAP server detection guide
│   ├── LDAP_ATTRIBUTES.md          # LDAP attribute reference
│   └── PRODUCTION_READINESS_ASSESSMENT.md  # Production checklist
│
└── tests/                          # Test files
    └── test_app.py                 # Application tests
```

## Key Files

### Application
- **`app.py`** - Main Flask application with LDAP authentication
- **`requirements.txt`** - Python dependencies (Flask, ldap3, etc.)

### Configuration
- **`.env.example`** - Template for environment variables
  - Copy to `.env` and configure for your environment
  - `.env` is in `.gitignore` (not committed)

### Deployment

#### Docker
- **`deploy/Dockerfile`** - Builds the Docker image
- **`deploy/docker-compose.yml`** - Orchestrates containers
- **`deploy/requirements-docker.txt`** - Docker-specific Python packages

#### Kerberos/Keytab
- **`deploy/create-keytab.ps1`** - **Automated keytab creation**
  - Checks for RSAT tools
  - Offers to install RSAT automatically
  - Creates keytab file
- **`deploy/krb5.conf.example`** - Kerberos configuration template
  - Copy to `krb5.conf` and configure
  - `krb5.conf` is in `.gitignore` (not committed)

#### Kubernetes
- **`deploy/kubernetes.yml`** - Kubernetes deployment manifest

### Documentation
- **`README.md`** - Main project documentation
- **`PROJECT_STRUCTURE.md`** - This file
- **`deploy/README.md`** - Deployment overview
- **`deploy/DOCKER_DEPLOYMENT.md`** - Detailed Docker deployment guide
- **`deploy/KEYTAB_GUIDE.md`** - Comprehensive keytab guide
- **`docs/LDAP_SERVER_DETECTION.md`** - 📖 **Start here!** Find your LDAP server
- **`docs/LDAP_ATTRIBUTES.md`** - LDAP attribute reference
- **`docs/PRODUCTION_READINESS_ASSESSMENT.md`** - Production checklist

## Quick Start

### 1. Local Development (Windows)
```bash
# Install dependencies
pip install -r requirements.txt

# Configure environment
copy .env.example .env
# Edit .env with your settings
# Need help? See docs/LDAP_SERVER_DETECTION.md

# Run application
python app.py
```

### 2. Docker Deployment

#### Step 1: Create Keytab
```powershell
# Run as Administrator
.\deploy\create-keytab.ps1
```

The script will automatically:
- Check if RSAT tools are installed
- Offer to install RSAT if missing
- Create the keytab file

#### Step 2: Configure Kerberos
```bash
# Copy and edit krb5.conf
cp deploy/krb5.conf.example deploy/krb5.conf
# Edit with your domain details
```

#### Step 3: Deploy
```bash
cd deploy
docker-compose up -d
```

See [`deploy/DOCKER_DEPLOYMENT.md`](deploy/DOCKER_DEPLOYMENT.md) for details.

### 3. Kubernetes Deployment
```bash
# Create keytab secret
kubectl create secret generic kerberos-keytab --from-file=keytab=./app.keytab

# Deploy
kubectl apply -f deploy/kubernetes.yml
```

## Environment Variables

See [`.env.example`](.env.example) for all available configuration options:

**Required:**
- `LDAP_SERVER` - LDAP server address
- `LDAP_BASE_DN` - Base DN for searches

**Optional:**
- `LDAP_POOL_SIZE` - Connection pool size (default: 10)
- `LDAP_POOL_KEEPALIVE` - Connection lifetime (default: 300s)
- `LOG_LEVEL` - Logging level (default: INFO)
- `FLASK_DEBUG` - Debug mode (default: False)

**Don't know your LDAP server?** See [`docs/LDAP_SERVER_DETECTION.md`](docs/LDAP_SERVER_DETECTION.md)

## Testing

```bash
# Run tests
pytest tests/

# Or using unittest
python -m unittest tests/test_app.py

# Test Docker deployment
cd deploy
./test-docker.sh
```

## Documentation

### Getting Started
- **[`README.md`](README.md)** - Main project documentation
- **[`docs/LDAP_SERVER_DETECTION.md`](docs/LDAP_SERVER_DETECTION.md)** - 📖 **Start here!** Find your LDAP server

### Deployment
- **[`deploy/README.md`](deploy/README.md)** - Deployment overview
- **[`deploy/DOCKER_DEPLOYMENT.md`](deploy/DOCKER_DEPLOYMENT.md)** - Complete Docker guide
- **[`deploy/KEYTAB_GUIDE.md`](deploy/KEYTAB_GUIDE.md)** - Keytab creation and usage

### Reference
- **[`docs/LDAP_ATTRIBUTES.md`](docs/LDAP_ATTRIBUTES.md)** - LDAP attribute reference
- **[`docs/PRODUCTION_READINESS_ASSESSMENT.md`](docs/PRODUCTION_READINESS_ASSESSMENT.md)** - Production checklist

## Security Notes

### Files in `.gitignore` (Not Committed)
- `.env` - Your actual LDAP configuration
- `deploy/krb5.conf` - Your actual Kerberos configuration
- `*.keytab` - Authentication credentials
- `*.log` - Log files

### Best Practices
- ✅ Never commit `.env` or `krb5.conf` to version control
- ✅ Never commit `*.keytab` files
- ✅ Use dedicated service accounts (not personal accounts)
- ✅ Rotate keytabs every 90-180 days
- ✅ Use secrets management in production (Kubernetes secrets, Azure Key Vault)

## Support

For issues or questions:
1. Check the documentation in [`docs/`](docs/) and [`deploy/`](deploy/)
2. Review the keytab guide for authentication issues
3. Check logs: `docker-compose logs -f` (Docker) or application logs
