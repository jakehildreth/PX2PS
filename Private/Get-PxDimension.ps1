function Get-PxDimension {
    <#
    .SYNOPSIS
        Reads width and height from .px file header.
    
    .DESCRIPTION
        Extracts dimensions stored as 32-bit little-endian integers at offsets 0x64 and 0x68.
    
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
    
    $width = [BitConverter]::ToInt32($Data, 0x64)
    $height = [BitConverter]::ToInt32($Data, 0x68)
    
    return [PSCustomObject]@{
        Width = $width
        Height = $height
    }
}
