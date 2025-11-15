# OOBE Script Research Findings

Research conducted for cachyos-wsl-gqb

## Microsoft's OOBE Sample Analysis

**Source:** build-custom-distro.md lines 124-155

**Key Points:**
- Simple user creation with `adduser` command
- Uses `uid 1000` for default user
- Groups: `adm,cdrom,sudo,dip,plugdev` (Debian-style)
- Checks if user exists before creating (avoids duplication)
- Uses a while loop to retry on failure
- Must return 0 on success (non-zero blocks shell access)

**Structure:**
```bash
#!/bin/bash
set -ue

# Check if user exists
if getent passwd "$DEFAULT_UID" > /dev/null ; then
  exit 0
fi

# Prompt for username
# Create user with adduser
# Add to groups with usermod
```

## Arch Linux Requirements (from Arch Wiki)

### Sudo Access
**Source:** https://wiki.archlinux.org/title/Sudo

**Essential Finding:**
- Use the `wheel` group for administrative access
- Polkit treats wheel group members as administrators by default
- Must configure `/etc/sudoers` to enable wheel group
- Use `visudo` to safely edit sudoers file

**Recommended sudoers configuration:**
```
%wheel      ALL=(ALL:ALL) ALL
```

### User Groups
**Source:** https://wiki.archlinux.org/title/Users_and_groups

**Modern Approach:**
- **wheel**: Essential for sudo/administrative access
- **systemd-journal**: Optional for log access
- **storage**: Optional for removable drives

**Deprecated Groups (don't use):**
- `audio, video, optical, disk, input, kvm`: Handled automatically by udev/logind ACLs
- Adding users to these groups can actually break functionality (e.g., audio breaks fast user switching)

**Key Quote:** "Deprecated in favour of udev marking the devices with a uaccess tag and logind assigning the permissions dynamically via ACLs"

### Package Manager Keyring
**Source:** https://wiki.archlinux.org/title/Pacman/Package_signing

**Required Commands:**
```bash
pacman-key --init      # Initialize keyring (creates local key)
pacman-key --populate  # Populate with distribution keys
```

**When Needed:**
- Required before first pacman use with signature verification
- For CachyOS: `pacman-key --populate archlinux cachyos`
- ALHP would be: `pacman-key --populate alhp` (if using those repos)

**Why It Matters:**
- Establishes web of trust for package verification
- Without this, pacman cannot verify package signatures
- Security critical for package installation

## Decisions for Our Implementation

Based on official documentation (not copying other implementations):

### 1. User Creation
- Use uid 1000
- Add to `wheel` group only (modern approach)
- Use `useradd` (Arch-style) instead of `adduser` (Debian-style)
- Set up home directory
- Prompt for password

### 2. Sudo Configuration
- Configure `/etc/sudoers` to enable wheel group
- Use in-place configuration or document manual setup

### 3. Keyring Initialization
**Decision: YES, initialize in OOBE**

**Reasoning:**
- Users expect pacman to work immediately after first login
- Without keyring, users get confusing signature errors
- One-time setup that prevents frustration
- Official requirement for using pacman with signatures

**Commands:**
```bash
pacman-key --init
pacman-key --populate archlinux cachyos
```

### 4. Locale Configuration
**Decision: Optional enhancement**

This could detect Windows locale and configure Linux to match, but is not essential for basic functionality. Consider for future enhancement.

### 5. Default User in wsl.conf
**Decision: YES, set in OOBE**

The OOBE script should append to `/etc/wsl.conf`:
```
[user]
default=<username>
```

This ensures the user created during OOBE is the default user for subsequent launches.

## Implementation Approach

Our OOBE script should:

1. **Check for existing user** (uid 1000)
2. **Prompt for username**
3. **Create user** with `useradd`:
   - uid 1000
   - wheel group
   - home directory
   - bash shell
4. **Set password** (prompt interactively)
5. **Initialize pacman keyring** (required for package management)
6. **Set default user** in /etc/wsl.conf
7. **Return 0** on success

This gives users a working system with:
- Sudo access (via wheel group)
- Functional package manager (via keyring init)
- Automatic login (via wsl.conf default user)
- Modern device access (via udev/logind, no manual groups needed)

## References

- [Arch Wiki: Sudo](https://wiki.archlinux.org/title/Sudo)
- [Arch Wiki: Users and groups](https://wiki.archlinux.org/title/Users_and_groups)
- [Arch Wiki: Pacman Package signing](https://wiki.archlinux.org/title/Pacman/Package_signing)
- Microsoft WSL Documentation: build-custom-distro.md
