# Systemd User Sessions and WSLg Integration Approaches

## Background

WSL 2 with WSLg (GUI applications support) mounts graphical and audio sockets at `/mnt/wslg/runtime-dir/`:
- `wayland-0` - Wayland compositor socket
- `pulse/` - PulseAudio socket directory
- `bus` - D-Bus session bus socket

GUI applications expect these to be available via `XDG_RUNTIME_DIR`, which is traditionally `/run/user/$UID` (e.g., `/run/user/1000`).

### The Conflict

When systemd is enabled in WSL, there's a fundamental conflict between:
1. **WSL's WSLg mount**: WSL mounts `/mnt/wslg/runtime-dir` at `/run/user/1000`
2. **Systemd user sessions**: `pam_systemd` creates `/run/user/1000` as a tmpfs mount and populates it with session files

When both are active, one overwrites the other, causing either:
- WSLg sockets disappear → GUI apps fail
- Systemd session files disappear → `systemctl --user` fails, D-Bus session issues

### Microsoft's Official Guidance

From [Microsoft Learn - Build a Custom WSL Distro](https://learn.microsoft.com/en-us/windows/wsl/build-custom-distro#systemd-recommendations):

> If systemd is enabled, units that can cause issues with WSL should be disabled or masked.

Recommended to disable/mask:
- `systemd-resolved.service`
- `systemd-networkd.service`
- `NetworkManager.service`
- `systemd-tmpfiles-setup.service`
- `systemd-tmpfiles-clean.service`
- `systemd-tmpfiles-clean.timer`
- `systemd-tmpfiles-setup-dev-early.service`
- `systemd-tmpfiles-setup-dev.service`
- `tmp.mount`

**Note**: This guidance focuses on avoiding conflicts, but at the cost of disabling systemd features.

## Approach Comparison

| Feature | Option 1: Simple Shell Env | Option 2: Microsoft Recommended | Option 3: Full Systemd + Workaround |
|---------|---------------------------|--------------------------------|-------------------------------------|
| **Systemd enabled** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Systemd user sessions** | ❌ No (disabled) | ❌ No (disabled) | ✅ Yes (with workaround) |
| **systemd-tmpfiles** | ❌ Masked | ❌ Masked (per Microsoft) | ✅ Enabled |
| **XDG_RUNTIME_DIR** | Shell configs | Shell configs | pam_systemd |
| **WSLg socket access** | Direct path | Direct path | Symlinks via tmpfiles.d |
| **systemctl --user works** | ❌ No | ❌ No | ✅ Yes |
| **User timers/services** | ❌ No | ❌ No | ✅ Yes |
| **Complexity** | Low | Low | Medium |
| **Reliability** | High | High | Medium (requires workaround) |

## Option 1: Simple Shell Environment Variables (Current Implementation)

### Overview
Directly point shell environments to WSLg's runtime directory, avoiding systemd user sessions entirely.

### Implementation

**1. Disable problematic systemd units** (already in OOBE script):
```bash
# Mask systemd user session services
systemctl mask systemd-tmpfiles-setup.service
systemctl mask systemd-tmpfiles-clean.timer
systemctl mask user@.service
```

**2. Set environment variables in shell configs**:

`/etc/fish/conf.d/wsl.fish`:
```fish
# WSLg support
if test -d /mnt/wslg/runtime-dir
    set -gx XDG_RUNTIME_DIR /mnt/wslg/runtime-dir
    set -gx WAYLAND_DISPLAY wayland-0
    set -gx DISPLAY :0
end
```

`/etc/zsh/zshenv.d/wsl.zsh`:
```zsh
# WSLg support
if [[ -d /mnt/wslg/runtime-dir ]]; then
    export XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir
    export WAYLAND_DISPLAY=wayland-0
    export DISPLAY=:0
fi
```

`/etc/profile.d/wsl.sh`:
```bash
# WSLg support
if [[ -d /mnt/wslg/runtime-dir ]]; then
    export XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir
    export WAYLAND_DISPLAY=wayland-0
    export DISPLAY=:0
fi
```

### Pros
- ✅ Simple, minimal configuration
- ✅ No systemd conflicts
- ✅ Reliable WSLg support
- ✅ Works immediately on every shell launch
- ✅ No complex systemd workarounds needed

### Cons
- ❌ `systemctl --user` doesn't work
- ❌ No systemd user timers/services available
- ❌ Less "native Linux" behavior

### Best For
- Users who primarily want GUI apps to work
- Distributions prioritizing simplicity and reliability
- Environments where systemd user services aren't needed

## Option 2: Microsoft's Recommended Approach

### Overview
Follow Microsoft's official guidance by masking tmpfiles services while using shell environment variables.

### Implementation

**1. Mask all recommended services** (in OOBE script or systemd presets):
```bash
systemctl mask systemd-resolved.service
systemctl mask systemd-networkd.service
systemctl mask NetworkManager.service
systemctl mask systemd-tmpfiles-setup.service
systemctl mask systemd-tmpfiles-clean.service
systemctl mask systemd-tmpfiles-clean.timer
systemctl mask systemd-tmpfiles-setup-dev-early.service
systemctl mask systemd-tmpfiles-setup-dev.service
systemctl mask tmp.mount
systemctl mask user@.service
```

**2. Use shell environment variables** (same as Option 1)

### Pros
- ✅ Follows official Microsoft guidance
- ✅ Avoids known WSL-systemd conflicts
- ✅ Reliable WSLg support
- ✅ Well-documented approach

### Cons
- ❌ Loses tmpfiles functionality entirely
- ❌ No systemd user sessions
- ❌ May be overly conservative (some distros ignore this)

### Best For
- Conservative deployments prioritizing stability
- Following vendor recommendations strictly
- Minimal surprise/debugging

## Option 3: Full Systemd with User Sessions (Advanced)

### Overview
Enable full systemd functionality including user sessions by working around the `/run/user/$UID` conflict.

### Implementation

**1. Keep systemd enabled** (`/etc/wsl.conf`):
```ini
[boot]
systemd=true
```

**2. Apply user-runtime-dir workaround**:

Create `/lib/systemd/system/user-runtime-dir@.service.d/override.conf`:
```ini
[Unit]
# Don't try to create runtime dir if WSL already mounted it
ConditionPathIsMountPoint=!/run/user/%i
```

**3. Use systemd-tmpfiles.d for WSLg symlinks**:

Create `/etc/tmpfiles.d/wslg.conf`:
```
# Symlink WSLg sockets into user runtime directory
L+ /run/user/%U/wayland-0.lock - - - - /mnt/wslg/runtime-dir/wayland-0.lock
L+ /run/user/%U/wayland-0 - - - - /mnt/wslg/runtime-dir/wayland-0
L+ /run/user/%U/pulse - - - - /mnt/wslg/runtime-dir/pulse
```

Create `/etc/tmpfiles.d/wslg-system.conf`:
```
# Symlink X11 socket
L /tmp/.X11-unix - - - - /mnt/wslg/.X11-unix
```

**4. Let pam_systemd handle XDG_RUNTIME_DIR** (no shell configs needed)

**5. Optional: Enable linger for user persistence**:
```bash
loginctl enable-linger $USERNAME
```

### Pros
- ✅ Full systemd user session support
- ✅ `systemctl --user` works completely
- ✅ User timers and services available
- ✅ More "native Linux" behavior
- ✅ tmpfiles.d functionality available
- ✅ XDG_RUNTIME_DIR set automatically via pam_systemd

### Cons
- ❌ More complex setup
- ❌ Requires understanding of the workaround
- ❌ May have edge cases or race conditions
- ❌ Not all distros use this approach (mixed success)

### Known Issues & Workarounds

**Issue**: WSL login might still nuke user sessions in some cases
- **Source**: [microsoft/WSL#10205](https://github.com/microsoft/WSL/issues/10205)
- **Status**: Marked as CLOSED (August 2025), but may still occur in edge cases
- **Workaround**: Add to `.bashrc`:
  ```bash
  # Auto-restart user session if it got nuked
  if ! systemctl --user is-active --quiet dbus.service; then
      sudo systemctl restart user@$(id -u)
  fi
  ```

**Issue**: User runtime directory gets unmounted
- **Source**: [microsoft/WSL#8918](https://github.com/microsoft/WSL/issues/8918)
- **Status**: CLOSED (May 2024), workaround above should prevent
- **Alternative**: Add to override.conf:
  ```ini
  [Unit]
  Requires=run-user-%i.mount
  ```

### Best For
- Power users who want full systemd capabilities
- Distributions aiming for maximum compatibility with native Linux
- Environments using systemd user services (e.g., podman rootless)
- Users familiar with systemd internals

## Real-World Distribution Choices

### Fedora WSL
- **Approach**: Option 3 variant
- Enables systemd user sessions
- Uses tmpfiles.d for WSLg symlinks
- **Ignores** Microsoft's tmpfiles masking recommendation
- No user-runtime-dir override.conf found (may rely on WSL fixes)

### Arch Linux WSL
- **Approach**: Hybrid (systemd enabled, minimal masking)
- Enables systemd
- Masks: `systemd-firstboot`, `console-getty`, `getty@.service`, `serial-getty@.service`
- **Does not mask** tmpfiles or user services
- **No explicit WSLg configuration found** (relies on defaults)

### CachyOS WSL (Current)
- **Approach**: Option 1 (Simple Shell Environment)
- Enables systemd
- Masks tmpfiles services
- Direct XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir in shell configs
- Prioritizes simplicity and reliability

## Migration Path

If we want to move from Option 1 to Option 3 in the future:

### Step 1: Add override.conf
Create `/lib/systemd/system/user-runtime-dir@.service.d/override.conf` with the workaround.

### Step 2: Add tmpfiles.d configuration
Create `/etc/tmpfiles.d/wslg.conf` and `/etc/tmpfiles.d/wslg-system.conf`.

### Step 3: Unmask systemd units
```bash
systemctl unmask systemd-tmpfiles-setup.service
systemctl unmask systemd-tmpfiles-clean.timer
systemctl unmask user@.service
```

### Step 4: Remove shell environment variables
Remove WSLg-specific XDG_RUNTIME_DIR settings from:
- `/etc/fish/conf.d/wsl.fish`
- `/etc/zsh/zshenv.d/wsl.zsh`
- `/etc/profile.d/wsl.sh`

(Keep WAYLAND_DISPLAY and DISPLAY if needed)

### Step 5: Test user session
```bash
# Verify user session starts
systemctl --user status

# Verify WSLg sockets are accessible
ls -la $XDG_RUNTIME_DIR
```

## References

- [Microsoft Learn - Build Custom WSL Distro](https://learn.microsoft.com/en-us/windows/wsl/build-custom-distro)
- [microsoft/WSL#8918 - systemd user session destroys /mnt/wslg/runtime-dir](https://github.com/microsoft/WSL/issues/8918)
- [microsoft/WSL#10205 - WSL login nukes systemd/dbus user session](https://github.com/microsoft/WSL/issues/10205)
- [Fedora wsl-setup package](https://src.fedoraproject.org/rpms/wsl-setup)
- [Arch Linux WSL distribution](https://gitlab.archlinux.org/archlinux/archlinux-wsl)
- [pam_systemd documentation](https://www.freedesktop.org/software/systemd/man/pam_systemd.html)

## Recommendation

**Current**: Option 1 is the right choice for CachyOS WSL's initial release.

**Future**: Consider Option 3 if users request systemd user service support (e.g., for rootless podman, user timers, etc.).

**Not Recommended**: Option 2 (Microsoft's full masking list) appears overly conservative based on real-world distribution behavior.
