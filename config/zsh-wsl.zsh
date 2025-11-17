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
