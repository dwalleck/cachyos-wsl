# Automated Testing Strategy for CachyOS WSL

Research and recommendations for automated validation of the WSL distribution.

## Overview

Testing a WSL distribution can be broken into three layers:
1. **Static Validation** - Fast checks during build (no WSL/Windows needed)
2. **Container-based Testing** - Validate rootfs in Docker (Linux only)
3. **Integration Testing** - Full WSL testing on Windows (GitHub Actions)

## Layer 1: Static Validation (Build-time)

**Goal:** Catch configuration errors before packaging
**Environment:** Linux build system (no Windows needed)
**Speed:** Seconds
**Reliability:** 100% reproducible

### What We Can Validate

#### File Existence
```bash
# Verify critical files exist
test -f "$ROOTFS_DIR/etc/wsl.conf"
test -f "$ROOTFS_DIR/etc/wsl-distribution.conf"
test -f "$ROOTFS_DIR/usr/lib/wsl/oobe.sh"
test -f "$ROOTFS_DIR/usr/lib/wsl/terminal-profile.json"
test -f "$ROOTFS_DIR/usr/lib/wsl/cachyos.ico"
test -f "$ROOTFS_DIR/etc/pacman.conf"
test -f "$ROOTFS_DIR/etc/shadow"
test -f "$ROOTFS_DIR/etc/passwd"
```

#### File Permissions
```bash
# OOBE script must be executable
test -x "$ROOTFS_DIR/usr/lib/wsl/oobe.sh"

# wsl.conf must be 644
test "$(stat -c '%a' "$ROOTFS_DIR/etc/wsl.conf")" = "644"

# shadow must be 000 or have no passwords
grep -q '^root:!:' "$ROOTFS_DIR/etc/shadow"
```

#### File Contents
```bash
# Verify systemd is enabled
grep -q 'systemd = true' "$ROOTFS_DIR/etc/wsl.conf"

# Verify pacman enhancements (if implemented)
grep -q '^Color' "$ROOTFS_DIR/etc/pacman.conf"
grep -q 'ILoveCandy' "$ROOTFS_DIR/etc/pacman.conf"

# Verify multi-user.target (if implemented)
readlink "$ROOTFS_DIR/etc/systemd/system/default.target" | grep -q 'multi-user.target'
```

#### JSON Validation
```bash
# Validate terminal-profile.json is valid JSON
jq empty "$ROOTFS_DIR/usr/lib/wsl/terminal-profile.json"

# Check it doesn't contain forbidden fields
! jq 'has("name")' "$ROOTFS_DIR/usr/lib/wsl/terminal-profile.json" | grep -q true
! jq 'has("commandLine")' "$ROOTFS_DIR/usr/lib/wsl/terminal-profile.json" | grep -q true
```

#### Prohibited Files
```bash
# These files should NOT exist in rootfs
test ! -f "$ROOTFS_DIR/etc/resolv.conf"
test ! -f "$ROOTFS_DIR/etc/machine-id"
test ! -f "$ROOTFS_DIR/etc/hostname"

# No kernel/initramfs
test ! -f "$ROOTFS_DIR/boot/vmlinuz-linux"
test ! -f "$ROOTFS_DIR/boot/initramfs-linux.img"
```

#### Service Masking
```bash
# Verify problematic services are masked
services=(
    "systemd-resolved.service"
    "systemd-networkd.service"
    "NetworkManager.service"
    "tmp.mount"
)

for service in "${services[@]}"; do
    link="$ROOTFS_DIR/etc/systemd/system/$service"
    test -L "$link" && test "$(readlink "$link")" = "/dev/null"
done
```

#### Size Checks
```bash
# Verify archive isn't too large (should be <500MB)
tar_size=$(stat -c '%s' "dist/cachyos-v3-rootfs.tar.gz")
test "$tar_size" -lt 524288000  # 500MB in bytes

# Icon file should be under 10MB
icon_size=$(stat -c '%s' "$ROOTFS_DIR/usr/lib/wsl/cachyos.ico")
test "$icon_size" -lt 10485760  # 10MB in bytes
```

