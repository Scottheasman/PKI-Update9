<#
.SYNOPSIS
    PKI Lab - Phase 2: Automated AD CS Configuration (LOAD-BALANCED & COMPATIBILITY)
.DESCRIPTION
    - Configures NDES, CEP, and TWO CES instances per server.
    - Uses App Pool renaming to bypass the hard-coded "WSEnrollmentServer" limitation.
#>

$hostname = $env:COMPUTERNAME
$isWeb1 = $hostname -match 'WEB1'

# Define both CA strings
$ca1Config = "subca1.lab.local\Lab Issuing CA 1"
$ca2Config = "subca2.lab.local\Lab Issuing CA 2"

if ($isWeb1) {
    $primaryCA = $ca1Config
    $caServer = "subca1.lab.local"
} else {
    $primaryCA = $ca2Config
    $caServer = "subca2.lab.local"
}

# Credentials
$ndesSvc = Get-Credential -UserName "LAB\PKINDESSvc" -Message "Enter password for NDES Service Account"
$enrollSvc = Get-Credential -UserName "LAB\PKIEnrollSvc" -Message "Enter password for CEP/CES Service Account"

Write-Host "--- Phase 2: Configuring Load-Balanced AD CS Roles ---" -ForegroundColor Cyan
Import-Module WebAdministration

# 1. PRE-FLIGHT: Ensure templates exist on the local affinity CA
Write-Host "Ensuring temporary templates exist on $caServer..." -ForegroundColor Yellow
Invoke-Command -ComputerName $caServer -ScriptBlock {
    certutil -SetCATemplates "+CEPEncryption"
    certutil -SetCATemplates "+ExchangeEnrollmentAgentOfflineRequest"
} -ErrorAction SilentlyContinue

# 2. Configure NDES (Points to Primary CA)
Write-Host "Configuring NDES pointing to $primaryCA..." -ForegroundColor Gray
Install-AdcsNetworkDeviceEnrollmentService `
    -CAConfig $primaryCA `
    -ServiceAccountName $ndesSvc.UserName `
    -ServiceAccountPassword $ndesSvc.Password `
    -Force

# 3. Configure CEP (Kerberos)
Write-Host "Configuring CEP (Kerberos)..." -ForegroundColor Gray
Install-AdcsEnrollmentPolicyWebService -AuthenticationType Kerberos -Force
Set-ItemProperty "IIS:\AppPools\WSEnrollmentPolicyServer" -Name processModel.identityType -Value 3
Set-ItemProperty "IIS:\AppPools\WSEnrollmentPolicyServer" -Name processModel.userName -Value $enrollSvc.UserName
Set-ItemProperty "IIS:\AppPools\WSEnrollmentPolicyServer" -Name processModel.password -Value $enrollSvc.GetNetworkCredential().Password

# 4. Configure CES for CA1
Write-Host "Configuring CES for CA1..." -ForegroundColor Gray
Install-AdcsEnrollmentWebService `
    -CAConfig $ca1Config `
    -AuthenticationType Kerberos `
    -ServiceAccountName $enrollSvc.UserName `
    -ServiceAccountPassword $enrollSvc.Password `
    -Force

# Rename App Pool for CA1 to free up the default name
Write-Host "Renaming CA1 App Pool for compatibility..." -ForegroundColor Yellow
$ca1AppPool = "WSEnrollmentServer_CA1"
if (Test-Path "IIS:\AppPools\WSEnrollmentServer") {
    New-Item "IIS:\AppPools\$ca1AppPool" -Type AppPool | Out-Null
    # Copy settings from default to new
    $orig = Get-Item "IIS:\AppPools\WSEnrollmentServer"
    Set-ItemProperty "IIS:\AppPools\$ca1AppPool" -Name processModel -Value $orig.processModel
    
    # Point the CA1 application to the new pool
    Set-ItemProperty "IIS:\Sites\Default Web Site\Lab Issuing CA 1_CES_Kerberos" -Name applicationPool -Value $ca1AppPool
    Remove-Item "IIS:\AppPools\WSEnrollmentServer" -Recurse
}

# 5. Configure CES for CA2
Write-Host "Configuring CES for CA2..." -ForegroundColor Gray
Install-AdcsEnrollmentWebService `
    -CAConfig $ca2Config `
    -AuthenticationType Kerberos `
    -ServiceAccountName $enrollSvc.UserName `
    -ServiceAccountPassword $enrollSvc.Password `
    -Force

