#!/bin/bash
# CachyOS WSL Build Validation Script
#
# This script validates the rootfs after build to catch configuration errors
# before packaging. It performs static checks that don't require Windows/WSL.
#
# Usage: validate.sh /path/to/rootfs
#
# Exit codes:
#   0 - All validations passed
#   1 - One or more validations failed

set -u  # Exit on undefined variable

ROOTFS_DIR="${1:-}"
ERRORS=0
WARNINGS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

##############################################################################
# Helper Functions
##############################################################################

error() {
    echo -e "${RED}❌ FAIL:${NC} $1"
    ERRORS=$((ERRORS + 1))
}

pass() {
    echo -e "${GREEN}✅ PASS:${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠️  WARN:${NC} $1"
    WARNINGS=$((WARNINGS + 1))
}

check_file_exists() {
    local file="$1"
    local description="$2"

    if [ -f "$file" ]; then
        pass "$description exists"
    else
        error "$description missing: $file"
    fi
}

check_file_not_exists() {
    local file="$1"
    local description="$2"

    if [ ! -f "$file" ]; then
        pass "$description does not exist (correct)"
    else
        error "$description should not exist: $file"
    fi
}

check_executable() {
    local file="$1"
    local description="$2"

    if [ -x "$file" ]; then
        pass "$description is executable"
    else
        error "$description is not executable: $file"
    fi
}

check_permissions() {
    local file="$1"
    local expected="$2"
    local description="$3"

    if [ -f "$file" ]; then
        actual=$(stat -c '%a' "$file")
        if [ "$actual" = "$expected" ]; then
            pass "$description has correct permissions ($expected)"
        else
            error "$description has wrong permissions: $actual (expected $expected)"
        fi
    else
        error "$description does not exist: $file"
    fi
}

check_file_contains() {
    local file="$1"
    local pattern="$2"
    local description="$3"

    if [ -f "$file" ]; then
        if grep -q "$pattern" "$file"; then
            pass "$description contains '$pattern'"
        else
            error "$description does not contain '$pattern'"
        fi
    else
        error "$description does not exist: $file"
    fi
}

check_symlink() {
    local link="$1"
    local target="$2"
    local description="$3"

    if [ -L "$link" ]; then
        actual_target=$(readlink "$link")
        if [[ "$actual_target" == *"$target"* ]]; then
            pass "$description links to $target"
        else
            error "$description links to wrong target: $actual_target (expected $target)"
        fi
    else
        error "$description is not a symlink: $link"
    fi
}

##############################################################################
# Validate Arguments
##############################################################################

if [ -z "$ROOTFS_DIR" ]; then
    echo "Usage: $0 /path/to/rootfs"
    exit 1
fi

if [ ! -d "$ROOTFS_DIR" ]; then
    echo "Error: Directory does not exist: $ROOTFS_DIR"
    exit 1
fi

echo "============================================"
echo "CachyOS WSL Rootfs Validation"
echo "============================================"
echo "Rootfs: $ROOTFS_DIR"
echo ""

##############################################################################
# Category 1: Required Configuration Files
##############################################################################

echo "==> Checking required configuration files..."

check_file_exists "$ROOTFS_DIR/etc/wsl.conf" "wsl.conf"
check_file_exists "$ROOTFS_DIR/etc/wsl-distribution.conf" "wsl-distribution.conf"
check_file_exists "$ROOTFS_DIR/usr/lib/wsl/oobe.sh" "OOBE script"
check_file_exists "$ROOTFS_DIR/usr/lib/wsl/terminal-profile.json" "Terminal profile"
check_file_exists "$ROOTFS_DIR/usr/lib/wsl/cachyos.ico" "CachyOS icon"

echo ""

##############################################################################
# Category 2: File Permissions
##############################################################################

echo "==> Checking file permissions..."

