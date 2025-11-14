# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains work to build a custom **CachyOS distribution for Windows Subsystem for Linux (WSL)**. The goal is to create a `.wsl` file that users can install on Windows via `wsl --install --from-file <file>` or by double-clicking in File Explorer.

The project follows Microsoft's modern tar-based WSL distribution format (WSL 2.4.4+), not the legacy appx format.

## Project Management with Beads

This project uses **Beads (bd)** for dependency-aware issue tracking. Beads stores work items in a local SQLite database (`.beads/beads.db`) with automatic git synchronization.

### Key Beads Commands

```bash
# View all work items
bd list

# Show ready-to-work tasks (no blockers)
bd ready

# Show details of a specific issue
bd show <issue-id>

# Update issue status
bd update <issue-id> --status in_progress
bd update <issue-id> --status open
bd close <issue-id>

# View dependency tree
bd dep tree <issue-id>

# View blocked issues
bd blocked
```

### Beads MCP Integration

When using Claude Code's MCP tools for Beads:
- **ALWAYS** call `mcp__plugin_beads_beads__set_context` with the workspace root first
- Use `mcp__plugin_beads_beads__ready` to find unblocked tasks
- Use `mcp__plugin_beads_beads__list` to see all issues
- Use `mcp__plugin_beads_beads__show` to view issue details including dependencies

The database auto-syncs to `.beads/beads.jsonl` for version control (configured in `.gitattributes` to use `merge=beads`).

## WSL Distribution Build Process

The build follows this dependency chain:

1. **Obtain CachyOS root filesystem** (critical path)
   - Options: Docker export, official rootfs, or build from scratch
   - Must exclude: `/etc/resolv.conf`, kernel, initramfs, password hashes
   - Must include: root user with uid=0

2. **Create WSL configuration files** (parallel tasks after rootfs obtained)
   - `/etc/wsl-distribution.conf` - Controls OOBE, shortcuts, terminal profile
   - `/etc/wsl.conf` - Per-distribution settings (systemd, etc.)
   - OOBE script (e.g., `/etc/oobe.sh`) - First-run user creation
   - Windows Terminal profile template (JSON)
   - Icon file (`.ico` format, max 10MB)

3. **Package and test**
   - Package rootfs as `tar.gz` using: `tar --numeric-owner --absolute-names -c * | gzip --best > install.tar.gz`
   - Rename to `.wsl` extension
   - Test locally using PowerShell registry override script
   - Validate installation, OOBE, shortcuts, and terminal profile

## Critical WSL Configuration Requirements

### /etc/wsl-distribution.conf
- Required fields: `oobe.command`, `oobe.defaultUid` (1000), `oobe.defaultName`
- Set `shortcut.enabled=true` and `shortcut.icon` for Start Menu integration
- Set `windowsterminal.enabled=true` for Windows Terminal integration
- File must be `root:root` with permissions `0644`

### OOBE Script Requirements
- Create user with uid 1000
- Add user to wheel/sudo groups for privilege escalation
- Set default user in `/etc/wsl.conf` via `[user]\ndefault=$username`
- Must return 0 on success (non-zero blocks shell access)
- Handle existing user gracefully (check if uid 1000 exists)

### systemd Configuration (if enabled)
Must disable/mask these problematic units:
- systemd-resolved.service
- systemd-networkd.service
- NetworkManager.service
- systemd-tmpfiles-* services and timers
- tmp.mount

### Tar Packaging Requirements
- Root of tar must be filesystem root (not a parent directory)
- Use gzip compression for compatibility
- Use `--numeric-owner` flag to preserve uid/gid numbers
- Tar must not contain `/etc/resolv.conf`

## Local Testing Workflow

1. Create PowerShell test script (`override-manifest.ps1`) that:
   - Computes SHA256 hash of `.wsl` file
   - Generates local manifest JSON
   - Sets registry key: `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss\DistributionListUrl`

2. Run in elevated PowerShell:
   ```powershell
   .\override-manifest.ps1 -TarPath /path/to/cachyos.wsl
   wsl --list --online  # Verify distribution appears
   wsl --install test-distro
   ```

3. Clean up registry key after testing:
   ```powershell
   Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss" -Name DistributionListUrl
   ```

## Reference Documentation

- `build-custom-distro.md` - Downloaded Microsoft WSL documentation for building custom distributions
- `use-custom-distro.md` - Documentation on importing/using custom distributions
- Sample OOBE script in `build-custom-distro.md` lines 124-155
- Sample PowerShell test script in `build-custom-distro.md` lines 336-370

## Architecture Notes

This is a **packaging project**, not a software development project. The deliverable is a `.wsl` file containing:
- CachyOS Linux root filesystem
- WSL configuration files
- OOBE scripts
- Branding assets (icon, terminal profile)

The repository structure will evolve to include build scripts, configuration templates, and the final distribution artifact.
