BeforeAll {
    . $PSScriptRoot/TestHelpers.ps1
    . $PSScriptRoot/../Private/ConvertFrom-PngData.ps1
    . $PSScriptRoot/../Private/Read-PiskelLayerData.ps1
}

Describe 'Read-PiskelLayerData' {
    Context 'when given a single-layer piskel file' {
        BeforeAll {
            $rgba = [byte[]]@(
                255, 0, 0, 255,
                0, 255, 0, 255,
                0, 0, 255, 255,
                128, 128, 128, 255
            )
            $pngBytes = New-MinimalPng -Width 2 -Height 2 -RgbaData $rgba
            $json = New-MinimalPiskelJson -Name 'Test' -Width 2 -Height 2 -LayerNames @('Layer 1') -LayerPngBytes @(, $pngBytes)
            $piskelData = $json | ConvertFrom-Json
            $script:layers = Read-PiskelLayerData -PiskelData $piskelData -Width 2 -Height 2
        }

        It 'should return one layer' {
            $script:layers.Count | Should -Be 1
        }

        It 'should return correct byte count per layer' {
            $script:layers[0].Length | Should -Be 16
        }

        It 'should decode first pixel as red' {
            $script:layers[0][0] | Should -Be 255
            $script:layers[0][1] | Should -Be 0
            $script:layers[0][2] | Should -Be 0
            $script:layers[0][3] | Should -Be 255
        }
    }

    Context 'when given a multi-layer piskel file' {
        BeforeAll {
            $layer1Rgba = [byte[]]@(
                255, 0, 0, 255,
                0, 0, 0, 0,
                0, 0, 0, 0,
                0, 0, 0, 0
            )
            $layer2Rgba = [byte[]]@(
                0, 0, 0, 0,
                0, 255, 0, 255,
                0, 0, 0, 0,
                0, 0, 0, 0
            )
            $png1 = New-MinimalPng -Width 2 -Height 2 -RgbaData $layer1Rgba
            $png2 = New-MinimalPng -Width 2 -Height 2 -RgbaData $layer2Rgba
            $json = New-MinimalPiskelJson -Name 'Test' -Width 2 -Height 2 -LayerNames @('Bottom', 'Top') -LayerPngBytes @($png1, $png2)
            $piskelData = $json | ConvertFrom-Json
            $script:layers = Read-PiskelLayerData -PiskelData $piskelData -Width 2 -Height 2
        }

        It 'should return two layers' {
            $script:layers.Count | Should -Be 2
        }

        It 'should preserve layer order from JSON' {
            # first layer has red at (0,0)
            $script:layers[0][0] | Should -Be 255
            $script:layers[0][1] | Should -Be 0
            # second layer has green at (1,0)
            $script:layers[1][4] | Should -Be 0
            $script:layers[1][5] | Should -Be 255
        }
    }

    Context 'when a layer has mismatched dimensions' {
        BeforeAll {
            # create a 1x1 PNG but claim the piskel is 2x2
            $smallRgba = [byte[]]@(255, 0, 0, 255)
            $smallPng = New-MinimalPng -Width 1 -Height 1 -RgbaData $smallRgba
            $json = New-MinimalPiskelJson -Name 'Test' -Width 2 -Height 2 -LayerNames @('Mismatched') -LayerPngBytes @(, $smallPng)
            $piskelData = $json | ConvertFrom-Json
            $script:layers = Read-PiskelLayerData -PiskelData $piskelData -Width 2 -Height 2
        }

        It 'should skip the mismatched layer' {
            $script:layers.Count | Should -Be 0
        }
    }
}
