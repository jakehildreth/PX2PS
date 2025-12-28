function Convert-PX2PS {
    [alias('px2ps')] 
    <#
    .SYNOPSIS
        Converts Pixquare .px files to terminal pixel graphics.
    
    .DESCRIPTION
        Reads .px pixel art files and renders them in the PowerShell terminal
        using the lower half block character (▄) with ANSI True Color.
        Each line of output represents two rows of pixels: top pixel uses
        background color, bottom pixel uses foreground color.
        
        Supports both single-layer and multi-layer .px files with automatic
        layer compositing and transparency handling.
    
    .PARAMETER Path
        Path to a .px file or directory containing .px files.
        If a directory is provided, all .px files in that directory are processed.
    
    .PARAMETER PassThru
        If specified, returns PSCustomObject with file information instead of
        rendering directly to terminal.
    
    .EXAMPLE
        ConvertFrom-PxFile -Path "Stepper 4.px"
        
        Renders the specified .px file to the terminal.
    
    .EXAMPLE
        ConvertFrom-PxFile -Path "C:\PixelArt"
        
        Renders all .px files found in the specified directory.
    
    .EXAMPLE
        Get-ChildItem -Path "." -Filter "*.px" | ConvertFrom-PxFile
        
        Processes .px files from pipeline input.
    
    .OUTPUTS
        None by default. With -PassThru, outputs PSCustomObject with:
        - FilePath: Full path to the .px file
        - Width: Image width in pixels
        - Height: Image height in pixels
        - Pixels: Array of RGBA pixel data
    
    .NOTES
        Requires PowerShell 5.1 or later.
        On Windows PowerShell 5.1, automatically enables Virtual Terminal Processing.
    #>
    [CmdletBinding()]
    [OutputType([void], [PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [ValidateNotNullOrEmpty()]
        [string]$Path,
        
        [Parameter()]
        [switch]$PassThru
    )
    
    begin {
        Write-Verbose 'Starting .px file processing'
    }
    
    process {
        if (-not (Test-Path -Path $Path)) {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.IO.FileNotFoundException]::new("Path not found: $Path"),
                'PathNotFound',
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $Path
            )
            $PSCmdlet.WriteError($errorRecord)
            return
        }
        
        $pathItem = Get-Item -Path $Path
        
        if ($pathItem.PSIsContainer) {
            $pxFiles = Get-ChildItem -Path $Path -Filter '*.px' -File
            
            if ($pxFiles.Count -eq 0) {
                Write-Warning "No .px files found in $Path"
                return
            }
            
            Write-Host "Found $($pxFiles.Count) .px file(s)" -ForegroundColor Green
            
            foreach ($file in $pxFiles) {
                ConvertFrom-PxFile -Path $file.FullName -PassThru:$PassThru
            }
            return
        }
        
        if ($pathItem.Extension -ne '.px') {
            Write-Warning "File does not appear to be a .px file: $Path"
        }
        
        try {
            $data = [System.IO.File]::ReadAllBytes($pathItem.FullName)
            $dimensions = Get-PxDimension -Data $data
            $width = $dimensions.Width
            $height = $dimensions.Height
            
            if ($width -le 0 -or $height -le 0) {
                Write-Warning "Invalid dimensions in $($pathItem.Name)"
                return
            }
            
            Write-Verbose "Processing $($pathItem.Name): ${width}x${height}"
            
            $layers = Read-PxLayerData -Data $data -Width $width -Height $height
            
            if ($layers.Count -eq 0) {
                Write-Warning "Could not extract layer data from $($pathItem.Name)"
                return
            }
            
            $pixels = Merge-PxLayer -Layers $layers -Width $width -Height $height
            
            if ($PassThru.IsPresent) {
                Write-Output ([PSCustomObject]@{
                    FilePath = $pathItem.FullName
                    Width = $width
                    Height = $height
                    Pixels = $pixels
                })
            } else {
                Write-PxTerminal -Width $width -Height $height -Pixels $pixels
            }
        } catch {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                $_.Exception,
                'PxFileProcessingFailed',
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                $Path
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }
    
    end {
        Write-Verbose 'Completed .px file processing'
    }
}
