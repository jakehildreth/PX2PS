function Merge-PxLayer {
    <#
    .SYNOPSIS
        Composites multiple pixel layers into final RGBA data.
    
    .PARAMETER Layers
        Array of byte arrays, each containing RGBA data for one layer.
    
    .PARAMETER Width
        Image width in pixels.
    
    .PARAMETER Height
        Image height in pixels.
    
    .OUTPUTS
        System.Array of RGBA pixel arrays.
    #>
    [CmdletBinding()]
    [OutputType([byte[][]])]
    param(
        [Parameter(Mandatory)]
        [byte[][]]$Layers,
        
        [Parameter(Mandatory)]
        [int]$Width,
        
        [Parameter(Mandatory)]
        [int]$Height
    )
    
    $pixelCount = $Width * $Height
    $pixels = [System.Collections.Generic.List[byte[]]]::new($pixelCount)
    
    if ($Layers.Count -eq 1) {
        $layer = $Layers[0]
        for ($i = 0; $i -lt $pixelCount; $i++) {
            $idx = $i * 4
            $r = $layer[$idx]
            $g = $layer[$idx + 1]
            $b = $layer[$idx + 2]
            $a = $layer[$idx + 3]
            
            if ($r -eq 0 -and $g -eq 0 -and $b -eq 0) {
                $a = 0
            }
            $pixels.Add([byte[]]@($r, $g, $b, $a))
        }
    } else {
        $layer0 = $Layers[0]
        $layer0IsColorMask = $true
        
        for ($i = 0; $i -lt $pixelCount; $i++) {
            $idx = $i * 4
            $r = $layer0[$idx]
            $g = $layer0[$idx + 1]
            $b = $layer0[$idx + 2]
            
            if (($r -ne 0 -or $g -ne 0 -or $b -ne 0) -and $layer0[$idx + 3] -gt 0) {
                $layer0IsColorMask = $false
                break
            }
        }
        
        for ($i = 0; $i -lt $pixelCount; $i++) {
            $idx = $i * 4
            
            if ($layer0IsColorMask) {
                $maskAlpha = $layer0[$idx + 3]
                
                if ($maskAlpha -eq 0) {
                    $r = $Layers[1][$idx]
                    $g = $Layers[1][$idx + 1]
                    $b = $Layers[1][$idx + 2]
                    $a = $Layers[1][$idx + 3]
                    
                    for ($li = 2; $li -lt $Layers.Count; $li++) {
                        $layer = $Layers[$li]
                        $la = $layer[$idx + 3]
                        if ($la -gt 0) {
                            $r = $layer[$idx]
                            $g = $layer[$idx + 1]
                            $b = $layer[$idx + 2]
                            $a = $la
                        }
                    }
                } else {
                    $r = 0
                    $g = 0
                    $b = 0
                    $a = 0
                }
            } else {
                $bottomLayer = $Layers[$Layers.Count - 1]
                $r = $bottomLayer[$idx]
                $g = $bottomLayer[$idx + 1]
                $b = $bottomLayer[$idx + 2]
                $a = $bottomLayer[$idx + 3]
                
                for ($li = $Layers.Count - 2; $li -ge 0; $li--) {
                    $layer = $Layers[$li]
                    $la = $layer[$idx + 3]
                    
                    if ($la -gt 0) {
                        $r = $layer[$idx]
                        $g = $layer[$idx + 1]
                        $b = $layer[$idx + 2]
                        $a = $la
                    }
                }
            }
            
            $pixels.Add([byte[]]@($r, $g, $b, $a))
        }
    }
    
    return $pixels.ToArray()
}
