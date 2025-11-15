# wsl-distribution.conf Research Findings

Research conducted for cachyos-wsl-zhy

## Microsoft Documentation

**Source:** build-custom-distro.md lines 85-121

### File Purpose
`/etc/wsl-distribution.conf` defines how the Linux distribution should be configured when first launched by the user.

### Configuration Format
INI-style configuration with sections: `[oobe]`, `[shortcut]`, `[windowsterminal]`

### Available Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `oobe.command` | string | None | Command that runs on first interactive shell. Non-zero return prevents shell access |
| `oobe.defaultUid` | integer | None | Default UID the distribution starts with |
| `oobe.defaultName` | string | None | Default name the distribution is registered under |
| `shortcut.enabled` | boolean | true | Whether to create start menu shortcut |
| `shortcut.icon` | string | Default WSL icon | Path to icon file (.ico format, max 10MB) |
| `windowsterminal.enabled` | boolean | true | Whether to create Windows Terminal profile |
| `windowsterminal.profileTemplate` | string | None | JSON template for Windows Terminal profile |

### Microsoft Sample

```ini
[oobe]
command = /etc/oobe.sh
defaultUid = 1000
defaultName = my-distro

[shortcut]
enabled = true
icon = /usr/lib/wsl/my-icon.ico

[windowsterminal]
enabled = true
ProfileTemplate = /usr/lib/wsl/terminal-profile.json
```

**Note:** The Microsoft sample shows `ProfileTemplate` capitalized.

## Path Format

**Question:** Are paths absolute paths in the rootfs or something else?

**Answer:** Yes, paths are absolute paths within the rootfs filesystem.

**Evidence:**
- Microsoft sample uses: `/etc/oobe.sh` and `/usr/lib/wsl/`
- Industry practice (okrc) uses: `/usr/lib/wsl/` for all WSL-specific files
- No indication of relative paths or Windows paths

**Standard Location:** `/usr/lib/wsl/` appears to be the conventional directory for WSL-specific files (OOBE scripts, icons, terminal profiles)

## Field Details

### oobe.command
- **Must be executable**
- **Must return 0 on success** (non-zero blocks shell access)
- Runs only on first interactive shell launch
- Typically used to create user accounts

### oobe.defaultUid
- Should match the UID created in the OOBE script
- **Standard value: 1000** (first non-root user in Linux)

### oobe.defaultName
- Used when installing via double-click (`.wsl` file)
- Can be overridden with: `wsl --install <distro> --name <customname>`
- **Our choice: "cachyos"** or "cachyos-wsl"

### shortcut.icon
- **Format: .ico only**
- **Max size: 10MB**
- Absolute path in rootfs (e.g., `/usr/lib/wsl/cachyos.ico`)
- Optional - WSL provides default if omitted

### windowsterminal.ProfileTemplate
- **Format: JSON file**
- Must NOT include `name` or `commandLine` fields (WSL auto-generates these)
- Can define: color scheme, font, antialiasing, etc.
- Optional - Windows Terminal generates default if omitted

## Best Practices

### File Organization
Use `/usr/lib/wsl/` directory for all WSL-specific files:
- `/usr/lib/wsl/oobe.sh` - OOBE script
- `/usr/lib/wsl/terminal-profile.json` - Terminal template
- `/usr/lib/wsl/cachyos.ico` - Icon file

### File Permissions
- `/etc/wsl-distribution.conf` must be `root:root` with permissions `0644`
- OOBE script must be executable (`0755`)
- Icon and JSON can be `0644`

### Field Capitalization
**Important:** Microsoft docs show inconsistency:
- Table shows: `windowsterminal.profileTemplate` (lowercase)
- Sample shows: `windowsterminal.ProfileTemplate` (capitalized)

**Recommendation:** Use **lowercase** `profileTemplate` to match the table specification and INI conventions.

## Decisions for Our Implementation

### Configuration Values

```ini
[oobe]
command = /usr/lib/wsl/oobe.sh
defaultUid = 1000
defaultName = cachyos

[shortcut]
enabled = true
icon = /usr/lib/wsl/cachyos.ico

[windowsterminal]
enabled = true
profileTemplate = /usr/lib/wsl/terminal-profile.json
```

### Rationale

1. **OOBE path:** `/usr/lib/wsl/oobe.sh` - Standard location, keeps WSL files together
2. **defaultUid:** `1000` - Matches our OOBE script's user creation
3. **defaultName:** `cachyos` - Simple, recognizable, matches distribution name
4. **shortcut.enabled:** `true` - Provide convenient Start Menu access
5. **icon:** `/usr/lib/wsl/cachyos.ico` - Custom branding (when we have the icon)
6. **windowsterminal.enabled:** `true` - Provide custom Terminal experience
7. **profileTemplate:** `/usr/lib/wsl/terminal-profile.json` - Custom colors (when we have it)

### File Structure in Rootfs

```
/etc/
  └── wsl-distribution.conf    (0644, root:root)
/usr/lib/wsl/
  ├── oobe.sh                   (0755, root:root)
  ├── terminal-profile.json     (0644, root:root)
  └── cachyos.ico               (0644, root:root)
```

## References

- [Microsoft: Build a Custom Linux Distribution for WSL](build-custom-distro.md)
- Industry practice: `/usr/lib/wsl/` as standard location
