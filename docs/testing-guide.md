# CachyOS WSL Testing Guide

Comprehensive guide for testing the CachyOS WSL distribution on Windows.

## Prerequisites

### System Requirements
- **Windows 10/11** with WSL 2 support
- **WSL 2.4.4 or later** (check with `wsl --version`)
- **Administrator privileges** (required for registry override)
- **PowerShell 5.1 or later**

### Required Files
- `dist/cachyos-v3.wsl` - The distribution file (390MB)
- `scripts/override-manifest.ps1` - PowerShell test script

## Testing Workflow

### Phase 1: Setup Local Testing Environment

#### Step 1: Copy Files to Windows

Transfer the following files to your Windows machine:
```
cachyos-wsl/
├── dist/cachyos-v3.wsl
└── scripts/override-manifest.ps1
```

Recommended location: `C:\Users\<YourUser>\Downloads\cachyos-wsl\`

#### Step 2: Open PowerShell as Administrator

Right-click PowerShell and select "Run as Administrator"

Verify WSL version:
```powershell
wsl --version
```

Expected output should show WSL 2.4.4 or later.

### Phase 2: Run Local Testing Script

#### Step 3: Execute Override Script

Navigate to the directory containing the files:
```powershell
cd C:\Users\<YourUser>\Downloads\cachyos-wsl
```

Run the override script:
```powershell
.\scripts\override-manifest.ps1 -TarPath .\dist\cachyos-v3.wsl
```

**Expected Output:**
- SHA256 hash computed successfully
- Manifest file created
- Registry override set
- Distribution appears in output

**Troubleshooting:**
- If you get "script execution is disabled", run: `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`
- If you get "not running as Administrator", restart PowerShell as Administrator

#### Step 4: Verify Distribution Appears

Check that the distribution is listed:
```powershell
wsl --list --online
```

**Expected Output:**
```
NAME              FRIENDLY NAME
cachyos-wsl-v1    CachyOS WSL Distribution
...
```

✅ **Test Checkpoint 1:** Distribution visible in WSL list

### Phase 3: Install Distribution

#### Step 5: Install CachyOS WSL

Install the distribution:
```powershell
wsl --install cachyos-wsl-v1
```

**Expected Behavior:**
- WSL downloads and extracts the rootfs
- Installation completes
- OOBE script launches automatically

**Installation Log Check:**
Look for messages indicating:
- Extracting files
- Setting up distribution
- Running OOBE command

✅ **Test Checkpoint 2:** Installation completes without errors

### Phase 4: OOBE (Out-of-Box Experience) Testing

#### Step 6: Complete First-Run Setup

The OOBE script should automatically run and display:

```
============================================
Welcome to CachyOS for WSL!
============================================

Please create a default user account.
This user will have administrative privileges via sudo.

For more information visit: https://wiki.cachyos.org/

Enter new UNIX username:
```

**Test Actions:**
1. Enter a valid username (lowercase, start with letter)
2. Set a password when prompted
3. Confirm password

**Expected Behavior:**
- Username validation works (rejects invalid names)
- Password is set successfully
- Success message displays:
  ```
  User <username> created successfully!
  ```

**Verify User Creation:**
- User created with UID 1000
- User added to wheel group
- Sudo access enabled
- Pacman keyring initialized

**Troubleshooting:**
- If OOBE fails, check `/var/log/` for errors
- Verify OOBE script exists: `ls -la /usr/lib/wsl/oobe.sh`
- Check permissions: should be 755

✅ **Test Checkpoint 3:** OOBE successfully creates user account

#### Step 7: Verify Default User

After OOBE completes, close and reopen the distribution:
```powershell
wsl -d cachyos-wsl-v1
```

**Expected Behavior:**
- Should log in as the user you created (not root)
- Prompt shows: `username@hostname:~$`

**Verify User Configuration:**
```bash
# Check current user
whoami
# Should output: your_username

# Check UID
id -u
# Should output: 1000

# Check groups
groups
# Should include: wheel