### Implementation: validate.sh Script

```bash
#!/bin/bash
# build/validate.sh - Run after rootfs creation

set -e

ROOTFS_DIR="${1:-/rootfs}"
ERRORS=0

echo "==> Running static validation checks..."

# File existence checks
check_file_exists() {
    if [ ! -f "$1" ]; then
        echo "❌ FAIL: Missing file: $1"
        ERRORS=$((ERRORS + 1))
    else
        echo "✅ PASS: File exists: $1"
    fi
}

check_file_exists "$ROOTFS_DIR/etc/wsl.conf"
check_file_exists "$ROOTFS_DIR/etc/wsl-distribution.conf"
check_file_exists "$ROOTFS_DIR/usr/lib/wsl/oobe.sh"
# ... more checks ...

if [ $ERRORS -eq 0 ]; then
    echo "✅ All validation checks passed!"
    exit 0
else
    echo "❌ $ERRORS validation check(s) failed"
    exit 1
fi
```

Add to `build-rootfs.sh`:
```bash
# After cleanup, before tar creation:
echo "==> Validating rootfs..."
"$SCRIPT_DIR/validate.sh" "$ROOTFS_DIR"
```

## Layer 2: Container-based Testing

**Goal:** Test rootfs behavior without Windows
**Environment:** Docker on Linux
**Speed:** Minutes
**Reliability:** Good (simulates Linux environment)

### What We Can Test

#### Extract and Inspect
```bash
# Extract tar in temporary container
docker run --rm -v $(pwd)/dist:/dist alpine sh -c '
    cd /tmp
    tar -xzf /dist/cachyos-v3-rootfs.tar.gz

    # Run checks
    test -f /tmp/etc/wsl.conf
    test -x /tmp/usr/lib/wsl/oobe.sh

    # Verify no resolv.conf
    test ! -f /tmp/etc/resolv.conf
'
```

#### Test OOBE Script Syntax
```bash
# Verify OOBE script has valid bash syntax
docker run --rm -v $(pwd)/dist:/dist cachyos/cachyos:latest bash -n /dist/oobe.sh
```

#### Simulate User Creation
```bash
# Test OOBE user creation logic (dry-run)
docker run --rm -v $(pwd)/config:/config cachyos/cachyos:latest bash -c '
    # Source the OOBE script functions
    useradd --help > /dev/null  # Verify useradd exists
    pacman-key --help > /dev/null  # Verify pacman-key exists
'
```

### Implementation: GitHub Actions Build Workflow

```yaml
# .github/workflows/build.yml
name: Build and Validate

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build-and-validate:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Build rootfs
        run: make rootfs

      - name: Run static validation
        run: |
          # Extract tar to temp directory
          mkdir -p /tmp/rootfs-check
          cd /tmp/rootfs-check
          tar -xzf $GITHUB_WORKSPACE/dist/cachyos-v3-rootfs.tar.gz

          # Run validation script
          bash $GITHUB_WORKSPACE/build/validate.sh /tmp/rootfs-check

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: cachyos-wsl
          path: dist/cachyos-v3-rootfs.tar.gz
```

## Layer 3: Integration Testing (WSL on Windows)

**Goal:** Full end-to-end validation in real WSL environment
**Environment:** GitHub Actions Windows runner
**Speed:** 10-20 minutes
**Reliability:** Excellent (real environment)

### What We Can Test

#### Installation
```powershell
# Install the distribution
wsl --install --from-file cachyos-v3.wsl --name cachyos-test

# Verify it's installed
wsl -l -v | Select-String "cachyos-test"
```

#### OOBE Script
```bash
# Test OOBE by passing pre-configured input
echo -e "testuser\ntestpass\ntestpass" | wsl -d cachyos-test

# Verify user was created
wsl -d cachyos-test -u root id testuser
wsl -d cachyos-test -u root groups testuser | grep wheel
```

