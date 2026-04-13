function Write-PxTerminal {
    <#
    .SYNOPSIS
        Renders pixel data to terminal using block characters with True Color.

    .DESCRIPTION
        Renders pixel art to terminal using ANSI True Color escape sequences.
        Supports transparency by choosing appropriate block characters:
        - Both opaque: lower half block with BG (top) and FG (bottom)
        - Top opaque, bottom transparent: upper half block with FG (top)
        - Top transparent, bottom opaque: lower half block with FG (bottom)
        - Both transparent: space (console background shows through)

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

    # ISE fallback: delegate to ConsoleColor renderer
    if ($Host.Name -eq 'Windows PowerShell ISE Host') {
        Write-PxTerminalISE -Width $Width -Height $Height -Pixels $Pixels
        return
    }

    $reset = Get-AnsiReset
    $oddHeight = ($Height % 2) -eq 1
    $startY = if ($oddHeight) { -1 } else { 0 }
    $endY = if ($oddHeight) { $Height - 1 } else { $Height }

    for ($y = $startY; $y -lt $endY; $y += 2) {
        $line = ''
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

            if ($null -ne $cell.BackgroundRGB -and $null -ne $cell.ForegroundRGB) {
                # Both opaque
                $bg = Get-TrueColorBg -R $cell.BackgroundRGB[0] -G $cell.BackgroundRGB[1] -B $cell.BackgroundRGB[2]
                $fg = Get-TrueColorFg -R $cell.ForegroundRGB[0] -G $cell.ForegroundRGB[1] -B $cell.ForegroundRGB[2]
                $line += "${bg}${fg}$($cell.Character)"
            } elseif ($null -ne $cell.ForegroundRGB) {
                # One pixel transparent, one opaque
                $fg = Get-TrueColorFg -R $cell.ForegroundRGB[0] -G $cell.ForegroundRGB[1] -B $cell.ForegroundRGB[2]
                $line += "${reset}${fg}$($cell.Character)"
            } else {
                # Both transparent
                $line += "${reset} "
            }
        }
        $line += "$script:ESC[0m$script:ESC[K"
        Write-Host $line
    }

    Write-Host ''
}
