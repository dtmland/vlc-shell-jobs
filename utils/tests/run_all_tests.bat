@echo off
REM ============================================================================
REM run_all_tests.bat
REM
REM Master test runner that executes all test suites for the batch scripts.
REM This file runs each individual test BAT file and reports overall results.
REM
REM Usage: run_all_tests.bat
REM ============================================================================

setlocal EnableDelayedExpansion

echo ============================================================================
echo MASTER TEST RUNNER
echo ============================================================================
echo.
echo Running all test suites for batch scripts...
echo.

set "SCRIPT_DIR=%~dp0"
set "PASSED_COUNT=0"
set "FAILED_COUNT=0"
set "TOTAL_COUNT=0"

REM Track which tests passed/failed
set "FAILED_TESTS="

REM ============================================================================
REM Run test_job_async_run.bat
REM ============================================================================
echo.
echo ############################################################################
echo RUNNING: test_job_async_run.bat
echo ############################################################################
echo.

call "%SCRIPT_DIR%test_job_async_run.bat"
if %ERRORLEVEL% EQU 0 (
    set /a PASSED_COUNT+=1
    echo [SUITE PASSED] test_job_async_run.bat
) else (
    set /a FAILED_COUNT+=1
    set "FAILED_TESTS=!FAILED_TESTS! test_job_async_run.bat"
    echo [SUITE FAILED] test_job_async_run.bat
)
set /a TOTAL_COUNT+=1

REM ============================================================================
REM Run test_job_async_check.bat
REM ============================================================================
echo.
echo ############################################################################
echo RUNNING: test_job_async_check.bat
echo ############################################################################
echo.

call "%SCRIPT_DIR%test_job_async_check.bat"
if %ERRORLEVEL% EQU 0 (
    set /a PASSED_COUNT+=1
    echo [SUITE PASSED] test_job_async_check.bat
) else (
    set /a FAILED_COUNT+=1
    set "FAILED_TESTS=!FAILED_TESTS! test_job_async_check.bat"
    echo [SUITE FAILED] test_job_async_check.bat
)
set /a TOTAL_COUNT+=1

REM ============================================================================
REM Run test_job_async_stop.bat
REM ============================================================================
echo.
echo ############################################################################
echo RUNNING: test_job_async_stop.bat
echo ############################################################################
echo.

call "%SCRIPT_DIR%test_job_async_stop.bat"
if %ERRORLEVEL% EQU 0 (
    set /a PASSED_COUNT+=1
    echo [SUITE PASSED] test_job_async_stop.bat
) else (
    set /a FAILED_COUNT+=1
    set "FAILED_TESTS=!FAILED_TESTS! test_job_async_stop.bat"
    echo [SUITE FAILED] test_job_async_stop.bat
)
set /a TOTAL_COUNT+=1

REM ============================================================================
REM Run test_job.bat
REM ============================================================================
echo.
echo ############################################################################
echo RUNNING: test_job.bat
echo ############################################################################
echo.

call "%SCRIPT_DIR%test_job.bat"
if %ERRORLEVEL% EQU 0 (
    set /a PASSED_COUNT+=1
    echo [SUITE PASSED] test_job.bat
) else (
    set /a FAILED_COUNT+=1
    set "FAILED_TESTS=!FAILED_TESTS! test_job.bat"
    echo [SUITE FAILED] test_job.bat
)
set /a TOTAL_COUNT+=1

REM ============================================================================
REM Summary
REM ============================================================================
echo.
echo ############################################################################
echo MASTER TEST SUMMARY
echo ############################################################################
echo.
echo Test Suites Passed: %PASSED_COUNT% / %TOTAL_COUNT%
echo Test Suites Failed: %FAILED_COUNT% / %TOTAL_COUNT%
echo.

if %FAILED_COUNT% GTR 0 (
    echo Failed test suites:%FAILED_TESTS%
    echo.
    echo ============================================================================
    echo RESULT: SOME TEST SUITES FAILED
    echo ============================================================================
    endlocal
    exit /b 1
) else (
    echo ============================================================================
    echo RESULT: ALL TEST SUITES PASSED
    echo ============================================================================
    endlocal
    exit /b 0
)