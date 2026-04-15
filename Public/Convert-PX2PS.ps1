function Convert-PX2PS {
    [alias('px2ps')] 
    <#
    .SYNOPSIS
        Converts Pixquare .px and Piskel .piskel files to terminal pixel graphics.
    
    .DESCRIPTION
        Reads .px and .piskel pixel art files and renders them in the PowerShell
        terminal using the lower half block character (▄) with ANSI True Color.
        Each line of output represents two rows of pixels: top pixel uses
        background color, bottom pixel uses foreground color.
        
        Supports both single-layer and multi-layer files with automatic
        layer compositing and transparency handling.
        
        For .piskel files, only the first frame of each layer is used
        (animation is not supported).
    
    .PARAMETER Path
        Path to a .px or .piskel file, or a directory containing such files.
        If a directory is provided, all .px and .piskel files are processed.
    
    .PARAMETER OutputMode
        Controls the output format:
        - Display: Renders directly to terminal (default)
        - ScriptBlock: Returns a scriptblock that can be invoked to render
        - Script: Generates a standalone .ps1 file (requires -OutputPath)
    
    .PARAMETER OutputPath
        File path for generated script when using -OutputMode Script.
        Must end with .ps1 extension.
    
    .PARAMETER RenderMode
        Controls the rendering engine used for terminal output:
        - Auto: Detect host and use ConsoleColor for ISE, VT for everything else (default)
        - VT: Force ANSI True Color rendering regardless of host
        - ConsoleColor: Force 16-color Write-Host rendering regardless of host

    .PARAMETER PassThru
        If specified, returns PSCustomObject with file information instead of
        rendering directly to terminal. Maintained for backward compatibility.
    
    .EXAMPLE
        Convert-PX2PS -Path "Stepper 4.px"
        
        Renders the specified .px file to the terminal.
    
    .EXAMPLE
        Convert-PX2PS -Path "C:\PixelArt"
        
        Renders all .px files found in the specified directory.
    
    .EXAMPLE
        Get-ChildItem -Path "." -Filter "*.px" | Convert-PX2PS
        
        Processes .px files from pipeline input.
    
    .EXAMPLE
        $sb = Convert-PX2PS -Path "logo.px" -OutputMode ScriptBlock
        & $sb
        
        Gets a scriptblock for deferred rendering.
    
    .EXAMPLE
        Convert-PX2PS -Path "banner.px" -OutputMode Script -OutputPath "banner.ps1"
        
        Generates a standalone script file that can render the image.
    
    .EXAMPLE
        Convert-PX2PS -Path "logo.px" -RenderMode ConsoleColor

        Forces 16-color ConsoleColor rendering for testing without ISE.

    .EXAMPLE
        $data = Convert-PX2PS -Path "image.px" -PassThru
        
        Gets pixel data without rendering.
    
    .OUTPUTS
        None by default.
        With -OutputMode ScriptBlock, outputs [scriptblock].
        With -PassThru, outputs PSCustomObject with:
        - FilePath: Full path to the .px file
        - Width: Image width in pixels
        - Height: Image height in pixels
        - Pixels: Array of RGBA pixel data
    
    .NOTES
        Requires PowerShell 5.1 or later.
        On Windows PowerShell 5.1, automatically enables Virtual Terminal Processing.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Display')]
    [OutputType([void], [PSCustomObject], [scriptblock])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'Display')]
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'ScriptBlock')]
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'Script')]
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'PassThru')]
        [Alias('FullName')]
        [ValidateNotNullOrEmpty()]
        [string]$Path,
        
        [Parameter(ParameterSetName = 'ScriptBlock')]
        [Parameter(ParameterSetName = 'Script')]
        [ValidateSet('ScriptBlock', 'Script')]
        [string]$OutputMode,
        
        [Parameter(Mandatory, ParameterSetName = 'Script')]
        [ValidatePattern('\.ps1$')]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,
        
        [Parameter(ParameterSetName = 'Display')]
        [Parameter(ParameterSetName = 'ScriptBlock')]
        [Parameter(ParameterSetName = 'Script')]
        [ValidateSet('Auto', 'VT', 'ConsoleColor')]
        [string]$RenderMode = 'Auto',

        [Parameter(ParameterSetName = 'PassThru')]
        [switch]$PassThru
    )
    
    begin {
        Write-Verbose 'Starting pixel art file processing'
    }
    
    process {
        if (-not (Test-Path -Path $Path)) {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.IO.FileNotFoundException]::new("Path not found: $Path"),
                'PathNotFound',
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $Path
            )
            $PSCmdlet.WriteError($errorRecord)
            return
        }
        
        $pathItem = Get-Item -Path $Path
        
        if ($pathItem.PSIsContainer) {
            $pxFiles = Get-ChildItem -Path $Path -File | Where-Object { $_.Extension -in '.px', '.piskel', '.ase', '.aseprite' }
            
            if ($pxFiles.Count -eq 0) {
                Write-Warning "No .px, .piskel, .ase, or .aseprite files found in $Path"
                return
            }
            
            Write-Host "Found $($pxFiles.Count) pixel art file(s)" -ForegroundColor Green
            
            foreach ($file in $pxFiles) {
                $params = @{
                    Path = $file.FullName
                }
                
                if ($PassThru.IsPresent) {
                    $params['PassThru'] = $true
                }
                
                if ($PSBoundParameters.ContainsKey('RenderMode')) {
                    $params['RenderMode'] = $RenderMode
                }

                if ($PSBoundParameters.ContainsKey('OutputMode')) {
                    $params['OutputMode'] = $OutputMode
                    
                    if ($PSBoundParameters.ContainsKey('OutputPath')) {
                        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                        $directory = [System.IO.Path]::GetDirectoryName($OutputPath)
                        $extension = [System.IO.Path]::GetExtension($OutputPath)
                        $params['OutputPath'] = [System.IO.Path]::Combine($directory, "$baseName$extension")
                    }
                }
                
                Convert-PX2PS @params
            }
            return
        }
        
        if ($pathItem.Extension -notin '.px', '.piskel', '.ase', '.aseprite') {
            Write-Warning "File does not appear to be a supported pixel art file: $Path"
        }
        
        try {
            if ($pathItem.Extension -eq '.piskel') {
                $json = Get-Content -Path $pathItem.FullName -Raw | ConvertFrom-Json
                $width = [int]$json.piskel.width
                $height = [int]$json.piskel.height

                if ($width -le 0 -or $height -le 0) {
                    Write-Warning "Invalid dimensions in $($pathItem.Name)"
                    return
                }

                Write-Verbose "Processing $($pathItem.Name): ${width}x${height}"

                $layers = Read-PiskelLayerData -PiskelData $json -Width $width -Height $height
            } elseif ($pathItem.Extension -in '.ase', '.aseprite') {
                $data = [System.IO.File]::ReadAllBytes($pathItem.FullName)
                $dimensions = Get-AseDimension -Data $data
                $width = $dimensions.Width
                $height = $dimensions.Height

                if ($width -le 0 -or $height -le 0) {
                    Write-Warning "Invalid dimensions in $($pathItem.Name)"
                    return
                }

                Write-Verbose "Processing $($pathItem.Name): ${width}x${height}"

                $layers = Read-AseLayerData -Data $data -Width $width -Height $height
            } else {
                $data = [System.IO.File]::ReadAllBytes($pathItem.FullName)
                $dimensions = Get-PxDimension -Data $data
                $width = $dimensions.Width
                $height = $dimensions.Height

                if ($width -le 0 -or $height -le 0) {
                    Write-Warning "Invalid dimensions in $($pathItem.Name)"
                    return
                }

                Write-Verbose "Processing $($pathItem.Name): ${width}x${height}"

                $layers = Read-PxLayerData -Data $data -Width $width -Height $height
            }
            
            if ($layers.Count -eq 0) {
                Write-Warning "Could not extract layer data from $($pathItem.Name)"
                return
            }
            
            # Ensure $layers is treated as an array of byte arrays
            [byte[][]]$layersArray = $layers
            $pixels = Merge-PxLayer -Layers $layersArray -Width $width -Height $height
            
            if ($PassThru.IsPresent) {
                Write-Output ([PSCustomObject]@{
                    FilePath = $pathItem.FullName
                    Width = $width
                    Height = $height
                    Pixels = $pixels
                })
            } elseif ($OutputMode -eq 'ScriptBlock') {
                $pixelsString = ($pixels | ForEach-Object { "@($($_ -join ','))" }) -join ",`n    "

                $useConsoleColorExpr = switch ($RenderMode) {
                    'ConsoleColor' { '$true' }
                    'VT' { '$false' }
                    default { '$Host.Name -eq ''Windows PowerShell ISE Host''' }
                }
                
                $scriptContent = @"
`$ESC = [char]27
`$LowerHalfBlock = [char]0x2584
`$UpperHalfBlock = [char]0x2580
`$width = $width
`$height = $height
`$pixels = @(
    $pixelsString
)

`$oddHeight = (`$height % 2) -eq 1
`$startY = if (`$oddHeight) { -1 } else { 0 }
`$endY = if (`$oddHeight) { `$height - 1 } else { `$height }

