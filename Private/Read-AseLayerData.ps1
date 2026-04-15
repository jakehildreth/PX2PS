function Read-AseLayerData {
    <#
    .SYNOPSIS
        Reads and decompresses layer data from an Aseprite .ase file.

    .DESCRIPTION
        Parses Aseprite frame data to extract cel chunks (0x2005) with
        compressed image data. Only processes the first frame. Each cel's
        zlib-compressed RGBA data is decompressed and returned as a byte array.

    .PARAMETER Data
        Byte array containing .ase file data.

    .PARAMETER Width
        Expected image width in pixels.

    .PARAMETER Height
        Expected image height in pixels.

    .OUTPUTS
        System.Array of byte arrays, one per valid layer.

    .NOTES
        Aseprite frame layout:
        - Frame header: 16 bytes (size, magic 0xF1FA, chunk count, etc.)
        - Chunks: layer (0x2004), cel (0x2005), etc.
        - Cel chunk with type 2 = compressed image: has width, height, then zlib data.
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

    $expectedBytes = $Width * $Height * 4
    $layers = [System.Collections.Generic.List[byte[]]]::new()

    if ($Data.Length -lt 128) {
        return , $layers.ToArray()
    }

    $frameCount = [BitConverter]::ToUInt16($Data, 6)
    if ($frameCount -eq 0) {
        return , $layers.ToArray()
    }

    # only process the first frame
    $offset = 128

    if ($offset + 16 -gt $Data.Length) {
        return , $layers.ToArray()
    }

    $frameSize = [BitConverter]::ToUInt32($Data, $offset)
    $frameMagic = [BitConverter]::ToUInt16($Data, $offset + 4)

    if ($frameMagic -ne 0xF1FA) {
        Write-Warning "Invalid frame magic: 0x$($frameMagic.ToString('X4'))"
        return , $layers.ToArray()
    }

    $oldChunkCount = [BitConverter]::ToUInt16($Data, $offset + 6)
    $newChunkCount = [BitConverter]::ToUInt32($Data, $offset + 12)
    $chunkCount = if ($newChunkCount -ne 0) { $newChunkCount } else { $oldChunkCount }

    $chunkOffset = $offset + 16

    for ($ci = 0; $ci -lt $chunkCount; $ci++) {
        if ($chunkOffset + 6 -gt $Data.Length) {
            break
        }

        $chunkSize = [BitConverter]::ToUInt32($Data, $chunkOffset)
        $chunkType = [BitConverter]::ToUInt16($Data, $chunkOffset + 4)

        if ($chunkType -eq 0x2005) {
            # cel chunk
            $celDataOffset = $chunkOffset + 6
            # layer index: WORD at +0
            # x position:  SHORT at +2
            # y position:  SHORT at +4
            # opacity:     BYTE at +6
            # cel type:    WORD at +7
            # z-index:     SHORT at +9
            # future:      5 bytes at +11
            $celType = [BitConverter]::ToUInt16($Data, $celDataOffset + 7)

            if ($celType -eq 2) {
                # compressed image
                # cel width:  WORD at +16
                # cel height: WORD at +18
                # compressed data starts at +20
                $celWidth = [BitConverter]::ToUInt16($Data, $celDataOffset + 16)
                $celHeight = [BitConverter]::ToUInt16($Data, $celDataOffset + 18)
                $compressedStart = $celDataOffset + 20

                if ($celWidth -eq $Width -and $celHeight -eq $Height) {
                    try {
                        $layerData = Expand-ZlibData -Data $Data -Offset $compressedStart
                        if ($layerData.Length -eq $expectedBytes) {
                            $layers.Add($layerData)
                        } else {
                            Write-Verbose "Cel data length mismatch: expected $expectedBytes, got $($layerData.Length)"
                        }
                    } catch {
                        Write-Verbose "Failed to decompress cel at offset $compressedStart`: $($_.Exception.Message)"
                    }
                }
            }
        }

        $chunkOffset += $chunkSize
    }

    return , $layers.ToArray()
}
