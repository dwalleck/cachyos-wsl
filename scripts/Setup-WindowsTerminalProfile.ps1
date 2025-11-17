#Requires -Version 5.1
<#
.SYNOPSIS
    Sets up Windows Terminal profile for CachyOS WSL distribution.

.DESCRIPTION
    This script configures Windows Terminal with a custom profile for CachyOS,
    including the CachyOS color scheme and icon. It safely modifies the Windows
    Terminal settings.json file, creating a backup before making changes.

.PARAMETER DistributionName
    The name of the WSL distribution (default: "CachyOS")

.PARAMETER SetAsDefault
    If specified, sets the CachyOS profile as the default profile in Windows Terminal

.EXAMPLE
    .\Setup-WindowsTerminalProfile.ps1
    Sets up the CachyOS profile in Windows Terminal

.EXAMPLE
    .\Setup-WindowsTerminalProfile.ps1 -SetAsDefault
    Sets up the CachyOS profile and makes it the default

.EXAMPLE
    .\Setup-WindowsTerminalProfile.ps1 -DistributionName "cachyos"
    Sets up profile for a distribution named "cachyos"

.NOTES
    Author: CachyOS WSL Team
    Requires: Windows Terminal, WSL 2, CachyOS distribution installed
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$DistributionName = "CachyOS",

    [Parameter()]
    [switch]$SetAsDefault
)

$ErrorActionPreference = "Stop"

#region Helper Functions

