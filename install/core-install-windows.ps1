<#
.SYNOPSIS
    VLC Extension - Core Windows Installer

.DESCRIPTION
    A modular installer script that can be used for any VLC extension.
    This script accepts extension-specific parameters and performs the installation.
    
    VLC uses the Roaming AppData directory (%APPDATA%) because user preferences
    and extensions should follow the user across different machines in a domain
    environment. This is standard Windows behavior for user-specific application
    data that isn't machine-dependent.

.PARAMETER ExtensionName
    Name of the main extension file (e.g., "shell_jobs.lua")

.PARAMETER ExtensionDisplayName
    Human-readable name (e.g., "VLC Shell Jobs")

.PARAMETER ModuleFiles
    Comma-separated list of module files to install

.PARAMETER IconFile
    Path to icon data file (relative to repo root, or empty for no icon)

.PARAMETER VlcExtensionsSubdir
    VLC extensions subdirectory (e.g., "extensions")

.PARAMETER VlcModulesSubdir
    VLC modules subdirectory (e.g., "modules\extensions")

.PARAMETER Force
    Overwrite existing files without prompting.

.EXAMPLE
    .\core-install-windows.ps1 `
        -ExtensionName "shell_jobs.lua" `
        -ExtensionDisplayName "VLC Shell Jobs" `
        -ModuleFiles "dynamic_dialog.lua,os_detect.lua,shell_execute.lua,shell_job.lua,shell_job_defs.lua,shell_job_state.lua,shell_operator_fileio.lua" `
        -IconFile "utils\icon\shell_jobs_32x32.lua" `
        -VlcExtensionsSubdir "extensions" `
        -VlcModulesSubdir "modules\extensions" `
        -Force
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ExtensionName,
    
    [Parameter(Mandatory=$true)]
    [string]$ExtensionDisplayName,
    
    [Parameter(Mandatory=$false)]
    [string]$ModuleFiles = "",
    
    [Parameter(Mandatory=$false)]
    [string]$IconFile = "",
    
    [Parameter(Mandatory=$true)]
    [string]$VlcExtensionsSubdir,
    
    [Parameter(Mandatory=$true)]
    [string]$VlcModulesSubdir,
    
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Get the script directory (where this script is located)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir = Split-Path -Parent $ScriptDir

# VLC directories on Windows
$VlcBaseDir = Join-Path $env:APPDATA "vlc\lua"
$ExtensionsDir = Join-Path $VlcBaseDir $VlcExtensionsSubdir
$ModulesDir = Join-Path $VlcBaseDir $VlcModulesSubdir

# Source directories
$SrcExtensionsDir = Join-Path $RepoDir "lua\extensions"
$SrcModulesDir = Join-Path $RepoDir "lua\modules\extensions"

# Icon file path (if provided)
if ($IconFile) {
    $IconDataFile = Join-Path $RepoDir $IconFile
} else {
    $IconDataFile = ""
}

Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "$ExtensionDisplayName - Windows Installer" -ForegroundColor Cyan
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

# Compare files by checksum (SHA256)
function Are-FilesIdentical {
    param(
        [string]$FileA,
        [string]$FileB
    )
    if (-not (Test-Path $FileA) -or -not (Test-Path $FileB)) { return $false }
    try {
        $hA = Get-FileHash -Path $FileA -Algorithm SHA256
        $hB = Get-FileHash -Path $FileB -Algorithm SHA256
        return $hA.Hash -eq $hB.Hash
    } catch {
        # if hashing fails, fall back to treat as different
        return $false
    }
}

# Copy file with optional overwrite confirmation (skip if identical)
function Copy-FileWithPrompt {
    param(
        [string]$Source,
        [string]$Destination,
        [switch]$Force
    )
    
    $FileName = Split-Path -Leaf $Source
    
    if ((Test-Path $Destination)) {
        if (Are-FilesIdentical -FileA $Source -FileB $Destination) {
            Write-Host "  Skipping: $FileName (identical)" -ForegroundColor Yellow
            return $false
        }
        if (-not $Force) {
            $response = Read-Host "File '$FileName' already exists at destination. Overwrite? (y/N)"
            if ($response -ne 'y' -and $response -ne 'Y') {
                Write-Host "  Skipping: $FileName" -ForegroundColor Yellow
                return $false
            }
        }
    }
    
    Copy-Item -Path $Source -Destination $Destination -Force
    Write-Host "  Copied: $FileName" -ForegroundColor Green
    return $true
}

# Ensure target directories exist
Write-Host "Creating VLC directories..." -ForegroundColor White
Ensure-Directory $ExtensionsDir
if ($ModuleFiles) {
    Ensure-Directory $ModulesDir
}

# Compute SHA256 hash for a string (used to compare generated content)
function Get-StringHashSHA256 {
    param([string]$Text)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $sha.ComputeHash($bytes)
    return ($hashBytes | ForEach-Object { $_.ToString("x2") }) -join ""
}

# Function to embed icon data into extension content
function Get-ExtensionContentWithIcon {
    param(
        [string]$ExtensionFile,
        [string]$IconDataFile
    )
    
    $ExtContent = Get-Content -Path $ExtensionFile -Raw
    
    if ($IconDataFile -and (Test-Path $IconDataFile)) {
        $IconContent = Get-Content -Path $IconDataFile -Raw
        
        # Add icon reference to descriptor and append icon data
        $ExtContent = $ExtContent -replace "(capabilities = \{\},)", "`$1`n        icon = png_data,"
        $ExtContent = $ExtContent + "`n`n-- Icon data (embedded during installation)`n" + $IconContent
        
        Write-Host "  Embedding icon data..." -ForegroundColor Green
    } else {
        if ($IconDataFile) {
            Write-Host "  WARNING: Icon data file not found, installing without icon" -ForegroundColor Yellow
        }
    }
    
    return $ExtContent
}

