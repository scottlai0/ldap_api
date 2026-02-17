# Automated Kerberos Keytab Creation Script
# Handles RSAT installation check and guides you through the process

param(
    [Parameter(Mandatory=$false)]
    [string]$ServiceAccount = "svc-ldap-app",
    
    [Parameter(Mandatory=$false)]
    [string]$Domain = $env:USERDNSDOMAIN,
    
    [Parameter(Mandatory=$false)]
    [string]$AppHostname = "ldap-app",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFile = "app.keytab"
)

# Colors for output
$ColorCyan = "Cyan"
$ColorGreen = "Green"
$ColorYellow = "Yellow"
$ColorRed = "Red"
$ColorWhite = "White"
$ColorGray = "Gray"

Write-Host "========================================" -ForegroundColor $ColorCyan
Write-Host "Automated Keytab Creation Script" -ForegroundColor $ColorCyan
Write-Host "========================================" -ForegroundColor $ColorCyan
Write-Host ""

# Step 1: Check if running as administrator
Write-Host "Step 1: Checking administrator privileges..." -ForegroundColor $ColorYellow
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "❌ ERROR: This script must be run as Administrator" -ForegroundColor $ColorRed
    Write-Host ""
    Write-Host "To run as Administrator:" -ForegroundColor $ColorYellow
    Write-Host "  1. Right-click PowerShell" -ForegroundColor $ColorGray
    Write-Host "  2. Select 'Run as Administrator'" -ForegroundColor $ColorGray
    Write-Host "  3. Navigate to this directory" -ForegroundColor $ColorGray
    Write-Host "  4. Run: .\deploy\create-keytab-auto.ps1" -ForegroundColor $ColorGray
    Write-Host ""
    exit 1
}
Write-Host "✅ Running as Administrator" -ForegroundColor $ColorGreen
Write-Host ""

# Step 2: Check if domain is available
Write-Host "Step 2: Detecting domain..." -ForegroundColor $ColorYellow
if (-not $Domain) {
    Write-Host "❌ ERROR: Could not detect domain" -ForegroundColor $ColorRed
    Write-Host "Please specify domain manually: .\create-keytab-auto.ps1 -Domain 'domain.com'" -ForegroundColor $ColorYellow
    exit 1
}
Write-Host "✅ Domain detected: $Domain" -ForegroundColor $ColorGreen
Write-Host ""

# Step 3: Check if ktpass is available
Write-Host "Step 3: Checking for ktpass command..." -ForegroundColor $ColorYellow
$ktpassAvailable = $false
try {
    $ktpassPath = Get-Command ktpass -ErrorAction Stop
    $ktpassAvailable = $true
    Write-Host "✅ ktpass found: $($ktpassPath.Source)" -ForegroundColor $ColorGreen
} catch {
    Write-Host "❌ ktpass not found" -ForegroundColor $ColorRed
}
Write-Host ""

