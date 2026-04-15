Add-Type -AssemblyName System.IO.Compression

function New-MinimalPng {
    <#
    .SYNOPSIS
        Builds a minimal valid RGBA PNG from known pixel data.

    .PARAMETER Width
        Image width in pixels.

    .PARAMETER Height
        Image height in pixels.

    .PARAMETER RgbaData
        Flat byte array: R,G,B,A per pixel, row by row, top to bottom.

    .OUTPUTS
        byte[] containing a valid PNG file.
    #>
    param(
        [int]$Width,
        [int]$Height,
        [byte[]]$RgbaData
    )

    $result = [System.Collections.Generic.List[byte]]::new()

    # PNG signature
    $result.AddRange([byte[]]@(137, 80, 78, 71, 13, 10, 26, 10))

    # IHDR chunk (13 bytes data)
    $ihdrData = [byte[]]::new(13)
    $ihdrData[0] = ($Width -shr 24) -band 0xFF
    $ihdrData[1] = ($Width -shr 16) -band 0xFF
    $ihdrData[2] = ($Width -shr 8) -band 0xFF
    $ihdrData[3] = $Width -band 0xFF
    $ihdrData[4] = ($Height -shr 24) -band 0xFF
    $ihdrData[5] = ($Height -shr 16) -band 0xFF
    $ihdrData[6] = ($Height -shr 8) -band 0xFF
    $ihdrData[7] = $Height -band 0xFF
    $ihdrData[8] = 8   # bit depth
    $ihdrData[9] = 6   # color type: RGBA
    $ihdrData[10] = 0  # compression
    $ihdrData[11] = 0  # filter
    $ihdrData[12] = 0  # interlace

    $ihdrLength = [BitConverter]::GetBytes([int]13)
    [Array]::Reverse($ihdrLength)
    $result.AddRange($ihdrLength)
    $result.AddRange([byte[]]@(73, 72, 68, 82))  # "IHDR"
    $result.AddRange($ihdrData)
    $result.AddRange([byte[]]@(0, 0, 0, 0))  # CRC placeholder

    # Build scanline data with filter byte 0 (None) per row
    $stride = $Width * 4
    $rawScanlines = [byte[]]::new($Height * ($stride + 1))
    for ($row = 0; $row -lt $Height; $row++) {
        $rawOffset = $row * ($stride + 1)
        $rawScanlines[$rawOffset] = 0  # filter type None
        $srcOffset = $row * $stride
        [Array]::Copy($RgbaData, $srcOffset, $rawScanlines, $rawOffset + 1, $stride)
    }

    # Compress with deflate, wrap in zlib
    $memStream = [System.IO.MemoryStream]::new()
    $deflateStream = [System.IO.Compression.DeflateStream]::new(
        $memStream,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $true
    )
    $deflateStream.Write($rawScanlines, 0, $rawScanlines.Length)
    $deflateStream.Close()
    $deflatedBytes = $memStream.ToArray()
    $memStream.Dispose()

    # IDAT chunk: zlib header + deflated data
    $idatPayload = [System.Collections.Generic.List[byte]]::new()
    $idatPayload.AddRange([byte[]]@(0x78, 0x9C))
    $idatPayload.AddRange($deflatedBytes)
    $idatLength = [BitConverter]::GetBytes([int]$idatPayload.Count)
    [Array]::Reverse($idatLength)
    $result.AddRange($idatLength)
    $result.AddRange([byte[]]@(73, 68, 65, 84))  # "IDAT"
    $result.AddRange($idatPayload)
    $result.AddRange([byte[]]@(0, 0, 0, 0))  # CRC placeholder

    # IEND chunk
    $result.AddRange([byte[]]@(0, 0, 0, 0))  # length 0
    $result.AddRange([byte[]]@(73, 69, 78, 68))  # "IEND"
    $result.AddRange([byte[]]@(0, 0, 0, 0))  # CRC placeholder

    return , $result.ToArray()
}

