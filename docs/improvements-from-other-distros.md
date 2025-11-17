# Potential Improvements Based on Fedora and Arch Linux WSL

This document catalogs improvements we could consider based on analysis of the official Fedora and Arch Linux WSL distributions.

## 1. OOBE Script Improvements (from Fedora)

### Current State
Our OOBE script (config/oobe.sh) has:
- ✅ Good username validation
- ✅ User creation with configurable UID
- ✅ Password setting
- ✅ Sudo configuration via wheel group
- ✅ Pacman keyring initialization
- ⚠️ Basic error handling

### Fedora's Approach
```bash
rc=$(
  set +e
  /usr/sbin/useradd -m -G wheel --uid "$DEFAULT_USER_ID" "$username" > /dev/null
  echo $?
)

case $rc in
  3 | 19)  # Invalid argument / Bad login name
    echo "Invalid username..."
    continue
    ;;
  9)  # Username already in use
    echo "User \"$username\" already exists"
    continue
    ;;
  0)
    break
    ;;
  *)
    echo "Unexpected error code from useradd: $rc"
    break
    ;;
esac
```

### Recommendation
**Medium priority**: Consider adding specific error code handling in our OOBE:

```bash
# After line 67 in config/oobe.sh, replace simple if/else with:
rc=$?
case $rc in
    0)
        # Success - continue to password setting
        ;;
    3|19)
        echo "Error: Invalid username format."
        continue
        ;;
    9)
        echo "Error: User \"$username\" already exists. Please choose a different username."
        continue
        ;;
    *)
        echo "Error: Failed to create user (exit code: $rc). Please try a different username."
        continue
        ;;
esac
```

**Benefit**: More informative error messages, better UX
**Risk**: Low (minor change)

---

## 2. Check for Existing UID Before User Creation (from Fedora)

### Current State
We don't check if UID 1000 already exists before entering the user creation loop.

### Fedora's Approach
```bash
if getent passwd $DEFAULT_USER_ID > /dev/null ; then
  echo 'User account already exists, skipping creation'
  exit 0
fi
```

### Recommendation
**High priority**: Add this check at the beginning of our OOBE (after locale setup, before the "while true" loop):

```bash
# After line 43 in config/oobe.sh, add:
# Check if default user already exists
if getent passwd "$DEFAULT_UID" > /dev/null; then
    existing_user=$(getent passwd "$DEFAULT_UID" | cut -d: -f1)
    echo "Default user already exists: $existing_user (UID $DEFAULT_UID)"
    echo "Skipping user creation."
    exit 0
fi
```

**Benefit**: Handles re-runs of OOBE gracefully, avoids confusing errors
**Risk**: Very low (defensive programming)

---

## 3. Less Aggressive systemd Masking (from Arch Linux)

### Current State (config/oobe.sh:231-263)
We mask many systemd services based on Microsoft's recommendations:
```bash
systemctl mask systemd-resolved.service
systemctl mask systemd-networkd.service
systemctl mask systemd-tmpfiles-setup.service
systemctl mask systemd-tmpfiles-clean.timer
# ... and more
```

### Arch Linux's Approach
Arch only masks:
```bash
systemctl mask systemd-firstboot console-getty
ln -sf /dev/null /etc/systemd/system/getty@.service
ln -sf /dev/null /etc/systemd/system/serial-getty@.service
```

### Analysis
- **Arch doesn't mask tmpfiles** - yet WSL works fine for them
- **Fedora doesn't mask tmpfiles either** - they use it for WSLg
- **Both distros ignore Microsoft's conservative guidance** - successfully

### Recommendation
**Low priority (future consideration)**: If we implement Option 3 from systemd-user-sessions-wslg.md, we could:
1. Unmask systemd-tmpfiles-* services
2. Use tmpfiles.d for WSLg socket symlinks (like Fedora)
3. Keep masking: systemd-resolved, systemd-networkd, NetworkManager (these genuinely conflict)

**Benefit**: More systemd functionality available
**Risk**: Medium (need thorough testing)
**Status**: Document for future, keep current conservative approach for now

---

## 4. Tar Exclude List Improvements (from Arch Linux)

### Current State
We don't have a formal exclude list for tar creation yet.

### Arch Linux's Exclude List
```
./sys
./proc
./dev
./etc/hostname
./etc/machine-id
./etc/resolv.conf
./etc/pacman.d/gnupg/openpgp-revocs.d/*
./etc/pacman.d/gnupg/private-keys-v1.d/*
./etc/pacman.d/gnupg/pubring.gpg~
./etc/pacman.d/gnupg/S.*
./root/*
./tmp/*
./var/cache/pacman/pkg/*
./var/lib/pacman/sync/*
./var/tmp/*
./alpm-hooks
```

