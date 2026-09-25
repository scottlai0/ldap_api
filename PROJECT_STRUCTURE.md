# Project Structure

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
│   ├── LDAP_SERVER_DETECTION.md    # LDAP server detection guide
│   ├── LDAP_ATTRIBUTES.md          # LDAP attribute reference
│   └── PRODUCTION_READINESS_ASSESSMENT.md  # Production checklist
│
└── tests/                          # Test files
    └── test_app.py                 # Application tests
```

## Key Files

`app.py` is the entire application — a single Flask file that handles LDAP authentication. Dependencies are split between `requirements.txt` for local installs and `deploy/requirements-docker.txt` for the Docker image.

`deploy/create-keytab.ps1` automates keytab creation on Windows: it checks for the RSAT tools, offers to install them if missing, and writes the keytab file. The manual process is documented in `deploy/KEYTAB_GUIDE.md`.

Two files are templates meant to be copied before use: `.env.example` to `.env`, and `deploy/krb5.conf.example` to `deploy/krb5.conf`. The copied files hold your real settings and are gitignored.

If you don't know your LDAP server, start with `docs/LDAP_SERVER_DETECTION.md`.

## Quick Start

**Local development (Windows):**

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

**Docker deployment:**

Create the keytab (run as Administrator):

```powershell
.\deploy\create-keytab.ps1
```

The script checks for the RSAT tools, offers to install them if missing, and creates the keytab file.

Configure Kerberos — copy the template and edit it with your domain details:

```bash
# Copy and edit krb5.conf
cp deploy/krb5.conf.example deploy/krb5.conf
# Edit with your domain details
```

Deploy:

```bash
cd deploy
docker-compose up -d
```

See [`deploy/DOCKER_DEPLOYMENT.md`](deploy/DOCKER_DEPLOYMENT.md) for details.

**Kubernetes deployment:**

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

For a running Docker deployment, tail the logs with `docker-compose logs -f` (from `deploy/`).

## Security Notes

Files that stay out of git:

- `.env` - Your actual LDAP configuration
- `deploy/krb5.conf` - Your actual Kerberos configuration
- `*.keytab` - Authentication credentials
- `*.log` - Log files

Best practices:

- Never commit `.env` or `krb5.conf` to version control
- Never commit `*.keytab` files
- Use dedicated service accounts (not personal accounts)
- Rotate keytabs every 90-180 days
- Use secrets management in production (Kubernetes secrets, Azure Key Vault)
