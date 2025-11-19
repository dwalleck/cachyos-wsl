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
    existing_user=$(getent passwd "$DEFAULT_UID" | cut -d: -f1)
    echo ""
    echo "Default user already exists: $existing_user (UID $DEFAULT_UID)"
    echo "Skipping user creation."
    echo ""
    echo "To create a new user or change the default user, run:"
    echo "  sudo useradd -m -G wheel <username>"
    echo "  Then edit /etc/wsl.conf to set [user] default=<username>"
    echo ""
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
        --shell /usr/bin/fish \
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
# Configure system locale
##############################################################################

echo ""
echo "Configuring system locale..."

# Try to detect Windows locale and map to Linux locale
DETECTED_LOCALE=""
if command -v powershell.exe &> /dev/null; then
    # Get Windows locale (e.g., "en-US", "de-DE", "ja-JP")
    WIN_LOCALE=$(powershell.exe -NoProfile -Command "Get-Culture | Select-Object -ExpandProperty Name" 2>/dev/null | tr -d '\r\n')

    # Map common Windows locales to Linux locales
    case "$WIN_LOCALE" in
        en-US) DETECTED_LOCALE="en_US.UTF-8" ;;
        en-GB) DETECTED_LOCALE="en_GB.UTF-8" ;;
        de-DE) DETECTED_LOCALE="de_DE.UTF-8" ;;
        fr-FR) DETECTED_LOCALE="fr_FR.UTF-8" ;;
        es-ES) DETECTED_LOCALE="es_ES.UTF-8" ;;
        it-IT) DETECTED_LOCALE="it_IT.UTF-8" ;;
        ja-JP) DETECTED_LOCALE="ja_JP.UTF-8" ;;
        zh-CN) DETECTED_LOCALE="zh_CN.UTF-8" ;;
        zh-TW) DETECTED_LOCALE="zh_TW.UTF-8" ;;
        ko-KR) DETECTED_LOCALE="ko_KR.UTF-8" ;;
        pt-BR) DETECTED_LOCALE="pt_BR.UTF-8" ;;
        ru-RU) DETECTED_LOCALE="ru_RU.UTF-8" ;;
        pl-PL) DETECTED_LOCALE="pl_PL.UTF-8" ;;
        nl-NL) DETECTED_LOCALE="nl_NL.UTF-8" ;;
        sv-SE) DETECTED_LOCALE="sv_SE.UTF-8" ;;
        *)     DETECTED_LOCALE="en_US.UTF-8" ;;  # Fallback
    esac
fi

# Default to en_US.UTF-8 if detection failed
SELECTED_LOCALE="${DETECTED_LOCALE:-en_US.UTF-8}"

# Show detected/default locale and allow user to change
echo ""
if [ -n "$WIN_LOCALE" ]; then
    echo "Detected Windows locale: $WIN_LOCALE"
fi
echo "System locale will be set to: $SELECTED_LOCALE"
read -p "Press Enter to accept, or type a different locale (e.g., de_DE.UTF-8, ja_JP.UTF-8): " user_locale

if [ -n "$user_locale" ]; then
    SELECTED_LOCALE="$user_locale"
    echo "Using locale: $SELECTED_LOCALE"
fi

# Convert locale to locale.gen format (e.g., "en_US.UTF-8 UTF-8")
LOCALE_GEN_LINE="${SELECTED_LOCALE} UTF-8"

# Enable the selected locale in locale.gen
if [ -f /etc/locale.gen ]; then
    # Uncomment the selected locale if it exists
    if grep -q "^#${LOCALE_GEN_LINE}" /etc/locale.gen; then
        sed -i "s/^#${LOCALE_GEN_LINE}/${LOCALE_GEN_LINE}/" /etc/locale.gen
    # Or add it if it doesn't exist
    elif ! grep -q "^${LOCALE_GEN_LINE}" /etc/locale.gen; then
        echo "${LOCALE_GEN_LINE}" >> /etc/locale.gen
    fi

    # Generate the locale
    if locale-gen; then
        echo "Locale '${SELECTED_LOCALE}' generated successfully."
    else
        echo "Warning: Locale generation failed. Falling back to C locale."
        SELECTED_LOCALE="C.UTF-8"
    fi
else
    echo "Warning: /etc/locale.gen not found, using C.UTF-8"
    SELECTED_LOCALE="C.UTF-8"
fi

# Set system-wide locale
echo "LANG=${SELECTED_LOCALE}" > /etc/locale.conf
export LANG="${SELECTED_LOCALE}"

echo "System locale set to: ${SELECTED_LOCALE}"

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

# WSL: Set locale for GUI applications
if [ -f /etc/locale.conf ]; then
    export $(grep '^LANG=' /etc/locale.conf)
    export LC_ALL="$LANG"
fi

# WSLg support: Set XDG_RUNTIME_DIR to where WSLg mounts Wayland/DBus sockets
# WSLg provides Wayland, X11, and PulseAudio sockets in /mnt/wslg/runtime-dir
# This is required for GUI applications to work properly with WSLg
if [ -d /mnt/wslg/runtime-dir ]; then
    export XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir
    export WAYLAND_DISPLAY=wayland-0
    export DISPLAY=:0
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
echo "  - Default shell: Fish (modern, user-friendly)"
echo ""
echo "You can now use 'sudo' to run commands with administrative privileges."
echo ""
echo "Shell options:"
echo "  - Fish (default): Modern shell with excellent defaults and CachyOS customizations"
echo "  - Zsh: Powerful shell with oh-my-zsh and Powerlevel10k theme"
echo "  - Bash: Traditional shell (available as fallback)"
echo ""
echo "To switch shells:"
echo "  chsh -s /usr/bin/fish   # Fish (default)"
echo "  chsh -s /usr/bin/zsh    # Zsh"
echo "  chsh -s /bin/bash       # Bash"
echo ""
echo "Package management:"
echo "  sudo pacman -Syu         # Update all packages"
echo "  sudo pacman -S <package> # Install a package"
echo ""
echo "Enjoy CachyOS on WSL!"
echo ""

# Return success
exit 0
