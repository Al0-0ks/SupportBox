@echo off
:: Force la console à utiliser l'encodage UTF-8 pour supporter les accents
chcp 65001 > nul

powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0supportbox.ps1"