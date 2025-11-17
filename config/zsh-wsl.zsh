# WSL-specific configuration for Zsh
# This file should be sourced from ~/.zshrc
#
# Purpose: Handle Windows mount point paths in WSL and set locale
# When WSL is launched from Windows (e.g., from File Explorer or Windows Terminal),
# it starts in the Windows working directory, which is mounted under /mnt/
# This provides a better UX by automatically changing to the Linux home directory.

# Check if current directory is a Windows mount point
if [[ "$PWD" == /mnt/* ]]; then
    # Change to home directory for better WSL experience
    cd ~
fi

# Set locale for GUI applications
# Read from /etc/locale.conf if it exists
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
