function Publish-PX2PSArtifact {
    <#
    .SYNOPSIS
        Publishes a built PX2PS artifact to PSGallery and GitHub.
    .DESCRIPTION
        Publishes by path so PSGallery and the GitHub release contain the same
        package. Reads version and prerelease metadata from the built manifest.
    .PARAMETER Path
        Directory containing the built PX2PS module.
    .PARAMETER PublishToPSGallery
        Publishes the module to PSGallery.
    .PARAMETER PSGalleryAPIKey
        PSGallery API key.
    .PARAMETER PublishToGitHub
        Creates a GitHub release and uploads the module zip.
    .PARAMETER GitHubAPIKey
        GitHub token with permission to create releases.
    .PARAMETER GitHubSha
        Commit for the GitHub release.
    .EXAMPLE
        Publish-PX2PSArtifact -Path ./Artefacts/Unpacked/PX2PS -PublishToPSGallery -PSGalleryAPIKey $env:PSGALLERY_API_KEY
    .OUTPUTS
        None.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,
        [switch]$PublishToPSGallery,
        [string]$PSGalleryAPIKey,
        [switch]$PublishToGitHub,
        [string]$GitHubAPIKey,
        [string]$GitHubSha
    )

    $ErrorActionPreference = 'Stop'
    $modulePath = (Resolve-Path -LiteralPath $Path).ProviderPath
    $manifestPath = Join-Path $modulePath 'PX2PS.psd1'
    $null = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
    $manifest = Import-PowerShellDataFile -Path $manifestPath

    if ($PublishToPSGallery.IsPresent -and [string]::IsNullOrWhiteSpace($PSGalleryAPIKey)) {
        $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
            [System.ArgumentException]::new('PSGallery publishing requires a PSGallery API key.'),
            'MissingPSGalleryCredential',
            [System.Management.Automation.ErrorCategory]::InvalidArgument,
            $modulePath
        ))
    }
    if ($PublishToGitHub.IsPresent -and [string]::IsNullOrWhiteSpace($GitHubAPIKey)) {
        $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
            [System.ArgumentException]::new('GitHub publishing requires a GitHub token.'),
            'MissingGitHubCredential',
            [System.Management.Automation.ErrorCategory]::InvalidArgument,
            $modulePath
        ))
    }
    if ($PublishToGitHub.IsPresent -and [string]::IsNullOrWhiteSpace($GitHubSha)) {
        $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
            [System.ArgumentException]::new('GitHub publishing requires the release commit SHA.'),
            'MissingGitHubSha',
            [System.Management.Automation.ErrorCategory]::InvalidArgument,
            $modulePath
        ))
    }

    if ($PublishToPSGallery.IsPresent -and $PSCmdlet.ShouldProcess($modulePath, 'Publish to PSGallery')) {
        Publish-Module -Path $modulePath -NuGetApiKey $PSGalleryAPIKey -Repository PSGallery -Force -ErrorAction Stop
    }

    if ($PublishToGitHub.IsPresent -and $PSCmdlet.ShouldProcess('jakehildreth/PX2PS', 'Create release and upload module zip')) {
        $prerelease = $manifest.PrivateData.PSData.Prerelease
        $releaseTag = if ($prerelease) { "$($manifest.ModuleVersion)-$prerelease" } else { $manifest.ModuleVersion }
        $zipName = "PX2PS-$releaseTag.zip"
        $zipPath = Join-Path (Split-Path $modulePath -Parent) $zipName
        Compress-Archive -LiteralPath $modulePath -DestinationPath $zipPath -Force -ErrorAction Stop

        $releaseData = @{
            tag_name               = $releaseTag
            target_commitish       = $GitHubSha
            name                   = "PX2PS $releaseTag"
            body                   = "PX2PS release $releaseTag"
            draft                  = $false
            prerelease             = [bool]$prerelease
            generate_release_notes = $true
        } | ConvertTo-Json
        $headers = @{
            Authorization          = "Bearer $GitHubAPIKey"
            Accept                 = 'application/vnd.github+json'
            'X-GitHub-Api-Version' = '2022-11-28'
        }
        $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/jakehildreth/PX2PS/releases' -Method Post -Headers $headers -Body $releaseData -ContentType 'application/json' -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($release.upload_url)) {
            $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                [System.InvalidOperationException]::new('GitHub returned a release without an asset upload URL.'),
                'MissingGitHubUploadUrl',
                [System.Management.Automation.ErrorCategory]::InvalidResult,
                $release
            ))
        }
        $uploadUri = ($release.upload_url -replace '\{\?[^}]+\}', '') + "?name=$([uri]::EscapeDataString($zipName))"
        $null = Invoke-RestMethod -Uri $uploadUri -Method Post -Headers $headers -InFile $zipPath -ContentType 'application/zip' -ErrorAction Stop
    }
}
