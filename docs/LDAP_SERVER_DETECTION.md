# LDAP Server Detection Guide

This guide shows how to find your Active Directory LDAP server address and base DN for configuration.

The fastest way to get both values on a domain-joined Windows machine is this one-liner:

```powershell
# Get all info at once
$d = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain(); Write-Host "LDAP_SERVER=ldap://$($d.PdcRoleOwner.Name)"; Write-Host "LDAP_BASE_DN=DC=$($d.Name -replace '\.',',DC=')"
```

**Example Output:**
```
LDAP_SERVER=ldap://DC01.company.com
LDAP_BASE_DN=DC=company,DC=com
```

## Detection on Windows

**PowerShell.** The most complete option — returns the DC holding the PDC role, all domain controllers, and the base DN:

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

**Command Prompt.** Works without PowerShell:

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

**Environment variables.** Quick but only works on a domain-joined machine:

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

**Batch script.** Save as `detect-ldap.bat`:
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

## Other Detection Methods

**DNS query (nslookup).** Finds domain controllers via SRV records, useful from any machine that can reach the domain's DNS:

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

**Active Directory PowerShell module.** Requires the RSAT tools:

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

**ldp.exe (GUI).** Ships with Windows Server and RSAT:

1. Open **ldp.exe**
2. **Connection** → **Connect**
3. Leave server blank (auto-detect) or enter DC name
4. Port: 389 (LDAP) or 636 (LDAPS)
5. Click **OK**
6. **Connection** → **Bind**
7. Select **Bind as currently logged on user**
8. View **RootDSE** to see domain information

## Configuration Examples

### For .env File

Based on detection results, configure your `.env` (see [`.env.example`](../.env.example) for the full template):

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

For the keytab setup that uses this file, see [`deploy/KEYTAB_GUIDE.md`](../deploy/KEYTAB_GUIDE.md).

## Testing LDAP Connection

**PowerShell:**

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
        Write-Host "LDAP connection successful!" -ForegroundColor Green
        Write-Host "Server: $ldapServer" -ForegroundColor White
        Write-Host "Base DN: $baseDN" -ForegroundColor White
    }
} catch {
    Write-Host "LDAP connection failed!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}
```

**ldapsearch (Linux/Docker):**

```bash
# Test LDAP connection
ldapsearch -H ldap://DC01.company.com -b "DC=company,DC=com" -x "(objectClass=*)" -LLL

# Test with Kerberos
kinit username@COMPANY.COM
ldapsearch -H ldap://DC01.company.com -b "DC=company,DC=com" -Y GSSAPI "(objectClass=*)" -LLL
```

**Python (ldap3):**

```python
from ldap3 import Server, Connection, ALL

# Test connection
server = Server('ldap://DC01.company.com', get_info=ALL)
conn = Connection(server, auto_bind=True)

if conn.bound:
    print("LDAP connection successful!")
    print(f"Server: {server}")
    print(f"Info: {server.info}")
else:
    print("LDAP connection failed!")

conn.unbind()
```

## Common Scenarios

**Domain-joined machine on the corporate network.** Read the values straight from the environment:

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

**Multiple domains (forest).** Use the Global Catalog port (3268) for cross-domain queries:

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

**Subdomain.** The base DN gets one `DC=` component per DNS segment:

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

**Remote or VPN access.** Point at a specific DC rather than the domain name, and verify connectivity first:

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

## Troubleshooting

**Cannot detect domain.** The machine is not domain-joined or not on the corporate network. Check domain membership:

```powershell
# Check domain membership
(Get-WmiObject Win32_ComputerSystem).PartOfDomain

# If False, machine is not domain-joined
# Contact IT to get LDAP server details
```

**Multiple domain controllers.** Pick one of these approaches:

```bash
# Option 1: Use domain name (DNS handles load balancing)
LDAP_SERVER=ldap://yourdomain.com

# Option 2: List multiple servers
LDAP_SERVER=ldap://DC01.yourdomain.com,ldap://DC02.yourdomain.com

# Option 3: Use closest DC
# Run: nltest /dsgetdc:%USERDNSDOMAIN% /force
# Use the returned DC
```

**LDAP connection timeout.** Usually a firewall or network issue. Test the ports:

```powershell
# Test connectivity
Test-NetConnection DC01.yourdomain.com -Port 389  # LDAP
Test-NetConnection DC01.yourdomain.com -Port 636  # LDAPS
Test-NetConnection DC01.yourdomain.com -Port 3268 # Global Catalog

# Check firewall rules
# Contact network team if ports are blocked
```

**Wrong Base DN.** Derive it from the actual domain name rather than guessing:

```powershell
# Get correct Base DN
$domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
$baseDN = "DC=" + ($domain.Name -replace "\.", ",DC=")
Write-Host "Correct Base DN: $baseDN"
```
