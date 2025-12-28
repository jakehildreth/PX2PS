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
# Convert a single .px file
ConvertFrom-PxFile -Path "image.px"

# Convert all .px files in a directory
ConvertFrom-PxFile -Path "C:\PixelArt"

# Pipeline support
Get-ChildItem -Path . -Filter "*.px" | ConvertFrom-PxFile
```

## Features

- [x] Renders .px files directly in the terminal using ANSI True Color
- [x] Supports single-layer and multi-layer .px files
- [x] Automatic layer compositing and transparency handling
- [x] Cross-platform support (Windows, Linux, macOS)
- [x] PowerShell 5.1+ compatible
- [x] Pipeline input support

## Requirements

- PowerShell 5.1 or later
- Terminal with True Color (24-bit color) support

## Examples

### Basic Usage

```powershell
# Display a pixel art file
ConvertFrom-PxFile -Path "Stepper 4.px"
```

### Working with Directories

```powershell
# Process all .px files in the current directory
ConvertFrom-PxFile -Path .

# Process files from a specific folder
ConvertFrom-PxFile -Path "C:\Users\Jake\Pictures\PixelArt"
```

### Pipeline Operations

```powershell
# Filter and display specific files
Get-ChildItem -Recurse -Filter "*.px" | 
    Where-Object { $_.Name -like "*logo*" } | 
    ConvertFrom-PxFile
```

### Using PassThru

```powershell
# Get pixel data without rendering
$imageData = ConvertFrom-PxFile -Path "image.px" -PassThru
Write-Host "Dimensions: $($imageData.Width)x$($imageData.Height)"
```

## How It Works

PX2PS reads Pixquare .px files, decompresses the zlib-encoded layer data, composites multiple layers if present, and renders the final image using Unicode lower half block characters (▄) with ANSI True Color escape sequences. Each terminal line represents two rows of pixels.

## Credits

Created by [Jake Hildreth](https://jakehildreth.com)

## License

See [LICENSE](LICENSE) file for details.
