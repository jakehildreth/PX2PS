function Get-AseDimension {
    <#
    .SYNOPSIS
        Reads dimensions and color depth from an Aseprite .ase file header.

    .DESCRIPTION
        Parses the 128-byte Aseprite file header to extract image width,
        height, and color depth. Validates the magic number (0xA5E0) and
        minimum data length.

    .PARAMETER Data
        Byte array containing .ase file data.

    .OUTPUTS
        PSCustomObject with Width, Height, and ColorDepth properties.

    .NOTES
        Aseprite header layout (little-endian):
        Offset 0:  DWORD  file size
        Offset 4:  WORD   magic number (0xA5E0)
        Offset 6:  WORD   frame count
        Offset 8:  WORD   width in pixels
        Offset 10: WORD   height in pixels
        Offset 12: WORD   color depth (32=RGBA, 16=Grayscale, 8=Indexed)
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [byte[]]$Data
    )

    if ($Data.Length -lt 128) {
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.FormatException]::new("Data is too short for an Aseprite header (got $($Data.Length) bytes, need 128)"),
            'AseTooShort',
            [System.Management.Automation.ErrorCategory]::InvalidData,
            $Data
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    $magic = [BitConverter]::ToUInt16($Data, 4)
    if ($magic -ne 0xA5E0) {
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.FormatException]::new("Invalid Aseprite magic number: 0x$($magic.ToString('X4')) (expected 0xA5E0)"),
            'AseInvalidMagic',
            [System.Management.Automation.ErrorCategory]::InvalidData,
            $Data
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    $width = [BitConverter]::ToUInt16($Data, 8)
    $height = [BitConverter]::ToUInt16($Data, 10)
    $colorDepth = [BitConverter]::ToUInt16($Data, 12)

    Write-Verbose "Aseprite header: ${width}x${height}, ${colorDepth}bpp"

    return [PSCustomObject]@{
        Width      = [int]$width
        Height     = [int]$height
        ColorDepth = [int]$colorDepth
    }
}