# Step 4: If ktpass not available, check RSAT and offer to install
if (-not $ktpassAvailable) {
    Write-Host "Step 4: Checking RSAT installation..." -ForegroundColor $ColorYellow
    
    # Check if RSAT is installed
    $rsatInstalled = $false
    try {
        $rsat = Get-WindowsCapability -Name "Rsat.ActiveDirectory.DS-LDS.Tools*" -Online -ErrorAction Stop
        if ($rsat.State -eq "Installed") {
            $rsatInstalled = $true
            Write-Host "⚠️  RSAT is installed but ktpass not in PATH" -ForegroundColor $ColorYellow
            Write-Host "   Try restarting PowerShell or your computer" -ForegroundColor $ColorGray
        } else {
            Write-Host "❌ RSAT is not installed" -ForegroundColor $ColorRed
        }
    } catch {
        Write-Host "⚠️  Cannot check RSAT status" -ForegroundColor $ColorYellow
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor $ColorCyan
    Write-Host "RSAT Tools Installation Required" -ForegroundColor $ColorCyan
    Write-Host "========================================" -ForegroundColor $ColorCyan
    Write-Host ""
    Write-Host "The ktpass command requires RSAT tools to be installed." -ForegroundColor $ColorWhite
    Write-Host ""
    
    # Offer to install RSAT automatically
    Write-Host "Would you like to install RSAT tools now? (y/n)" -ForegroundColor $ColorYellow
    $installRSAT = Read-Host
    
    if ($installRSAT -eq 'y' -or $installRSAT -eq 'Y') {
        Write-Host ""
        Write-Host "Installing RSAT tools..." -ForegroundColor $ColorYellow
        Write-Host "This may take 2-5 minutes..." -ForegroundColor $ColorGray
        Write-Host ""
        
        try {
            Add-WindowsCapability -Online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0" -ErrorAction Stop
            Write-Host "✅ RSAT tools installed successfully!" -ForegroundColor $ColorGreen
            Write-Host ""
            Write-Host "⚠️  IMPORTANT: Please restart PowerShell and run this script again" -ForegroundColor $ColorYellow
            Write-Host ""
            Write-Host "Steps:" -ForegroundColor $ColorWhite
            Write-Host "  1. Close this PowerShell window" -ForegroundColor $ColorGray
            Write-Host "  2. Open PowerShell as Administrator again" -ForegroundColor $ColorGray
            Write-Host "  3. Run: .\deploy\create-keytab-auto.ps1" -ForegroundColor $ColorGray
            Write-Host ""
            exit 0
        } catch {
            Write-Host "❌ Failed to install RSAT tools automatically" -ForegroundColor $ColorRed
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor $ColorRed
            Write-Host ""
            Write-Host "Please install manually:" -ForegroundColor $ColorYellow
            Write-Host "  1. Open Settings (Win + I)" -ForegroundColor $ColorGray
            Write-Host "  2. Apps → Optional Features" -ForegroundColor $ColorGray
            Write-Host "  3. Add a feature" -ForegroundColor $ColorGray
            Write-Host "  4. Search for 'RSAT'" -ForegroundColor $ColorGray
            Write-Host "  5. Install 'RSAT: Active Directory Domain Services...'" -ForegroundColor $ColorGray
            Write-Host "  6. Restart PowerShell and run this script again" -ForegroundColor $ColorGray
            Write-Host ""
            exit 1
        }
    } else {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor $ColorCyan
        Write-Host "Manual Installation Instructions" -ForegroundColor $ColorCyan
        Write-Host "========================================" -ForegroundColor $ColorCyan
        Write-Host ""
        Write-Host "Option 1: Windows Settings (Recommended)" -ForegroundColor $ColorYellow
        Write-Host "  1. Open Settings (Win + I)" -ForegroundColor $ColorGray
        Write-Host "  2. Apps → Optional Features" -ForegroundColor $ColorGray
        Write-Host "  3. Add a feature" -ForegroundColor $ColorGray
        Write-Host "  4. Search for 'RSAT'" -ForegroundColor $ColorGray
        Write-Host "  5. Install 'RSAT: Active Directory Domain Services...'" -ForegroundColor $ColorGray
        Write-Host "  6. Restart PowerShell" -ForegroundColor $ColorGray
        Write-Host "  7. Run this script again" -ForegroundColor $ColorGray
        Write-Host ""
        Write-Host "Option 2: PowerShell Command" -ForegroundColor $ColorYellow
        Write-Host "  Run as Administrator:" -ForegroundColor $ColorGray
        Write-Host "  Add-WindowsCapability -Online -Name 'Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0'" -ForegroundColor $ColorCyan
        Write-Host ""
        Write-Host "Option 3: Create on Domain Controller" -ForegroundColor $ColorYellow
        Write-Host "  ktpass is already installed on Domain Controllers" -ForegroundColor $ColorGray
        Write-Host "  Create the keytab there and copy it to this machine" -ForegroundColor $ColorGray
        Write-Host ""
        Write-Host "See deploy/INSTALL_RSAT.md for detailed instructions" -ForegroundColor $ColorWhite
        Write-Host ""
        exit 0
    }
}

# Continue with keytab creation if ktpass is available
$DomainUpper = $Domain.ToUpper()
$ServiceAccountUPN = "$ServiceAccount@$Domain"
$Principal = "HTTP/$AppHostname.$Domain@$DomainUpper"

Write-Host "Configuration:" -ForegroundColor $ColorGreen
Write-Host "  Domain: $Domain" -ForegroundColor $ColorWhite
Write-Host "  Service Account: $ServiceAccountUPN" -ForegroundColor $ColorWhite
Write-Host "  Principal: $Principal" -ForegroundColor $ColorWhite
Write-Host "  Output File: $OutputFile" -ForegroundColor $ColorWhite
Write-Host ""

# Step 5: Check if service account exists
Write-Host "Step 5: Verifying service account..." -ForegroundColor $ColorYellow
Write-Host "⚠️  This script assumes the service account already exists" -ForegroundColor $ColorYellow
Write-Host ""
Write-Host "Does the service account '$ServiceAccountUPN' already exist? (y/n)" -ForegroundColor $ColorWhite
$accountExists = Read-Host

if ($accountExists -ne 'y' -and $accountExists -ne 'Y') {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor $ColorCyan
    Write-Host "Create Service Account First" -ForegroundColor $ColorCyan
    Write-Host "========================================" -ForegroundColor $ColorCyan
    Write-Host ""
    Write-Host "Please create the service account first:" -ForegroundColor $ColorYellow
    Write-Host ""
    Write-Host "Option 1: Active Directory Users and Computers (GUI)" -ForegroundColor $ColorWhite
    Write-Host "  1. Open 'Active Directory Users and Computers'" -ForegroundColor $ColorGray
    Write-Host "  2. Create new user: $ServiceAccount" -ForegroundColor $ColorGray
    Write-Host "  3. Set UPN: $ServiceAccountUPN" -ForegroundColor $ColorGray
    Write-Host "  4. Set password to never expire" -ForegroundColor $ColorGray
    Write-Host "  5. Enable the account" -ForegroundColor $ColorGray
    Write-Host ""
    Write-Host "Option 2: PowerShell (on Domain Controller)" -ForegroundColor $ColorWhite
    Write-Host "  New-ADUser -Name '$ServiceAccount' ``" -ForegroundColor $ColorCyan
    Write-Host "             -UserPrincipalName '$ServiceAccountUPN' ``" -ForegroundColor $ColorCyan
    Write-Host "             -AccountPassword (Read-Host -AsSecureString) ``" -ForegroundColor $ColorCyan
    Write-Host "             -Enabled `$true ``" -ForegroundColor $ColorCyan
    Write-Host "             -PasswordNeverExpires `$true" -ForegroundColor $ColorCyan
    Write-Host ""
    Write-Host "After creating the account, run this script again" -ForegroundColor $ColorYellow
    Write-Host ""
    exit 0
}

# Step 6: Get password
Write-Host ""
Write-Host "Step 6: Enter service account password" -ForegroundColor $ColorYellow
$password = Read-Host "Enter password for '$ServiceAccountUPN'" -AsSecureString
$pwd = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))