function Write-Status {
    param([string]$Message, [string]$Type = "Info")

    switch ($Type) {
        "Success" { Write-Host "✅ $Message" -ForegroundColor Green }
        "Error"   { Write-Host "❌ $Message" -ForegroundColor Red }
        "Warning" { Write-Host "⚠️  $Message" -ForegroundColor Yellow }
        "Info"    { Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
        default   { Write-Host $Message }
    }
}

function Test-WSLDistribution {
    param([string]$Name)

    $distributions = wsl --list --quiet
    return $distributions -contains $Name
}

function Get-WindowsTerminalSettingsPath {
    # Windows Terminal settings location
    $wtPackage = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe"

    if (Test-Path $wtPackage) {
        return Join-Path $wtPackage "LocalState\settings.json"
    }

    # Try Windows Terminal Preview
    $wtPreviewPackage = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe"
    if (Test-Path $wtPreviewPackage) {
        return Join-Path $wtPreviewPackage "LocalState\settings.json"
    }

    return $null
}

function Export-WSLFile {
    param(
        [string]$DistributionName,
        [string]$WSLPath,
        [string]$WindowsPath
    )

    # Export file from WSL to Windows
    $tempFile = New-TemporaryFile
    wsl -d $DistributionName --exec cat $WSLPath > $tempFile.FullName

    if (Test-Path $tempFile.FullName) {
        Move-Item -Path $tempFile.FullName -Destination $WindowsPath -Force
        return $true
    }

    return $false
}

#endregion

#region Main Script

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "CachyOS Windows Terminal Profile Setup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check if WSL distribution exists
Write-Status "Checking for WSL distribution: $DistributionName" "Info"
if (-not (Test-WSLDistribution -Name $DistributionName)) {
    Write-Status "WSL distribution '$DistributionName' not found" "Error"
    Write-Host ""
    Write-Host "Available distributions:"
    wsl --list --verbose
    Write-Host ""
    Write-Host "Please install CachyOS first or specify the correct distribution name with -DistributionName"
    exit 1
}
Write-Status "Found distribution: $DistributionName" "Success"

# Check if Windows Terminal is installed
Write-Status "Checking for Windows Terminal" "Info"
$settingsPath = Get-WindowsTerminalSettingsPath
if (-not $settingsPath) {
    Write-Status "Windows Terminal not found" "Error"
    Write-Host ""
    Write-Host "Please install Windows Terminal from the Microsoft Store:"
    Write-Host "https://aka.ms/terminal"
    exit 1
}
Write-Status "Found Windows Terminal settings: $settingsPath" "Success"

# Create directory for CachyOS assets
$cachyosAssetsDir = Join-Path $env:LOCALAPPDATA "CachyOS\WSL"
if (-not (Test-Path $cachyosAssetsDir)) {
    Write-Status "Creating assets directory: $cachyosAssetsDir" "Info"
    New-Item -ItemType Directory -Path $cachyosAssetsDir -Force | Out-Null
}

# Export icon from WSL
Write-Status "Exporting CachyOS icon" "Info"
$iconPath = Join-Path $cachyosAssetsDir "cachyos.ico"
$exported = Export-WSLFile -DistributionName $DistributionName `
                          -WSLPath "/usr/lib/wsl/cachyos.ico" `
                          -WindowsPath $iconPath

if (-not $exported -or -not (Test-Path $iconPath)) {
    Write-Status "Failed to export icon from WSL" "Warning"
    $iconPath = $null
} else {
    Write-Status "Icon exported to: $iconPath" "Success"
}

# Read terminal profile template from WSL
Write-Status "Reading terminal profile configuration" "Info"
$profileJson = wsl -d $DistributionName --exec cat /usr/lib/wsl/terminal-profile.json 2>$null

if (-not $profileJson) {
    Write-Status "Failed to read terminal-profile.json from WSL" "Error"
    Write-Status "This file should be at /usr/lib/wsl/terminal-profile.json" "Info"
    exit 1
}

try {
    $profileTemplate = $profileJson | ConvertFrom-Json
} catch {
    Write-Status "Failed to parse terminal-profile.json: $_" "Error"
    exit 1
}

# Backup existing settings
Write-Status "Creating backup of Windows Terminal settings" "Info"
$backupPath = "$settingsPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item -Path $settingsPath -Destination $backupPath -Force
Write-Status "Backup created: $backupPath" "Success"

# Read current Windows Terminal settings
Write-Status "Reading Windows Terminal settings" "Info"
try {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
} catch {
    Write-Status "Failed to read Windows Terminal settings: $_" "Error"
    Write-Status "Restoring backup" "Warning"
    Copy-Item -Path $backupPath -Destination $settingsPath -Force
    exit 1
}

# Get WSL distribution GUID for the profile
Write-Status "Getting distribution GUID" "Info"
$wslConfig = wsl -d $DistributionName --exec cat /etc/wsl-distribution.conf 2>$null
$distroGuid = [guid]::NewGuid().ToString()  # Fallback GUID

# Create the new profile
$newProfile = @{
    "name" = $DistributionName
    "commandline" = "wsl.exe -d $DistributionName"
    "hidden" = $false
    "startingDirectory" = "~"
}

# Add color scheme from template
if ($profileTemplate.profiles -and $profileTemplate.profiles[0].colorScheme) {
    $newProfile["colorScheme"] = $profileTemplate.profiles[0].colorScheme
}

# Add icon if we have it
if ($iconPath -and (Test-Path $iconPath)) {
    $newProfile["icon"] = $iconPath
}

# Add or update the color scheme in settings
if ($profileTemplate.schemes -and $profileTemplate.schemes.Count -gt 0) {
    Write-Status "Adding CachyOS color scheme" "Info"

    if (-not $settings.schemes) {
        $settings | Add-Member -MemberType NoteProperty -Name "schemes" -Value @()
    }

    $colorScheme = $profileTemplate.schemes[0]

    # Remove existing CachyOS scheme if present
    $settings.schemes = @($settings.schemes | Where-Object { $_.name -ne $colorScheme.name })

    # Add the new scheme
    $settings.schemes += $colorScheme
    Write-Status "Color scheme '$($colorScheme.name)' added" "Success"
}

# Add or update the profile
Write-Status "Adding CachyOS profile to Windows Terminal" "Info"

if (-not $settings.profiles) {
    Write-Status "Invalid settings.json structure" "Error"
    Copy-Item -Path $backupPath -Destination $settingsPath -Force
    exit 1
}

# Handle both old and new settings format
$profilesList = $settings.profiles
if ($settings.profiles.list) {
    $profilesList = $settings.profiles.list
}

# Remove existing CachyOS profile if present
$profilesList = @($profilesList | Where-Object { $_.name -ne $DistributionName })

# Add new profile
$profilesList += $newProfile

# Update settings
if ($settings.profiles.list) {
    $settings.profiles.list = $profilesList
} else {
    $settings.profiles = $profilesList
}

Write-Status "Profile '$DistributionName' added" "Success"

# Set as default if requested
if ($SetAsDefault) {
    Write-Status "Setting CachyOS as default profile" "Info"

    # Find the profile GUID or use the name
    $defaultProfile = $DistributionName

    $settings | Add-Member -MemberType NoteProperty -Name "defaultProfile" -Value $defaultProfile -Force
    Write-Status "CachyOS set as default profile" "Success"
}

# Save updated settings
Write-Status "Saving Windows Terminal settings" "Info"
try {
    $settings | ConvertTo-Json -Depth 100 | Set-Content -Path $settingsPath -Encoding UTF8
    Write-Status "Settings saved successfully" "Success"
} catch {
    Write-Status "Failed to save settings: $_" "Error"
    Write-Status "Restoring backup" "Warning"
    Copy-Item -Path $backupPath -Destination $settingsPath -Force
    exit 1
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "✅ CachyOS profile has been added to Windows Terminal" -ForegroundColor Green
Write-Host ""
Write-Host "You can now:"
Write-Host "  1. Open Windows Terminal" -ForegroundColor Cyan
Write-Host "  2. Click the dropdown (˅) next to the tabs" -ForegroundColor Cyan
Write-Host "  3. Select '$DistributionName' from the list" -ForegroundColor Cyan
Write-Host ""

if ($SetAsDefault) {
    Write-Host "✨ CachyOS is now your default profile!" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "Backup saved at:" -ForegroundColor Gray
Write-Host "  $backupPath" -ForegroundColor Gray
Write-Host ""

#endregion
