#Requires -Version 5.1
<#
.SYNOPSIS
    Quick setup script for CachyOS Windows Terminal integration.

.DESCRIPTION
    Simple wrapper around Setup-WindowsTerminalProfile.ps1 for easy post-install configuration.

.EXAMPLE
    .\setup-terminal.ps1
    Interactive setup with prompts

.NOTES
    Run this after installing CachyOS with: wsl --install --from-file cachyos-v3.wsl
#>

param(
    [Parameter()]
    [string]$DistroName
)

Write-Host ""
Write-Host "CachyOS Windows Terminal Setup" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""

# Auto-detect distribution name if not provided
if (-not $DistroName) {
    Write-Host "Detecting CachyOS distributions..." -ForegroundColor Yellow
    $distros = wsl --list --quiet | Where-Object { $_ -match "cachy" -or $_ -match "CachyOS" }

    if ($distros.Count -eq 0) {
        Write-Host ""
        Write-Host "No CachyOS distribution found. Please specify the distribution name." -ForegroundColor Red
        Write-Host ""
        Write-Host "Available distributions:" -ForegroundColor Yellow
        wsl --list --verbose
        Write-Host ""
        $DistroName = Read-Host "Enter the distribution name"
    } elseif ($distros.Count -eq 1) {
        $DistroName = $distros[0].Trim()
        Write-Host "Found: $DistroName" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "Multiple CachyOS distributions found:" -ForegroundColor Yellow
        $distros | ForEach-Object { Write-Host "  - $_" -ForegroundColor Cyan }
        Write-Host ""
        $DistroName = Read-Host "Enter the distribution name to configure"
    }
}

Write-Host ""
$makeDefault = Read-Host "Set CachyOS as default Windows Terminal profile? (y/N)"
$setAsDefaultSwitch = if ($makeDefault -match "^[Yy]") { "-SetAsDefault" } else { "" }

Write-Host ""
Write-Host "Starting setup..." -ForegroundColor Cyan

# Run the main setup script
$scriptPath = Join-Path $PSScriptRoot "Setup-WindowsTerminalProfile.ps1"

if (Test-Path $scriptPath) {
    if ($setAsDefaultSwitch) {
        & $scriptPath -DistributionName $DistroName -SetAsDefault
    } else {
        & $scriptPath -DistributionName $DistroName
    }
} else {
    Write-Host "Error: Setup-WindowsTerminalProfile.ps1 not found!" -ForegroundColor Red
    Write-Host "Expected at: $scriptPath" -ForegroundColor Red
    exit 1
}