#### System Functionality
```bash
# Test as created user
wsl -d cachyos-test whoami  # Should be testuser, not root

# Test sudo
wsl -d cachyos-test sudo whoami  # Should be root

# Test systemd
wsl -d cachyos-test systemctl is-system-running
wsl -d cachyos-test systemctl get-default  # Should be multi-user.target

# Test pacman
wsl -d cachyos-test sudo pacman -Sy
wsl -d cachyos-test pacman -Q | wc -l  # Count installed packages
```

#### Configuration Validation
```bash
# Verify wsl.conf settings
wsl -d cachyos-test cat /etc/wsl.conf | grep "systemd = true"

# Verify services are masked
wsl -d cachyos-test systemctl status systemd-resolved || true
wsl -d cachyos-test systemctl is-enabled systemd-resolved | grep masked
```

### Implementation: GitHub Actions WSL Test Workflow

```yaml
# .github/workflows/wsl-test.yml
name: WSL Integration Tests

on:
  workflow_run:
    workflows: ["Build and Validate"]
    types: [completed]

jobs:
  test-wsl:
    runs-on: windows-latest
    if: ${{ github.event.workflow_run.conclusion == 'success' }}

    steps:
      - uses: actions/checkout@v4

      - name: Download build artifact
        uses: actions/download-artifact@v4
        with:
          name: cachyos-wsl
          path: dist

      - name: Create .wsl file
        shell: pwsh
        run: |
          Copy-Item dist/cachyos-v3-rootfs.tar.gz dist/cachyos-test.wsl

      - name: Install WSL distribution
        shell: pwsh
        run: |
          wsl --install --from-file dist/cachyos-test.wsl --name cachyos-ci-test

      - name: Wait for installation
        shell: pwsh
        run: Start-Sleep -Seconds 10

      - name: Run OOBE with automated input
        shell: pwsh
        run: |
          # Create automated OOBE input
          $input = @"
          citest
          TestPass123!
          TestPass123!
          "@
          $input | wsl -d cachyos-ci-test

      - name: Test basic functionality
        shell: bash
        run: |
          # Verify user created
          wsl -d cachyos-ci-test -u root id citest

          # Verify wheel group
          wsl -d cachyos-ci-test -u root groups citest | grep wheel

          # Test default user
          [[ $(wsl -d cachyos-ci-test whoami) == "citest" ]]

          # Test sudo
          [[ $(wsl -d cachyos-ci-test sudo whoami) == "root" ]]

          # Test systemd
          wsl -d cachyos-ci-test systemctl is-system-running

          # Test pacman
          wsl -d cachyos-ci-test sudo pacman -Sy

          # Count packages (should be ~130)
          pkg_count=$(wsl -d cachyos-ci-test pacman -Q | wc -l)
          [[ $pkg_count -gt 100 ]]

      - name: Test systemd configuration
        shell: bash
        run: |
          # Verify systemd target
          target=$(wsl -d cachyos-ci-test systemctl get-default)
          [[ "$target" == "multi-user.target" ]]

          # Verify masked services
          wsl -d cachyos-ci-test systemctl is-enabled systemd-resolved | grep masked

      - name: Cleanup
        if: always()
        shell: pwsh
        run: wsl --unregister cachyos-ci-test
```

### Alternative: Using setup-wsl Action

```yaml
# Using Vampire/setup-wsl action
jobs:
  test-wsl-with-action:
    runs-on: windows-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup WSL
        uses: Vampire/setup-wsl@v3
        with:
          distribution: Debian
          use-cache: true
          set-as-default: true

      - name: Install our distribution
        shell: pwsh
        run: |
          wsl --install --from-file dist/cachyos-test.wsl

      # ... rest of tests
```

## Layer 4: Health Check Script (Post-Install)

**Goal:** User-runnable validation
**Environment:** Inside WSL after installation
**Use case:** Troubleshooting, verification

### Implementation: health-check.sh

