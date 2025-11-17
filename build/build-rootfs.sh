#!/bin/bash
# CachyOS WSL Root Filesystem Build Script
#
# This script builds a WSL-compliant CachyOS root filesystem by:
# 1. Creating a clean rootfs directory
# 2. Installing packages using pacman
# 3. Applying WSL-specific cleanup
# 4. Creating a compressed tar archive
#
# This script is designed to run inside a CachyOS Docker container.
#
# Usage: build-rootfs.sh [architecture]
# Architecture: v3 (default), v4, or znver4

set -e  # Exit on error
set -u  # Exit on undefined variable

##############################################################################
# Configuration
##############################################################################

ARCH="${1:-v3}"  # Default to x86-64-v3
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ROOTFS_DIR="/rootfs"
OUTPUT_DIR="$PROJECT_ROOT/dist"
PACKAGE_LIST="$SCRIPT_DIR/packages.list"
CLEANUP_SCRIPT="$SCRIPT_DIR/cleanup.sh"

# Output filename
OUTPUT_FILE="$OUTPUT_DIR/cachyos-$ARCH-rootfs.tar.gz"

echo "========================================"
echo "CachyOS WSL Rootfs Builder"
echo "========================================"
echo "Architecture: $ARCH"
echo "Output: $OUTPUT_FILE"
echo ""

##############################################################################
# Verify prerequisites
##############################################################################

echo "==> Verifying prerequisites..."

if [ ! -f "$PACKAGE_LIST" ]; then
    echo "ERROR: Package list not found: $PACKAGE_LIST"
    exit 1
fi

if [ ! -f "$CLEANUP_SCRIPT" ]; then
    echo "ERROR: Cleanup script not found: $CLEANUP_SCRIPT"
    exit 1
fi

if ! command -v pacman &> /dev/null; then
    echo "ERROR: pacman not found. This script must run in a CachyOS/Arch environment."
    exit 1
fi

##############################################################################
# Clean up any existing rootfs
##############################################################################

echo "==> Cleaning up existing rootfs..."

if [ -d "$ROOTFS_DIR" ]; then
    echo "  - Removing existing $ROOTFS_DIR"
    rm -rf "$ROOTFS_DIR"
fi

##############################################################################
# Create rootfs directory structure
##############################################################################

echo "==> Creating rootfs directory structure..."

mkdir -p "$ROOTFS_DIR"
mkdir -p "$ROOTFS_DIR/var/lib/pacman"
mkdir -p "$ROOTFS_DIR/var/cache/pacman/pkg"

echo "  - Created $ROOTFS_DIR"

##############################################################################
# Initialize pacman keyring (if needed)
##############################################################################

echo "==> Initializing pacman keyring..."

# Check if host keyring is initialized
if [ ! -d "/etc/pacman.d/gnupg" ] || [ ! -f "/etc/pacman.d/gnupg/trustdb.gpg" ]; then
    echo "  - Initializing host keyring"
    pacman-key --init
    pacman-key --populate archlinux cachyos
fi

##############################################################################
# Read package list (filter out comments and empty lines)
##############################################################################

echo "==> Reading package list..."

PACKAGES=$(grep -v '^#' "$PACKAGE_LIST" | grep -v '^$' | tr '\n' ' ')

echo "  - Packages to install: $PACKAGES"
echo ""

##############################################################################
# Install packages to rootfs
##############################################################################

echo "==> Installing packages to rootfs..."

# Use pacman to install packages to the rootfs directory
# --root: Install to alternate root
# --dbpath: Use alternate database path
# --cachedir: Use alternate cache directory
# --noconfirm: Don't ask for confirmation
# -Sy: Sync databases
# -u: Upgrade (not needed for fresh install, but safe)

pacman --root "$ROOTFS_DIR" \
       --dbpath "$ROOTFS_DIR/var/lib/pacman" \
       --cachedir "$ROOTFS_DIR/var/cache/pacman/pkg" \
       --noconfirm \
       -Sy \
       $PACKAGES

echo "  - Package installation complete"

##############################################################################
# Copy configuration files to rootfs
##############################################################################

echo "==> Copying WSL configuration files..."

CONFIG_DIR="$PROJECT_ROOT/config"

if [ -d "$CONFIG_DIR" ]; then
    # Copy wsl.conf if it exists
    if [ -f "$CONFIG_DIR/wsl.conf" ]; then
        echo "  - Copying wsl.conf"
        mkdir -p "$ROOTFS_DIR/etc"
        cp "$CONFIG_DIR/wsl.conf" "$ROOTFS_DIR/etc/wsl.conf"
        chmod 644 "$ROOTFS_DIR/etc/wsl.conf"
    fi

    # Copy wsl-distribution.conf if it exists
    if [ -f "$CONFIG_DIR/wsl-distribution.conf" ]; then
        echo "  - Copying wsl-distribution.conf"
        mkdir -p "$ROOTFS_DIR/etc"
        cp "$CONFIG_DIR/wsl-distribution.conf" "$ROOTFS_DIR/etc/wsl-distribution.conf"
        chmod 644 "$ROOTFS_DIR/etc/wsl-distribution.conf"
    fi

    # Copy OOBE script if it exists
    if [ -f "$CONFIG_DIR/oobe.sh" ]; then
        echo "  - Copying OOBE script"
        mkdir -p "$ROOTFS_DIR/usr/lib/wsl"
        cp "$CONFIG_DIR/oobe.sh" "$ROOTFS_DIR/usr/lib/wsl/oobe.sh"
        chmod 755 "$ROOTFS_DIR/usr/lib/wsl/oobe.sh"
    fi

    # Copy terminal profile if it exists
    if [ -f "$CONFIG_DIR/terminal-profile.json" ]; then
        echo "  - Copying terminal profile"
        mkdir -p "$ROOTFS_DIR/usr/lib/wsl"
        cp "$CONFIG_DIR/terminal-profile.json" "$ROOTFS_DIR/usr/lib/wsl/terminal-profile.json"
        chmod 644 "$ROOTFS_DIR/usr/lib/wsl/terminal-profile.json"
    fi

    # Copy icon if it exists
    if [ -f "$PROJECT_ROOT/assets/cachyos.ico" ]; then
        echo "  - Copying icon"
        mkdir -p "$ROOTFS_DIR/usr/lib/wsl"
        cp "$PROJECT_ROOT/assets/cachyos.ico" "$ROOTFS_DIR/usr/lib/wsl/cachyos.ico"
        chmod 644 "$ROOTFS_DIR/usr/lib/wsl/cachyos.ico"
    fi
