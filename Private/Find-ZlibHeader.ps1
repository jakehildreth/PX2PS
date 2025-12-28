function Find-ZlibHeader {
    <#
    .SYNOPSIS
        Finds all zlib header positions in byte array.
    
    .DESCRIPTION
        Searches for zlib compression headers (78 9C, 78 DA, 78 01, 78 5E).
    
    .PARAMETER Data
        Byte array to search.
    
    .OUTPUTS
        System.Int32[]
    #>
    [CmdletBinding()]
    [OutputType([int[]])]
    param(
        [Parameter(Mandatory)]
        [byte[]]$Data
    )
    
    $offsets = [System.Collections.Generic.List[int]]::new()
    $validSecondBytes = @(0x9C, 0xDA, 0x01, 0x5E)
    
    for ($i = 0; $i -lt ($Data.Length - 1); $i++) {
        if ($Data[$i] -eq 0x78 -and $Data[$i + 1] -in $validSecondBytes) {
            $offsets.Add($i)
        }
    }
    
    return $offsets.ToArray()
}