# Test sudo access
sudo whoami
# Should output: root (after entering password)
```

✅ **Test Checkpoint 4:** Default user configuration correct

### Phase 5: Windows Integration Testing

#### Step 8: Check Start Menu Shortcut

1. Press Windows key
2. Search for "CachyOS"
3. Verify shortcut appears with custom icon

**Expected:**
- Shortcut named "CachyOS WSL Distribution" (or similar)
- Custom CachyOS icon visible (teal/cyan logo)
- Clicking shortcut launches distribution

**Troubleshooting:**
- If no icon, verify `/usr/lib/wsl/cachyos.ico` exists
- Check `/etc/wsl-distribution.conf` has correct icon path
- Icon should be 107KB with multiple resolutions

✅ **Test Checkpoint 5:** Start Menu shortcut created with icon

#### Step 9: Check Windows Terminal Profile

Open Windows Terminal (if installed):
1. Click dropdown arrow (⌄)
2. Look for "CachyOS WSL Distribution" profile
3. Select it to open

**Expected:**
- Profile appears in dropdown menu
- Opening profile shows CachyOS distribution
- Color scheme matches CachyOS branding:
  - Dark background (#2E3440)
  - Cyan cursor (#1dc7b5)
  - Nord-based colors

**Verify Profile Template:**
Inside WSL:
```bash
cat /usr/lib/wsl/terminal-profile.json
```

Should show color scheme configuration.

**Troubleshooting:**
- If profile not generated, check Windows Terminal version (needs fragment extension support)
- Verify `/usr/lib/wsl/terminal-profile.json` exists in rootfs

✅ **Test Checkpoint 6:** Windows Terminal profile generated correctly

### Phase 6: Functionality Testing

#### Step 10: Test Package Manager

Inside the CachyOS distribution:

```bash
# Update package databases
sudo pacman -Sy

# Search for a package
pacman -Ss neofetch

# Install a test package
sudo pacman -S neofetch

# Run the installed package
neofetch

# Remove the package
sudo pacman -R neofetch
```

**Expected Behavior:**
- Database sync succeeds without signature errors
- Package search works
- Installation succeeds
- Package runs correctly
- Removal works

**Troubleshooting:**
- If signature errors, verify keyring was initialized in OOBE
- Check `/var/log/pacman.log` for errors
- Manually run: `sudo pacman-key --init && sudo pacman-key --populate archlinux cachyos`

✅ **Test Checkpoint 7:** Package manager functional

#### Step 11: Test systemd

Check systemd status:
```bash
# Verify systemd is running
ps aux | grep systemd

# Check systemd status
systemctl status

# List failed units (should be minimal)
systemctl --failed

# Verify masked services
systemctl list-unit-files | grep masked
```

**Expected:**
- systemd is PID 1
- `systemctl status` shows "running"
- Problematic services are masked:
  - systemd-resolved.service
  - systemd-networkd.service
  - NetworkManager.service
  - systemd-tmpfiles-* services
  - tmp.mount

**Verify WSL Config:**
```bash
cat /etc/wsl.conf
```

Should show:
```ini
[boot]
systemd = true
```

✅ **Test Checkpoint 8:** systemd configured correctly

#### Step 12: Test Network Connectivity

```bash
# Test DNS resolution
ping -c 3 archlinux.org

# Test HTTPS
curl -I https://cachyos.org

# Check nameserver
cat /etc/resolv.conf
```

**Expected:**
- Ping succeeds
- HTTPS connection works
- `/etc/resolv.conf` is WSL-managed

✅ **Test Checkpoint 9:** Network connectivity works

#### Step 13: Test Windows Interop

```bash
# Run Windows command from Linux
cmd.exe /c ver

# Check Windows PATH integration
echo $PATH | grep -i windows

# Access Windows filesystem
ls /mnt/c/Users/
```

**Expected:**
- Windows commands execute
- Windows paths in $PATH
- `/mnt/c/` accessible

**Verify WSL Config:**
```bash
grep -A 5 "\[interop\]" /etc/wsl.conf
```

Should show:
```ini
[interop]
enabled = true
appendWindowsPath = true
```

✅ **Test Checkpoint 10:** Windows interoperability functional

### Phase 7: Advanced Testing

#### Step 14: Test File Permissions

```bash
# Create test file
echo "test" > ~/test.txt

# Check ownership
ls -l ~/test.txt
# Should be owned by your user (UID 1000)

# Test sudo
sudo touch /root/test-root.txt
ls -l /root/test-root.txt
# Should be owned by root
```

✅ **Test Checkpoint 11:** File permissions work correctly

#### Step 15: Test Locale and Timezone

```bash
# Check locale
locale

# Check timezone
timedatectl

