# PowerShell Test Script Research Findings

Research conducted for cachyos-wsl-1pf

## Microsoft Sample Script Analysis

**Source:** build-custom-distro.md lines 336-370

### Script Overview

The sample PowerShell script (`override-manifest.ps1`) allows testing a custom WSL distribution locally without publishing to the Microsoft Store. It works by overriding the WSL distribution list with a local manifest file.

### How It Works

#### 1. SHA256 Hash Computation

```powershell
$TarPath = Resolve-Path $TarPath
$hash = (Get-Filehash $TarPath -Algorithm SHA256).Hash
```

**Key Points:**
- Uses `Get-Filehash` cmdlet with SHA256 algorithm
- Resolves the full path first with `Resolve-Path`
- Extracts just the `.Hash` property (hex string)
- Hash is prefixed with `0x` when used in manifest

#### 2. Manifest.json Format

The manifest is a nested PowerShell hashtable that gets converted to JSON:

```powershell
$manifest= @{
    ModernDistributions=@{
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
```

**Structure:**
- **ModernDistributions**: Top-level container
- **Flavor**: Distribution family name (e.g., "cachyos")
- **Array of versions**: Each flavor can have multiple versions
  - **Name**: Version identifier (shows in `wsl --list --online`)
  - **Default**: Boolean indicating if this is the default version
  - **FriendlyName**: Human-readable description
  - **Amd64Url**: Object containing download info
    - **Url**: File path as `file://` URL
    - **Sha256**: Hash prefixed with `0x`

**JSON Output:**
```json
{
  "ModernDistributions": {
    "cachyos": [
      {
        "Name": "cachyos-v1",
        "Default": true,
        "FriendlyName": "CachyOS WSL Distribution",
        "Amd64Url": {
          "Url": "file://C:/path/to/cachyos.wsl",
          "Sha256": "0xABCD1234..."
        }
      }
    ]
  }
}
```

#### 3. Registry Override Mechanism

```powershell
Set-ItemProperty -Path "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss" `
    -Name DistributionListUrl `
    -Value "file://$manifestFile" `
    -Type String `
    -Force
```

**How It Works:**
- WSL checks the registry key `DistributionListUrl` for the distribution manifest URL
- Normally points to Microsoft's official manifest
- Override points it to a local `file://` URL
- WSL reads the local manifest instead of fetching from Microsoft
- Distribution appears in `wsl --list --online` output

**Registry Key:**
- **Path**: `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss`
- **Name**: `DistributionListUrl`
- **Type**: String
- **Value**: `file://C:/path/to/manifest.json`

#### 4. Cleanup Procedure

**Source:** build-custom-distro.md line 391

To revert to the official manifest after testing:

```powershell
# In elevated PowerShell:
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss" -Name DistributionListUrl
```

**Important:**
- Must run in elevated (Administrator) PowerShell
- Deletes the registry override
- WSL reverts to using Microsoft's official distribution list
- Any installed test distributions remain installed (uninstall separately if needed)

### Script Parameters

The Microsoft sample uses these parameters:

```powershell
param (
    [Parameter(Mandatory = $true)][string]$TarPath,
    [string]$Flavor = "test-distro",
    [string]$Version = "test-distro-v1",
    [string]$FriendlyName = "Test distribution version 1"
)
```

**For Our Implementation:**
- **TarPath**: Path to our `.wsl` file (mandatory)
- **Flavor**: `"cachyos"` (distribution family)
- **Version**: `"cachyos-wsl-v1"` or similar
- **FriendlyName**: `"CachyOS WSL Distribution"` or more descriptive

### Testing Workflow

1. **Build the .wsl file**
   ```bash
   make rootfs
   cd dist
   mv cachyos-v3-rootfs.tar.gz cachyos.wsl
   ```

2. **Run the override script** (elevated PowerShell)
   ```powershell
   .\override-manifest.ps1 -TarPath C:\path\to\cachyos.wsl
   ```

3. **Verify distribution appears**
   ```powershell
   wsl --list --online
   ```

4. **Install for testing**
   ```powershell
   wsl --install cachyos-wsl-v1
   ```

5. **Test the OOBE experience**
   - Create user account
   - Verify sudo access
   - Test package manager
   - Check systemd status

6. **Clean up registry** (when done testing)
   ```powershell
   Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss" -Name DistributionListUrl
   ```

7. **Uninstall test distribution** (optional)
   ```powershell
   wsl --unregister cachyos-wsl-v1
   ```

## Implementation Notes

### Script Location

Create as: `scripts/override-manifest.ps1`

### Enhancements to Consider

1. **Auto-detect architecture** from tar filename
2. **Validate .wsl file exists** before proceeding
3. **Check if running as Administrator** with helpful error
4. **Backup existing registry value** before overriding
5. **Provide restore script** to revert changes

### Security Considerations

- Script requires Administrator privileges (uses `#Requires -RunAsAdministrator`)
- Modifying HKLM registry requires elevation
- File:// URLs must use absolute paths
- SHA256 hash ensures file integrity

## References

- [Microsoft: Build a Custom Linux Distribution for WSL](../build-custom-distro.md) lines 336-391
- PowerShell cmdlets: `Get-FileHash`, `Set-ItemProperty`, `Remove-ItemProperty`
