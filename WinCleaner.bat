@echo off
rem Opens the WinCleaner window as administrator / WinCleaner penceresini yonetici olarak acar
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0WinCleaner.GUI.ps1"
