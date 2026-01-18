@echo off
REM ============================================================================
REM job_cleanup.bat
REM
REM Purpose: Clean up old job directories from the jobrunner folder
REM
REM Usage: job_cleanup.bat [max_age_seconds]
REM   max_age_seconds - optional, maximum age in seconds before cleanup (default: 86400 = 1 day)
REM
REM Example:
REM   job_cleanup.bat                  (cleanup jobs older than 1 day)
REM   job_cleanup.bat 3600             (cleanup jobs older than 1 hour)
REM   job_cleanup.bat 604800           (cleanup jobs older than 1 week)
REM ============================================================================

setlocal EnableDelayedExpansion

REM Default max age is 1 day (86400 seconds)
set "MAX_AGE_SECONDS=%~1"
if "%MAX_AGE_SECONDS%"=="" set "MAX_AGE_SECONDS=86400"

set "JOBRUNNER_DIR=%APPDATA%\jobrunner"

echo ============================================================================
echo CLEANUP OLD JOBS
echo ============================================================================
echo Jobrunner Directory: %JOBRUNNER_DIR%
echo Max Age (seconds): %MAX_AGE_SECONDS%
echo ============================================================================

if not exist "%JOBRUNNER_DIR%" (
    echo INFO: Jobrunner directory does not exist. Nothing to clean up.
    exit /b 0
)

REM Use PowerShell to find and remove old directories
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$maxAgeSeconds = %MAX_AGE_SECONDS%;" ^
    "$jobrunnerDir = '%JOBRUNNER_DIR%';" ^
    "$currentTime = Get-Date;" ^
    "$cleanedCount = 0;" ^
    "if (Test-Path $jobrunnerDir) {" ^
    "    Get-ChildItem -Path $jobrunnerDir -Directory | ForEach-Object {" ^
    "        $stdoutFile = Join-Path $_.FullName 'stdout.txt';" ^
    "        $jobStatusFile = Join-Path $_.FullName 'job_status.txt';" ^
    "        $checkFile = if (Test-Path $stdoutFile) { $stdoutFile } elseif (Test-Path $jobStatusFile) { $jobStatusFile } else { $null };" ^
    "        if ($checkFile) {" ^
    "            $lastWriteTime = (Get-Item $checkFile).LastWriteTime;" ^
    "            $ageSeconds = ($currentTime - $lastWriteTime).TotalSeconds;" ^
    "            if ($ageSeconds -gt $maxAgeSeconds) {" ^
    "                Write-Host ('Removing old job directory (age: ' + [math]::Round($ageSeconds) + 's): ' + $_.Name);" ^
    "                Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue;" ^
    "                $cleanedCount++;" ^
    "            } else {" ^
    "                Write-Host ('Keeping recent job directory (age: ' + [math]::Round($ageSeconds) + 's): ' + $_.Name);" ^
    "            }" ^
    "        } else {" ^
    "            Write-Host ('Could not determine age for: ' + $_.Name);" ^
    "        }" ^
    "    }" ^
    "}" ^
    "Write-Host '';" ^
    "Write-Host ('Cleanup complete. Removed ' + $cleanedCount + ' old job directories.');"

echo.
echo ============================================================================
endlocal
exit /b 0
