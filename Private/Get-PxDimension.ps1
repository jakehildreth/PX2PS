function Get-PxDimension {
    <#
    .SYNOPSIS
        Reads width and height from .px file according to Pixquare binary spec.
    
    .DESCRIPTION
        Parses the Artwork model header and content to extract canvas Size.
        According to spec: Artwork has 64-byte header, then DumbString ID, then Size (UInt32 Width, UInt32 Height).
    
    .PARAMETER Data
        Byte array containing .px file data.
    
    .OUTPUTS
        PSCustomObject with Width and Height properties.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [byte[]]$Data
    )
    
    # Artwork header is 64 bytes
    # Byte 8 is the ID length
    $idLength = $Data[8]
    
    # Canvas Size starts after: 64-byte header + ID string (idLength bytes)
    $sizeOffset = 64 + $idLength
    
    # Size type is: UInt32 Width, UInt32 Height (little-endian)
    $width = [BitConverter]::ToUInt32($Data, $sizeOffset)
    $height = [BitConverter]::ToUInt32($Data, $sizeOffset + 4)
    
    return [PSCustomObject]@{
        Width = $width
        Height = $height
    }
}