# Test date
date
```

**Expected:**
- Locale configured (may default to C.UTF-8)
- Timezone syncs with Windows
- Date is correct

#### Step 16: Stress Test Package Installation

Install a larger package:
```bash
sudo pacman -S --noconfirm base-devel git
```

**Expected:**
- Installation completes successfully
- No dependency issues
- All tools functional

✅ **Test Checkpoint 12:** Complex package installation works

### Phase 8: Cleanup and Documentation

#### Step 17: Clean Up Registry Override

After testing is complete, clean up the registry override:

```powershell
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss" -Name DistributionListUrl
```

**Verify:**
```powershell
wsl --list --online
```

Should no longer show cachyos-wsl-v1 (reverts to Microsoft's official list).

**Note:** The installed distribution remains installed even after cleanup.

✅ **Test Checkpoint 13:** Registry cleanup successful

#### Step 18: Optional - Uninstall Distribution

If you want to remove the test installation:

```powershell
wsl --unregister cachyos-wsl-v1
```

**Warning:** This deletes all data in the distribution.

#### Step 19: Document Issues

Create a testing report documenting:
- All test checkpoints and results (✅ Pass / ❌ Fail)
- Any errors encountered
- Workarounds applied
- Performance observations
- Suggestions for improvements

## Test Checkpoints Summary

| # | Checkpoint | Expected Result |
|---|------------|-----------------|
| 1 | Distribution visible in WSL list | ✅ Shows in `wsl --list --online` |
| 2 | Installation completes | ✅ No errors during install |
| 3 | OOBE creates user | ✅ User created with UID 1000 |
| 4 | Default user configured | ✅ Auto-login works, sudo enabled |
| 5 | Start Menu shortcut | ✅ Shortcut with custom icon |
| 6 | Terminal profile | ✅ Custom color scheme applied |
| 7 | Package manager | ✅ pacman works, no signature errors |
| 8 | systemd | ✅ systemd running, services masked |
| 9 | Network | ✅ DNS and internet access work |
| 10 | Windows interop | ✅ Can run Windows commands |
| 11 | File permissions | ✅ Ownership and sudo work |
| 12 | Complex packages | ✅ base-devel installs successfully |
| 13 | Registry cleanup | ✅ Override removed cleanly |

## Common Issues and Solutions

### Issue: "Cannot find distribution"
**Cause:** Registry override not set correctly
**Solution:** Re-run override-manifest.ps1 as Administrator

### Issue: OOBE script doesn't run
**Cause:** Script permissions or path incorrect
**Solution:**
```bash
sudo chmod +x /usr/lib/wsl/oobe.sh
sudo /usr/lib/wsl/oobe.sh
```

### Issue: Signature errors with pacman
**Cause:** Keyring not initialized
**Solution:**
```bash
sudo pacman-key --init
sudo pacman-key --populate archlinux cachyos
```

### Issue: No icon on shortcut
**Cause:** Icon file missing or path incorrect
**Solution:** Verify in `/etc/wsl-distribution.conf` and check `/usr/lib/wsl/cachyos.ico` exists

### Issue: systemd-resolved conflicts
**Cause:** Service not masked
**Solution:**
```bash
sudo systemctl mask systemd-resolved
```

## Success Criteria

The distribution is considered **ready for release** when:

✅ All 13 test checkpoints pass
✅ No critical errors during installation
✅ OOBE completes successfully
✅ Package manager fully functional
✅ systemd services properly configured
✅ Windows integration working
✅ No data corruption or permission issues

## Next Steps After Successful Testing

1. **Document any issues** found and create tasks to fix them
2. **Update configuration files** based on testing feedback
3. **Rebuild rootfs** with fixes (if needed)
4. **Retest** to verify fixes
5. **Prepare for distribution**:
   - Create release notes
   - Document installation instructions for end users
   - Consider publishing to GitHub Releases
   - Optional: Create video demo

## Testing Artifacts

After testing, save these artifacts:
- Testing report (checklist results)
- Screenshots of:
  - Start Menu shortcut with icon
  - Windows Terminal with color scheme
  - OOBE welcome screen
  - `wsl --list --online` output
- Log files from any errors
- Performance metrics (installation time, memory usage)

## Automated Testing Ideas (Future)

Consider automating tests with:
- PowerShell Pester tests for WSL CLI operations
- GitHub Actions with Windows runners
- Automated screenshot capture
- Integration testing framework

---

**Testing completed by:** _________________
**Date:** _________________
**WSL Version:** _________________
**Windows Version:** _________________
**Overall Result:** ✅ Pass / ❌ Fail
