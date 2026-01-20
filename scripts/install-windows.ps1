<#
.SYNOPSIS
    Installs VLC Shell Jobs extension on Windows.

.DESCRIPTION
    Copies the VLC Shell Jobs extension files to the correct VLC directories.
    
    VLC uses the Roaming AppData directory (%APPDATA%) because user preferences
    and extensions should follow the user across different machines in a domain
    environment. This is standard Windows behavior for user-specific application
    data that isn't machine-dependent.

.PARAMETER Force
    Overwrite existing files without prompting.

.EXAMPLE
    .\install-windows.ps1
    
.EXAMPLE
    .\install-windows.ps1 -Force
#>

param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Get the script directory (where this script is located)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir = Split-Path -Parent $ScriptDir

# VLC directories on Windows
$VlcBaseDir = Join-Path $env:APPDATA "vlc\lua"
$ExtensionsDir = Join-Path $VlcBaseDir "extensions"
$ModulesDir = Join-Path $VlcBaseDir "modules\extensions"

# Source directories
$SrcExtensionsDir = Join-Path $RepoDir "lua\extensions"
$SrcModulesDir = Join-Path $RepoDir "lua\modules\extensions"

Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "VLC Shell Jobs - Windows Installer" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Source repository: $RepoDir"
Write-Host "VLC base directory: $VlcBaseDir"
Write-Host ""

# Create directories if they don't exist
function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        Write-Host "Creating directory: $Path"
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

# Copy file with optional overwrite confirmation
function Copy-FileWithPrompt {
    param(
        [string]$Source,
        [string]$Destination,
        [switch]$Force
    )
    
    $FileName = Split-Path -Leaf $Source
    
    if ((Test-Path $Destination) -and -not $Force) {
        $response = Read-Host "File '$FileName' already exists at destination. Overwrite? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-Host "  Skipping: $FileName" -ForegroundColor Yellow
            return $false
        }
    }
    
    Copy-Item -Path $Source -Destination $Destination -Force
    Write-Host "  Copied: $FileName" -ForegroundColor Green
    return $true
}

# Ensure target directories exist
Write-Host "Creating VLC directories..." -ForegroundColor White
Ensure-Directory $ExtensionsDir
Ensure-Directory $ModulesDir

# Copy main extension file
Write-Host ""
Write-Host "Installing extension file..." -ForegroundColor White
$ExtensionFile = Join-Path $SrcExtensionsDir "shell_jobs.lua"
if (Test-Path $ExtensionFile) {
    $DestFile = Join-Path $ExtensionsDir "shell_jobs.lua"
    Copy-FileWithPrompt -Source $ExtensionFile -Destination $DestFile -Force:$Force
} else {
    Write-Host "  ERROR: Extension file not found: $ExtensionFile" -ForegroundColor Red
    exit 1
}

# Copy module files (exclude tests directory)
Write-Host ""
Write-Host "Installing module files..." -ForegroundColor White
$ModuleFiles = @(
    "dynamic_dialog.lua",
    "shell_execute.lua",
    "shell_job.lua",
    "shell_job_defs.lua",
    "shell_job_state.lua",
    "shell_operator_fileio.lua"
)

foreach ($file in $ModuleFiles) {
    $SourceFile = Join-Path $SrcModulesDir $file
    if (Test-Path $SourceFile) {
        $DestFile = Join-Path $ModulesDir $file
        Copy-FileWithPrompt -Source $SourceFile -Destination $DestFile -Force:$Force
    } else {
        Write-Host "  WARNING: Module file not found: $file" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Files installed to:"
Write-Host "  Extensions: $ExtensionsDir"
Write-Host "  Modules:    $ModulesDir"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Restart VLC"
Write-Host "  2. Go to View menu -> Shell Jobs"
Write-Host ""
