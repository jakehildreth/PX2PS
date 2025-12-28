function Write-PxTerminal {
    <#
    .SYNOPSIS
        Renders pixel data to terminal using lower half blocks with True Color.
    
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
    
    $reset = Get-AnsiReset
    $oddHeight = ($Height % 2) -eq 1
    $startY = if ($oddHeight) { -1 } else { 0 }
    $endY = if ($oddHeight) { $Height - 1 } else { $Height }
    
    for ($y = $startY; $y -lt $endY; $y += 2) {
        $line = ""
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
            
            $botR = if ($bottomPixel[3] -lt 32) { 0 } else { $bottomPixel[0] }
            $botG = if ($bottomPixel[3] -lt 32) { 0 } else { $bottomPixel[1] }
            $botB = if ($bottomPixel[3] -lt 32) { 0 } else { $bottomPixel[2] }
            
            if ($null -eq $topPixel) {
                $fg = Get-TrueColorFg -R $botR -G $botG -B $botB
                $line += "${fg}$script:LowerHalfBlock"
            } else {
                $topR = if ($topPixel[3] -lt 32) { 0 } else { $topPixel[0] }
                $topG = if ($topPixel[3] -lt 32) { 0 } else { $topPixel[1] }
                $topB = if ($topPixel[3] -lt 32) { 0 } else { $topPixel[2] }
                
                $bg = Get-TrueColorBg -R $topR -G $topG -B $topB
                $fg = Get-TrueColorFg -R $botR -G $botG -B $botB
                $line += "${bg}${fg}$script:LowerHalfBlock"
            }
        }
        $line += "$script:ESC[0m$script:ESC[K"
        Write-Host $line
    }
    
    Write-Host ""
}
