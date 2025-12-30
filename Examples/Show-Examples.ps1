#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests all .px files and generates standalone scripts for each.

.DESCRIPTION
    This script tests all Pixquare .px files in the Examples folder by rendering them
    to the terminal, then generates standalone PowerShell scripts for each image in
    the Scripts subdirectory.

.EXAMPLE
    ./Generate-Scripts.ps1
#>

[CmdletBinding()]
param()

# Import the PX2PS module
$modulePath = Join-Path $PSScriptRoot '..' 'PX2PS.psd1'
Import-Module $modulePath -Force

Write-Host 'Testing all .px files in Examples folder...' -ForegroundColor Green
Get-ChildItem (Join-Path $PSScriptRoot '*.px') | ForEach-Object {
    Write-Host ("`nRendering: {0}" -f $_.Name) -ForegroundColor Cyan
    Convert-PX2PS $_.FullName
    Start-Sleep -Milliseconds 300
}

Write-Host "`n`nGenerating scripts..." -ForegroundColor Green

# Create Scripts folder
$scriptsFolder = Join-Path $PSScriptRoot 'Scripts'
if (-not (Test-Path $scriptsFolder)) {
    New-Item -ItemType Directory -Path $scriptsFolder | Out-Null
    Write-Host "Created folder: $scriptsFolder"
}

# Generate script for each .px file
Get-ChildItem (Join-Path $PSScriptRoot '*.px') | ForEach-Object {
    $outputPath = Join-Path $scriptsFolder "$($_.BaseName).ps1"
    Convert-PX2PS $_.FullName -OutputMode Script -OutputPath $outputPath
    Write-Host "  Generated: $outputPath"
}

Write-Host "`nDone! Scripts saved to: $scriptsFolder" -ForegroundColor Green
