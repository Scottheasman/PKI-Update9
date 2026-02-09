<#
.SYNOPSIS
    PKI Lab - Phase 1: Install Web Tier Roles (WEB1 & WEB2)
.DESCRIPTION
    Installs Windows Features for NDES, CEP, and CES and sets local permissions.
#>

Write-Host "--- Phase 1: Installing Windows Features ---" -ForegroundColor Cyan

# 1. Install AD CS Web Roles and IIS
$Features = @(
    "ADCS-Device-Enrollment",   # NDES
    "ADCS-Enroll-Web-Pol",      # CEP
    "ADCS-Enroll-Web-Svc",      # CES
    "Web-Windows-Auth",         # Required for Kerberos
    "RSAT-ADCS"                 # Management Tools
)

foreach ($f in $Features) {
    Write-Host "Installing $f..." -ForegroundColor Gray
    Install-WindowsFeature $f -IncludeManagementTools | Out-Null
}

# 2. Add Service Accounts to Local IIS_IUSRS Group
$SvcAccounts = @("LAB\PKINDESSvc", "LAB\PKIEnrollSvc")
foreach ($acc in $SvcAccounts) {
    Write-Host "Adding $acc to local IIS_IUSRS group..." -ForegroundColor Gray
    net localgroup IIS_IUSRS $acc /add 2>$null
}

Write-Host "--- Phase 1 Complete. Please REBOOT before running Phase 2 ---" -ForegroundColor Green