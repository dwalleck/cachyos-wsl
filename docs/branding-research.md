# CachyOS Branding Assets Research

Research conducted for cachyos-wsl-68h

## Official Logo Sources

### Primary Source: GitHub Repository

**Location:** https://github.com/CachyOS/CachyOS-icons

The CachyOS-icons repository contains official logo assets in multiple formats:
- **White/CachyOS.svg** - White version of logo (for dark backgrounds)
- **Black/CachyOS.svg** - Black version (for light backgrounds)
- **Green/CachyOS.svg** - Green version (brand color variant)

**License:** Check repository for current license terms

### Alternative Source: Wikimedia Commons

**Location:** https://commons.wikimedia.org/wiki/File:CachyOS_Logo.svg

Official CachyOS logo available as SVG (scalable vector graphics).

**Advantage:** Freely licensed, high quality vector format
**Disadvantage:** May need conversion to .ico format for Windows

## Brand Colors

### Primary Color Palette

Based on official CachyOS-icons repository and theme files:

| Color Name | Hex Code | RGB | Usage |
|------------|----------|-----|-------|
| **Highlight (Teal)** | `#1dc7b5` | 29, 199, 181 | Primary accent, icon highlights |
| **Cyan** | `#00ccff` | 0, 204, 255 | Logo accent, bright highlights |
| **Dark Gray** | `#333333` | 51, 51, 51 | Text, foreground |
| **White** | `#ffffff` | 255, 255, 255 | Background, logo base |
| **Near Black** | `#020202` | 2, 2, 2 | Shadows, gradients |

### Theme-Specific Colors (Emerald)

CachyOS Emerald theme uses green accents:

| Color Name | Hex Code | RGB | Usage |
|------------|----------|-----|-------|
| **Dark Green** | `#006d0c` | 0, 109, 12 | Focus/selection |
| **Bright Green** | `#009014` | 0, 144, 20 | Hover states |
| **Light Green** | `#71f79f` | 113, 247, 159 | Positive/success |

### Recommended Colors for WSL

For Windows Terminal profile, use the primary palette:
- **Background**: `#ffffff` (white) or `#282c34` (dark gray for dark theme)
- **Foreground**: `#333333` (dark gray)
- **Cursor**: `#1dc7b5` (teal highlight)
- **Selection**: `#1dc7b5` with 30% opacity

## Terminal Color Schemes

### CachyOS Default Approach

CachyOS uses **Nord-based color schemes** for terminal applications:
- **Theme files:** CachyOSNord.colors, CachyOSNordLightly.colors
- **Location (system):** `/usr/share/color-schemes/`
- **Location (user):** `~/.local/share/konsole/`

### Nord Color Palette (Base Reference)

Since CachyOS uses Nord variants, reference the Nord palette:

**Polar Night (Dark):**
- `#2E3440` - Background
- `#3B4252` - Lighter background
- `#434C5E` - Selection
- `#4C566A` - Comments

**Snow Storm (Light):**
- `#D8DEE9` - Light gray
- `#E5E9F0` - Lighter gray
- `#ECEFF4` - White

