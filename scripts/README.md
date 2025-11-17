# CachyOS WSL Post-Install Scripts

This directory contains helpful scripts for configuring your CachyOS WSL installation.

## Windows Terminal Setup

After installing CachyOS with `wsl --install --from-file`, the Windows Terminal profile isn't automatically created. Use these scripts to set it up manually.

### Quick Setup (Recommended)

```powershell
.\scripts\setup-terminal.ps1
```

This interactive script will:
- Auto-detect your CachyOS distribution
- Ask if you want to set it as the default profile
- Configure Windows Terminal with CachyOS colors and icon

### Advanced Setup

For more control, use the full script:

```powershell
# Basic setup
.\scripts\Setup-WindowsTerminalProfile.ps1

# Set as default profile
.\scripts\Setup-WindowsTerminalProfile.ps1 -SetAsDefault

# Specify distribution name
.\scripts\Setup-WindowsTerminalProfile.ps1 -DistributionName "cachyos"
```

### What It Does

The setup script will:

1. ✅ Verify CachyOS distribution is installed
2. ✅ Check Windows Terminal is available
3. ✅ Export CachyOS icon from WSL to Windows
4. ✅ Read color scheme configuration from distribution
5. ✅ Backup existing Windows Terminal settings
6. ✅ Add CachyOS profile with custom colors
7. ✅ Add CachyOS icon to the profile
8. ✅ Optionally set as default profile

### Requirements

- Windows Terminal (get it from [Microsoft Store](https://aka.ms/terminal))
- CachyOS WSL distribution installed
- PowerShell 5.1 or later

### Backup and Safety

The script automatically creates a timestamped backup of your Windows Terminal settings before making any changes. If something goes wrong, you can restore from:

```
%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json.backup-YYYYMMDD-HHMMSS
```

### Troubleshooting

**"WSL distribution not found"**
- Make sure you've installed CachyOS: `wsl --install --from-file cachyos-v3.wsl`
- Check installed distributions: `wsl --list --verbose`
- Specify the exact name: `-DistributionName "YourDistroName"`

**"Windows Terminal not found"**
- Install Windows Terminal from the [Microsoft Store](https://aka.ms/terminal)
- Or use Windows Terminal Preview

**"Failed to export icon"**
- The script will continue without the icon
- Verify the distribution has the icon at: `/usr/lib/wsl/cachyos.ico`
- You can manually copy it later

### Manual Configuration

If you prefer to configure Windows Terminal manually:

1. Open Windows Terminal settings (Ctrl+,)
2. Click "Add a new profile" → "New empty profile"
3. Set the following:
   - **Name**: CachyOS
   - **Command line**: `wsl.exe -d CachyOS`
   - **Starting directory**: `~`
   - **Icon**: Export `/usr/lib/wsl/cachyos.ico` from WSL
4. Add the color scheme from `/usr/lib/wsl/terminal-profile.json`

## Other Scripts

More scripts will be added here for common post-install tasks.
