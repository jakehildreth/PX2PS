function Write-PxTerminalISE {
    <#
    .SYNOPSIS
        Renders pixel data using Write-Host with ConsoleColor for ISE compatibility.

    .DESCRIPTION
        ISE-compatible fallback renderer that uses Write-Host with
        -ForegroundColor and -BackgroundColor instead of ANSI escape sequences.
        Colors are mapped from 24-bit RGB to the nearest of 16 ConsoleColor values.
        Supports transparency by omitting color parameters for transparent pixels.

    .PARAMETER Width
        Image width in pixels.

    .PARAMETER Height
        Image height in pixels.

    .PARAMETER Pixels
        Array of RGBA pixel arrays.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Width,

        [Parameter(Mandatory)]
        [int]$Height,

        [Parameter(Mandatory)]
        [byte[][]]$Pixels
    )

    $oddHeight = ($Height % 2) -eq 1
    $startY = if ($oddHeight) { -1 } else { 0 }
    $endY = if ($oddHeight) { $Height - 1 } else { $Height }

    for ($y = $startY; $y -lt $endY; $y += 2) {
        for ($x = 0; $x -lt $Width; $x++) {
            $topY = $y
            $bottomY = $y + 1

            if ($topY -lt 0) {
                $topPixel = $null
            } else {
                $topIdx = ($topY * $Width) + $x
                $topPixel = if ($topIdx -lt $Pixels.Count) { $Pixels[$topIdx] } else { @(0, 0, 0, 0) }
            }

            $bottomIdx = ($bottomY * $Width) + $x
            $bottomPixel = if ($bottomIdx -lt $Pixels.Count) { $Pixels[$bottomIdx] } else { @(0, 0, 0, 0) }

            $cell = Get-PxCellInfo -TopPixel $topPixel -BottomPixel $bottomPixel

            $writeHostParams = @{
                Object    = $cell.Character
                NoNewline = $true
            }

            if ($null -ne $cell.ForegroundRGB) {
                $writeHostParams['ForegroundColor'] = ConvertTo-ConsoleColor -R $cell.ForegroundRGB[0] -G $cell.ForegroundRGB[1] -B $cell.ForegroundRGB[2]
            }

            if ($null -ne $cell.BackgroundRGB) {
                $writeHostParams['BackgroundColor'] = ConvertTo-ConsoleColor -R $cell.BackgroundRGB[0] -G $cell.BackgroundRGB[1] -B $cell.BackgroundRGB[2]
            }

            Write-Host @writeHostParams
        }
        Write-Host ''
    }

    Write-Host ''
}
