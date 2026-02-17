# Kerberos Keytab Guide

## Quick Start

### Prerequisites
1. Active Directory service account (e.g., `svc-ldap-app@domain.com`)
2. Windows machine with administrator rights

### Create Keytab in 2 Steps

```powershell
# 1. Open PowerShell as Administrator
# 2. Run the script
.\deploy\create-keytab.ps1
```

The script will:
- ✅ Check if RSAT tools are installed
- ✅ Offer to install RSAT automatically if missing
- ✅ Detect your domain automatically
- ✅ Verify service account exists
- ✅ Prompt for service account password
- ✅ Generate `app.keytab` file
- ✅ Set secure permissions

**Note:** Service account must already exist in Active Directory. See "Creating Service Account" section below.

---

## What is a Keytab?

A **keytab** (key table) is a file containing pairs of Kerberos principals and encrypted keys. It's essentially a **password file** that allows applications to authenticate to Kerberos without requiring interactive password entry.

Think of it as a "service account password file" for automated authentication.

---

## Why Do You Need It for Docker?

### The Problem:

**Windows (IIS):**
- Your Windows machine is domain-joined
- Windows automatically handles Kerberos authentication
- Your app uses your Windows credentials seamlessly
- ✅ **No keytab needed**

**Docker (Linux Container):**
- Container is NOT domain-joined
- Container doesn't have your Windows credentials
- Container can't automatically authenticate to Active Directory
- ❌ **Needs keytab for authentication**

### The Solution:

A keytab file allows the Docker container to authenticate to Kerberos/Active Directory without being domain-joined.

---

## How Keytab Works

```
┌─────────────────┐
│  Docker Container│
│                  │
│  1. Reads keytab │──┐
│  2. Gets ticket  │  │
│  3. Auth to LDAP │  │
└─────────────────┘  │
                     │
                     ▼
              ┌──────────────┐
              │   Keytab     │
              │              │
              │ Principal:   │
              │ HTTP/app@... │
              │              │
              │ Encrypted    │
              │ Password     │
              └──────────────┘
                     │
                     ▼
              ┌──────────────┐
              │  Kerberos    │
              │  KDC         │
              │ (Domain      │
              │  Controller) │
              └──────────────┘
                     │
                     ▼
              ┌──────────────┐
              │  LDAP Server │
              │              │
              │  Returns     │
              │  User Data   │
              └──────────────┘
```

---

## Creating a Keytab

### Method 1: Using the Automated Script (Recommended)

We provide a fully automated PowerShell script that handles everything:

#### `create-keytab.ps1` - Automated Keytab Creation

**Features:**
- ✅ Checks if RSAT tools are installed
- ✅ **Offers to install RSAT automatically** if missing
- ✅ Detects domain automatically
- ✅ Verifies service account exists
- ✅ Generates keytab with proper encryption
- ✅ Sets secure file permissions
- ✅ Provides next steps for Docker deployment

**Usage:**
```powershell
# Run as Administrator
.\deploy\create-keytab.ps1

# With custom parameters
.\deploy\create-keytab.ps1 -ServiceAccount "my-svc" -Domain "company.com"
```

**What happens:**
1. Checks if you're running as Administrator
2. Detects your domain
3. Checks if `ktpass` is available
4. **If ktpass is missing:**
   - Asks: "Would you like to install RSAT tools now? (y/n)"
   - If yes: Installs RSAT automatically
   - If no: Provides manual installation instructions
5. **If ktpass is available:**
   - Verifies service account exists
   - Prompts for password
   - Creates keytab file
   - Shows next steps

### Method 2: Manual Creation

#### Step 1: Create Service Account

**Option A: Using Active Directory Users and Computers (GUI)**
1. Open **Active Directory Users and Computers**
2. Right-click → **New** → **User**
3. Set name: `svc-ldap-app`
4. Set UPN: `svc-ldap-app@yourdomain.com`
5. Set password and check:
   - ✅ Password never expires
   - ✅ User cannot change password

**Option B: Using PowerShell (on Domain Controller)**
```powershell
New-ADUser -Name "svc-ldap-app" `
           -UserPrincipalName "svc-ldap-app@domain.com" `
           -AccountPassword (Read-Host -AsSecureString "Enter password") `
           -Enabled $true `
           -PasswordNeverExpires $true `
           -CannotChangePassword $true
