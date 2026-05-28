@echo off
:: Force la console à utiliser l'encodage UTF-8 pour supporter les accents
chcp 65001 > nul

:: Lance le script PowerShell sans contourner la politique d'exécution globale.
:: RemoteSigned est appliqué uniquement au processus courant.
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0supportbox_vF.ps1"

pause
