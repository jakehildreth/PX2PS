<#
.SYNOPSIS
    Converts Pixquare .px files to terminal pixel graphics.

.DESCRIPTION
    Reads .px pixel art files and renders them in the PowerShell terminal
    using the lower half block character (▄). Each line of output represents
    two rows of pixels: top pixel = BackgroundColor, bottom pixel = ForegroundColor.

.PARAMETER Path
    Path to a .px file or directory containing .px files.

.EXAMPLE
    .\px2term.ps1 "Stepper 4.px"
    .\px2term.ps1 .
#>

param(
    [Parameter(Position = 0)]
    [string]$Path = "."
)

# Enable Virtual Terminal Processing for ANSI colors (Windows PowerShell 5.1 compatibility)
if ($PSVersionTable.PSVersion.Major -le 5 -and $env:OS -eq 'Windows_NT') {
    $vtEnabled = $false
    try {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class VTConsole {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetStdHandle(int nStdHandle);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
    public static void EnableVT() {
        IntPtr handle = GetStdHandle(-11);
        uint mode;
        GetConsoleMode(handle, out mode);
        SetConsoleMode(handle, mode | 0x4);
    }
}
"@ -ErrorAction SilentlyContinue
        [VTConsole]::EnableVT()
        $vtEnabled = $true
    } catch {
        # VT processing may already be enabled or not available
    }
}

Add-Type -AssemblyName System.IO.Compression

# Lower half block character
$LowerHalfBlock = [char]0x2584

# ANSI escape character
$ESC = [char]27

function Get-TrueColorFg {
    param([int]$R, [int]$G, [int]$B)
    return "$ESC[38;2;${R};${G};${B}m"
}

function Get-TrueColorBg {
    param([int]$R, [int]$G, [int]$B)
    return "$ESC[48;2;${R};${G};${B}m"
}

function Get-AnsiReset {
    return "$ESC[0m"
}

function Decompress-Zlib {
    <#
    .SYNOPSIS
        Decompresses zlib data (skips 2-byte header, uses raw deflate).
    #>
    param([byte[]]$Data, [int]$Offset)
    
    # Skip 2-byte zlib header (78 xx)
    $slice = $Data[($Offset + 2)..($Data.Length - 1)]
    $ms = New-Object System.IO.MemoryStream (, $slice)
    $ds = New-Object System.IO.Compression.DeflateStream ($ms, [System.IO.Compression.CompressionMode]::Decompress)
    $outMs = New-Object System.IO.MemoryStream
    $ds.CopyTo($outMs)
    $result = $outMs.ToArray()
    $ds.Dispose()
    $ms.Dispose()
    $outMs.Dispose()
    return $result
}

function Find-ZlibOffsets {
    <#
    .SYNOPSIS
        Finds all zlib headers (78 9C, 78 DA, 78 01, 78 5E) in the data.
    #>
    param([byte[]]$Data)
    
    $offsets = @()
    for ($i = 0; $i -lt $Data.Length - 1; $i++) {
        if ($Data[$i] -eq 0x78 -and $Data[$i + 1] -in @(0x9C, 0xDA, 0x01, 0x5E)) {
            $offsets += $i
        }
    }
    return $offsets
}

function Read-PxDimensions {
    <#
    .SYNOPSIS
        Reads width and height from .px file header.
        Dimensions are stored as 32-bit LE integers at offsets 0x64 and 0x68.
    #>
    param([byte[]]$Data)
    
    $width = [BitConverter]::ToInt32($Data, 0x64)
    $height = [BitConverter]::ToInt32($Data, 0x68)
    return @{ Width = $width; Height = $height }
}

