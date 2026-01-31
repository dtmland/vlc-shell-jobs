<#
.SYNOPSIS
    VLC Shell Jobs - Windows Setup

.DESCRIPTION
    Wrapper script that calls the core installer with shell-jobs specific parameters.
    Copies the VLC Shell Jobs extension files to the correct VLC directories.
    Embeds the icon data into the installed shell_jobs.lua file.
    
    VLC uses the Roaming AppData directory (%APPDATA%) because user preferences
    and extensions should follow the user across different machines in a domain
    environment. This is standard Windows behavior for user-specific application
    data that isn't machine-dependent.

.PARAMETER Force
    Overwrite existing files without prompting.

.EXAMPLE
    .\setup-windows.ps1
    
.EXAMPLE
    .\setup-windows.ps1 -Force
#>

param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Get the script directory (where this script is located)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Extension-specific configuration
$ExtensionName = "shell_jobs.lua"
$ExtensionDisplayName = "VLC Shell Jobs"
$ModuleFiles = "dynamic_dialog.lua,os_detect.lua,shell_execute.lua,shell_job.lua,shell_job_defs.lua,shell_job_state.lua,shell_operator_fileio.lua,xspf_writer.lua,path_utils.lua"
$IconFile = "utils\icon\shell_jobs_32x32.lua"
$VlcExtensionsSubdir = "extensions"
$VlcModulesSubdir = "modules\extensions"

# Call the core installer with the extension-specific parameters
& "$ScriptDir\core\core-install-windows.ps1" `
    -ExtensionName $ExtensionName `
    -ExtensionDisplayName $ExtensionDisplayName `
    -ModuleFiles $ModuleFiles `
    -IconFile $IconFile `
    -VlcExtensionsSubdir $VlcExtensionsSubdir `
    -VlcModulesSubdir $VlcModulesSubdir `
    -Force:$Force