```bash
#!/bin/bash
# config/health-check.sh - User can run to verify installation

echo "==> CachyOS WSL Health Check"
echo ""

ERRORS=0

check() {
    if eval "$1" > /dev/null 2>&1; then
        echo "✅ $2"
    else
        echo "❌ $2"
        ERRORS=$((ERRORS + 1))
    fi
}

check "systemctl is-system-running" "systemd is running"
check "systemctl get-default | grep -q multi-user" "systemd target is multi-user"
check "groups | grep -q wheel" "user is in wheel group"
check "sudo -n true" "sudo is configured"
check "pacman -Sy" "pacman database sync works"
check "ping -c 1 archlinux.org" "network connectivity"
check "systemctl is-enabled systemd-resolved | grep -q masked" "systemd-resolved is masked"

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "✅ All health checks passed!"
else
    echo "❌ $ERRORS health check(s) failed"
fi
```

Include in rootfs at `/usr/bin/cachyos-health-check`

## Recommended Implementation Strategy

### Phase 1: Static Validation (Immediate)
1. Create `build/validate.sh` with file/permission checks
2. Integrate into `build-rootfs.sh`
3. Run locally before committing

**Effort:** 2-3 hours
**Value:** High - catches 80% of issues immediately

### Phase 2: GitHub Actions Build (Next)
1. Create `.github/workflows/build.yml`
2. Build on every push/PR
3. Run static validation
4. Upload artifact

**Effort:** 1-2 hours
**Value:** High - automated on every change

### Phase 3: Container Testing (Optional)
1. Add tar extraction tests
2. Add OOBE syntax checks
3. Simulate user creation

**Effort:** 2-3 hours
**Value:** Medium - catches additional issues

### Phase 4: WSL Integration Tests (Advanced)
1. Create `.github/workflows/wsl-test.yml`
2. Test on Windows runner
3. Full OOBE and functionality testing

**Effort:** 4-6 hours
**Value:** Very High - real environment testing

### Phase 5: Health Check Script (Nice-to-have)
1. Create user-facing health check
2. Include in documentation
3. Helps with troubleshooting

**Effort:** 1 hour
**Value:** Medium - helps users

## Cost Considerations

### GitHub Actions Free Tier

**Linux runners (ubuntu-latest):**
- 2,000 minutes/month (free tier)
- Build + validate: ~5 minutes per run
- ~400 builds/month possible

**Windows runners (windows-latest):**
- 2,000 minutes/month (free tier)
- BUT: Windows minutes count 2x (1 min = 2 minutes used)
- WSL test: ~15 minutes = 30 minutes billed
- ~66 test runs/month possible

**Recommendation:** Run WSL tests only on:
- Releases (tags)
- Manual workflow_dispatch
- Main branch pushes (not PRs)

This keeps Windows runner usage low while still validating releases.

## Example Test Matrix

| Test Type | Environment | Frequency | Duration | Detects |
|-----------|-------------|-----------|----------|---------|
| Static validation | Linux | Every commit | 10s | Config errors, missing files |
| Container tests | Linux | Every commit | 2min | Structure, syntax errors |
| WSL integration | Windows | Releases only | 15min | Runtime issues, OOBE, systemd |
| Health check | User's WSL | Post-install | 30s | Installation problems |

## Success Metrics

With full automation:
- **0 configuration errors** shipped to users
- **100% of builds validated** before release
- **Faster iteration** (catch issues in CI, not manual testing)
- **Confidence in releases** (every release fully tested)

## Next Steps

1. Implement Phase 1 (static validation)
2. Set up Phase 2 (GitHub Actions build)
3. Test locally and in CI
4. Document for contributors
5. Expand to Phases 3-4 as needed

## References

- [Ubuntu WSL Testing Blog](https://ubuntu.com/blog/improved-testing-ubuntu-wsl)
- [setup-wsl GitHub Action](https://github.com/marketplace/actions/setup-wsl)
- [Ubuntu WSL Actions Example](https://github.com/ubuntu/wsl-actions-example)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
