BeforeAll {
    . $PSScriptRoot/TestHelpers.ps1
    . $PSScriptRoot/../Private/ConvertFrom-PngData.ps1
}

Describe 'ConvertFrom-PngData' {
    Context 'when given a valid 2x2 RGBA PNG' {
        BeforeAll {
            # 2x2 image: red, green, blue, transparent
            $script:testRgba = [byte[]]@(
                255, 0, 0, 255,      # (0,0) red
                0, 255, 0, 255,      # (1,0) green
                0, 0, 255, 255,      # (0,1) blue
                0, 0, 0, 0           # (1,1) transparent
            )
            $pngBytes = New-MinimalPng -Width 2 -Height 2 -RgbaData $script:testRgba
            $script:result = ConvertFrom-PngData -Data $pngBytes
        }

        It 'should return a non-null result' {
            $script:result | Should -Not -BeNullOrEmpty
        }

        It 'should return correct width' {
            $script:result.Width | Should -Be 2
        }

        It 'should return correct height' {
            $script:result.Height | Should -Be 2
        }

        It 'should return RGBA data of correct length' {
            $script:result.RgbaData.Length | Should -Be 16
        }

        It 'should decode pixel (0,0) as red' {
            $script:result.RgbaData[0] | Should -Be 255
            $script:result.RgbaData[1] | Should -Be 0
            $script:result.RgbaData[2] | Should -Be 0
            $script:result.RgbaData[3] | Should -Be 255
        }

        It 'should decode pixel (1,0) as green' {
            $script:result.RgbaData[4] | Should -Be 0
            $script:result.RgbaData[5] | Should -Be 255
            $script:result.RgbaData[6] | Should -Be 0
            $script:result.RgbaData[7] | Should -Be 255
        }

        It 'should decode pixel (0,1) as blue' {
            $script:result.RgbaData[8] | Should -Be 0
            $script:result.RgbaData[9] | Should -Be 0
            $script:result.RgbaData[10] | Should -Be 255
            $script:result.RgbaData[11] | Should -Be 255
        }

        It 'should decode pixel (1,1) as transparent' {
            $script:result.RgbaData[12] | Should -Be 0
            $script:result.RgbaData[13] | Should -Be 0
            $script:result.RgbaData[14] | Should -Be 0
            $script:result.RgbaData[15] | Should -Be 0
        }
    }

    Context 'when given a 1x1 solid white PNG' {
        BeforeAll {
            $rgba = [byte[]]@(255, 255, 255, 255)
            $pngBytes = New-MinimalPng -Width 1 -Height 1 -RgbaData $rgba
            $script:result = ConvertFrom-PngData -Data $pngBytes
        }

        It 'should return 1x1 dimensions' {
            $script:result.Width | Should -Be 1
            $script:result.Height | Should -Be 1
        }

        It 'should return 4 bytes of RGBA data' {
            $script:result.RgbaData.Length | Should -Be 4
        }

        It 'should decode as white with full opacity' {
            $script:result.RgbaData[0] | Should -Be 255
            $script:result.RgbaData[1] | Should -Be 255
            $script:result.RgbaData[2] | Should -Be 255
            $script:result.RgbaData[3] | Should -Be 255
        }
    }

    Context 'when given invalid data' {
        It 'should throw on invalid PNG signature' {
            $badData = [byte[]]@(0, 0, 0, 0, 0, 0, 0, 0)
            { ConvertFrom-PngData -Data $badData } | Should -Throw '*Invalid PNG signature*'
        }
    }
}