**Frost (Blue/Cyan accents):**
- `#8FBCBB` - Teal (similar to CachyOS #1dc7b5)
- `#88C0D0` - Light blue
- `#81A1C1` - Medium blue
- `#5E81AC` - Dark blue

**Aurora (Semantic colors):**
- `#BF616A` - Red (errors)
- `#D08770` - Orange (warnings)
- `#EBCB8B` - Yellow (attention)
- `#A3BE8C` - Green (success)
- `#B48EAD` - Purple (special)

## Windows Terminal Profile Template

### Recommended Configuration

For our Windows Terminal profile template, use a color scheme that matches CachyOS branding while maintaining Nord compatibility:

```json
{
    "background": "#2E3440",
    "foreground": "#D8DEE9",
    "black": "#3B4252",
    "red": "#BF616A",
    "green": "#A3BE8C",
    "yellow": "#EBCB8B",
    "blue": "#81A1C1",
    "purple": "#B48EAD",
    "cyan": "#1dc7b5",
    "white": "#E5E9F0",
    "brightBlack": "#4C566A",
    "brightRed": "#BF616A",
    "brightGreen": "#A3BE8C",
    "brightYellow": "#EBCB8B",
    "brightBlue": "#81A1C1",
    "brightPurple": "#B48EAD",
    "brightCyan": "#00ccff",
    "brightWhite": "#ECEFF4",
    "cursorColor": "#1dc7b5",
    "selectionBackground": "#4C566A"
}
```

**Key customizations:**
- **cyan/brightCyan**: Use CachyOS signature colors (#1dc7b5 and #00ccff)
- **cursorColor**: Use teal highlight (#1dc7b5)
- Otherwise follow Nord palette for consistency

### Alternative: Light Theme

For users who prefer light terminals:

```json
{
    "background": "#FFFFFF",
    "foreground": "#333333",
    "cursorColor": "#1dc7b5",
    "selectionBackground": "#D8DEE9"
}
```

## Icon File (.ico) Creation

### Conversion Process

To create a Windows .ico file from SVG:

1. **Download SVG:** Get White/CachyOS.svg from CachyOS-icons repo
2. **Convert to PNG:** Use Inkscape or ImageMagick to render at multiple sizes:
   - 16x16, 32x32, 48x48, 64x64, 128x128, 256x256
3. **Combine to ICO:** Use ImageMagick or an online converter
4. **Verify size:** Must be under 10MB (should be well under this limit)

### Command Line Approach

Using ImageMagick:

```bash
# Download SVG
curl -o cachyos.svg https://raw.githubusercontent.com/CachyOS/CachyOS-icons/master/White/CachyOS.svg

# Convert to multi-resolution ICO
convert cachyos.svg -resize 256x256 \
    \( -clone 0 -resize 128x128 \) \
    \( -clone 0 -resize 64x64 \) \
    \( -clone 0 -resize 48x48 \) \
    \( -clone 0 -resize 32x32 \) \
    \( -clone 0 -resize 16x16 \) \
    cachyos.ico
```

### Alternative: Use Existing PNG

If SVG conversion is problematic, CachyOS may have PNG versions available in their repositories.

## Decisions for Our Implementation

### Icon File
- **Source:** Download White/CachyOS.svg from CachyOS/CachyOS-icons
- **Format:** Convert to .ico with multiple resolutions (16-256px)
- **Location in rootfs:** `/usr/lib/wsl/cachyos.ico`
- **Referenced in:** `/etc/wsl-distribution.conf` → `shortcut.icon`

### Terminal Profile
- **Base scheme:** Nord palette with CachyOS cyan accents
- **Key color:** Use #1dc7b5 for cursor and cyan colors
- **Format:** JSON (without 'name' or 'commandLine' fields)
- **Location in rootfs:** `/usr/lib/wsl/terminal-profile.json`
- **Referenced in:** `/etc/wsl-distribution.conf` → `windowsterminal.profileTemplate`

### Brand Consistency
- Maintain Nord-based aesthetic (matches CachyOS desktop experience)
- Use signature teal/cyan (#1dc7b5, #00ccff) for brand recognition
- Dark theme by default (matches developer preferences)

## Implementation Files Needed

1. **assets/cachyos.svg** - Downloaded from CachyOS-icons repository
2. **assets/cachyos.ico** - Converted from SVG
3. **config/terminal-profile.json** - Windows Terminal color scheme

## References

- [CachyOS-icons GitHub Repository](https://github.com/CachyOS/CachyOS-icons)
- [CachyOS Emerald KDE Theme](https://github.com/CachyOS/CachyOS-Emerald-KDE)
- [Nord Color Palette](https://www.nordtheme.com/)
- [Windows Terminal Color Schemes Documentation](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/color-schemes)
- [Wikimedia Commons: CachyOS Logo](https://commons.wikimedia.org/wiki/File:CachyOS_Logo.svg)
