# Installing RSAT Tools for Keytab Creation

## Why You Need RSAT

The `ktpass` command is required to create Kerberos keytab files. This command is part of the **Remote Server Administration Tools (RSAT)** package.

---

## Installation Methods

### Method 1: Windows Settings (Recommended)

**For Windows 10/11:**

1. **Open Settings**
   - Press `Win + I`
   - Or click Start → Settings

2. **Navigate to Apps**
   - Click **Apps**
   - Click **Optional Features**

3. **Add RSAT Tools**
   - Click **Add a feature** (or **View features**)
   - In the search box, type: `RSAT`

4. **Install AD Tools**
   - Find: **RSAT: Active Directory Domain Services and Lightweight Directory Services Tools**
   - Check the box
   - Click **Install**

5. **Wait for Installation**
   - Installation takes 2-5 minutes
   - You may need to restart your computer

6. **Verify Installation**
   ```powershell
   # Open PowerShell and run:
   Get-Command ktpass
   ```

   Expected output:
   ```
   CommandType     Name        Version    Source
   -----------     ----        -------    ------
   Application     ktpass.exe  10.0.19... C:\Windows\system32\ktpass.exe
   ```

---

### Method 2: PowerShell (Alternative)

```powershell
# Run PowerShell as Administrator
Get-WindowsCapability -Name RSAT* -Online | Add-WindowsCapability -Online
```

Or install specific component:
```powershell
# Run PowerShell as Administrator
Add-WindowsCapability -Online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"
```

---

### Method 3: Windows Server

**For Windows Server:**

```powershell
# Run PowerShell as Administrator
Install-WindowsFeature -Name RSAT-AD-PowerShell,RSAT-AD-Tools
```

---

## After Installation

### 1. Verify ktpass is Available

```powershell
# Check if ktpass is installed
Get-Command ktpass

# Check version
ktpass /?
```

### 2. Create Keytab

```powershell
# Navigate to project directory
cd "c:\Users\slaib\OneDrive - Micron Technology, Inc\Projects\F10\Kerberos Based Auth"

# Run the keytab creation script
.\deploy\create-keytab-simple.ps1
```

---

## Troubleshooting

### Issue: "ktpass not found" after installation

**Solution 1: Restart PowerShell**
```powershell
# Close and reopen PowerShell
# Then try again
Get-Command ktpass
```

**Solution 2: Restart Computer**
- Some RSAT installations require a restart
- Restart your computer
- Try again

**Solution 3: Check PATH**
```powershell
# ktpass should be in System32
Test-Path "C:\Windows\System32\ktpass.exe"
```

### Issue: "Installation failed"

**Solution:**
1. Check Windows Update is working
2. Ensure you have administrator rights
3. Check disk space (need ~100MB)
4. Try Method 2 (PowerShell) instead

### Issue: "Feature not found"

**Possible causes:**
- Windows 10 Home edition (RSAT not available)
- Windows version too old

**Solution:**
- Upgrade to Windows 10 Pro or Enterprise
- Or create keytab on a different machine (Domain Controller, Windows Server)

---

## Alternative: Create Keytab on Domain Controller

If you cannot install RSAT on your machine, create the keytab on a Domain Controller:

### On Domain Controller:

```powershell
# ktpass is already installed on Domain Controllers
ktpass -princ HTTP/ldap-app.na.micron.com@NA.MICRON.COM `
       -mapuser svc-ldap-app@na.micron.com `
       -pass "YourPassword" `
       -out app.keytab `
       -ptype KRB5_NT_PRINCIPAL `
       -crypto AES256-SHA1
```

### Transfer Keytab:

1. Copy `app.keytab` from Domain Controller to your machine
2. Place it in the `deploy` folder
3. Continue with Docker deployment

---

## Security Note

⚠️ **Keep keytab files secure!**
- Never commit to version control
- Set restrictive file permissions
- Rotate every 90-180 days
- Use dedicated service accounts

---

## Quick Reference

### Check if RSAT is Installed
```powershell
Get-WindowsCapability -Name RSAT* -Online | Where-Object State -eq "Installed"
```

### Install RSAT (PowerShell)
```powershell
# Run as Administrator
Add-WindowsCapability -Online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"
```

### Verify ktpass
```powershell
Get-Command ktpass
ktpass /?
```

### Create Keytab
```powershell
.\deploy\create-keytab-simple.ps1
```

---

## Next Steps

After installing RSAT and creating the keytab:

1. ✅ Install RSAT tools
2. ✅ Verify ktpass is available
3. ✅ Run `create-keytab-simple.ps1`
4. ✅ Move keytab to deploy folder
5. ✅ Update docker-compose.yml
6. ✅ Deploy with Docker

See [`KEYTAB_GUIDE.md`](KEYTAB_GUIDE.md) for complete keytab documentation.
