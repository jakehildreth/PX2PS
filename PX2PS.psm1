# Enable Virtual Terminal Processing for ANSI colors (Windows PowerShell 5.1 compatibility)
if ($PSVersionTable.PSVersion.Major -le 5 -and $env:OS -eq 'Windows_NT') {
    $vtEnabled = $false
    try {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class VTConsole {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetStdHandle(int nStdHandle);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
    public static void EnableVT() {
        IntPtr handle = GetStdHandle(-11);
        uint mode;
        GetConsoleMode(handle, out mode);
        SetConsoleMode(handle, mode | 0x4);
    }
}
"@ -ErrorAction SilentlyContinue
        [VTConsole]::EnableVT()
        $vtEnabled = $true
    } catch {
        # VT processing may already be enabled or not available
    }
}

Add-Type -AssemblyName System.IO.Compression

# Module-scoped constants
$script:LowerHalfBlock = [char]0x2584
$script:ESC = [char]27

# Dot source private functions
$privateFunctions = @(Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -ErrorAction SilentlyContinue)
foreach ($function in $privateFunctions) {
    try {
        . $function.FullName
    } catch {
        Write-Error "Failed to import function $($function.FullName): $_"
    }
}

# Dot source public functions
$publicFunctions = @(Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -ErrorAction SilentlyContinue)
foreach ($function in $publicFunctions) {
    try {
        . $function.FullName
    } catch {
        Write-Error "Failed to import function $($function.FullName): $_"
    }
}

# Export public functions
Export-ModuleMember -Function $publicFunctions.BaseName
