# WSL-specific configuration for Fish shell
# This file is automatically sourced by Fish on startup
#
# Purpose: Handle Windows mount point paths in WSL
# When WSL is launched from Windows (e.g., from File Explorer or Windows Terminal),
# it starts in the Windows working directory, which is mounted under /mnt/
# This provides a better UX by automatically changing to the Linux home directory.

# Check if current directory is a Windows mount point
if string match -q "/mnt/*" $PWD
    # Change to home directory for better WSL experience
    cd ~
end
