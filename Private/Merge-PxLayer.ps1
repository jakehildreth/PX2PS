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
            
            $pixels.Add([byte[]]@($r, $g, $b, $a))
        }
    } else {
        # Composite layers from bottom to top
        # Start with bottom layer (last in array) and work upward
        for ($i = 0; $i -lt $pixelCount; $i++) {
            $idx = $i * 4
            
            # Start with bottom layer
            $bottomLayer = $Layers[$Layers.Count - 1]
            $r = $bottomLayer[$idx]
            $g = $bottomLayer[$idx + 1]
            $b = $bottomLayer[$idx + 2]
            $a = $bottomLayer[$idx + 3]
            
            # Composite each layer on top from bottom to top
            for ($li = $Layers.Count - 2; $li -ge 0; $li--) {
                $layer = $Layers[$li]
                $lr = $layer[$idx]
                $lg = $layer[$idx + 1]
                $lb = $layer[$idx + 2]
                $la = $layer[$idx + 3]
                
                # Composite if top layer has opacity (even if it's black)
                if ($la -gt 0) {
                    $r = $lr
                    $g = $lg
                    $b = $lb
                    $a = $la
                }
            }
            
            $pixels.Add([byte[]]@($r, $g, $b, $a))
        }
    }
    
    return $pixels.ToArray()
}
