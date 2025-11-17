# WSL-specific configuration for Fish shell
# This file is automatically sourced by Fish on startup
#
# Purpose: Handle Windows mount point paths in WSL and set locale
# When WSL is launched from Windows (e.g., from File Explorer or Windows Terminal),
# it starts in the Windows working directory, which is mounted under /mnt/
# This provides a better UX by automatically changing to the Linux home directory.

# Check if current directory is a Windows mount point
if string match -q "/mnt/*" $PWD
    # Change to home directory for better WSL experience
    cd ~
end

# Set locale for GUI applications
# Read from /etc/locale.conf if it exists
if test -f /etc/locale.conf
    set -l locale_lang (grep '^LANG=' /etc/locale.conf | cut -d= -f2)
    if test -n "$locale_lang"
        set -gx LANG $locale_lang
        set -gx LC_ALL $locale_lang
    end
end
