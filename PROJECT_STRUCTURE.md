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
│
├── deploy/                         # Deployment files
│   ├── Dockerfile                  # Docker image definition
│   ├── docker-compose.yml          # Docker Compose configuration
│   ├── requirements-docker.txt     # Docker-specific dependencies
│   ├── .dockerignore               # Docker ignore rules
│   ├── kubernetes.yml              # Kubernetes deployment config
│   ├── krb5.conf.example           # Kerberos configuration template
│   ├── create-keytab-simple.ps1    # ✅ Keytab creation (recommended)
│   ├── create-keytab.ps1           # Keytab creation (full-featured, needs RSAT)
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

### Deployment

#### Docker
- **`deploy/Dockerfile`** - Builds the Docker image
- **`deploy/docker-compose.yml`** - Orchestrates containers
- **`deploy/requirements-docker.txt`** - Docker-specific Python packages

#### Kerberos/Keytab
- **`deploy/create-keytab-simple.ps1`** - **Recommended** - Simple keytab creation
- **`deploy/create-keytab.ps1`** - Full-featured (requires RSAT tools)
- **`deploy/krb5.conf.example`** - Kerberos configuration template

#### Kubernetes
- **`deploy/kubernetes.yml`** - Kubernetes deployment manifest

### Documentation
- **`README.md`** - Main project documentation
- **`deploy/README.md`** - Deployment overview
- **`deploy/DOCKER_DEPLOYMENT.md`** - Detailed Docker deployment guide
- **`deploy/KEYTAB_GUIDE.md`** - Comprehensive keytab guide
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

# Run application
python app.py
```

### 2. Docker Deployment

#### Step 1: Create Keytab
```powershell
# Run as Administrator
.\deploy\create-keytab-simple.ps1
```

#### Step 2: Deploy
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

- `LDAP_SERVER` - LDAP server address
- `LDAP_BASE_DN` - Base DN for searches
- `KRB5_KTNAME` - Path to keytab file (Docker only)
- `LOG_LEVEL` - Logging level (DEBUG, INFO, WARNING, ERROR)

## Testing

```bash
# Run tests
pytest tests/

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

## Support

For issues or questions:
1. Check the documentation in `docs/` and `deploy/`
2. Review the keytab guide for authentication issues
3. Check logs: `docker-compose logs -f` (Docker) or application logs