# Step 7: Generate keytab
Write-Host ""
Write-Host "Step 7: Generating keytab file..." -ForegroundColor $ColorYellow

try {
    $ktpassCmd = "ktpass -princ $Principal -mapuser $ServiceAccountUPN -pass `"$pwd`" -out `"$OutputFile`" -ptype KRB5_NT_PRINCIPAL -crypto AES256-SHA1"
    
    Write-Host "Executing: ktpass -princ $Principal -mapuser $ServiceAccountUPN -pass *** -out $OutputFile ..." -ForegroundColor $ColorGray
    
    # Execute ktpass
    $result = Invoke-Expression $ktpassCmd 2>&1
    
    if (Test-Path $OutputFile) {
        Write-Host "✅ Keytab file created: $OutputFile" -ForegroundColor $ColorGreen
    } else {
        Write-Host "❌ ERROR: Keytab file was not created" -ForegroundColor $ColorRed
        Write-Host $result -ForegroundColor $ColorRed
        exit 1
    }
} catch {
    Write-Host "❌ ERROR: Failed to generate keytab" -ForegroundColor $ColorRed
    Write-Host $_.Exception.Message -ForegroundColor $ColorRed
    exit 1
}

# Step 8: Verify keytab
Write-Host ""
Write-Host "Step 8: Verifying keytab..." -ForegroundColor $ColorYellow

