function ConvertTo-ConsoleColor {
    <#
    .SYNOPSIS
        Maps an RGB color to the nearest System.ConsoleColor.

    .DESCRIPTION
        Finds the closest match among the 16 standard ConsoleColor values
        using Euclidean distance in RGB color space. Intended for ISE
        compatibility where ANSI True Color is not supported.

    .PARAMETER R
        Red component (0-255).

    .PARAMETER G
        Green component (0-255).

    .PARAMETER B
        Blue component (0-255).

    .EXAMPLE
        ConvertTo-ConsoleColor -R 255 -G 0 -B 0

        Returns [System.ConsoleColor]::Red

    .EXAMPLE
        ConvertTo-ConsoleColor -R 128 -G 128 -B 128

        Returns [System.ConsoleColor]::DarkGray

    .OUTPUTS
        System.ConsoleColor
    #>
    [CmdletBinding()]
    [OutputType([System.ConsoleColor])]
    param(
        [Parameter(Mandatory)]
        [int]$R,

        [Parameter(Mandatory)]
        [int]$G,

        [Parameter(Mandatory)]
        [int]$B
    )

    $colorMap = @(
        @{ Color = [System.ConsoleColor]::Black;       R = 0;   G = 0;   B = 0   }
        @{ Color = [System.ConsoleColor]::DarkBlue;    R = 0;   G = 0;   B = 128 }
        @{ Color = [System.ConsoleColor]::DarkGreen;   R = 0;   G = 128; B = 0   }
        @{ Color = [System.ConsoleColor]::DarkCyan;    R = 0;   G = 128; B = 128 }
        @{ Color = [System.ConsoleColor]::DarkRed;     R = 128; G = 0;   B = 0   }
        @{ Color = [System.ConsoleColor]::DarkMagenta; R = 128; G = 0;   B = 128 }
        @{ Color = [System.ConsoleColor]::DarkYellow;  R = 128; G = 128; B = 0   }
        @{ Color = [System.ConsoleColor]::Gray;        R = 192; G = 192; B = 192 }
        @{ Color = [System.ConsoleColor]::DarkGray;    R = 128; G = 128; B = 128 }
        @{ Color = [System.ConsoleColor]::Blue;        R = 0;   G = 0;   B = 255 }
        @{ Color = [System.ConsoleColor]::Green;       R = 0;   G = 255; B = 0   }
        @{ Color = [System.ConsoleColor]::Cyan;        R = 0;   G = 255; B = 255 }
        @{ Color = [System.ConsoleColor]::Red;         R = 255; G = 0;   B = 0   }
        @{ Color = [System.ConsoleColor]::Magenta;     R = 255; G = 0;   B = 255 }
        @{ Color = [System.ConsoleColor]::Yellow;      R = 255; G = 255; B = 0   }
        @{ Color = [System.ConsoleColor]::White;       R = 255; G = 255; B = 255 }
    )

    $nearestColor = [System.ConsoleColor]::Black
    $minDistance = [int]::MaxValue

    foreach ($entry in $colorMap) {
        $dr = $R - $entry.R
        $dg = $G - $entry.G
        $db = $B - $entry.B
        $distance = ($dr * $dr) + ($dg * $dg) + ($db * $db)

        if ($distance -lt $minDistance) {
            $minDistance = $distance
            $nearestColor = $entry.Color
        }
    }

    return $nearestColor
}
