@echo off
chcp 65001 > nul

:: On force le mode Bypass pour que le technicien n'ait jamais l'erreur rouge de sécurité
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0SupportBoxEN.ps1"

pause