function Read-PiskelLayerData {
    <#
    .SYNOPSIS
        Reads and decodes layer data from a parsed .piskel file.

    .DESCRIPTION
        Extracts RGBA pixel data from each layer in a .piskel file by decoding
        the embedded base64 PNG images. Only processes the first frame of each
        layer (animation is not supported).

    .PARAMETER PiskelData
        Parsed JSON object from a .piskel file.

    .PARAMETER Width
        Expected image width in pixels.

    .PARAMETER Height
        Expected image height in pixels.

    .OUTPUTS
        System.Array of byte arrays, one per valid layer.
    #>
    [CmdletBinding()]
    [OutputType([byte[][]])]
    param(
        [Parameter(Mandatory)]
        [PSObject]$PiskelData,

        [Parameter(Mandatory)]
        [int]$Width,

        [Parameter(Mandatory)]
        [int]$Height
    )

    $expectedBytes = $Width * $Height * 4
    $layers = [System.Collections.Generic.List[byte[]]]::new()

    foreach ($layerJson in $PiskelData.piskel.layers) {
        $layer = $layerJson | ConvertFrom-Json

        if ($layer.frameCount -gt 1) {
            Write-Warning "Layer '$($layer.name)' has $($layer.frameCount) frames; only the first frame will be used"
        }

        $chunk = $layer.chunks[0]
        $base64Png = $chunk.base64PNG

        # strip data URI prefix
        if ($base64Png -match '^data:image/png;base64,') {
            $base64Png = $base64Png -replace '^data:image/png;base64,', ''
        }

        try {
            $pngBytes = [Convert]::FromBase64String($base64Png)
            $decoded = ConvertFrom-PngData -Data $pngBytes

            if ($null -eq $decoded) {
                Write-Warning "Failed to decode PNG for layer '$($layer.name)'"
                continue
            }

            if ($decoded.RgbaData.Length -eq $expectedBytes) {
                $layers.Add($decoded.RgbaData)
            } else {
                Write-Warning "Layer '$($layer.name)' pixel count mismatch: expected $expectedBytes bytes, got $($decoded.RgbaData.Length)"
            }
        } catch {
            Write-Verbose "Skipped layer '$($layer.name)': $($_.Exception.Message)"
        }
    }

    return , $layers.ToArray()
}
