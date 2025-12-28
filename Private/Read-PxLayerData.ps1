function Read-PxLayerData {
    <#
    .SYNOPSIS
        Reads and decompresses layer data from .px file.
    
    .PARAMETER Data
        Byte array containing .px file data.
    
    .PARAMETER Width
        Image width in pixels.
    
    .PARAMETER Height
        Image height in pixels.
    
    .OUTPUTS
        System.Array of byte arrays, one per valid layer.
    #>
    [CmdletBinding()]
    [OutputType([byte[][]])]
    param(
        [Parameter(Mandatory)]
        [byte[]]$Data,
        
        [Parameter(Mandatory)]
        [int]$Width,
        
        [Parameter(Mandatory)]
        [int]$Height
    )
    
    $pixelCount = $Width * $Height
    $expectedBytes = $pixelCount * 4
    $zlibOffsets = Find-ZlibHeader -Data $Data
    
    if ($zlibOffsets.Count -eq 0) {
        return @()
    }
    
    $layers = [System.Collections.Generic.List[byte[]]]::new()
    
    foreach ($offset in $zlibOffsets) {
        try {
            $layerData = Expand-ZlibData -Data $Data -Offset $offset
            if ($layerData.Length -eq $expectedBytes) {
                $layers.Add($layerData)
            }
        } catch {
            Write-Verbose "Skipped invalid zlib stream at offset $offset"
        }
    }
    
    return $layers.ToArray()
}
