BeforeAll {
    . $PSScriptRoot/TestHelpers.ps1
    . $PSScriptRoot/../Private/Expand-ZlibData.ps1
    . $PSScriptRoot/../Private/Read-AseLayerData.ps1
}

Describe 'Read-AseLayerData' -Tag 'Aseprite' {
    Context 'when given a single-layer 2x2 RGBA .ase file' {
        BeforeAll {
            $script:testRgba = [byte[]]@(
                255, 0, 0, 255,      # red
                0, 255, 0, 255,      # green
                0, 0, 255, 255,      # blue
                128, 128, 128, 255   # gray
            )
            $aseBytes = New-MinimalAseFile -Width 2 -Height 2 -LayerNames @('Layer 1') -LayerRgbaData @(, $script:testRgba)
            $script:layers = Read-AseLayerData -Data $aseBytes -Width 2 -Height 2
        }

        It 'should return one layer' {
            $script:layers.Count | Should -Be 1
        }

        It 'should return correct byte count' {
            $script:layers[0].Length | Should -Be 16
        }

        It 'should decode first pixel as red' {
            $script:layers[0][0] | Should -Be 255
            $script:layers[0][1] | Should -Be 0
            $script:layers[0][2] | Should -Be 0
            $script:layers[0][3] | Should -Be 255
        }

        It 'should decode second pixel as green' {
            $script:layers[0][4] | Should -Be 0
            $script:layers[0][5] | Should -Be 255
            $script:layers[0][6] | Should -Be 0
            $script:layers[0][7] | Should -Be 255
        }

        It 'should decode third pixel as blue' {
            $script:layers[0][8] | Should -Be 0
            $script:layers[0][9] | Should -Be 0
            $script:layers[0][10] | Should -Be 255
            $script:layers[0][11] | Should -Be 255
        }

        It 'should decode fourth pixel as gray' {
            $script:layers[0][12] | Should -Be 128
            $script:layers[0][13] | Should -Be 128
            $script:layers[0][14] | Should -Be 128
            $script:layers[0][15] | Should -Be 255
        }
    }

    Context 'when given a multi-layer .ase file' {
        BeforeAll {
            $layer1 = [byte[]]@(
                255, 0, 0, 255,
                0, 0, 0, 0,
                0, 0, 0, 0,
                0, 0, 0, 0
            )
            $layer2 = [byte[]]@(
                0, 0, 0, 0,
                0, 255, 0, 255,
                0, 0, 0, 0,
                0, 0, 0, 0
            )
            $aseBytes = New-MinimalAseFile -Width 2 -Height 2 -LayerNames @('Bottom', 'Top') -LayerRgbaData @($layer1, $layer2)
            $script:layers = Read-AseLayerData -Data $aseBytes -Width 2 -Height 2
        }

        It 'should return two layers' {
            $script:layers.Count | Should -Be 2
        }

        It 'should preserve layer order' {
            # first layer has red at (0,0)
            $script:layers[0][0] | Should -Be 255
            $script:layers[0][1] | Should -Be 0
            # second layer has green at (1,0)
            $script:layers[1][4] | Should -Be 0
            $script:layers[1][5] | Should -Be 255
        }
    }

    Context 'when the file has no valid cel data' {
        It 'should return an empty array' {
            # header only, no frame data with cels
            $minimalData = [byte[]]::new(128)
            [Array]::Copy([BitConverter]::GetBytes([uint32]128), 0, $minimalData, 0, 4)
            [Array]::Copy([BitConverter]::GetBytes([uint16]0xA5E0), 0, $minimalData, 4, 2)
            [Array]::Copy([BitConverter]::GetBytes([uint16]0), 0, $minimalData, 6, 2)  # 0 frames
            $layers = Read-AseLayerData -Data $minimalData -Width 2 -Height 2
            $layers.Count | Should -Be 0
        }
    }
}
