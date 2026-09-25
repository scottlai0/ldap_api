# Kerberos Keytab Guide

## Quick Start

You need two things: an Active Directory service account (e.g., `svc-ldap-app@domain.com`) and a Windows machine where you have administrator rights. The service account must already exist — see Creating a Keytab below if you need to create one.

```powershell
# 1. Open PowerShell as Administrator
# 2. Run the script
.\deploy\create-keytab.ps1
```

The script checks for RSAT tools and offers to install them if they're missing, detects your domain, verifies the service account exists, prompts for its password, generates `app.keytab`, and sets secure permissions on it.

## What is a Keytab?

A **keytab** (key table) is a file containing pairs of Kerberos principals and encrypted keys — essentially a password file that lets an application authenticate to Kerberos without interactive password entry. Think of it as the service account's password, stored in a form an app can use unattended.

## Why Do You Need It for Docker?

On IIS, the Windows host is domain-joined, so Windows negotiates Kerberos with your logged-in credentials and no keytab is involved. A Linux container is not domain-joined and has none of those credentials, so it cannot authenticate to Active Directory by itself. The keytab closes that gap: at runtime the container reads the keytab, uses the encrypted key to request a ticket from the KDC (a domain controller), and presents that ticket to the LDAP server. Because the file effectively is the password, treat it as a credential everywhere it goes.

Which deployment to use:

- **Corporate production** — IIS. No keytab needed.
- **Cloud / Kubernetes production** — Docker with a mounted keytab.
- **Development** — Docker with Kerberos skipped (see Skipping Kerberos below).

## Creating a Keytab

**Automated script (recommended).** `deploy/create-keytab.ps1` does the whole job: it checks for RSAT tools and offers to install them, detects the domain, verifies the service account exists, generates the keytab with proper encryption, sets secure permissions, and prints next steps for the Docker deployment.

```powershell
# Run as Administrator
.\deploy\create-keytab.ps1

# With custom parameters
.\deploy\create-keytab.ps1 -ServiceAccount "my-svc" -Domain "company.com"
```

The script needs an elevated PowerShell session. If `ktpass` is missing it asks whether to install RSAT; if you decline, it prints manual installation instructions. Otherwise it verifies the account, prompts for the password, writes the keytab, and shows the next steps.

**Manually.** Create the service account first. In Active Directory Users and Computers: right-click → New → User, set the name to `svc-ldap-app`, the UPN to `svc-ldap-app@yourdomain.com`, and the password with Password never expires and User cannot change password checked. On a domain controller you can do the same with PowerShell:

```powershell
New-ADUser -Name "svc-ldap-app" `
           -UserPrincipalName "svc-ldap-app@domain.com" `
           -AccountPassword (Read-Host -AsSecureString "Enter password") `
           -Enabled $true `
           -PasswordNeverExpires $true `
           -CannotChangePassword $true
```

Then generate the keytab from an elevated prompt on a domain-joined Windows machine:

```powershell
# Run as Administrator on domain-joined Windows machine
ktpass -princ HTTP/ldap-app.domain.com@DOMAIN.COM `
       -mapuser svc-ldap-app@domain.com `
       -pass "YourPassword" `
       -out app.keytab `
       -ptype KRB5_NT_PRINCIPAL `
       -crypto AES256-SHA1
```

Parameters: `-princ` is the service principal name (SPN), `-mapuser` the AD service account, `-pass` its password, `-out` the output file, and `-crypto` the encryption type (AES256 recommended).

Verify the result on Linux/Docker:

```bash
# On Linux/Docker
klist -k -t app.keytab
```

Expected output:

```
Keytab name: FILE:app.keytab
KVNO Timestamp           Principal
---- ------------------- ------------------------------------------------------
   2 02/16/2026 23:00:00 HTTP/ldap-app.domain.com@DOMAIN.COM
```

If the script errors:

- **"New-ADUser not recognized"** — the AD PowerShell module isn't installed; install the RSAT tools or create the account in Active Directory Users and Computers instead.
- **"ktpass command not found"** — RSAT isn't installed; add it via Settings → Apps → Optional Features.
- **"Must be run as Administrator"** — right-click PowerShell → Run as Administrator.

## Using the Keytab in Docker

Mount it as a read-only volume and point Kerberos at it:

```yaml
services:
  ldap-auth:
    volumes:
      - ./app.keytab:/app/keytab:ro  # Read-only mount
    environment:
      - KRB5_KTNAME=/app/keytab      # Tell Kerberos where keytab is
```

On Kubernetes, create a secret from the file and mount it into the pod (see `kubernetes.yml`):

```bash
# Create secret from keytab file
kubectl create secret generic kerberos-keytab \
  --from-file=keytab=./app.keytab

# Mount in pod (see kubernetes.yml)
```

Do not copy the keytab into the image with `COPY`. It contains credentials, so it would sit in every image layer and any registry push; mount it or use a secret instead.

## Security Best Practices

Do:

1. Protect the keytab: `chmod 600 app.keytab`, store it in Kubernetes secrets or Azure Key Vault, and never commit it.
2. Use a dedicated service account, not a personal one; grant minimum required permissions and set the password to never expire.
3. Rotate it: reset the password and regenerate the keytab every 90–180 days.
4. Monitor it: log keytab authentication attempts and alert on failures.

Don't:

1. Commit the keytab to version control — add `*.keytab` to `.gitignore` and use secrets management.
2. Use production accounts for testing — create separate dev/test service accounts.
3. Share keytabs — each environment gets its own.
4. Build the keytab into the Docker image — mount it as a volume or use a secret.

## Skipping Kerberos (Development Only)

For development or testing without Windows Authentication, add a switch to `app.py`:

```python
# Development mode - skip Kerberos authentication
if os.getenv('SKIP_KERBEROS', 'false').lower() == 'true':
    # Use anonymous LDAP bind (if allowed)
    conn = Connection(ldap_server, auto_bind=True)
else:
    # Use Kerberos (requires keytab)
    conn = Connection(
        ldap_server,
        authentication=SASL,
        sasl_mechanism=KERBEROS,
        auto_bind=True
    )
```

And set it in `docker-compose.yml`:

```yaml
environment:
  - SKIP_KERBEROS=true  # Development only!
```

This only works if your LDAP server allows anonymous queries — most don't.

## Troubleshooting

**"No credentials were supplied"** — the keytab isn't found or isn't configured:

```bash
# Check keytab location
echo $KRB5_KTNAME

# Verify keytab exists
ls -l /app/keytab

# Test keytab
kinit -kt /app/keytab HTTP/ldap-app.domain.com@DOMAIN.COM
klist
```

**"Key table entry not found"** — the principal name in the keytab doesn't match:

```bash
# List principals in keytab
klist -k -t /app/keytab

# Regenerate with correct principal
```

**"Clock skew too great"** — the container clock is too far from the KDC's:

```bash
# Sync container time with host
docker run --cap-add SYS_TIME ...

# Or use NTP in container
```

## Quick Reference

```bash
# Generate keytab (Windows)
ktpass -princ HTTP/app@DOMAIN.COM -mapuser svc-app@domain.com -pass Password123! -out app.keytab

# Verify keytab (Linux)
klist -k -t app.keytab

# Test authentication
kinit -kt app.keytab HTTP/app@DOMAIN.COM
klist

# Use in Docker
docker run -v ./app.keytab:/app/keytab:ro -e KRB5_KTNAME=/app/keytab ...
```
