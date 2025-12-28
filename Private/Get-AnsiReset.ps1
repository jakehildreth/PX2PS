function Get-AnsiReset {
    <#
    .SYNOPSIS
        Returns ANSI reset sequence.
    
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    return "$script:ESC[0m"
}
