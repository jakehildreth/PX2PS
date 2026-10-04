<#
.SYNOPSIS
    Builds PX2PS with PSPublishModule 2.0.27 and optionally publishes it.
.DESCRIPTION
    Builds an isolated copy of the source with CalVer metadata. Keeps the
    split module layout and publishes the unpacked artifact, not an installed module.
.PARAMETER CalVer
    Module version in yyyy.M.dHHmm format. Defaults to the current time.
.PARAMETER Prerelease
    Optional prerelease label, such as pre.
.PARAMETER OutputPath
    Build output directory. Defaults to Artefacts in the repository.
.PARAMETER PublishToPSGallery
    Publishes the built module to PSGallery.
.PARAMETER PSGalleryAPIKey
    PSGallery API key. Defaults to the PSGALLERY_API_KEY environment variable.
.PARAMETER PublishToGitHub
    Creates a GitHub release and uploads the built module as a zip.
.PARAMETER GitHubAPIKey
    GitHub token. Defaults to the GITHUB_TOKEN environment variable.
.PARAMETER GitHubSha
    Commit for the GitHub release. Defaults to GITHUB_SHA.
.EXAMPLE
    ./Build/Build-Module.ps1 -CalVer 2026.10.41234 -Prerelease pre
.EXAMPLE
    ./Build/Build-Module.ps1 -PublishToPSGallery -PublishToGitHub
.OUTPUTS
    None.
#>
[CmdletBinding()]
param(
    [ValidatePattern('^\d{4}\.\d{1,2}\.\d{5,6}$')]
    [string]$CalVer = (Get-Date -Format 'yyyy.M.dHHmm'),

    [ValidatePattern('^[A-Za-z0-9]+$')]
    [string]$Prerelease,

    [ValidateNotNullOrEmpty()]
    [string]$OutputPath = (Join-Path $PSScriptRoot '../Artefacts'),

    [switch]$PublishToPSGallery,
    [string]$PSGalleryAPIKey = $env:PSGALLERY_API_KEY,
    [switch]$PublishToGitHub,
    [string]$GitHubAPIKey = $env:GITHUB_TOKEN,
    [string]$GitHubSha = $env:GITHUB_SHA
)

$ErrorActionPreference = 'Stop'
Import-Module -Name PSPublishModule -RequiredVersion 2.0.27 -ErrorAction Stop

$repositoryRoot = Split-Path $PSScriptRoot -Parent
$outputDirectory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
$workDirectory = Join-Path $outputDirectory "Work/$([guid]::NewGuid().ToString('N'))"
$sourceDirectory = Join-Path $workDirectory 'Source/PX2PS'
$artifactDirectory = Join-Path $workDirectory 'Unpacked'
$modulePath = Join-Path $outputDirectory 'Unpacked/PX2PS'
New-Item -ItemType Directory -Path $sourceDirectory -Force | Out-Null
foreach ($item in @('PX2PS.psd1', 'PX2PS.psm1', 'Public', 'Private', 'LICENSE', 'README.md', 'PX2PS.png')) {
    Copy-Item -LiteralPath (Join-Path $repositoryRoot $item) -Destination $sourceDirectory -Recurse -Force
}

$sourceManifest = Import-PowerShellDataFile -Path (Join-Path $sourceDirectory 'PX2PS.psd1')
$manifestSettings = @{
    ModuleVersion     = $CalVer
    GUID              = $sourceManifest.GUID
    Author            = $sourceManifest.Author
    CompanyName       = $sourceManifest.CompanyName
    Copyright         = $sourceManifest.Copyright
    Description       = $sourceManifest.Description
    PowerShellVersion = $sourceManifest.PowerShellVersion
    Tags              = $sourceManifest.PrivateData.PSData.Tags
    LicenseUri        = $sourceManifest.PrivateData.PSData.LicenseUri
    ProjectUri        = $sourceManifest.PrivateData.PSData.ProjectUri
    FunctionsToExport = $sourceManifest.FunctionsToExport
    AliasesToExport   = @('px2ps')
    CmdletsToExport   = @()
}
if ($Prerelease) {
    $manifestSettings['Prerelease'] = $Prerelease
}

$previousLocation = Get-Location
$temporaryDirectory = Join-Path $workDirectory 'Temporary'
New-Item -ItemType Directory -Path $temporaryDirectory -Force | Out-Null
$previousTemporaryPaths = @{}
foreach ($name in @('TMPDIR', 'TMP', 'TEMP')) {
    $previousTemporaryPaths[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    [Environment]::SetEnvironmentVariable($name, $temporaryDirectory, 'Process')
}
try {
    $buildResult = @(PSPublishModule\Build-Module -ModuleName 'PX2PS' -Path (Split-Path $sourceDirectory -Parent) -IncludeRoot @('*.psm1', '*.psd1', 'LICENSE', 'README.md', 'PX2PS.png') {
        # PSPublishModule otherwise replaces the user's installed module.
        @{
            Type = 'Information'
            Configuration = @{
                DirectoryModules = (Join-Path $workDirectory 'Modules')
                DirectoryModulesCore = (Join-Path $workDirectory 'Modules')
            }
        }
        New-ConfigurationManifest @manifestSettings
        New-ConfigurationBuild -Enable -MergeModuleOnBuild:$false -SignModule:$false
        New-ConfigurationImportModule -ImportSelf:$false -ImportRequiredModules:$false
        New-ConfigurationArtefact -Type Unpacked -Enable -Path $artifactDirectory
    })
    if ($buildResult -contains $false) {
        throw 'PSPublishModule reported a failed PX2PS build.'
    }

    $builtModulePath = Join-Path $artifactDirectory 'PX2PS'
    $builtManifestPath = Join-Path $builtModulePath 'PX2PS.psd1'
    Update-ModuleManifest -Path $builtManifestPath -ReleaseNotes $sourceManifest.PrivateData.PSData.ReleaseNotes
    $null = Test-ModuleManifest -Path $builtManifestPath -ErrorAction Stop
    $builtManifest = Import-PowerShellDataFile -Path $builtManifestPath
    if ($builtManifest.ModuleVersion -ne $CalVer -or [string]$builtManifest.PrivateData.PSData.Prerelease -ne [string]$Prerelease) {
        throw 'The built artifact does not match the requested version and prerelease metadata.'
    }

    if (Test-Path -LiteralPath $modulePath) {
        if (-not (Test-Path -LiteralPath (Join-Path $modulePath 'PX2PS.psd1'))) {
            throw "Cannot replace an output directory without a PX2PS manifest: $modulePath"
        }
        Remove-Item -LiteralPath $modulePath -Recurse -Force
    }
    New-Item -ItemType Directory -Path (Split-Path $modulePath -Parent) -Force | Out-Null
    Copy-Item -LiteralPath $builtModulePath -Destination $modulePath -Recurse
} finally {
    Set-Location -LiteralPath $previousLocation.Path
    foreach ($name in $previousTemporaryPaths.Keys) {
        [Environment]::SetEnvironmentVariable($name, $previousTemporaryPaths[$name], 'Process')
    }
    Remove-Item -LiteralPath $workDirectory -Recurse -Force
}

if ($PublishToPSGallery.IsPresent -or $PublishToGitHub.IsPresent) {
    . (Join-Path $PSScriptRoot 'Publish-PX2PSArtifact.ps1')
    Publish-PX2PSArtifact -Path $modulePath -PublishToPSGallery:$PublishToPSGallery -PSGalleryAPIKey $PSGalleryAPIKey -PublishToGitHub:$PublishToGitHub -GitHubAPIKey $GitHubAPIKey -GitHubSha $GitHubSha
}
