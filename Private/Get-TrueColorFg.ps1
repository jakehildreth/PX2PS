function Get-TrueColorFg {
    <#
    .SYNOPSIS
        Generates ANSI escape sequence for foreground true color.
    
    .PARAMETER R
        Red component (0-255).
    
    .PARAMETER G
        Green component (0-255).
    
    .PARAMETER B
        Blue component (0-255).
    
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(0, 255)]
        [int]$R,
        
        [Parameter(Mandatory)]
        [ValidateRange(0, 255)]
        [int]$G,
        
        [Parameter(Mandatory)]
        [ValidateRange(0, 255)]
        [int]$B
    )
    
    return "$script:ESC[38;2;${R};${G};${B}m"
}