function Read-PxFile {
    <#
    .SYNOPSIS
        Reads a .px file and extracts the composited RGBA pixel data.
        Handles both single-layer and multi-layer .px files.
    #>
    param([string]$FilePath)
    
    $data = [System.IO.File]::ReadAllBytes($FilePath)
    
    # Get dimensions
    $dims = Read-PxDimensions -Data $data
    $width = $dims.Width
    $height = $dims.Height
    $pixelCount = $width * $height
    $expectedBytes = $pixelCount * 4
    
    if ($width -le 0 -or $height -le 0) {
        Write-Warning "Invalid dimensions in $FilePath"
        return $null
    }
    
    # Find all zlib-compressed layer blobs
    $zlibOffsets = Find-ZlibOffsets -Data $data
    
    if ($zlibOffsets.Count -eq 0) {
        Write-Warning "No zlib data found in $FilePath"
        return $null
    }
    
    # Decompress all valid layers
    $layers = @()
    foreach ($offset in $zlibOffsets) {
        try {
            $layerData = Decompress-Zlib -Data $data -Offset $offset
            if ($layerData.Length -eq $expectedBytes) {
                $layers += , @($layerData)
            }
        } catch {
            # Skip invalid zlib streams
        }
    }
    
    if ($layers.Count -eq 0) {
        Write-Warning "Could not decompress layer data in $FilePath"
        return $null
    }
    
    $pixels = @()
    
    if ($layers.Count -eq 1) {
        # Single layer: direct RGBA, black (#000000) = transparent
        $layer = $layers[0]
        for ($i = 0; $i -lt $pixelCount; $i++) {
            $idx = $i * 4
            $r = $layer[$idx]
            $g = $layer[$idx + 1]
            $b = $layer[$idx + 2]
            $a = $layer[$idx + 3]
            
            # Treat black as transparent
            if ($r -eq 0 -and $g -eq 0 -and $b -eq 0) {
                $a = 0
            }
            $pixels += , @($r, $g, $b, $a)
        }
    } else {
        # Multi-layer compositing
        # First, determine if layer 0 is a "mask" layer (only black+transparent)
        # or a content layer (has actual colors)
        $layer0 = $layers[0]
        $layer0IsColorMask = $true
        for ($i = 0; $i -lt $pixelCount; $i++) {
            $idx = $i * 4
            $r = $layer0[$idx]
            $g = $layer0[$idx + 1]
            $b = $layer0[$idx + 2]
            # If we find any non-black color with alpha > 0, it's a content layer
            if (($r -ne 0 -or $g -ne 0 -or $b -ne 0) -and $layer0[$idx + 3] -gt 0) {
                $layer0IsColorMask = $false
                break
            }
        }
        
        for ($i = 0; $i -lt $pixelCount; $i++) {
            $idx = $i * 4
            
            if ($layer0IsColorMask) {
                # Layer 0 is a mask: alpha=0 means show through, alpha>0 (black) means blocked
                $maskAlpha = $layer0[$idx + 3]
                
                if ($maskAlpha -eq 0) {
                    # Show underlying layers (composite from layer 1 down)
                    $r = $layers[1][$idx]
                    $g = $layers[1][$idx + 1]
                    $b = $layers[1][$idx + 2]
                    $a = $layers[1][$idx + 3]
                    
                    # Apply any additional layers
                    for ($li = 2; $li -lt $layers.Count; $li++) {
                        $layer = $layers[$li]
                        $la = $layer[$idx + 3]
                        if ($la -gt 0) {
                            $r = $layer[$idx]
                            $g = $layer[$idx + 1]
                            $b = $layer[$idx + 2]
                            $a = $la
                        }
                    }
                } else {
                    # Masked out = transparent
                    $r = 0; $g = 0; $b = 0; $a = 0
                }
            } else {
                # Normal compositing: bottom-up, upper layers override where opaque
                # Start with bottom layer (last in array)
                $bottomLayer = $layers[$layers.Count - 1]
                $r = $bottomLayer[$idx]
                $g = $bottomLayer[$idx + 1]
                $b = $bottomLayer[$idx + 2]
                $a = $bottomLayer[$idx + 3]
                
                # Composite each layer from bottom-1 to top (index 0)
                for ($li = $layers.Count - 2; $li -ge 0; $li--) {
                    $layer = $layers[$li]
                    $lr = $layer[$idx]
                    $lg = $layer[$idx + 1]
                    $lb = $layer[$idx + 2]
                    $la = $layer[$idx + 3]
                    
                    # If this layer's pixel is opaque and not black, use it
                    if ($la -gt 0) {
                        $r = $lr
                        $g = $lg
                        $b = $lb
                        $a = $la
                    }
                }
            }
            
            $pixels += , @($r, $g, $b, $a)
        }
    }
    
    return [pscustomobject]@{
        FilePath = $FilePath
        Width    = $width
        Height   = $height
        Pixels   = $pixels
    }
}

