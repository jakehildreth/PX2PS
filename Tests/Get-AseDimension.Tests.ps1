BeforeAll {
    . $PSScriptRoot/TestHelpers.ps1
    . $PSScriptRoot/../Private/Get-AseDimension.ps1
}

Describe 'Get-AseDimension' -Tag 'Aseprite' {
    Context 'when given a valid 4x3 RGBA .ase file' {
        BeforeAll {
            $rgba = [byte[]]::new(4 * 3 * 4)  # 4x3 RGBA, all zeros
            $aseBytes = New-MinimalAseFile -Width 4 -Height 3 -LayerNames @('Layer 1') -LayerRgbaData @(, $rgba)
            $script:result = Get-AseDimension -Data $aseBytes
        }

        It 'should return correct width' {
            $script:result.Width | Should -Be 4
        }

        It 'should return correct height' {
            $script:result.Height | Should -Be 3
        }

        It 'should return color depth 32 for RGBA' {
            $script:result.ColorDepth | Should -Be 32
        }
    }

    Context 'when given a 16x16 .ase file' {
        BeforeAll {
            $rgba = [byte[]]::new(16 * 16 * 4)
            $aseBytes = New-MinimalAseFile -Width 16 -Height 16 -LayerNames @('BG') -LayerRgbaData @(, $rgba)
            $script:result = Get-AseDimension -Data $aseBytes
        }

        It 'should return width 16' {
            $script:result.Width | Should -Be 16
        }

        It 'should return height 16' {
            $script:result.Height | Should -Be 16
        }
    }

    Context 'when given invalid data' {
        It 'should throw on bad magic number' {
            $badData = [byte[]]::new(128)
            { Get-AseDimension -Data $badData } | Should -Throw
        }

        It 'should throw on data shorter than header' {
            $shortData = [byte[]]@(0xE0, 0xA5)
            { Get-AseDimension -Data $shortData } | Should -Throw
        }
    }
}
