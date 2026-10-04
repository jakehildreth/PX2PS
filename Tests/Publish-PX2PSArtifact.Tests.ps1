BeforeAll {
    . (Join-Path $PSScriptRoot '../Build/Publish-PX2PSArtifact.ps1')
}

Describe 'PX2PS artifact publishing' {
    BeforeEach {
        $casePath = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $artifactPath = Join-Path $casePath 'PX2PS'
        New-Item -ItemType Directory -Path $artifactPath -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $artifactPath 'PX2PS.psm1') -Value ''
        New-ModuleManifest -Path (Join-Path $artifactPath 'PX2PS.psd1') -RootModule 'PX2PS.psm1' -ModuleVersion '2026.10.41234' -Prerelease 'pre'
        Mock Publish-Module {}
        Mock Invoke-RestMethod {
            @{ upload_url = 'https://uploads.github.com/repos/jakehildreth/PX2PS/releases/1/assets{?name,label}' }
        }
    }

    It 'publishes the built path and creates a matching prerelease zip on the requested commit' {
        Publish-PX2PSArtifact -Path $artifactPath -PublishToPSGallery -PSGalleryAPIKey 'test-gallery-key' -PublishToGitHub -GitHubAPIKey 'test-github-token' -GitHubSha 'test-commit'
        Should -Invoke Publish-Module -Times 1 -Exactly -ParameterFilter {
            $Path -eq $artifactPath -and $Repository -eq 'PSGallery' -and $NuGetApiKey -eq 'test-gallery-key'
        }
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://api.github.com/repos/jakehildreth/PX2PS/releases' -and
            ($Body | ConvertFrom-Json).tag_name -eq '2026.10.41234-pre' -and
            ($Body | ConvertFrom-Json).target_commitish -eq 'test-commit' -and
            ($Body | ConvertFrom-Json).prerelease -eq $true
        }
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://uploads.github.com/repos/jakehildreth/PX2PS/releases/1/assets?name=PX2PS-2026.10.41234-pre.zip' -and
            $ContentType -eq 'application/zip' -and $InFile -like '*PX2PS-2026.10.41234-pre.zip'
        }
        $archive = [System.IO.Compression.ZipFile]::OpenRead((Join-Path $casePath 'PX2PS-2026.10.41234-pre.zip'))
        try {
            $archive.Entries.FullName | Should -Contain 'PX2PS/PX2PS.psd1'
            $archive.Entries.FullName | Should -Contain 'PX2PS/PX2PS.psm1'
        } finally {
            $archive.Dispose()
        }
    }

    It 'marks a stable GitHub release as non-prerelease' {
        New-ModuleManifest -Path (Join-Path $artifactPath 'PX2PS.psd1') -RootModule 'PX2PS.psm1' -ModuleVersion '2026.10.41234'
        Publish-PX2PSArtifact -Path $artifactPath -PublishToGitHub -GitHubAPIKey 'test-github-token' -GitHubSha 'test-commit'
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://api.github.com/repos/jakehildreth/PX2PS/releases' -and
            ($Body | ConvertFrom-Json).tag_name -eq '2026.10.41234' -and
            ($Body | ConvertFrom-Json).prerelease -eq $false
        }
        Should -Invoke Publish-Module -Times 0
    }

    It 'rejects missing PSGallery credentials before publishing anywhere' {
        { Publish-PX2PSArtifact -Path $artifactPath -PublishToPSGallery -PublishToGitHub -GitHubAPIKey 'test-github-token' -GitHubSha 'test-commit' } |
            Should -Throw '*PSGallery publishing requires*'
        Should -Invoke Publish-Module -Times 0
        Should -Invoke Invoke-RestMethod -Times 0
    }

    It 'rejects missing GitHub credentials before publishing to PSGallery' {
        { Publish-PX2PSArtifact -Path $artifactPath -PublishToPSGallery -PSGalleryAPIKey 'test-gallery-key' -PublishToGitHub -GitHubSha 'test-commit' } |
            Should -Throw '*GitHub publishing requires a GitHub token*'
        Should -Invoke Publish-Module -Times 0
        Should -Invoke Invoke-RestMethod -Times 0
    }

    It 'requires an explicit GitHub release commit' {
        { Publish-PX2PSArtifact -Path $artifactPath -PublishToGitHub -GitHubAPIKey 'test-github-token' } |
            Should -Throw '*release commit SHA*'
        Should -Invoke Invoke-RestMethod -Times 0
    }

    It 'supports WhatIf without publishing or creating a zip' {
        Publish-PX2PSArtifact -Path $artifactPath -PublishToPSGallery -PSGalleryAPIKey 'test-gallery-key' -PublishToGitHub -GitHubAPIKey 'test-github-token' -GitHubSha 'test-commit' -WhatIf
        Should -Invoke Publish-Module -Times 0
        Should -Invoke Invoke-RestMethod -Times 0
        (Join-Path $casePath 'PX2PS-2026.10.41234-pre.zip') | Should -Not -Exist
    }

    It 'stops before creating a GitHub release if PSGallery publishing fails' {
        Mock Publish-Module { throw 'PSGallery is unavailable.' }
        { Publish-PX2PSArtifact -Path $artifactPath -PublishToPSGallery -PSGalleryAPIKey 'test-gallery-key' -PublishToGitHub -GitHubAPIKey 'test-github-token' -GitHubSha 'test-commit' } |
            Should -Throw '*PSGallery is unavailable*'
        Should -Invoke Invoke-RestMethod -Times 0
    }

    It 'reports an invalid GitHub release response instead of claiming success' {
        Mock Invoke-RestMethod { @{} }
        { Publish-PX2PSArtifact -Path $artifactPath -PublishToGitHub -GitHubAPIKey 'test-github-token' -GitHubSha 'test-commit' } |
            Should -Throw '*without an asset upload URL*'
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly
    }

    It 'reports a failed GitHub asset upload' {
        Mock Invoke-RestMethod { throw 'Asset upload failed.' } -ParameterFilter { $ContentType -eq 'application/zip' }
        { Publish-PX2PSArtifact -Path $artifactPath -PublishToGitHub -GitHubAPIKey 'test-github-token' -GitHubSha 'test-commit' } |
            Should -Throw '*Asset upload failed*'
    }
}
