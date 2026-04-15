function ConvertFrom-PngData {
    <#
    .SYNOPSIS
        Decodes a PNG byte array into flat RGBA pixel data.

    .DESCRIPTION
        Pure PowerShell PNG decoder that extracts RGBA pixel data from PNG files.
        Handles RGBA (color type 6) and RGB (color type 2) with bit depth 8.
        Applies PNG scanline unfiltering (None, Sub, Up, Average, Paeth).

    .PARAMETER Data
        Byte array containing PNG file data.

    .OUTPUTS
        PSCustomObject with Width, Height, and RgbaData (flat byte array) properties.

    .NOTES
        Only supports bit depth 8 with color types 2 (RGB) and 6 (RGBA).
        Does not support interlaced PNGs.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [byte[]]$Data
    )

    # validate PNG signature
    $signature = @(137, 80, 78, 71, 13, 10, 26, 10)
    for ($i = 0; $i -lt 8; $i++) {
        if ($Data[$i] -ne $signature[$i]) {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.FormatException]::new('Invalid PNG signature'),
                'InvalidPngSignature',
                [System.Management.Automation.ErrorCategory]::InvalidData,
                $Data
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }

    # parse chunks to extract IHDR metadata and IDAT compressed data
    $offset = 8
    $width = 0
    $height = 0
    $bitDepth = 0
    $colorType = 0
    $bytesPerPixel = 0
    $idatData = [System.Collections.Generic.List[byte]]::new()

    while ($offset -lt $Data.Length) {
        $chunkLength = ([int]$Data[$offset] -shl 24) -bor ([int]$Data[$offset + 1] -shl 16) -bor ([int]$Data[$offset + 2] -shl 8) -bor [int]$Data[$offset + 3]
        $chunkType = [System.Text.Encoding]::ASCII.GetString($Data, $offset + 4, 4)
        $chunkDataOffset = $offset + 8

        switch ($chunkType) {
            'IHDR' {
                $width = ([int]$Data[$chunkDataOffset] -shl 24) -bor ([int]$Data[$chunkDataOffset + 1] -shl 16) -bor ([int]$Data[$chunkDataOffset + 2] -shl 8) -bor [int]$Data[$chunkDataOffset + 3]
                $height = ([int]$Data[$chunkDataOffset + 4] -shl 24) -bor ([int]$Data[$chunkDataOffset + 5] -shl 16) -bor ([int]$Data[$chunkDataOffset + 6] -shl 8) -bor [int]$Data[$chunkDataOffset + 7]
                $bitDepth = $Data[$chunkDataOffset + 8]
                $colorType = $Data[$chunkDataOffset + 9]
                $interlace = $Data[$chunkDataOffset + 12]

                if ($bitDepth -ne 8) {
                    Write-Warning "Unsupported PNG bit depth: $bitDepth (only 8 supported)"
                    return $null
                }

                if ($interlace -ne 0) {
                    Write-Warning 'Interlaced PNGs are not supported'
                    return $null
                }

                $bytesPerPixel = switch ($colorType) {
                    2 { 3 }  # RGB
                    6 { 4 }  # RGBA
                    default {
                        Write-Warning "Unsupported PNG color type: $colorType (only RGB=2 and RGBA=6 supported)"
                        return $null
                    }
                }

                Write-Verbose "PNG IHDR: ${width}x${height}, bitDepth=$bitDepth, colorType=$colorType"
            }
            'IDAT' {
                for ($i = 0; $i -lt $chunkLength; $i++) {
                    $idatData.Add($Data[$chunkDataOffset + $i])
                }
            }
            'IEND' {
                break
            }
        }

        $offset = $chunkDataOffset + $chunkLength + 4  # skip CRC
    }

    if ($idatData.Count -eq 0) {
        Write-Warning 'No IDAT data found in PNG'
        return $null
    }

    # decompress zlib data (skip 2-byte zlib header, use raw deflate)
    $compressedBytes = $idatData.ToArray()
    $memoryStream = [System.IO.MemoryStream]::new($compressedBytes, 2, $compressedBytes.Length - 2)
    $deflateStream = [System.IO.Compression.DeflateStream]::new(
        $memoryStream,
        [System.IO.Compression.CompressionMode]::Decompress
    )
    $outputStream = [System.IO.MemoryStream]::new()

    try {
        $deflateStream.CopyTo($outputStream)
    } finally {
        $deflateStream.Dispose()
        $memoryStream.Dispose()
    }

    $rawData = $outputStream.ToArray()
    $outputStream.Dispose()

    # unfilter scanlines
    $stride = $width * $bytesPerPixel
    $rgbaData = [byte[]]::new($width * $height * 4)
    $previousRow = [byte[]]::new($stride)

    for ($row = 0; $row -lt $height; $row++) {
        $rowOffset = $row * ($stride + 1)  # +1 for filter byte
        $filterType = $rawData[$rowOffset]
        $currentRow = [byte[]]::new($stride)

        for ($col = 0; $col -lt $stride; $col++) {
            $rawByte = $rawData[$rowOffset + 1 + $col]
            $a = if ($col -ge $bytesPerPixel) { $currentRow[$col - $bytesPerPixel] } else { 0 }
            $b = $previousRow[$col]
            $c = if ($col -ge $bytesPerPixel) { $previousRow[$col - $bytesPerPixel] } else { 0 }

            $unfiltered = switch ($filterType) {
                0 { $rawByte }
                1 { ($rawByte + $a) -band 0xFF }
                2 { ($rawByte + $b) -band 0xFF }
                3 { ($rawByte + [Math]::Floor(($a + $b) / 2)) -band 0xFF }
                4 {
                    $p = $a + $b - $c
                    $pa = [Math]::Abs($p - $a)
                    $pb = [Math]::Abs($p - $b)
                    $pc = [Math]::Abs($p - $c)
                    $predictor = if ($pa -le $pb -and $pa -le $pc) { $a } elseif ($pb -le $pc) { $b } else { $c }
                    ($rawByte + $predictor) -band 0xFF
                }
                default {
                    Write-Warning "Unknown PNG filter type: $filterType at row $row"
                    $rawByte
                }
            }

            $currentRow[$col] = [byte]$unfiltered
        }

        # write to output RGBA array
        $outputOffset = $row * $width * 4
        for ($px = 0; $px -lt $width; $px++) {
            $srcOffset = $px * $bytesPerPixel
            $dstOffset = $outputOffset + ($px * 4)
            $rgbaData[$dstOffset] = $currentRow[$srcOffset]
            $rgbaData[$dstOffset + 1] = $currentRow[$srcOffset + 1]
            $rgbaData[$dstOffset + 2] = $currentRow[$srcOffset + 2]
            if ($colorType -eq 6) {
                $rgbaData[$dstOffset + 3] = $currentRow[$srcOffset + 3]
            } else {
                $rgbaData[$dstOffset + 3] = 255  # RGB: fully opaque
            }
        }

        $previousRow = $currentRow
    }

    return [PSCustomObject]@{
        Width    = $width
        Height   = $height
        RgbaData = $rgbaData
    }
}
