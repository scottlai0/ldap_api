# LDAP Server Detection Guide

## Overview

This guide helps you find your Active Directory LDAP server address and base DN for configuration.

---

## Quick Detection (Windows)

### Method 1: Using PowerShell (Recommended)

```powershell
# Get domain information
$domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()

# Display LDAP server (Domain Controller)
Write-Host "LDAP Server: $($domain.PdcRoleOwner.Name)"
Write-Host "Domain: $($domain.Name)"

# Display all domain controllers
Write-Host "`nAll Domain Controllers:"
$domain.DomainControllers | ForEach-Object { Write-Host "  - $($_.Name)" }

# Display Base DN
$baseDN = "DC=" + ($domain.Name -replace "\.", ",DC=")
Write-Host "`nBase DN: $baseDN"
```

**Example Output:**
```
LDAP Server: DC01.company.com
Domain: company.com

All Domain Controllers:
  - DC01.company.com
  - DC02.company.com

Base DN: DC=company,DC=com
```

### Method 2: Using Command Prompt

```cmd
# Get domain name
echo %USERDNSDOMAIN%

# Get domain controller
nltest /dsgetdc:%USERDNSDOMAIN%

# Get all domain controllers
nltest /dclist:%USERDNSDOMAIN%
```

**Example Output:**
```
DC: \\DC01.company.com
Address: \\192.168.1.10
Dom Guid: 12345678-1234-1234-1234-123456789012
Dom Name: company.com
```

### Method 3: Using Environment Variables

```powershell
# Display domain information
Write-Host "DNS Domain: $env:USERDNSDOMAIN"
Write-Host "Domain: $env:USERDOMAIN"
Write-Host "Logon Server: $env:LOGONSERVER"
```

**Example Output:**
```
DNS Domain: company.com
Domain: COMPANY
Logon Server: \\DC01
```

---

## Detailed Detection Methods

### Using nslookup (DNS Query)

```cmd
# Find domain controllers via DNS
nslookup -type=SRV _ldap._tcp.dc._msdcs.yourdomain.com

# Example:
nslookup -type=SRV _ldap._tcp.dc._msdcs.company.com
```

**Example Output:**
```
_ldap._tcp.dc._msdcs.company.com SRV service location:
  priority       = 0
  weight         = 100
  port           = 389
  svr hostname   = DC01.company.com
```

### Using Active Directory PowerShell Module

```powershell
# Import AD module (requires RSAT tools)
Import-Module ActiveDirectory

# Get domain information
Get-ADDomain

# Get all domain controllers
Get-ADDomainController -Filter *

# Get specific DC
Get-ADDomainController -Discover
```

**Example Output:**
```
DistinguishedName : DC=company,DC=com
DNSRoot           : company.com
NetBIOSName       : COMPANY
PDCEmulator       : DC01.company.com
```

### Using LDAP Query Tool (ldp.exe)

1. Open **ldp.exe** (Windows Server or RSAT tools)
2. **Connection** → **Connect**
3. Leave server blank (auto-detect) or enter DC name
4. Port: 389 (LDAP) or 636 (LDAPS)
5. Click **OK**
6. **Connection** → **Bind**
7. Select **Bind as currently logged on user**
8. View **RootDSE** to see domain information

---

## Configuration Examples

### For .env File

Based on detection results, configure your `.env`:

```bash
# Example 1: Single domain controller
LDAP_SERVER=ldap://DC01.company.com
LDAP_BASE_DN=DC=company,DC=com

# Example 2: Multiple domain controllers (load balancing)
LDAP_SERVER=ldap://DC01.company.com,ldap://DC02.company.com
LDAP_BASE_DN=DC=company,DC=com

# Example 3: Using domain name (DNS round-robin)
LDAP_SERVER=ldap://company.com
LDAP_BASE_DN=DC=company,DC=com

# Example 4: Secure LDAP (LDAPS)
LDAP_SERVER=ldaps://DC01.company.com:636
LDAP_BASE_DN=DC=company,DC=com

# Example 5: Global Catalog (port 3268)
LDAP_SERVER=ldap://DC01.company.com:3268
LDAP_BASE_DN=DC=company,DC=com
```

### For Kerberos (krb5.conf)

```ini
[libdefaults]
    default_realm = COMPANY.COM
    dns_lookup_realm = false
    dns_lookup_kdc = true

[realms]
    COMPANY.COM = {
        kdc = DC01.company.com
        admin_server = DC01.company.com
        default_domain = company.com
    }

[domain_realm]
    .company.com = COMPANY.COM
    company.com = COMPANY.COM
```

---

## Testing LDAP Connection

### Using PowerShell

```powershell
# Test LDAP connection
$ldapServer = "DC01.company.com"
$baseDN = "DC=company,DC=com"