function New-MinimalPiskelJson {
    <#
    .SYNOPSIS
        Builds a minimal valid .piskel JSON string from layer PNG data.

    .PARAMETER Name
        Sprite name.

    .PARAMETER Width
        Image width.

    .PARAMETER Height
        Image height.

    .PARAMETER LayerNames
        Array of layer names.

    .PARAMETER LayerPngBytes
        Array of byte arrays, each a valid PNG file.

    .OUTPUTS
        String containing valid .piskel JSON.
    #>
    param(
        [string]$Name,
        [int]$Width,
        [int]$Height,
        [string[]]$LayerNames,
        [byte[][]]$LayerPngBytes
    )

    $layerJsonList = [System.Collections.Generic.List[string]]::new()

    for ($i = 0; $i -lt $LayerNames.Count; $i++) {
        $base64 = [Convert]::ToBase64String($LayerPngBytes[$i])
        $layerObj = @{
            name       = $LayerNames[$i]
            opacity    = 1
            frameCount = 1
            chunks     = @(
                @{
                    layout    = @(, @(0))
                    base64PNG = "data:image/png;base64,$base64"
                }
            )
        }
        $layerJsonList.Add(($layerObj | ConvertTo-Json -Depth 10 -Compress))
    }

    $piskelObj = @{
        modelVersion = 2
        piskel       = @{
            name        = $Name
            description = ''
            fps         = 12
            height      = $Height
            width       = $Width
            layers      = $layerJsonList.ToArray()
        }
    }

    return ($piskelObj | ConvertTo-Json -Depth 10 -Compress)
}