# Copy and patch main extension file with icon data
Write-Host ""
Write-Host "Installing extension file..." -ForegroundColor White
$ExtensionFile = Join-Path $SrcExtensionsDir $ExtensionName
if (Test-Path $ExtensionFile) {
    $DestFile = Join-Path $ExtensionsDir $ExtensionName
    
    # Generate the final content (with embedded icon) first
    $ExtContent = Get-ExtensionContentWithIcon -ExtensionFile $ExtensionFile -IconDataFile $IconDataFile
    $ExtContentHash = Get-StringHashSHA256 $ExtContent

    if (Test-Path $DestFile) {
        # Compare generated content hash to destination file hash
        try {
            $DestHash = (Get-FileHash -Path $DestFile -Algorithm SHA256 -ErrorAction Stop).Hash
        } catch {
            $DestHash = ""
        }

        if ($ExtContentHash -eq $DestHash) {
            Write-Host "  Skipping: $ExtensionName (identical)" -ForegroundColor Yellow
        } else {
            if (-not $Force) {
                $response = Read-Host "File '$ExtensionName' already exists at destination. Overwrite? (y/N)"
                if ($response -ne 'y' -and $response -ne 'Y') {
                    Write-Host "  Skipping: $ExtensionName" -ForegroundColor Yellow
                } else {
                    Set-Content -Path $DestFile -Value $ExtContent -NoNewline
                    Write-Host "  Installed: $ExtensionName" -ForegroundColor Green
                }
            } else {
                Set-Content -Path $DestFile -Value $ExtContent -NoNewline
                Write-Host "  Installed: $ExtensionName" -ForegroundColor Green
            }
        }
    } else {
        # Destination doesn't exist - write the generated content
        Set-Content -Path $DestFile -Value $ExtContent -NoNewline
        Write-Host "  Installed: $ExtensionName" -ForegroundColor Green
    }
} else {
    Write-Host "  ERROR: Extension file not found: $ExtensionFile" -ForegroundColor Red
    exit 1
}

# Copy module files if provided
if ($ModuleFiles) {
    Write-Host ""
    Write-Host "Installing module files..." -ForegroundColor White
    
    $ModuleFilesArray = $ModuleFiles -split ',' | ForEach-Object { $_.Trim() }
    
    foreach ($file in $ModuleFilesArray) {
        $SourceFile = Join-Path $SrcModulesDir $file
        if (Test-Path $SourceFile) {
            $DestFile = Join-Path $ModulesDir $file
            Copy-FileWithPrompt -Source $SourceFile -Destination $DestFile -Force:$Force
        } else {
            Write-Host "  WARNING: Module file not found: $file" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Files installed to:"
Write-Host "  Extensions: $ExtensionsDir"
if ($ModuleFiles) {
    Write-Host "  Modules:    $ModulesDir"
}
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Restart VLC"
Write-Host "  2. Go to View menu -> $ExtensionDisplayName"
Write-Host ""