if ($useConsoleColorExpr) {
    function ConvertTo-ConsoleColor {
        param([int]`$R, [int]`$G, [int]`$B)
        `$colorMap = @(
            @{ Color = [System.ConsoleColor]::Black;       R = 0;   G = 0;   B = 0   }
            @{ Color = [System.ConsoleColor]::DarkBlue;    R = 0;   G = 0;   B = 128 }
            @{ Color = [System.ConsoleColor]::DarkGreen;   R = 0;   G = 128; B = 0   }
            @{ Color = [System.ConsoleColor]::DarkCyan;    R = 0;   G = 128; B = 128 }
            @{ Color = [System.ConsoleColor]::DarkRed;     R = 128; G = 0;   B = 0   }
            @{ Color = [System.ConsoleColor]::DarkMagenta; R = 128; G = 0;   B = 128 }
            @{ Color = [System.ConsoleColor]::DarkYellow;  R = 128; G = 128; B = 0   }
            @{ Color = [System.ConsoleColor]::Gray;        R = 192; G = 192; B = 192 }
            @{ Color = [System.ConsoleColor]::DarkGray;    R = 128; G = 128; B = 128 }
            @{ Color = [System.ConsoleColor]::Blue;        R = 0;   G = 0;   B = 255 }
            @{ Color = [System.ConsoleColor]::Green;       R = 0;   G = 255; B = 0   }
            @{ Color = [System.ConsoleColor]::Cyan;        R = 0;   G = 255; B = 255 }
            @{ Color = [System.ConsoleColor]::Red;         R = 255; G = 0;   B = 0   }
            @{ Color = [System.ConsoleColor]::Magenta;     R = 255; G = 0;   B = 255 }
            @{ Color = [System.ConsoleColor]::Yellow;      R = 255; G = 255; B = 0   }
            @{ Color = [System.ConsoleColor]::White;       R = 255; G = 255; B = 255 }
        )
        `$nearestColor = [System.ConsoleColor]::Black
        `$minDistance = [int]::MaxValue
        foreach (`$entry in `$colorMap) {
            `$dr = `$R - `$entry.R
            `$dg = `$G - `$entry.G
            `$db = `$B - `$entry.B
            `$distance = (`$dr * `$dr) + (`$dg * `$dg) + (`$db * `$db)
            if (`$distance -lt `$minDistance) {
                `$minDistance = `$distance
                `$nearestColor = `$entry.Color
            }
        }
        return `$nearestColor
    }

    for (`$y = `$startY; `$y -lt `$endY; `$y += 2) {
        for (`$x = 0; `$x -lt `$width; `$x++) {
            `$topY = `$y
            `$bottomY = `$y + 1

            if (`$topY -lt 0) {
                `$topPixel = `$null
            } else {
                `$topIdx = (`$topY * `$width) + `$x
                `$topPixel = if (`$topIdx -lt `$pixels.Count) { `$pixels[`$topIdx] } else { @(0, 0, 0, 0) }
            }

            `$bottomIdx = (`$bottomY * `$width) + `$x
            `$bottomPixel = if (`$bottomIdx -lt `$pixels.Count) { `$pixels[`$bottomIdx] } else { @(0, 0, 0, 0) }

            `$topTransparent = (`$null -eq `$topPixel) -or (`$topPixel[3] -lt 32)
            `$bottomTransparent = `$bottomPixel[3] -lt 32

            if (-not `$topTransparent -and -not `$bottomTransparent) {
                `$fgColor = ConvertTo-ConsoleColor -R `$bottomPixel[0] -G `$bottomPixel[1] -B `$bottomPixel[2]
                `$bgColor = ConvertTo-ConsoleColor -R `$topPixel[0] -G `$topPixel[1] -B `$topPixel[2]
                Write-Host `$LowerHalfBlock -ForegroundColor `$fgColor -BackgroundColor `$bgColor -NoNewline
            } elseif (-not `$topTransparent -and `$bottomTransparent) {
                `$fgColor = ConvertTo-ConsoleColor -R `$topPixel[0] -G `$topPixel[1] -B `$topPixel[2]
                Write-Host `$UpperHalfBlock -ForegroundColor `$fgColor -NoNewline
            } elseif (`$topTransparent -and -not `$bottomTransparent) {
                `$fgColor = ConvertTo-ConsoleColor -R `$bottomPixel[0] -G `$bottomPixel[1] -B `$bottomPixel[2]
                Write-Host `$LowerHalfBlock -ForegroundColor `$fgColor -NoNewline
            } else {
                Write-Host ' ' -NoNewline
            }
        }
        Write-Host ''
    }

    Write-Host ''
} else {
    for (`$y = `$startY; `$y -lt `$endY; `$y += 2) {
        `$line = ""
        for (`$x = 0; `$x -lt `$width; `$x++) {
            `$topY = `$y
            `$bottomY = `$y + 1

            if (`$topY -lt 0) {
                `$topPixel = `$null
            } else {
                `$topIdx = (`$topY * `$width) + `$x
                `$topPixel = if (`$topIdx -lt `$pixels.Count) { `$pixels[`$topIdx] } else { @(0, 0, 0, 0) }
            }

            `$bottomIdx = (`$bottomY * `$width) + `$x
            `$bottomPixel = if (`$bottomIdx -lt `$pixels.Count) { `$pixels[`$bottomIdx] } else { @(0, 0, 0, 0) }

            `$topTransparent = (`$null -eq `$topPixel) -or (`$topPixel[3] -lt 32)
            `$bottomTransparent = `$bottomPixel[3] -lt 32

            if (-not `$topTransparent -and -not `$bottomTransparent) {
                `$bg = "`$ESC[48;2;`$(`$topPixel[0]);`$(`$topPixel[1]);`$(`$topPixel[2])m"
                `$fg = "`$ESC[38;2;`$(`$bottomPixel[0]);`$(`$bottomPixel[1]);`$(`$bottomPixel[2])m"
                `$line += "`${bg}`${fg}`$LowerHalfBlock"
            } elseif (-not `$topTransparent -and `$bottomTransparent) {
                `$fg = "`$ESC[38;2;`$(`$topPixel[0]);`$(`$topPixel[1]);`$(`$topPixel[2])m"
                `$line += "`$ESC[0m`${fg}`$UpperHalfBlock"
            } elseif (`$topTransparent -and -not `$bottomTransparent) {
                `$fg = "`$ESC[38;2;`$(`$bottomPixel[0]);`$(`$bottomPixel[1]);`$(`$bottomPixel[2])m"
                `$line += "`$ESC[0m`${fg}`$LowerHalfBlock"
            } else {
                `$line += "`$ESC[0m "
            }
        }
        `$line += "`$ESC[0m`$ESC[K"
        Write-Host `$line
    }

    Write-Host ""
}
"@
                Write-Output ([scriptblock]::Create($scriptContent))
            } elseif ($OutputMode -eq 'Script') {
                $useConsoleColorExprScript = switch ($RenderMode) {
                    'ConsoleColor' { '$true' }
                    'VT' { '$false' }
                    default { '$Host.Name -eq ''Windows PowerShell ISE Host''' }
                }

                $scriptContent = @"
#!/usr/bin/env pwsh
# Auto-generated by PX2PS 2025.12.29
# Source: $($pathItem.Name) (${width}x${height})
# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

# Enable Virtual Terminal Processing for ANSI colors (Windows PowerShell 5.1 compatibility)
if (`$PSVersionTable.PSVersion.Major -le 5 -and `$env:OS -eq 'Windows_NT' -and `$Host.Name -ne 'Windows PowerShell ISE Host') {
    try {
        Add-Type -TypeDefinition @`"
using System;
using System.Runtime.InteropServices;
public class VTConsole {
    [DllImport(`"kernel32.dll`", SetLastError = true)]
    public static extern IntPtr GetStdHandle(int nStdHandle);
    [DllImport(`"kernel32.dll`", SetLastError = true)]
    public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
    [DllImport(`"kernel32.dll`", SetLastError = true)]
    public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
    public static void EnableVT() {
        IntPtr handle = GetStdHandle(-11);
        uint mode;
        GetConsoleMode(handle, out mode);
        SetConsoleMode(handle, mode | 0x4);
    }
}
`"@ -ErrorAction SilentlyContinue
        [VTConsole]::EnableVT()
    } catch {
        # VT processing may already be enabled or not available
    }
}

`$ESC = [char]27
`$LowerHalfBlock = [char]0x2584
`$UpperHalfBlock = [char]0x2580

function ConvertTo-ConsoleColor {
    param([int]`$R, [int]`$G, [int]`$B)
    `$colorMap = @(
        @{ Color = [System.ConsoleColor]::Black;       R = 0;   G = 0;   B = 0   }
        @{ Color = [System.ConsoleColor]::DarkBlue;    R = 0;   G = 0;   B = 128 }
        @{ Color = [System.ConsoleColor]::DarkGreen;   R = 0;   G = 128; B = 0   }
        @{ Color = [System.ConsoleColor]::DarkCyan;    R = 0;   G = 128; B = 128 }
        @{ Color = [System.ConsoleColor]::DarkRed;     R = 128; G = 0;   B = 0   }
        @{ Color = [System.ConsoleColor]::DarkMagenta; R = 128; G = 0;   B = 128 }
        @{ Color = [System.ConsoleColor]::DarkYellow;  R = 128; G = 128; B = 0   }
        @{ Color = [System.ConsoleColor]::Gray;        R = 192; G = 192; B = 192 }
        @{ Color = [System.ConsoleColor]::DarkGray;    R = 128; G = 128; B = 128 }
        @{ Color = [System.ConsoleColor]::Blue;        R = 0;   G = 0;   B = 255 }
        @{ Color = [System.ConsoleColor]::Green;       R = 0;   G = 255; B = 0   }
        @{ Color = [System.ConsoleColor]::Cyan;        R = 0;   G = 255; B = 255 }
        @{ Color = [System.ConsoleColor]::Red;         R = 255; G = 0;   B = 0   }
        @{ Color = [System.ConsoleColor]::Magenta;     R = 255; G = 0;   B = 255 }
        @{ Color = [System.ConsoleColor]::Yellow;      R = 255; G = 255; B = 0   }
        @{ Color = [System.ConsoleColor]::White;       R = 255; G = 255; B = 255 }
    )
    `$nearestColor = [System.ConsoleColor]::Black
    `$minDistance = [int]::MaxValue
    foreach (`$entry in `$colorMap) {
        `$dr = `$R - `$entry.R
        `$dg = `$G - `$entry.G
        `$db = `$B - `$entry.B
        `$distance = (`$dr * `$dr) + (`$dg * `$dg) + (`$db * `$db)
        if (`$distance -lt `$minDistance) {
            `$minDistance = `$distance
            `$nearestColor = `$entry.Color
        }
    }
    return `$nearestColor
}

function Get-TrueColorFg {
    param([int]`$R, [int]`$G, [int]`$B)
    return "`$ESC[38;2;`${R};`${G};`${B}m"
}

function Get-TrueColorBg {
    param([int]`$R, [int]`$G, [int]`$B)
    return "`$ESC[48;2;`${R};`${G};`${B}m"
}

`$width = $width
`$height = $height
`$pixels = @(
$(($pixels | ForEach-Object { "    @($($_ -join ','))" }) -join ",`n")
)

`$oddHeight = (`$height % 2) -eq 1
`$startY = if (`$oddHeight) { -1 } else { 0 }
`$endY = if (`$oddHeight) { `$height - 1 } else { `$height }

if ($useConsoleColorExprScript) {
    for (`$y = `$startY; `$y -lt `$endY; `$y += 2) {
        for (`$x = 0; `$x -lt `$width; `$x++) {
            `$topY = `$y
            `$bottomY = `$y + 1

            if (`$topY -lt 0) {
                `$topPixel = `$null
            } else {
                `$topIdx = (`$topY * `$width) + `$x
                `$topPixel = if (`$topIdx -lt `$pixels.Count) { `$pixels[`$topIdx] } else { @(0, 0, 0, 0) }
            }

            `$bottomIdx = (`$bottomY * `$width) + `$x
            `$bottomPixel = if (`$bottomIdx -lt `$pixels.Count) { `$pixels[`$bottomIdx] } else { @(0, 0, 0, 0) }

            `$topTransparent = (`$null -eq `$topPixel) -or (`$topPixel[3] -lt 32)
            `$bottomTransparent = `$bottomPixel[3] -lt 32

            if (-not `$topTransparent -and -not `$bottomTransparent) {
                `$fgColor = ConvertTo-ConsoleColor -R `$bottomPixel[0] -G `$bottomPixel[1] -B `$bottomPixel[2]
                `$bgColor = ConvertTo-ConsoleColor -R `$topPixel[0] -G `$topPixel[1] -B `$topPixel[2]
                Write-Host `$LowerHalfBlock -ForegroundColor `$fgColor -BackgroundColor `$bgColor -NoNewline
            } elseif (-not `$topTransparent -and `$bottomTransparent) {
                `$fgColor = ConvertTo-ConsoleColor -R `$topPixel[0] -G `$topPixel[1] -B `$topPixel[2]
                Write-Host `$UpperHalfBlock -ForegroundColor `$fgColor -NoNewline
            } elseif (`$topTransparent -and -not `$bottomTransparent) {
                `$fgColor = ConvertTo-ConsoleColor -R `$bottomPixel[0] -G `$bottomPixel[1] -B `$bottomPixel[2]
                Write-Host `$LowerHalfBlock -ForegroundColor `$fgColor -NoNewline
            } else {
                Write-Host ' ' -NoNewline
            }
        }
        Write-Host ''
    }

    Write-Host ''
} else {
    for (`$y = `$startY; `$y -lt `$endY; `$y += 2) {
        `$line = ""
        for (`$x = 0; `$x -lt `$width; `$x++) {
            `$topY = `$y
            `$bottomY = `$y + 1

            if (`$topY -lt 0) {
                `$topPixel = `$null
            } else {
                `$topIdx = (`$topY * `$width) + `$x
                `$topPixel = if (`$topIdx -lt `$pixels.Count) { `$pixels[`$topIdx] } else { @(0, 0, 0, 0) }
            }

            `$bottomIdx = (`$bottomY * `$width) + `$x
            `$bottomPixel = if (`$bottomIdx -lt `$pixels.Count) { `$pixels[`$bottomIdx] } else { @(0, 0, 0, 0) }

            `$topTransparent = (`$null -eq `$topPixel) -or (`$topPixel[3] -lt 32)
            `$bottomTransparent = `$bottomPixel[3] -lt 32

            if (-not `$topTransparent -and -not `$bottomTransparent) {
                `$bg = Get-TrueColorBg -R `$topPixel[0] -G `$topPixel[1] -B `$topPixel[2]
                `$fg = Get-TrueColorFg -R `$bottomPixel[0] -G `$bottomPixel[1] -B `$bottomPixel[2]
                `$line += "`${bg}`${fg}`$LowerHalfBlock"
            } elseif (-not `$topTransparent -and `$bottomTransparent) {
                `$fg = Get-TrueColorFg -R `$topPixel[0] -G `$topPixel[1] -B `$topPixel[2]
                `$line += "`$ESC[0m`${fg}`$UpperHalfBlock"
            } elseif (`$topTransparent -and -not `$bottomTransparent) {
                `$fg = Get-TrueColorFg -R `$bottomPixel[0] -G `$bottomPixel[1] -B `$bottomPixel[2]
                `$line += "`$ESC[0m`${fg}`$LowerHalfBlock"
            } else {
                `$line += "`$ESC[0m "
            }
        }
        `$line += "`$ESC[0m`$ESC[K"
        Write-Host `$line
    }

    Write-Host ""
}
"@
                Set-Content -Path $OutputPath -Value $scriptContent -Encoding UTF8 -NoNewline
                Write-Verbose "Script file created: $OutputPath"
            } else {
                $useConsoleColor = switch ($RenderMode) {
                    'ConsoleColor' { $true }
                    'VT' { $false }
                    default { $Host.Name -eq 'Windows PowerShell ISE Host' }
                }

                if ($useConsoleColor) {
                    Write-PxTerminalISE -Width $width -Height $height -Pixels $pixels
                } else {
                    Write-PxTerminal -Width $width -Height $height -Pixels $pixels
                }
            }
        } catch {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                $_.Exception,
                'PxFileProcessingFailed',
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                $Path
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }
    
    end {
        Write-Verbose 'Completed pixel art file processing'
    }
}