function New-MinimalAseFile {
    <#
    .SYNOPSIS
        Builds a minimal valid .ase binary from known pixel data.

    .DESCRIPTION
        Constructs a valid Aseprite file with a 128-byte header, one frame,
        and one layer chunk + one compressed cel chunk per layer.
        All cels are full-canvas at position (0,0), 32bpp RGBA.

    .PARAMETER Width
        Image width.

    .PARAMETER Height
        Image height.

    .PARAMETER LayerNames
        Array of layer names.

    .PARAMETER LayerRgbaData
        Array of flat byte arrays, one per layer (R,G,B,A per pixel).

    .OUTPUTS
        byte[] containing a valid .ase file.
    #>
    param(
        [int]$Width,
        [int]$Height,
        [string[]]$LayerNames,
        [byte[][]]$LayerRgbaData
    )

    $frameData = [System.Collections.Generic.List[byte]]::new()
    $chunkCount = $LayerNames.Count * 2

    # frame header placeholder (16 bytes)
    $frameData.AddRange([byte[]]@(0, 0, 0, 0))                             # frame size placeholder
    $frameData.AddRange([BitConverter]::GetBytes([uint16]0xF1FA))           # magic
    $frameData.AddRange([BitConverter]::GetBytes([uint16]$chunkCount))      # old chunk count
    $frameData.AddRange([BitConverter]::GetBytes([uint16]100))              # frame duration
    $frameData.AddRange([byte[]]@(0, 0))                                   # future
    $frameData.AddRange([BitConverter]::GetBytes([uint32]0))                # new chunk count (0 = use old)

    for ($li = 0; $li -lt $LayerNames.Count; $li++) {
        $nameBytes = [System.Text.Encoding]::UTF8.GetBytes($LayerNames[$li])

        # layer chunk (0x2004)
        $layerChunk = [System.Collections.Generic.List[byte]]::new()
        $layerChunk.AddRange([byte[]]@(0, 0, 0, 0))                        # chunk size placeholder
        $layerChunk.AddRange([BitConverter]::GetBytes([uint16]0x2004))       # chunk type
        $layerChunk.AddRange([BitConverter]::GetBytes([uint16]1))            # flags: visible
        $layerChunk.AddRange([BitConverter]::GetBytes([uint16]0))            # layer type: normal
        $layerChunk.AddRange([BitConverter]::GetBytes([uint16]0))            # child level
        $layerChunk.AddRange([BitConverter]::GetBytes([uint16]0))            # default width (ignored)
        $layerChunk.AddRange([BitConverter]::GetBytes([uint16]0))            # default height (ignored)
        $layerChunk.AddRange([BitConverter]::GetBytes([uint16]0))            # blend mode: normal
        $layerChunk.Add([byte]255)                                          # opacity
        $layerChunk.AddRange([byte[]]@(0, 0, 0))                            # future
        $layerChunk.AddRange([BitConverter]::GetBytes([uint16]$nameBytes.Length))
        $layerChunk.AddRange($nameBytes)

        $chunkSizeBytes = [BitConverter]::GetBytes([uint32]$layerChunk.Count)
        $layerChunk[0] = $chunkSizeBytes[0]
        $layerChunk[1] = $chunkSizeBytes[1]
        $layerChunk[2] = $chunkSizeBytes[2]
        $layerChunk[3] = $chunkSizeBytes[3]
        $frameData.AddRange($layerChunk)

        # cel chunk (0x2005) - compressed image
        $celChunk = [System.Collections.Generic.List[byte]]::new()
        $celChunk.AddRange([byte[]]@(0, 0, 0, 0))                          # chunk size placeholder
        $celChunk.AddRange([BitConverter]::GetBytes([uint16]0x2005))         # chunk type
        $celChunk.AddRange([BitConverter]::GetBytes([uint16]$li))            # layer index
        $celChunk.AddRange([BitConverter]::GetBytes([int16]0))               # x position
        $celChunk.AddRange([BitConverter]::GetBytes([int16]0))               # y position
        $celChunk.Add([byte]255)                                            # opacity
        $celChunk.AddRange([BitConverter]::GetBytes([uint16]2))              # cel type: compressed image
        $celChunk.AddRange([BitConverter]::GetBytes([int16]0))               # z-index
        $celChunk.AddRange([byte[]]@(0, 0, 0, 0, 0))                        # future
        $celChunk.AddRange([BitConverter]::GetBytes([uint16]$Width))          # cel width
        $celChunk.AddRange([BitConverter]::GetBytes([uint16]$Height))         # cel height

        # compress RGBA data with zlib
        $memStream = [System.IO.MemoryStream]::new()
        $deflateStream = [System.IO.Compression.DeflateStream]::new(
            $memStream,
            [System.IO.Compression.CompressionLevel]::Optimal,
            $true
        )
        $deflateStream.Write($LayerRgbaData[$li], 0, $LayerRgbaData[$li].Length)
        $deflateStream.Close()
        $deflatedBytes = $memStream.ToArray()
        $memStream.Dispose()

        $zlibData = [System.Collections.Generic.List[byte]]::new()
        $zlibData.AddRange([byte[]]@(0x78, 0x9C))
        $zlibData.AddRange($deflatedBytes)
        $celChunk.AddRange($zlibData)

        $chunkSizeBytes = [BitConverter]::GetBytes([uint32]$celChunk.Count)
        $celChunk[0] = $chunkSizeBytes[0]
        $celChunk[1] = $chunkSizeBytes[1]
        $celChunk[2] = $chunkSizeBytes[2]
        $celChunk[3] = $chunkSizeBytes[3]
        $frameData.AddRange($celChunk)
    }

    # set frame size
    $frameSizeBytes = [BitConverter]::GetBytes([uint32]$frameData.Count)
    $frameData[0] = $frameSizeBytes[0]
    $frameData[1] = $frameSizeBytes[1]
    $frameData[2] = $frameSizeBytes[2]
    $frameData[3] = $frameSizeBytes[3]

    # 128-byte header
    $header = [byte[]]::new(128)
    $fileSize = 128 + $frameData.Count
    [Array]::Copy([BitConverter]::GetBytes([uint32]$fileSize), 0, $header, 0, 4)
    [Array]::Copy([BitConverter]::GetBytes([uint16]0xA5E0), 0, $header, 4, 2)
    [Array]::Copy([BitConverter]::GetBytes([uint16]1), 0, $header, 6, 2)         # 1 frame
    [Array]::Copy([BitConverter]::GetBytes([uint16]$Width), 0, $header, 8, 2)
    [Array]::Copy([BitConverter]::GetBytes([uint16]$Height), 0, $header, 10, 2)
    [Array]::Copy([BitConverter]::GetBytes([uint16]32), 0, $header, 12, 2)       # 32bpp RGBA
    [Array]::Copy([BitConverter]::GetBytes([uint32]1), 0, $header, 14, 4)        # flags: layer opacity valid
    [Array]::Copy([BitConverter]::GetBytes([uint16]100), 0, $header, 18, 2)      # speed
    $header[34] = 1  # pixel width
    $header[35] = 1  # pixel height
    [Array]::Copy([BitConverter]::GetBytes([uint16]16), 0, $header, 40, 2)       # grid width
    [Array]::Copy([BitConverter]::GetBytes([uint16]16), 0, $header, 42, 2)       # grid height

    $result = [System.Collections.Generic.List[byte]]::new()
    $result.AddRange($header)
    $result.AddRange($frameData)

    return , $result.ToArray()
}
