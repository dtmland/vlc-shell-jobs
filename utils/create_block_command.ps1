# create_block_command.ps1
# PowerShell script that generates the block_runner.bat file for troubleshooting
# This avoids complex batch escaping by writing batch from PowerShell

param(
    [Parameter(Mandatory=$true)]
    [string]$Command,
    
    [Parameter(Mandatory=$true)]
    [string]$CommandDir,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputBatFile,
    
    [Parameter(Mandatory=$true)]
    [string]$SuccessDesignator,
    
    [Parameter(Mandatory=$true)]
    [string]$FailureDesignator
)

# Build the PowerShell one-liner that mostly matches executor.lua's blocking_command
# Using '&&' and '||' directly. Using single quotes for PS string values to avoid escaping hell.
$innerScript = @"
`$psi = New-Object System.Diagnostics.ProcessStartInfo;
`$psi.FileName = 'cmd.exe';
`$psi.Arguments = '/c cd $CommandDir && $Command && echo $SuccessDesignator || echo $FailureDesignator';
`$psi.RedirectStandardOutput = `$true;
`$psi.RedirectStandardError = `$true;
`$psi.UseShellExecute = `$false;
`$psi.CreateNoWindow = `$true;
`$process = [System.Diagnostics.Process]::Start(`$psi);
`$process.WaitForExit();
`$stdout = `$process.StandardOutput.ReadToEnd();
`$stderr = `$process.StandardError.ReadToEnd();
`$exitCode = `$process.ExitCode;
Write-Host '';
Write-Host '============================================================================';
Write-Host 'RESULT';
Write-Host '============================================================================';
if (`$stdout -match '$SuccessDesignator') { Write-Host 'Status: SUCCESS' } else { Write-Host 'Status: FAILURE' };
Write-Host 'Exit Code:' `$exitCode;
Write-Host '';
Write-Host '============================================================================';
Write-Host 'STDOUT';
Write-Host '============================================================================';
`$stdoutClean = `$stdout -replace '$SuccessDesignator', '' -replace '$FailureDesignator', '';
Write-Host `$stdoutClean;
Write-Host '';
Write-Host '============================================================================';
Write-Host 'STDERR';
Write-Host '============================================================================';
Write-Host `$stderr;
Write-Host ''
"@

# Collapse newlines to spaces
$flatScript = $innerScript -replace "`r`n", " " -replace "`n", " "
$psOneLiner = "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command ""$flatScript"""

# Write the batch file
$batContent = @"
@echo off
REM Generated batch file for block_command execution
REM This file can be run manually for troubleshooting
REM Command: $Command
REM Working Directory: $CommandDir

$psOneLiner
"@

# Write to file
Set-Content -Path $OutputBatFile -Value $batContent -Encoding ASCII

# Return the path for confirmation
Write-Output $OutputBatFile