# Rename App Pool for CA2
Write-Host "Renaming CA2 App Pool for compatibility..." -ForegroundColor Yellow
$ca2AppPool = "WSEnrollmentServer_CA2"
if (Test-Path "IIS:\AppPools\WSEnrollmentServer") {
    New-Item "IIS:\AppPools\$ca2AppPool" -Type AppPool | Out-Null
    $orig = Get-Item "IIS:\AppPools\WSEnrollmentServer"
    Set-ItemProperty "IIS:\AppPools\$ca2AppPool" -Name processModel -Value $orig.processModel
    Set-ItemProperty "IIS:\Sites\Default Web Site\Lab Issuing CA 2_CES_Kerberos" -Name applicationPool -Value $ca2AppPool
    Remove-Item "IIS:\AppPools\WSEnrollmentServer" -Recurse
}

# ====================================================================
# INTEGRATED FIXES
# ====================================================================
Write-Host "--- Applying IIS and Registry Fixes ---" -ForegroundColor Cyan
$site = "Default Web Site"
$path = "C:\Windows\system32\CertSrv\mscep"

# Fix IIS Hierarchy for NDES
Remove-WebApplication -Site $site -Name "CertSrv/mscep" -ErrorAction SilentlyContinue
Remove-WebApplication -Site $site -Name "CertSrv/mscep_admin" -ErrorAction SilentlyContinue
if (-not (Test-Path "IIS:\Sites\$site\certsrv")) {
    New-WebApplication -Site $site -Name "certsrv" -PhysicalPath $path -ApplicationPool "SCEP"
}
New-Item "IIS:\Sites\$site\certsrv\mscep" -Type Application -PhysicalPath $path -Force | Out-Null
New-Item "IIS:\Sites\$site\certsrv\mscep_admin" -Type Application -PhysicalPath $path -Force | Out-Null
Set-ItemProperty "IIS:\Sites\$site\certsrv\mscep" -Name applicationPool -Value "SCEP"
Set-ItemProperty "IIS:\Sites\$site\certsrv\mscep_admin" -Name applicationPool -Value "SCEP"

# Fix mscep_admin Auth
Set-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' -Location "$site/certsrv/mscep_admin" -Filter "system.webServer/security/authentication/anonymousAuthentication" -Name enabled -Value False
Set-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' -Location "$site/certsrv/mscep_admin" -Filter "system.webServer/security/authentication/windowsAuthentication" -Name enabled -Value True
Set-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' -Location "$site/certsrv/mscep_admin" -Filter "system.webServer/security/authentication/windowsAuthentication" -Name useKernelMode -Value False

# NDES Registry
$reg = "HKLM:\SOFTWARE\Microsoft\Cryptography\MSCEP"
Set-ItemProperty -Path $reg -Name "EncryptionTemplate" -Value "IEX-NDES-RA"
Set-ItemProperty -Path $reg -Name "SignatureTemplate" -Value "IEX-NDES-RA"
Set-ItemProperty -Path $reg -Name "GeneralPurposeTemplate" -Value "IEX-NDES-Device"

# Cleanup Temporary Templates
Write-Host "Cleaning up temporary templates..." -ForegroundColor Yellow
Invoke-Command -ComputerName $caServer -ScriptBlock {
    certutil -SetCATemplates "-CEPEncryption"
    certutil -SetCATemplates "-ExchangeEnrollmentAgentOfflineRequest"
} -ErrorAction SilentlyContinue

iisreset
Write-Host "--- FULLY AUTOMATED LOAD-BALANCED BUILD COMPLETE ---" -ForegroundColor Green