@echo off
REM VLC Shell Jobs - Windows Installer (Batch Wrapper)
REM This script launches the PowerShell installer with proper execution policy

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-windows.ps1" %*
