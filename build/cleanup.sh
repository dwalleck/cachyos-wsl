#!/bin/bash
# WSL Cleanup Script
#
# This script makes a Linux rootfs WSL-compliant by removing files that
# cause conflicts with WSL and ensuring proper system configuration.
#
# Usage: cleanup.sh <rootfs_path>
# Example: cleanup.sh /rootfs

set -e  # Exit on error
set -u  # Exit on undefined variable

ROOTFS="${1:-/rootfs}"

echo "==> Starting WSL cleanup for: $ROOTFS"

# Verify rootfs exists
if [ ! -d "$ROOTFS" ]; then
    echo "ERROR: Rootfs directory not found: $ROOTFS"
    exit 1
fi

##############################################################################
# Remove WSL-incompatible files
##############################################################################

echo "==> Removing WSL-incompatible files..."

# WSL manages DNS, so remove any existing resolv.conf
if [ -f "$ROOTFS/etc/resolv.conf" ] || [ -L "$ROOTFS/etc/resolv.conf" ]; then
    echo "  - Removing /etc/resolv.conf"
    rm -f "$ROOTFS/etc/resolv.conf"
fi

# WSL generates machine-id dynamically
if [ -f "$ROOTFS/etc/machine-id" ]; then
    echo "  - Removing /etc/machine-id"
    rm -f "$ROOTFS/etc/machine-id"
fi

# WSL manages hostname
if [ -f "$ROOTFS/etc/hostname" ]; then
    echo "  - Removing /etc/hostname"
    rm -f "$ROOTFS/etc/hostname"
fi

# WSL manages /etc/hosts
if [ -f "$ROOTFS/etc/hosts" ]; then
    echo "  - Removing /etc/hosts"
    rm -f "$ROOTFS/etc/hosts"
fi

##############################################################################
# Clean up shadow file (remove password hashes)
##############################################################################

echo "==> Cleaning /etc/shadow..."

if [ -f "$ROOTFS/etc/shadow" ]; then
    # Replace all password hashes with '!' (locked account)
    # This allows WSL's OOBE to set passwords properly
    sed -i 's/^\([^:]*\):[^:]*:/\1:!:/' "$ROOTFS/etc/shadow"
    echo "  - Removed password hashes from /etc/shadow"
fi

##############################################################################
# Verify root user exists
##############################################################################

echo "==> Verifying root user configuration..."

if ! grep -q '^root:x:0:0:' "$ROOTFS/etc/passwd"; then
    echo "ERROR: Root user with uid=0 not found in /etc/passwd"
    exit 1
fi

echo "  - Root user verified (uid=0)"

##############################################################################
# Remove kernel and initramfs files
##############################################################################

echo "==> Removing kernel and initramfs files..."

# Remove kernel files
if ls "$ROOTFS/boot/vmlinuz"* &>/dev/null; then
    echo "  - Removing kernel files from /boot"
    rm -f "$ROOTFS/boot/vmlinuz"*
fi

# Remove initramfs files
if ls "$ROOTFS/boot/initramfs"* &>/dev/null || ls "$ROOTFS/boot/initrd"* &>/dev/null; then
    echo "  - Removing initramfs files from /boot"
    rm -f "$ROOTFS/boot/initramfs"* "$ROOTFS/boot/initrd"*
fi

# Remove systemd's kernel install directory if present
if [ -d "$ROOTFS/usr/lib/kernel" ]; then
    echo "  - Removing /usr/lib/kernel"
    rm -rf "$ROOTFS/usr/lib/kernel"
fi

##############################################################################
# Mask problematic systemd services
##############################################################################

echo "==> Masking problematic systemd services..."

# Only mask services if systemd is present
if [ -d "$ROOTFS/usr/lib/systemd/system" ]; then
    # Create systemd mask directory if it doesn't exist
    mkdir -p "$ROOTFS/etc/systemd/system"

    # Services that conflict with WSL
    SERVICES_TO_MASK=(
        "systemd-resolved.service"
        "systemd-networkd.service"
        "systemd-networkd.socket"
        "NetworkManager.service"
        "systemd-timesyncd.service"
        "tmp.mount"
    )

    # Mask each service by symlinking to /dev/null
    for service in "${SERVICES_TO_MASK[@]}"; do
        if [ -f "$ROOTFS/usr/lib/systemd/system/$service" ]; then
            echo "  - Masking $service"
            ln -sf /dev/null "$ROOTFS/etc/systemd/system/$service"
        fi
    done

    # Mask systemd-tmpfiles services and timers
    for unit in "$ROOTFS"/usr/lib/systemd/system/systemd-tmpfiles-*.{service,timer}; do
        if [ -f "$unit" ]; then
            unit_name=$(basename "$unit")
            echo "  - Masking $unit_name"
            ln -sf /dev/null "$ROOTFS/etc/systemd/system/$unit_name"
        fi
    done

    echo "  - Systemd services masked"
else
    echo "  - Systemd not present, skipping service masking"
fi

##############################################################################
# Final verification
##############################################################################

echo "==> Running final verification..."

# Verify critical files don't exist
SHOULD_NOT_EXIST=(
    "$ROOTFS/etc/resolv.conf"
    "$ROOTFS/etc/machine-id"
    "$ROOTFS/etc/hostname"
)

for file in "${SHOULD_NOT_EXIST[@]}"; do
    if [ -e "$file" ]; then
        echo "WARNING: $file still exists after cleanup"
    fi
done

echo "==> WSL cleanup completed successfully!"
echo ""
echo "Summary:"
echo "  - Removed WSL-incompatible files"
echo "  - Cleaned password hashes from /etc/shadow"
echo "  - Verified root user (uid=0)"
echo "  - Removed kernel/initramfs files"
echo "  - Masked problematic systemd services"
