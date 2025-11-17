#!/bin/bash
# CachyOS WSL Out-of-Box Experience (OOBE) Script
#
# This script runs on first launch to create a user account and configure
# the system for initial use.
#
# Based on research from official Arch Wiki and Microsoft WSL documentation.
# See docs/oobe-research.md for design decisions.

set -e  # Exit on error
set -u  # Exit on undefined variable

##############################################################################
# Configuration
##############################################################################

DEFAULT_UID="1000"
DEFAULT_GROUPS="wheel"  # Modern Arch approach - wheel group only

##############################################################################
# Check if user already exists
##############################################################################

if getent passwd "$DEFAULT_UID" > /dev/null; then
    echo "User account with UID $DEFAULT_UID already exists."
    echo "Skipping OOBE setup."
    exit 0
fi

##############################################################################
# Welcome message
##############################################################################

echo ""
echo "============================================"
echo "Welcome to CachyOS for WSL!"
echo "============================================"
echo ""
echo "Please create a default user account."
echo "This user will have administrative privileges via sudo."
echo ""
echo "For more information visit: https://wiki.cachyos.org/"
echo ""

##############################################################################
# Prompt for username and create user
##############################################################################

while true; do
    # Prompt for username
    read -p "Enter new UNIX username: " username

    # Validate username (basic check)
    if [[ ! "$username" =~ ^[a-z][-a-z0-9]*$ ]]; then
        echo "Error: Username must start with a lowercase letter and contain only lowercase letters, numbers, and hyphens."
        continue
    fi

    # Create the user with useradd (Arch-style)
    echo "Creating user: $username"

    if useradd \
        --uid "$DEFAULT_UID" \
        --groups "$DEFAULT_GROUPS" \
        --create-home \
        --shell /bin/bash \
        "$username"; then

        # Set password
        echo "Setting password for $username:"
        if passwd "$username"; then
            echo ""
            echo "User $username created successfully!"
            break
        else
            echo "Error: Failed to set password. Removing user and retrying."
            userdel -r "$username" 2>/dev/null || true
        fi
    else
        echo "Error: Failed to create user. Please try a different username."
    fi
done

##############################################################################
# Configure sudo access
##############################################################################

echo ""
echo "Configuring sudo access for wheel group..."

# Check if wheel group is already enabled in sudoers
if grep -q "^%wheel.*ALL=(ALL:ALL).*ALL" /etc/sudoers; then
    echo "Wheel group already configured in sudoers."
else
    # Add wheel group to sudoers using a drop-in file (safer than editing /etc/sudoers)
    echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
    chmod 0440 /etc/sudoers.d/wheel
    echo "Wheel group configured in /etc/sudoers.d/wheel"
fi

##############################################################################
# Initialize pacman keyring
##############################################################################

echo ""
echo "Initializing package manager keyring (this may take a moment)..."
echo "This is required for secure package installation."

# Initialize the keyring
if pacman-key --init; then
    echo "Keyring initialized successfully."
else
    echo "Warning: Keyring initialization failed. You may need to run 'sudo pacman-key --init' manually."
fi

# Populate with Arch and CachyOS keys
echo "Populating keyring with distribution keys..."
if pacman-key --populate archlinux cachyos; then
    echo "Keyring populated successfully."
else
    echo "Warning: Keyring population failed. You may need to run 'sudo pacman-key --populate archlinux cachyos' manually."
fi

##############################################################################
# Set default user in wsl.conf
##############################################################################

echo ""
echo "Setting default user for WSL..."

# Create or update /etc/wsl.conf with default user
if [ -f /etc/wsl.conf ]; then
    # File exists - check if [user] section exists
    if grep -q "^\[user\]" /etc/wsl.conf; then
        # [user] section exists - update or add default line
        if grep -q "^default=" /etc/wsl.conf; then
            # Update existing default
            sed -i "s/^default=.*/default=$username/" /etc/wsl.conf
        else
            # Add default under [user] section
            sed -i "/^\[user\]/a default=$username" /etc/wsl.conf
        fi
    else
        # Add [user] section
        echo "" >> /etc/wsl.conf
        echo "[user]" >> /etc/wsl.conf
        echo "default=$username" >> /etc/wsl.conf
    fi
else
    # Create new wsl.conf (should have been created by build, but just in case)
    cat > /etc/wsl.conf <<EOF
[user]
default=$username
EOF
fi

echo "Default user set to: $username"

##############################################################################
# Configure shell to start in home directory
##############################################################################

echo ""
echo "Configuring shell to start in home directory..."

# Add snippet to .bashrc to change to home directory when starting from Windows paths
# This ensures WSL starts in the Linux home directory instead of Windows home
USER_BASHRC="/home/$username/.bashrc"

if [ -f "$USER_BASHRC" ]; then
    # Check if snippet already exists
    if ! grep -q "WSL: Start in home directory" "$USER_BASHRC"; then
        cat >> "$USER_BASHRC" <<'BASHRC_EOF'

# WSL: Start in home directory if launched from Windows path
# This provides a better user experience by defaulting to Linux home
if [[ "$PWD" == /mnt/* ]]; then
    cd ~
fi
BASHRC_EOF
        echo "Added home directory snippet to .bashrc"
    else
        echo ".bashrc already configured"
    fi
else
    echo "Warning: .bashrc not found for $username"
fi

##############################################################################
# Success message
##############################################################################

echo ""
echo "============================================"
echo "Setup complete!"
echo "============================================"
echo ""
echo "User '$username' has been created with:"
echo "  - UID: $DEFAULT_UID"
echo "  - Groups: $DEFAULT_GROUPS"
echo "  - Sudo access: enabled"
echo "  - Package manager: configured"
echo ""
echo "You can now use 'sudo' to run commands with administrative privileges."
echo ""
echo "To update packages: sudo pacman -Syu"
echo "To install packages: sudo pacman -S <package-name>"
echo ""
echo "Enjoy CachyOS on WSL!"
echo ""

# Return success
exit 0