else
    echo "  - No config directory found, skipping configuration files"
fi

##############################################################################
# Configure systemd
##############################################################################

echo "==> Configuring systemd..."

# Set multi-user.target as default (WSL is headless, no GUI)
echo "  - Setting multi-user.target as default"
mkdir -p "$ROOTFS_DIR/etc/systemd/system"
ln -sf /usr/lib/systemd/system/multi-user.target "$ROOTFS_DIR/etc/systemd/system/default.target"

##############################################################################
# Configure pacman
##############################################################################

echo "==> Configuring pacman..."

# Enable Color output in pacman for better user experience
if [ -f "$ROOTFS_DIR/etc/pacman.conf" ]; then
    echo "  - Enabling Color in pacman.conf"
    sed -i 's/^#Color$/Color/' "$ROOTFS_DIR/etc/pacman.conf"
else
    echo "  - Warning: /etc/pacman.conf not found, skipping Color configuration"
fi

# Enable some Arch mirrors in mirrorlist
if [ -f "$ROOTFS_DIR/etc/pacman.d/mirrorlist" ]; then
    echo "  - Enabling mirrors in /etc/pacman.d/mirrorlist"
    # Uncomment the first few worldwide mirrors for reliability
    # Match full URLs to avoid uncommenting comment headers
    sed -i 's|^#Server = https://geo.mirror.pkgbuild.com|Server = https://geo.mirror.pkgbuild.com|' "$ROOTFS_DIR/etc/pacman.d/mirrorlist"
    sed -i 's|^#Server = https://fastly.mirror.pkgbuild.com|Server = https://fastly.mirror.pkgbuild.com|' "$ROOTFS_DIR/etc/pacman.d/mirrorlist"
    sed -i 's|^#Server = https://mirror.rackspace.com/archlinux|Server = https://mirror.rackspace.com/archlinux|' "$ROOTFS_DIR/etc/pacman.d/mirrorlist"
    echo "  - Enabled geo.mirror.pkgbuild.com, fastly.mirror.pkgbuild.com, and mirror.rackspace.com"
else
    echo "  - Warning: /etc/pacman.d/mirrorlist not found"
fi

##############################################################################
# Run WSL cleanup
##############################################################################

echo "==> Running WSL cleanup..."

"$CLEANUP_SCRIPT" "$ROOTFS_DIR"

##############################################################################
# Validate rootfs
##############################################################################

echo "==> Validating rootfs..."

VALIDATE_SCRIPT="$SCRIPT_DIR/validate.sh"
if [ -f "$VALIDATE_SCRIPT" ]; then
    "$VALIDATE_SCRIPT" "$ROOTFS_DIR"
else
    echo "  - Warning: Validation script not found, skipping validation"
fi

##############################################################################
# Create tar archive
##############################################################################

echo "==> Creating tar archive..."

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Remove old archive if it exists
if [ -f "$OUTPUT_FILE" ]; then
    echo "  - Removing existing archive"
    rm -f "$OUTPUT_FILE"
fi

# Create tar archive with:
# --numeric-owner: Use numeric user/group IDs (not names)
# -c: Create archive
# -z: Compress with gzip
# -f: Output file
# -C: Change to directory before archiving
# --transform: Strip the leading 'rootfs/' from paths
#
# We use --transform to ensure the tar root is the filesystem root,
# not a parent directory

cd "$ROOTFS_DIR"
tar --numeric-owner \
    -czf "$OUTPUT_FILE" \
    *

echo "  - Archive created: $OUTPUT_FILE"

# Show archive size
ARCHIVE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
echo "  - Archive size: $ARCHIVE_SIZE"

##############################################################################
# Cleanup
##############################################################################

echo "==> Cleaning up temporary files..."

rm -rf "$ROOTFS_DIR"

echo "  - Temporary rootfs removed"

##############################################################################
# Success!
##############################################################################

echo ""
echo "========================================"
echo "Build completed successfully!"
echo "========================================"
echo "Output: $OUTPUT_FILE"
echo "Size: $ARCHIVE_SIZE"
echo ""
echo "To create a .wsl file:"
echo "  cd $OUTPUT_DIR"
echo "  mv cachyos-$ARCH-rootfs.tar.gz cachyos-$ARCH.wsl"