try {
    $searcher = New-Object System.DirectoryServices.DirectorySearcher
    $searcher.SearchRoot = "LDAP://$ldapServer/$baseDN"
    $searcher.Filter = "(objectClass=*)"
    $searcher.SearchScope = "Base"
    $result = $searcher.FindOne()
    
    if ($result) {
        Write-Host "✅ LDAP connection successful!" -ForegroundColor Green
        Write-Host "Server: $ldapServer" -ForegroundColor White
        Write-Host "Base DN: $baseDN" -ForegroundColor White
    }
} catch {
    Write-Host "❌ LDAP connection failed!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}
```

### Using ldapsearch (Linux/Docker)

```bash
# Test LDAP connection
ldapsearch -H ldap://DC01.company.com -b "DC=company,DC=com" -x "(objectClass=*)" -LLL

# Test with Kerberos
kinit username@COMPANY.COM
ldapsearch -H ldap://DC01.company.com -b "DC=company,DC=com" -Y GSSAPI "(objectClass=*)" -LLL
```

### Using Python (ldap3)

```python
from ldap3 import Server, Connection, ALL

# Test connection
server = Server('ldap://DC01.company.com', get_info=ALL)
conn = Connection(server, auto_bind=True)

if conn.bound:
    print("✅ LDAP connection successful!")
    print(f"Server: {server}")
    print(f"Info: {server.info}")
else:
    print("❌ LDAP connection failed!")

conn.unbind()
```

---

## Common Scenarios

### Scenario 1: Corporate Network (Domain-Joined)

**Detection:**
```powershell
# Automatic detection
$env:USERDNSDOMAIN
$env:LOGONSERVER
```

**Configuration:**
```bash
LDAP_SERVER=ldap://yourdomain.com
LDAP_BASE_DN=DC=yourdomain,DC=com
```

### Scenario 2: Multiple Domains (Forest)

**Detection:**
```powershell
# Get forest information
[System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
```

**Configuration:**
```bash
# Use Global Catalog for cross-domain queries
LDAP_SERVER=ldap://DC01.yourdomain.com:3268
LDAP_BASE_DN=DC=yourdomain,DC=com
```

### Scenario 3: Subdomain

**Detection:**
```powershell
# Example: subdomain.parent.com
$env:USERDNSDOMAIN  # Returns: subdomain.parent.com
```

**Configuration:**
```bash
LDAP_SERVER=ldap://subdomain.parent.com
LDAP_BASE_DN=DC=subdomain,DC=parent,DC=com
```

### Scenario 4: Remote/VPN Access

**Detection:**
```powershell
# Test connectivity first
Test-NetConnection DC01.yourdomain.com -Port 389
```

**Configuration:**
```bash
# Use specific DC (not domain name)
LDAP_SERVER=ldap://DC01.yourdomain.com
LDAP_BASE_DN=DC=yourdomain,DC=com
```

---

## Troubleshooting

### Issue: Cannot detect domain

**Cause:** Machine not domain-joined or not on corporate network

**Solution:**
```powershell
# Check domain membership
(Get-WmiObject Win32_ComputerSystem).PartOfDomain

# If False, machine is not domain-joined
# Contact IT to get LDAP server details
```

### Issue: Multiple domain controllers

**Cause:** Large organization with multiple DCs

**Solution:**
```bash
# Option 1: Use domain name (DNS handles load balancing)
LDAP_SERVER=ldap://yourdomain.com

# Option 2: List multiple servers
LDAP_SERVER=ldap://DC01.yourdomain.com,ldap://DC02.yourdomain.com

# Option 3: Use closest DC
# Run: nltest /dsgetdc:%USERDNSDOMAIN% /force
# Use the returned DC
```

### Issue: LDAP connection timeout

**Cause:** Firewall or network issue

**Solution:**
```powershell
# Test connectivity
Test-NetConnection DC01.yourdomain.com -Port 389  # LDAP
Test-NetConnection DC01.yourdomain.com -Port 636  # LDAPS
Test-NetConnection DC01.yourdomain.com -Port 3268 # Global Catalog

# Check firewall rules
# Contact network team if ports are blocked
```

### Issue: Wrong Base DN

**Cause:** Incorrect domain structure

**Solution:**
```powershell
# Get correct Base DN
$domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
$baseDN = "DC=" + ($domain.Name -replace "\.", ",DC=")
Write-Host "Correct Base DN: $baseDN"
```

---

## Quick Reference

### PowerShell One-Liner

```powershell
# Get all info at once
$d = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain(); Write-Host "LDAP_SERVER=ldap://$($d.PdcRoleOwner.Name)"; Write-Host "LDAP_BASE_DN=DC=$($d.Name -replace '\.',',DC=')"
```

**Example Output:**
```
LDAP_SERVER=ldap://DC01.company.com
LDAP_BASE_DN=DC=company,DC=com
```

### Batch Script

Save as `detect-ldap.bat`:
```batch
@echo off
echo LDAP Server Detection
echo =====================
echo.
echo Domain: %USERDNSDOMAIN%
echo Logon Server: %LOGONSERVER%
echo.
echo Suggested Configuration:
echo LDAP_SERVER=ldap://%USERDNSDOMAIN%
echo LDAP_BASE_DN=DC=%USERDNSDOMAIN:.=,DC=%
```

---

## Summary

### Recommended Detection Method

```powershell
# Run this PowerShell script
$domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
Write-Host "`n=== LDAP Configuration ===" -ForegroundColor Cyan
Write-Host "LDAP_SERVER=ldap://$($domain.PdcRoleOwner.Name)" -ForegroundColor Green
Write-Host "LDAP_BASE_DN=DC=$($domain.Name -replace '\.',',DC=')" -ForegroundColor Green
Write-Host "`nCopy these values to your .env file" -ForegroundColor Yellow
```

### Configuration Checklist

- [ ] Detect LDAP server using PowerShell
- [ ] Verify Base DN format
- [ ] Test LDAP connection
- [ ] Update `.env` file
- [ ] Test application connectivity
- [ ] Configure Kerberos (if using Docker)

---

## Additional Resources

- **Active Directory Basics**: [Microsoft Docs](https://docs.microsoft.com/en-us/windows-server/identity/ad-ds/)
- **LDAP Protocol**: [RFC 4511](https://tools.ietf.org/html/rfc4511)
- **Kerberos**: [RFC 4120](https://tools.ietf.org/html/rfc4120)

For application-specific configuration, see:
- [`../.env.example`](../.env.example) - Environment variables template
- [`../README.md`](../README.md) - Application documentation
- [`../deploy/KEYTAB_GUIDE.md`](../deploy/KEYTAB_GUIDE.md) - Kerberos configuration