### Recommendation
**High priority**: Create a formal exclude list when we implement tar packaging:

`scripts/tar-exclude.txt`:
```
# Virtual filesystems (WSL provides these)
./sys
./proc
./dev

# Runtime files (WSL generates these)
./etc/hostname
./etc/machine-id
./etc/resolv.conf

# GPG private keys and sockets (security + regenerated anyway)
./etc/pacman.d/gnupg/openpgp-revocs.d/*
./etc/pacman.d/gnupg/private-keys-v1.d/*
./etc/pacman.d/gnupg/pubring.gpg~
./etc/pacman.d/gnupg/S.*

# User data (shouldn't be in distribution)
./root/*
./home/*

# Temporary files
./tmp/*
./var/tmp/*

# Cache files (waste space in distribution)
./var/cache/pacman/pkg/*
./var/lib/pacman/sync/*

# Build artifacts
./var/log/*
```

Then use: `tar --exclude-from=scripts/tar-exclude.txt ...`

**Benefit**: Smaller distribution size, better security, cleaner image
**Risk**: Very low (follows established patterns)

---

## 5. Build Process with fakechroot/fakeroot (from Arch Linux)

### Current State
No formal build process yet.

### Arch Linux's Approach
```bash
fakechroot -- fakeroot -- \
    pacman -Sy -r "$BUILDDIR" \
        --noconfirm --dbpath "$BUILDDIR/var/lib/pacman" \
        --config "$WORKDIR/pacman.conf" \
        --noscriptlet \
        --hookdir "$BUILDDIR/alpm-hooks/usr/share/libalpm/hooks/" base

# Use fakeroot to map the gid / uid of the builder process to root
fakeroot -- \
    tar \
        --numeric-owner \
        --xattrs \
        --acls \
        --exclude-from=scripts/exclude \
        -C "$BUILDDIR" \
        -c . \
        -f "$OUTPUTDIR/archlinux-$IMAGE_VERSION.tar"
```

### Recommendation
**High priority**: When implementing automated builds, use fakechroot/fakeroot to:
- Build rootfs without requiring actual root privileges
- Properly preserve ownership (UID 0 for root files)
- Include extended attributes and ACLs

**Implementation**: Create `scripts/build.sh` based on Arch's approach but adapted for CachyOS packages.

**Benefit**: Reproducible builds, no root required, proper file ownership
**Risk**: Low (proven approach used by Arch)

---

## 6. X11 Socket Symlink via tmpfiles.d (from Fedora)

### Current State
No explicit X11 socket configuration.

### Fedora's Approach
`/etc/tmpfiles.d/wslg-system.conf`:
```
L /tmp/.X11-unix - - - - /mnt/wslg/.X11-unix
```

### Recommendation
**Medium priority**: Add this configuration to ensure X11 apps work properly:

Create `config/tmpfiles.d/wslg-x11.conf`:
```
# Symlink WSLg X11 socket directory
L /tmp/.X11-unix - - - - /mnt/wslg/.X11-unix
```

**Benefit**: Explicit X11 support (may already work implicitly)
**Risk**: Very low (just a symlink)

---

## 7. Shell Selection in OOBE (Consideration)

### Current State
We hardcode Fish shell in OOBE:
```bash
--shell /usr/bin/fish \
```

### Consideration
Should we let users choose their shell during OOBE? Fedora doesn't, Arch doesn't, but we're uniquely promoting Fish/Zsh.

### Recommendation
**Low priority**: Consider offering shell selection:
```bash
echo "Choose default shell:"
echo "1) Fish (recommended - modern, user-friendly)"
echo "2) Zsh (powerful, highly customizable)"
echo "3) Bash (traditional, widely compatible)"
read -p "Selection [1-3]: " shell_choice

case $shell_choice in
    2) user_shell="/usr/bin/zsh" ;;
    3) user_shell="/bin/bash" ;;
    *) user_shell="/usr/bin/fish" ;;
esac
```

**Benefit**: More user choice, better for Bash purists
**Drawback**: More complexity, may confuse new users
**Status**: Consider for future enhancement

---

## 8. Package Groups to Include (Analysis)

### Arch Linux WSL Packages
Arch uses minimal `base` group only.

### CachyOS Considerations
We should document what packages to include beyond base:

**Essential**:
- `base` - Base system
- `fish`, `zsh` - Shell support
- `sudo` - Privilege escalation
- `nano` or `vim` - Text editor

**Recommended**:
- `git` - Version control
- `base-devel` - Compilation tools (make, gcc, etc.)
- `wget`, `curl` - Download tools
- `man-db`, `man-pages` - Documentation

**GUI Support** (optional, for users wanting GUI apps):
- `mesa` - OpenGL support for WSLg
- `vulkan-*` - Vulkan support for GPU acceleration

