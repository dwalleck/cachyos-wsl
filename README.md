# CachyOS for WSL

A custom Windows Subsystem for Linux (WSL) distribution based on CachyOS, an optimized Arch Linux distribution.

## Features

- 🚀 **CachyOS Base** - Built on CachyOS with optimized packages and performance tweaks
- 🎨 **Custom Branding** - CachyOS icon, Windows Terminal color scheme with signature teal/cyan accents
- ⚙️ **systemd Support** - Modern init system with properly configured services for WSL
- 🔒 **Secure Setup** - OOBE (Out-of-Box Experience) creates user with sudo access
- 📦 **Pacman Package Manager** - Access to Arch Linux and CachyOS repositories
- 🔄 **Windows Integration** - Seamless interoperability with Windows

## Requirements

- **Windows 10/11** with WSL 2 support
- **WSL 2.4.4 or later** (check with `wsl --version`)
- **Administrator privileges** (for installation)

## Quick Start

### Option 1: Direct Installation (Recommended)

1. Download `cachyos-v3.wsl` from [Releases](../../releases)

2. Open PowerShell and run:
   ```powershell
   wsl --install --from-file path\to\cachyos-v3.wsl
   ```

3. Follow the OOBE prompts to create your user account

4. Start using CachyOS WSL!

### Option 2: Local Testing (Developers)

For testing the distribution locally before wider distribution:

1. Clone this repository
2. Download the built `.wsl` file or build from source
3. Run the test script in PowerShell (as Administrator):
   ```powershell
   .\scripts\override-manifest.ps1 -TarPath .\dist\cachyos-v3.wsl
   wsl --install cachyos-wsl-v1
   ```

See [Testing Guide](docs/testing-guide.md) for detailed testing procedures.

## Building from Source

### Prerequisites

- Linux machine with Docker installed
- Make, tar, gzip
- ImageMagick (for icon conversion)

### Build Steps

```bash
# Clone the repository
git clone https://github.com/dwalleck/cachyos-wsl.git
cd cachyos-wsl

# Build the rootfs (requires Docker)
make rootfs

# Create the .wsl file
cd dist
cp cachyos-v3-rootfs.tar.gz cachyos-v3.wsl
```

The resulting `dist/cachyos-v3.wsl` file can be installed on Windows.

## First Run Experience

On first launch, you'll see:

```
============================================
Welcome to CachyOS for WSL!
============================================

Please create a default user account.
This user will have administrative privileges via sudo.

For more information visit: https://wiki.cachyos.org/

Enter new UNIX username:
```

The OOBE script will:
1. Create your user account with UID 1000
2. Add you to the `wheel` group for sudo access
3. Configure sudo permissions
4. Initialize the pacman keyring for package management
5. Set you as the default user for future launches

## Package Management

CachyOS WSL uses **pacman** as its package manager:

```bash
# Update package databases
sudo pacman -Sy

# Search for packages
pacman -Ss <package-name>

# Install packages
sudo pacman -S <package-name>

# Update all packages
sudo pacman -Syu

# Remove packages
sudo pacman -R <package-name>
```

### Available Repositories

- **core** - Essential Arch Linux packages
- **extra** - Additional Arch Linux packages
- **multilib** - 32-bit libraries
- **cachyos** - CachyOS-specific optimized packages

## Configuration

### WSL Configuration

Located at `/etc/wsl.conf`:
- systemd enabled
- Network auto-generation enabled
- Windows interop enabled
- Windows PATH appended

### Distribution Configuration

Located at `/etc/wsl-distribution.conf`:
- OOBE script: `/usr/lib/wsl/oobe.sh`
- Default UID: 1000
- Custom icon: `/usr/lib/wsl/cachyos.ico`
- Terminal profile: `/usr/lib/wsl/terminal-profile.json`

## Windows Terminal Integration

The distribution automatically creates a Windows Terminal profile with:
- **Nord-based dark theme** - Matches CachyOS desktop aesthetic
- **Signature cyan colors** - CachyOS branding (#1dc7b5, #00ccff)
- **Cascadia Code font** - Modern monospace with ligatures
- **95% opacity** - Subtle transparency

## Troubleshooting

### Package Signature Errors

If you encounter signature errors with pacman:
```bash
sudo pacman-key --init
sudo pacman-key --populate archlinux cachyos
```

### OOBE Doesn't Run

Manually run the OOBE script:
```bash
sudo /usr/lib/wsl/oobe.sh
```

### systemd Issues

Verify systemd is enabled:
```bash
cat /etc/wsl.conf  # Check [boot] systemd = true
systemctl status   # Should show "running"
```

## Documentation

- [Testing Guide](docs/testing-guide.md) - Comprehensive testing procedures
- [OOBE Research](docs/oobe-research.md) - Design decisions for user setup
- [Branding Research](docs/branding-research.md) - CachyOS colors and assets
- [WSL Configuration Research](docs/wsl-distribution-conf-research.md) - WSL config details
- [PowerShell Testing](docs/powershell-test-script-research.md) - Local testing approach

## Project Structure

```
cachyos-wsl/
├── build/               # Build scripts
│   ├── build-rootfs.sh  # Main build orchestration
│   ├── cleanup.sh       # WSL-specific cleanup
│   └── packages.list    # Package list for rootfs
├── config/              # Configuration files
│   ├── oobe.sh          # First-run user setup script
│   ├── wsl.conf         # WSL per-distribution settings
│   ├── wsl-distribution.conf  # Distribution metadata
│   └── terminal-profile.json  # Windows Terminal colors
├── assets/              # Branding assets
│   ├── cachyos.svg      # Original logo (vector)
│   └── cachyos.ico      # Windows icon (multi-resolution)
├── scripts/             # Helper scripts
│   └── override-manifest.ps1  # Local testing script
├── docs/                # Documentation
├── dist/                # Build output (gitignored)
│   ├── cachyos-v3-rootfs.tar.gz
│   └── cachyos-v3.wsl
└── Makefile             # Build automation
```

## Contributing

This project was built as a learning exercise to understand WSL custom distribution creation. Contributions, suggestions, and feedback are welcome!

### Development Workflow

1. Make changes to config files or build scripts
2. Rebuild rootfs: `make clean && make rootfs`
3. Test on Windows using the testing guide
4. Document any issues or improvements
5. Iterate

## Credits

- **CachyOS Team** - For the excellent Arch-based distribution and optimizations
- **Microsoft** - For WSL and comprehensive documentation
- **Arch Linux** - For the solid foundation
- **Nord Theme** - For the beautiful color palette used in Terminal

## License

This project packages and configures existing open-source software:
- CachyOS and Arch Linux packages are under their respective licenses
- CachyOS branding used with reference to official sources
- Build scripts and configuration files: MIT License (see below)

### MIT License

```
MIT License

Copyright (c) 2025

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Links

- [CachyOS Official Website](https://cachyos.org/)
- [CachyOS Wiki](https://wiki.cachyos.org/)
- [WSL Documentation](https://learn.microsoft.com/en-us/windows/wsl/)
- [Arch Linux Wiki](https://wiki.archlinux.org/)

---

**Built with ❤️ as a learning project**

For questions or issues, please open a GitHub issue.