```

#### Step 2: Generate Keytab

```powershell
# Run as Administrator on domain-joined Windows machine
ktpass -princ HTTP/ldap-app.domain.com@DOMAIN.COM `
       -mapuser svc-ldap-app@domain.com `
       -pass "YourPassword" `
       -out app.keytab `
       -ptype KRB5_NT_PRINCIPAL `
       -crypto AES256-SHA1
```

**Parameters:**
- `-princ` - Service principal name (SPN)
- `-mapuser` - AD service account
- `-pass` - Service account password
- `-out` - Output filename
- `-crypto` - Encryption (AES256 recommended)

#### Step 3: Verify Keytab

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

### Troubleshooting Script Errors

**Error: "New-ADUser not recognized"**
- Cause: AD PowerShell module not installed
- Solution: Use `create-keytab-simple.ps1` instead, or install RSAT tools

**Error: "ktpass command not found"**
- Cause: RSAT tools not installed
- Solution: Install RSAT tools via Settings → Apps → Optional Features

**Error: "Must be run as Administrator"**
- Solution: Right-click PowerShell → Run as Administrator

---

## Using Keytab in Docker

### Option 1: Mount as Volume

**docker-compose.yml:**
```yaml
services:
  ldap-auth:
    volumes:
      - ./app.keytab:/app/keytab:ro  # Read-only mount
    environment:
      - KRB5_KTNAME=/app/keytab      # Tell Kerberos where keytab is
```

### Option 2: Kubernetes Secret

```bash
# Create secret from keytab file
kubectl create secret generic kerberos-keytab \
  --from-file=keytab=./app.keytab

# Mount in pod (see kubernetes.yml)
```

### Option 3: Build into Image (NOT RECOMMENDED)

```dockerfile
# DON'T DO THIS - Security risk!
COPY app.keytab /app/keytab
```

**Why not?** Keytab contains credentials - don't bake into image!

---

## Security Best Practices

### ✅ DO:

1. **Protect the keytab file**
   - Set permissions: `chmod 600 app.keytab`
   - Store securely (Kubernetes secrets, Azure Key Vault, etc.)
   - Never commit to git

2. **Use dedicated service account**
   - Don't use personal accounts
   - Grant minimum required permissions
   - Set password to never expire

3. **Rotate regularly**
   - Regenerate keytab every 90-180 days
   - Update password and regenerate keytab

4. **Monitor usage**
   - Log keytab authentication attempts
   - Alert on failures

### ❌ DON'T:

1. **Don't commit keytab to version control**
   - Add `*.keytab` to `.gitignore`
   - Use secrets management instead

2. **Don't use production accounts for testing**
   - Create separate dev/test service accounts

3. **Don't share keytabs**
   - Each environment should have its own keytab

4. **Don't build keytab into Docker image**
   - Mount as volume or use secrets

---

## Alternative: Skip Keytab (Development Only)

For development/testing without Windows Authentication:

### Modify app.py to skip Kerberos:

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

**docker-compose.yml:**
```yaml
environment:
  - SKIP_KERBEROS=true  # Development only!
```

**⚠️ Warning:** This only works if your LDAP server allows anonymous queries (most don't).

---

## Troubleshooting

### Error: "No credentials were supplied"

**Cause:** Keytab not found or not configured

**Solution:**
```bash
# Check keytab location
echo $KRB5_KTNAME

# Verify keytab exists
ls -l /app/keytab

# Test keytab
kinit -kt /app/keytab HTTP/ldap-app.domain.com@DOMAIN.COM
klist
```

### Error: "Key table entry not found"

**Cause:** Wrong principal name in keytab

**Solution:**
```bash
# List principals in keytab
klist -k -t /app/keytab

# Regenerate with correct principal
```

### Error: "Clock skew too great"

**Cause:** Time difference between container and KDC

**Solution:**
```bash
# Sync container time with host
docker run --cap-add SYS_TIME ...

# Or use NTP in container
```

---

## Summary

### For Windows/IIS Deployment:
- ✅ **No keytab needed**
- Windows handles Kerberos automatically
- Simplest option for corporate environments

### For Docker Deployment:
- ⚠️ **Keytab required** for Windows Authentication
- Create service account
- Generate keytab with `ktpass`
- Mount securely in container
- More complex but enables containerization

### Recommendation:

**Production (Corporate):** Use IIS (no keytab needed)
**Production (Cloud/K8s):** Use Docker with keytab
**Development:** Use Docker without keytab (skip Kerberos)

---

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
