@{
    RootModule = 'PX2PS.psm1'
    ModuleVersion = '2025.12.29'
    GUID = 'a5b9e8c7-d4f1-4a2b-9c3d-1e2f3a4b5c6d'
    Author = 'Jake Hildreth'
    CompanyName = 'jakehildreth'
    Copyright = '(c) 2025 Jake Hildreth. All rights reserved.'
    Description = 'Converts Pixquare .px files to terminal pixel graphics using ANSI True Color'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Convert-PX2PS')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @('px2ps')
    PrivateData = @{
        PSData = @{
            Tags = @('PixelArt', 'Terminal', 'ANSI', 'Graphics', 'Pixquare')
            LicenseUri = 'https://github.com/jakehildreth/PX2PS/blob/main/LICENSE'
            ProjectUri = 'https://github.com/jakehildreth/PX2PS'
            ReleaseNotes = 'Added OutputMode parameter for ScriptBlock and Script file generation'
        }
    }
}
