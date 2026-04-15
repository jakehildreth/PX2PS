BeforeAll {
    . $PSScriptRoot/TestHelpers.ps1
    Import-Module $PSScriptRoot/../PX2PS.psm1 -Force
}

Describe 'Convert-PX2PS' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "PX2PS_Tests_$([guid]::NewGuid().ToString('N'))"
        New-Item -Path $script:tempDir -ItemType Directory -Force | Out-Null

        # generate a 2x2 test piskel file
        $rgba = [byte[]]@(
            255, 0, 0, 255,
            0, 255, 0, 255,
            0, 0, 255, 255,
            255, 255, 0, 255
        )
        $pngBytes = New-MinimalPng -Width 2 -Height 2 -RgbaData $rgba
        $piskelJson = New-MinimalPiskelJson -Name 'Test' -Width 2 -Height 2 -LayerNames @('Layer 1') -LayerPngBytes @(, $pngBytes)
        $script:piskelPath = Join-Path $script:tempDir 'test.piskel'
        Set-Content -Path $script:piskelPath -Value $piskelJson -Encoding UTF8

        # generate a 2x2 test .ase file
        $script:aseRgba = $rgba
        $aseBytes = New-MinimalAseFile -Width 2 -Height 2 -LayerNames @('Layer 1') -LayerRgbaData @(, $rgba)
        $script:asePath = Join-Path $script:tempDir 'test.ase'
        [System.IO.File]::WriteAllBytes($script:asePath, $aseBytes)

        $script:asepritePath = Join-Path $script:tempDir 'test.aseprite'
        [System.IO.File]::WriteAllBytes($script:asepritePath, $aseBytes)
    }

    AfterAll {
        if (Test-Path $script:tempDir) {
            Remove-Item -Path $script:tempDir -Recurse -Force
        }
    }

    Context 'when processing a .piskel file with PassThru' {
        BeforeAll {
            $script:result = Convert-PX2PS -Path $script:piskelPath -PassThru
        }

        It 'should return a PSCustomObject' {
            $script:result | Should -BeOfType [PSCustomObject]
        }

        It 'should return correct width' {
            $script:result.Width | Should -Be 2
        }

        It 'should return correct height' {
            $script:result.Height | Should -Be 2
        }

        It 'should return correct pixel count' {
            $script:result.Pixels.Count | Should -Be 4
        }

        It 'should have RGBA byte arrays per pixel' {
            $script:result.Pixels[0].Length | Should -Be 4
        }
    }

    Context 'when processing a .ase file with PassThru' -Tag 'Aseprite' {
        BeforeAll {
            $script:result = Convert-PX2PS -Path $script:asePath -PassThru
        }

        It 'should return a PSCustomObject' {
            $script:result | Should -BeOfType [PSCustomObject]
        }

        It 'should return correct width' {
            $script:result.Width | Should -Be 2
        }

        It 'should return correct height' {
            $script:result.Height | Should -Be 2
        }

        It 'should return correct pixel count' {
            $script:result.Pixels.Count | Should -Be 4
        }
    }

    Context 'when processing a .aseprite file with PassThru' -Tag 'Aseprite' {
        BeforeAll {
            $script:result = Convert-PX2PS -Path $script:asepritePath -PassThru
        }

        It 'should accept .aseprite extension' {
            $script:result | Should -Not -BeNullOrEmpty
        }

        It 'should return correct dimensions' {
            $script:result.Width | Should -Be 2
            $script:result.Height | Should -Be 2
        }
    }

    Context 'when scanning a directory with mixed formats' {
        BeforeAll {
            $script:mixedDir = Join-Path $script:tempDir 'mixed'
            New-Item -Path $script:mixedDir -ItemType Directory -Force | Out-Null
            Copy-Item -Path $script:piskelPath -Destination $script:mixedDir
            Copy-Item -Path $script:asePath -Destination $script:mixedDir
        }

        It 'should find both .piskel and .ase files' -Tag 'Aseprite' {
            $results = Convert-PX2PS -Path $script:mixedDir -PassThru
            $results.Count | Should -Be 2
        }
    }

    Context 'when given a nonexistent path' {
        It 'should write an error' {
            $result = Convert-PX2PS -Path '/nonexistent/file.px' -PassThru -ErrorVariable testError -ErrorAction SilentlyContinue
            $testError.Count | Should -BeGreaterThan 0
        }
    }
}
