![A graphic that combines the Pixquare logo (the letters P and x in a pixelated style) with the PowerShell Core logo (A >_ console icon tilted to the right.)](PS2PX.png)

# PX2PS

A PowerShell module that converts [Pixquare](https://pixquare.app) .px files to terminal pixel graphics using ANSI True Color.

## Installation

### From Source

```powershell
# Clone the repository
git clone https://github.com/jakehildreth/PX2PS.git

# Import the module
Import-Module ./PX2PS/PX2PS.psd1
```

## Quick Start

```powershell
# Convert and display a .px file
Convert-PX2PS -Path "image.px"

# Convert all .px files in a directory using alias
px2ps -Path "C:\PixelArt"

# Pipeline support
Get-ChildItem -Path . -Filter "*.px" | Convert-PX2PS

# Get scriptblock for deferred rendering
$sb = Convert-PX2PS -Path "logo.px" -OutputMode ScriptBlock
& $sb

# Generate standalone script file
Convert-PX2PS -Path "banner.px" -OutputMode Script -OutputPath "banner.ps1"

# -PassThru to get pixel data without rendering
$imageData = px2ps -Path "image.px" -PassThru
Write-Host "Dimensions: $($imageData.Width)x$($imageData.Height)"

```

## Features

- [x] Renders .px files directly in the terminal using ANSI True Color
- [x] Supports single-layer and multi-layer .px files
- [x] Automatic layer compositing and transparency handling
- [x] ScriptBlock output for deferred rendering
- [x] Standalone script generation
- [x] Cross-platform support (Windows, Linux, macOS)
- [x] PowerShell 5.1+ compatible
- [x] Pipeline input support

## Requirements

- PowerShell 5.1 or later
- Terminal with True Color (24-bit color) support

## How It Works

PX2PS reads Pixquare .px files, decompresses the zlib-encoded layer data, composites multiple layers if present, and renders the final image using Unicode lower half block characters (▄) with ANSI True Color escape sequences. Each terminal line represents two rows of pixels.

## Credits

Created by [Jake Hildreth](https://jakehildreth.com)

## License

See [LICENSE](LICENSE) file for details.
