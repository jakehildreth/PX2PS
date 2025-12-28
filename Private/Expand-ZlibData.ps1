function Expand-ZlibData {
    <#
    .SYNOPSIS
        Decompresses zlib data by skipping 2-byte header and using raw deflate.
    
    .PARAMETER Data
        Byte array containing zlib-compressed data.
    
    .PARAMETER Offset
        Starting offset of zlib data in the byte array.
    
    .OUTPUTS
        System.Byte[]
    #>
    [CmdletBinding()]
    [OutputType([byte[]])]
    param(
        [Parameter(Mandatory)]
        [byte[]]$Data,
        
        [Parameter(Mandatory)]
        [int]$Offset
    )
    
    $slice = $Data[($Offset + 2)..($Data.Length - 1)]
    $memoryStream = New-Object System.IO.MemoryStream (, $slice)
    $deflateStream = New-Object System.IO.Compression.DeflateStream (
        $memoryStream,
        [System.IO.Compression.CompressionMode]::Decompress
    )
    $outputStream = New-Object System.IO.MemoryStream
    
    try {
        $deflateStream.CopyTo($outputStream)
        return $outputStream.ToArray()
    } finally {
        $deflateStream.Dispose()
        $memoryStream.Dispose()
        $outputStream.Dispose()
    }
}
