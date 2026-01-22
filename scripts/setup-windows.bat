@echo off
REM VLC Shell Jobs - Windows Setup (Batch Wrapper)
REM This script launches the PowerShell setup script with proper execution policy

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-windows.ps1" %*