### Recommendation
**High priority**: Document our package selection philosophy in `docs/package-selection.md`.

---

## 9. Compression Method (from Arch Linux)

### Current State
CLAUDE.md suggests: `gzip --best`

### Arch Linux's Approach
```bash
tar -c . -f "$OUTPUTDIR/archlinux-$IMAGE_VERSION.tar"
xz -T0 -9 "archlinux-$IMAGE_VERSION.tar"
```

Uses **xz compression** with:
- `-T0` - Use all CPU cores
- `-9` - Maximum compression

### Analysis
- **gzip**: Faster decompression, widely compatible, larger file
- **xz**: Better compression (~30-40% smaller), slower, still compatible with WSL

### Recommendation
**Medium priority**: Use xz compression for distribution release:

```bash
tar --numeric-owner --exclude-from=scripts/tar-exclude.txt -C "$ROOTFS" -cf cachyos.tar .
xz -T0 -9 cachyos.tar
mv cachyos.tar.xz cachyos.wsl
```

**Benefit**: Significantly smaller download size
**Drawback**: Slightly slower installation (one-time cost)
**WSL Compatibility**: WSL supports .tar, .tar.gz, .tar.xz, .tar.zst

---

## 10. Signature/Checksum File (from Arch Linux)

### Arch Linux's Approach
```bash
sha256sum "archlinux-$IMAGE_VERSION.wsl" > "archlinux-$IMAGE_VERSION.wsl.SHA256"
```

They also use Sigstore Cosign for cryptographic signing.

### Recommendation
**High priority**: Generate checksums for releases:

```bash
# In build script
sha256sum cachyos-${VERSION}.wsl > cachyos-${VERSION}.wsl.sha256
sha512sum cachyos-${VERSION}.wsl > cachyos-${VERSION}.wsl.sha512
```

**Future**: Consider GPG signing or Sigstore for verification.

**Benefit**: Users can verify download integrity
**Risk**: None (just additional files)

---

## Priority Summary

### Implement Soon (High Priority)
1. ✅ Check for existing UID before user creation (OOBE improvement)
2. ✅ Create formal tar exclude list
3. ✅ Build process with fakechroot/fakeroot
4. ✅ Document package selection philosophy
5. ✅ Generate SHA256/SHA512 checksums

### Consider Next (Medium Priority)
6. ⚠️ Improve OOBE error handling with specific exit codes
7. ⚠️ Add X11 socket tmpfiles.d configuration
8. ⚠️ Use xz compression for smaller distribution size

### Future Enhancements (Low Priority)
9. 📋 Shell selection in OOBE
10. 📋 Less aggressive systemd masking (requires Option 3 implementation)

---

## What CachyOS WSL Does Better

It's worth noting areas where our implementation is already superior:

### ✅ Locale Detection and Configuration
Neither Fedora nor Arch automatically detect and configure locales. We do:
```bash
# Detect Windows locale
lang_code=$(powershell.exe -NoProfile -Command '[System.Globalization.CultureInfo]::CurrentCulture.Name' 2>/dev/null | tr -d '\r')
```

### ✅ Multi-Shell Support
We provide first-class Fish and Zsh configurations. Others focus on Bash only.

### ✅ Comprehensive WSLg Configuration
Our shell configs explicitly set WAYLAND_DISPLAY and DISPLAY. Others rely on defaults.

### ✅ Better User Documentation
Our OOBE has more helpful messages and links to wiki.cachyos.org.

### ✅ Modern Shell Defaults
We default to Fish (beginner-friendly, modern). Others use Bash.

---

## Implementation Checklist

When implementing these improvements:

- [ ] Create `scripts/tar-exclude.txt` based on Arch's list
- [ ] Add UID existence check to OOBE script
- [ ] Improve OOBE error handling
- [ ] Create build script with fakechroot/fakeroot
- [ ] Add X11 tmpfiles.d configuration
- [ ] Document package selection in new doc
- [ ] Generate checksums in build process
- [ ] Consider xz compression for releases
- [ ] Test all changes in WSL environment
- [ ] Update CLAUDE.md with new build process

---

## References

- [Arch Linux WSL - build-image.sh](https://gitlab.archlinux.org/archlinux/archlinux-wsl/-/blob/main/scripts/build-image.sh)
- [Arch Linux WSL - exclude list](https://gitlab.archlinux.org/archlinux/archlinux-wsl/-/blob/main/scripts/exclude)
- [Fedora WSL - wsl-oobe.sh](https://src.fedoraproject.org/rpms/wsl-setup/blob/main/f/wsl-oobe.sh)
- [Fedora WSL - spec file](https://src.fedoraproject.org/rpms/wsl-setup/blob/main/f/wsl-setup.spec)
