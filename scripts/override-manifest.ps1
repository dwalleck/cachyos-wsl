#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Local testing script for CachyOS WSL distribution

.DESCRIPTION
    This script enables local testing of the CachyOS WSL distribution without
    publishing to the Microsoft Store. It creates a local manifest and overrides
    the WSL distribution list registry key.

.PARAMETER TarPath
    Path to the .wsl or .tar.gz file to test (required)

.PARAMETER Flavor
    Distribution family name (default: "cachyos")

.PARAMETER Version
    Version identifier shown in 'wsl --list --online' (default: "cachyos-wsl-v1")

.PARAMETER FriendlyName
    Human-readable description (default: "CachyOS WSL Distribution")

.EXAMPLE
    .\override-manifest.ps1 -TarPath C:\path\to\cachyos.wsl

.EXAMPLE
    .\override-manifest.ps1 -TarPath .\dist\cachyos-v3.wsl -Version "cachyos-dev"

.NOTES
    After testing, clean up with:
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss" -Name DistributionListUrl

    Based on Microsoft WSL custom distribution documentation.
#>

[CmdletBinding(PositionalBinding = $false)]
param (
    [Parameter(Mandatory = $true)]
    [string]$TarPath,

    [string]$Flavor = "cachyos",

    [string]$Version = "cachyos-wsl-v1",

    [string]$FriendlyName = "CachyOS WSL Distribution"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

##############################################################################
# Validate input
##############################################################################

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "CachyOS WSL Local Testing Setup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check if file exists
if (-not (Test-Path $TarPath)) {
    Write-Host "ERROR: File not found: $TarPath" -ForegroundColor Red
    exit 1
}

# Resolve to absolute path
$TarPath = Resolve-Path $TarPath

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Distribution: $Flavor" -ForegroundColor Gray
Write-Host "  Version: $Version" -ForegroundColor Gray
Write-Host "  Friendly Name: $FriendlyName" -ForegroundColor Gray
Write-Host "  File: $TarPath" -ForegroundColor Gray
Write-Host ""

##############################################################################
# Compute SHA256 hash
##############################################################################

Write-Host "[1/4] Computing SHA256 hash..." -ForegroundColor Yellow

try {
    $hash = (Get-FileHash $TarPath -Algorithm SHA256).Hash
    Write-Host "  SHA256: $hash" -ForegroundColor Gray
} catch {
    Write-Host "ERROR: Failed to compute hash: $_" -ForegroundColor Red
    exit 1
}

##############################################################################
# Create manifest
##############################################################################

Write-Host ""
Write-Host "[2/4] Creating distribution manifest..." -ForegroundColor Yellow

$manifest = @{
    ModernDistributions = @{
        "$Flavor" = @(
            @{
                "Name" = "$Version"
                Default = $true
                FriendlyName = "$FriendlyName"
                Amd64Url = @{
                    Url = "file://$TarPath"
                    Sha256 = "0x$hash"
                }
            })
    }
}

$manifestFile = "$PSScriptRoot\manifest.json"

try {
    $manifest | ConvertTo-Json -Depth 5 | Out-File -Encoding ascii $manifestFile
    Write-Host "  Manifest created: $manifestFile" -ForegroundColor Gray
} catch {
    Write-Host "ERROR: Failed to create manifest: $_" -ForegroundColor Red
    exit 1
}

##############################################################################
# Set registry override
##############################################################################

Write-Host ""
Write-Host "[3/4] Setting WSL registry override..." -ForegroundColor Yellow

$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss"
$regName = "DistributionListUrl"
$regValue = "file://$manifestFile"

try {
    Set-ItemProperty -Path $regPath -Name $regName -Value $regValue -Type String -Force
    Write-Host "  Registry key set successfully" -ForegroundColor Gray
    Write-Host "  Path: $regPath" -ForegroundColor Gray
    Write-Host "  Name: $regName" -ForegroundColor Gray
    Write-Host "  Value: $regValue" -ForegroundColor Gray
} catch {
    Write-Host "ERROR: Failed to set registry key: $_" -ForegroundColor Red
    Write-Host "Make sure you're running as Administrator" -ForegroundColor Red
    exit 1
}

##############################################################################
# Verify
##############################################################################

Write-Host ""
Write-Host "[4/4] Verifying installation..." -ForegroundColor Yellow

Write-Host "  Running 'wsl --list --online'..." -ForegroundColor Gray
Write-Host ""

try {
    & wsl --list --online
} catch {
    Write-Host "WARNING: Could not run wsl --list --online: $_" -ForegroundColor Yellow
}

##############################################################################
# Success message
##############################################################################

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Your distribution should now appear in 'wsl --list --online'" -ForegroundColor White
Write-Host ""
Write-Host "To install for testing:" -ForegroundColor Cyan
Write-Host "  wsl --install $Version" -ForegroundColor Gray
Write-Host ""
Write-Host "To uninstall after testing:" -ForegroundColor Cyan
Write-Host "  wsl --unregister $Version" -ForegroundColor Gray
Write-Host ""
Write-Host "To clean up registry override:" -ForegroundColor Cyan
Write-Host "  Remove-ItemProperty -Path '$regPath' -Name '$regName'" -ForegroundColor Gray
Write-Host ""
Write-Host "Happy testing!" -ForegroundColor Green
Write-Host ""