$keytabInfo = Get-Item $OutputFile
Write-Host "  File: $($keytabInfo.FullName)" -ForegroundColor $ColorWhite
Write-Host "  Size: $($keytabInfo.Length) bytes" -ForegroundColor $ColorWhite
Write-Host "  Created: $($keytabInfo.CreationTime)" -ForegroundColor $ColorWhite

# Step 9: Set permissions
Write-Host ""
Write-Host "Step 9: Setting file permissions..." -ForegroundColor $ColorYellow

try {
    # Remove inheritance
    $acl = Get-Acl $OutputFile
    $acl.SetAccessRuleProtection($true, $false)
    
    # Remove all existing rules
    $acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) | Out-Null }
    
    # Add current user with full control
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($currentUser, "FullControl", "Allow")
    $acl.AddAccessRule($rule)
    
    Set-Acl $OutputFile $acl
    
    Write-Host "✅ File permissions set (only accessible by $currentUser)" -ForegroundColor $ColorGreen
} catch {
    Write-Host "⚠️  Warning: Could not set file permissions" -ForegroundColor $ColorYellow
    Write-Host $_.Exception.Message -ForegroundColor $ColorYellow
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor $ColorCyan
Write-Host "✅ Keytab Creation Complete!" -ForegroundColor $ColorGreen
Write-Host "========================================" -ForegroundColor $ColorCyan
Write-Host ""
Write-Host "Next Steps for Docker Deployment:" -ForegroundColor $ColorYellow
Write-Host ""
Write-Host "1. Move keytab to deploy folder:" -ForegroundColor $ColorWhite
Write-Host "   Move-Item $OutputFile deploy\app.keytab" -ForegroundColor $ColorCyan
Write-Host ""
Write-Host "2. Uncomment keytab volume in docker-compose.yml:" -ForegroundColor $ColorWhite
Write-Host "   Edit deploy\docker-compose.yml line 29:" -ForegroundColor $ColorGray
Write-Host "   - ./app.keytab:/app/keytab:ro" -ForegroundColor $ColorCyan
Write-Host ""
Write-Host "3. Deploy with docker-compose:" -ForegroundColor $ColorWhite
Write-Host "   cd deploy" -ForegroundColor $ColorCyan
Write-Host "   docker-compose up -d" -ForegroundColor $ColorCyan
Write-Host ""
Write-Host "⚠️  SECURITY WARNING:" -ForegroundColor $ColorRed
Write-Host "   - Keep this keytab file secure!" -ForegroundColor $ColorYellow
Write-Host "   - Do NOT commit to version control" -ForegroundColor $ColorYellow
Write-Host "   - Rotate every 90-180 days" -ForegroundColor $ColorYellow
Write-Host ""
Write-Host "Service Account Details:" -ForegroundColor $ColorGreen
Write-Host "  Username: $ServiceAccountUPN" -ForegroundColor $ColorWhite
Write-Host "  Principal: $Principal" -ForegroundColor $ColorWhite
Write-Host "  Keytab: $OutputFile" -ForegroundColor $ColorWhite
Write-Host ""
