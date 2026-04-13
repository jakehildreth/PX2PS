function Get-PxCellInfo {
    <#
    .SYNOPSIS
        Classifies a pixel pair into a transparency case for terminal rendering.

    .DESCRIPTION
        Takes a top and bottom pixel (each a byte array of R, G, B, A) and determines
        the appropriate block character, foreground RGB, and background RGB for rendering.
        Pixels with alpha < 32 are treated as transparent.

    .PARAMETER TopPixel
        RGBA byte array for the top pixel, or $null for odd-height first row.

    .PARAMETER BottomPixel
        RGBA byte array for the bottom pixel.

    .OUTPUTS
        PSCustomObject with Character, ForegroundRGB, and BackgroundRGB properties.

    .NOTES
        Returns one of four cases:
        - Both opaque: lower half block, FG=bottom, BG=top
        - Top opaque, bottom transparent: upper half block, FG=top, BG=$null
        - Top transparent, bottom opaque: lower half block, FG=bottom, BG=$null
        - Both transparent: space, FG=$null, BG=$null
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [byte[]]$TopPixel,

        [Parameter(Mandatory)]
        [byte[]]$BottomPixel
    )

    $topTransparent = ($null -eq $TopPixel) -or ($TopPixel[3] -lt 32)
    $bottomTransparent = $BottomPixel[3] -lt 32

    if (-not $topTransparent -and -not $bottomTransparent) {
        # Both opaque: lower half block, FG=bottom color, BG=top color
        [PSCustomObject]@{
            Character     = $script:LowerHalfBlock
            ForegroundRGB = [byte[]]@($BottomPixel[0], $BottomPixel[1], $BottomPixel[2])
            BackgroundRGB = [byte[]]@($TopPixel[0], $TopPixel[1], $TopPixel[2])
        }
    } elseif (-not $topTransparent -and $bottomTransparent) {
        # Top opaque, bottom transparent: upper half block, FG=top color, no BG
        [PSCustomObject]@{
            Character     = $script:UpperHalfBlock
            ForegroundRGB = [byte[]]@($TopPixel[0], $TopPixel[1], $TopPixel[2])
            BackgroundRGB = $null
        }
    } elseif ($topTransparent -and -not $bottomTransparent) {
        # Top transparent, bottom opaque: lower half block, FG=bottom color, no BG
        [PSCustomObject]@{
            Character     = $script:LowerHalfBlock
            ForegroundRGB = [byte[]]@($BottomPixel[0], $BottomPixel[1], $BottomPixel[2])
            BackgroundRGB = $null
        }
    } else {
        # Both transparent: space, no colors
        [PSCustomObject]@{
            Character     = ' '
            ForegroundRGB = $null
            BackgroundRGB = $null
        }
    }
}