check_permissions "$ROOTFS_DIR/etc/wsl.conf" "644" "wsl.conf"
check_permissions "$ROOTFS_DIR/etc/wsl-distribution.conf" "644" "wsl-distribution.conf"
check_executable "$ROOTFS_DIR/usr/lib/wsl/oobe.sh" "OOBE script"

echo ""

##############################################################################
# Category 3: WSL Configuration Content
##############################################################################

echo "==> Checking WSL configuration content..."

# Check wsl.conf for systemd
check_file_contains "$ROOTFS_DIR/etc/wsl.conf" "systemd = true" "wsl.conf systemd"
check_file_contains "$ROOTFS_DIR/etc/wsl.conf" "enabled = true" "wsl.conf interop"

# Check wsl-distribution.conf
check_file_contains "$ROOTFS_DIR/etc/wsl-distribution.conf" "defaultUid = 1000" "wsl-distribution.conf defaultUid"
check_file_contains "$ROOTFS_DIR/etc/wsl-distribution.conf" "command = /usr/lib/wsl/oobe.sh" "wsl-distribution.conf OOBE command"

echo ""

##############################################################################
# Category 4: JSON Validation
##############################################################################

echo "==> Validating JSON files..."

if command -v jq &> /dev/null; then
    if [ -f "$ROOTFS_DIR/usr/lib/wsl/terminal-profile.json" ]; then
        if jq empty "$ROOTFS_DIR/usr/lib/wsl/terminal-profile.json" 2>/dev/null; then
            pass "terminal-profile.json is valid JSON"

            # Check for forbidden fields
            if jq 'has("name")' "$ROOTFS_DIR/usr/lib/wsl/terminal-profile.json" | grep -q true; then
                error "terminal-profile.json should not contain 'name' field"
            else
                pass "terminal-profile.json does not contain 'name' field (correct)"
            fi

            if jq 'has("commandLine")' "$ROOTFS_DIR/usr/lib/wsl/terminal-profile.json" | grep -q true; then
                error "terminal-profile.json should not contain 'commandLine' field"
            else
                pass "terminal-profile.json does not contain 'commandLine' field (correct)"
            fi
        else
            error "terminal-profile.json is not valid JSON"
        fi
    fi
else
    warn "jq not installed, skipping JSON validation"
fi

echo ""

##############################################################################
# Category 5: Prohibited Files (Must NOT exist)
##############################################################################

echo "==> Checking for prohibited files..."

check_file_not_exists "$ROOTFS_DIR/etc/resolv.conf" "/etc/resolv.conf"
check_file_not_exists "$ROOTFS_DIR/etc/machine-id" "/etc/machine-id"
check_file_not_exists "$ROOTFS_DIR/etc/hostname" "/etc/hostname"
check_file_not_exists "$ROOTFS_DIR/boot/vmlinuz-linux" "Kernel (vmlinuz)"
check_file_not_exists "$ROOTFS_DIR/boot/initramfs-linux.img" "initramfs"

echo ""

##############################################################################
# Category 6: Systemd Service Masking
##############################################################################

echo "==> Checking systemd service masking..."

MASKED_SERVICES=(
    "systemd-resolved.service"
    "systemd-networkd.service"
    "NetworkManager.service"
    "systemd-tmpfiles-setup.service"
    "systemd-tmpfiles-clean.service"
    "systemd-tmpfiles-clean.timer"
    "tmp.mount"
)

for service in "${MASKED_SERVICES[@]}"; do
    link="$ROOTFS_DIR/etc/systemd/system/$service"
    if [ -L "$link" ]; then
        target=$(readlink "$link")
        if [ "$target" = "/dev/null" ]; then
            pass "$service is masked"
        else
            error "$service is linked to $target (expected /dev/null)"
        fi
    else
        warn "$service is not masked (may cause issues in WSL)"
    fi
done

echo ""

##############################################################################
# Category 7: System Files
##############################################################################

echo "==> Checking system files..."