function Render-PxToTerminal {
    <#
    .SYNOPSIS
        Renders pixel data to the terminal using lower half blocks with True Color.
        For odd-height images, shifts down by one virtual pixel so the top row
        uses the terminal's natural background instead of forcing a black bottom.
    #>
    param([pscustomobject]$ImageData)
    
    $width = $ImageData.Width
    $height = $ImageData.Height
    $pixels = $ImageData.Pixels
    $reset = Get-AnsiReset
    
    # For odd heights, shift down by 1 virtual pixel so top uses terminal bg
    $oddHeight = ($height % 2) -eq 1
    $startY = if ($oddHeight) { -1 } else { 0 }
    $endY = if ($oddHeight) { $height - 1 } else { $height }
    
    # Process two rows at a time
    for ($y = $startY; $y -lt $endY; $y += 2) {
        $line = ""
        for ($x = 0; $x -lt $width; $x++) {
            # Top pixel (y) -> BackgroundColor
            # If y < 0 (odd height first row), top pixel is "empty" (no background)
            $topY = $y
            $bottomY = $y + 1
            
            if ($topY -lt 0) {
                # No top pixel - skip background color entirely
                $topPixel = $null
            } else {
                $topIdx = ($topY * $width) + $x
                $topPixel = if ($topIdx -lt $pixels.Count) { $pixels[$topIdx] } else { @(0, 0, 0, 0) }
            }
            
            # Bottom pixel (y+1) -> ForegroundColor
            $bottomIdx = ($bottomY * $width) + $x
            $bottomPixel = if ($bottomIdx -lt $pixels.Count) { $pixels[$bottomIdx] } else { @(0, 0, 0, 0) }
            
            # Handle transparency
            $botR = if ($bottomPixel[3] -lt 32) { 0 } else { $bottomPixel[0] }
            $botG = if ($bottomPixel[3] -lt 32) { 0 } else { $bottomPixel[1] }
            $botB = if ($bottomPixel[3] -lt 32) { 0 } else { $bottomPixel[2] }
            
            if ($null -eq $topPixel) {
                # No background - just foreground color on terminal's default bg
                $fg = Get-TrueColorFg -R $botR -G $botG -B $botB
                $line += "${fg}${LowerHalfBlock}"
            } else {
                $topR = if ($topPixel[3] -lt 32) { 0 } else { $topPixel[0] }
                $topG = if ($topPixel[3] -lt 32) { 0 } else { $topPixel[1] }
                $topB = if ($topPixel[3] -lt 32) { 0 } else { $topPixel[2] }
                
                # Build ANSI colored character
                $bg = Get-TrueColorBg -R $topR -G $topG -B $topB
                $fg = Get-TrueColorFg -R $botR -G $botG -B $botB
                $line += "${bg}${fg}${LowerHalfBlock}"
            }
        }
        # Reset all attributes and clear to end of line to prevent background bleeding
        $line += "$ESC[0m$ESC[K"
        Write-Host $line
    }
    
    Write-Host ""
}

# Main execution
if (Test-Path $Path -PathType Container) {
    # Directory: process all .px files
    $resolvedPath = Resolve-Path $Path
    $pxFiles = Get-ChildItem -Path $resolvedPath -Filter "*.px" -File
    
    if ($pxFiles.Count -eq 0) {
        Write-Warning "No .px files found in $Path"
        exit 1
    }
    
    Write-Host "Found $($pxFiles.Count) .px file(s)" -ForegroundColor Green
    
    foreach ($file in $pxFiles) {
        $imageData = Read-PxFile -FilePath $file.FullName
        if ($null -ne $imageData) {
            Render-PxToTerminal -ImageData $imageData
        }
    }
} elseif (Test-Path $Path -PathType Leaf) {
    # Single file - resolve to full path
    $resolvedPath = Resolve-Path $Path
    if ($resolvedPath -notlike "*.px") {
        Write-Warning "File does not appear to be a .px file: $Path"
    }
    
    $imageData = Read-PxFile -FilePath $resolvedPath.Path
    if ($null -ne $imageData) {
        Render-PxToTerminal -ImageData $imageData
    }
} else {
    Write-Error "Path not found: $Path"
    exit 1
}