# Check passwd and shadow exist
check_file_exists "$ROOTFS_DIR/etc/passwd" "/etc/passwd"
check_file_exists "$ROOTFS_DIR/etc/shadow" "/etc/shadow"

# Check root user exists in passwd
if [ -f "$ROOTFS_DIR/etc/passwd" ]; then
    if grep -q '^root:' "$ROOTFS_DIR/etc/passwd"; then
        pass "root user exists in /etc/passwd"

        # Check root UID is 0
        root_uid=$(grep '^root:' "$ROOTFS_DIR/etc/passwd" | cut -d: -f3)
        if [ "$root_uid" = "0" ]; then
            pass "root user has UID 0"
        else
            error "root user has wrong UID: $root_uid (expected 0)"
        fi
    else
        error "root user not found in /etc/passwd"
    fi
fi

# Check shadow has no password hashes (should be ! or *)
if [ -f "$ROOTFS_DIR/etc/shadow" ]; then
    if grep -q '^root:[!*]:' "$ROOTFS_DIR/etc/shadow"; then
        pass "/etc/shadow has no password hashes (correct)"
    else
        warn "/etc/shadow may contain password hashes (should be cleared)"
    fi
fi

echo ""

##############################################################################
# Category 8: Size Checks
##############################################################################

echo "==> Checking file sizes..."

# Icon should be under 10MB
if [ -f "$ROOTFS_DIR/usr/lib/wsl/cachyos.ico" ]; then
    icon_size=$(stat -c '%s' "$ROOTFS_DIR/usr/lib/wsl/cachyos.ico")
    icon_size_mb=$((icon_size / 1048576))

    if [ "$icon_size" -lt 10485760 ]; then  # 10MB
        pass "Icon file is ${icon_size_mb}MB (under 10MB limit)"
    else
        error "Icon file is ${icon_size_mb}MB (exceeds 10MB limit)"
    fi
fi

# Check if we're validating a tar file in addition to rootfs
TAR_FILE="dist/cachyos-v3-rootfs.tar.gz"
if [ -f "$TAR_FILE" ]; then
    tar_size=$(stat -c '%s' "$TAR_FILE")
    tar_size_mb=$((tar_size / 1048576))

    if [ "$tar_size" -lt 524288000 ]; then  # 500MB
        pass "Rootfs tar is ${tar_size_mb}MB (under 500MB)"
    else
        warn "Rootfs tar is ${tar_size_mb}MB (exceeds 500MB, may be too large)"
    fi
fi

echo ""

##############################################################################
# Category 9: Package Manager Configuration
##############################################################################

echo "==> Checking package manager configuration..."

if [ -f "$ROOTFS_DIR/etc/pacman.conf" ]; then
    check_file_exists "$ROOTFS_DIR/etc/pacman.conf" "pacman.conf"

    # Check for optional enhancements (warn if missing, don't fail)
    if grep -q '^Color' "$ROOTFS_DIR/etc/pacman.conf"; then
        pass "pacman Color is enabled"
    else
        warn "pacman Color is not enabled (cosmetic)"
    fi

    if grep -q 'ILoveCandy' "$ROOTFS_DIR/etc/pacman.conf"; then
        pass "pacman ILoveCandy is enabled"
    else
        warn "pacman ILoveCandy is not enabled (cosmetic)"
    fi
fi

echo ""

##############################################################################
# Summary
##############################################################################

echo "============================================"
echo "Validation Summary"
echo "============================================"

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ All critical checks passed!${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}⚠️  $WARNINGS warning(s) - non-critical issues found${NC}"
    fi
    echo ""
    echo "Rootfs is ready for packaging."
    exit 0
else
    echo -e "${RED}❌ $ERRORS critical check(s) failed${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}⚠️  $WARNINGS warning(s)${NC}"
    fi
    echo ""
    echo "Please fix the errors above before packaging."
    exit 1
fi
