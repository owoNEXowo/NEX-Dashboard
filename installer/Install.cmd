@echo off
setlocal DisableDelayedExpansion
title NEX Dashboard 2.7.0 - Setup
set "NEX_SETUP_FILE=%~dp0..\src\NexDashboard.ps1"
if not exist "%NEX_SETUP_FILE%" (
    echo Installer not found. Extract the entire ZIP archive first.
    pause
    exit /b 1
)
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -Command "$ErrorActionPreference='Stop'; try { $f=$env:NEX_SETUP_FILE; Write-Host 'NEX Dashboard 2.7.0 setup' -ForegroundColor Cyan; Write-Host 'Only continue if you trust the source of this installer.'; if ((Read-Host 'Install NEX Dashboard for your Windows account? [Y/N]') -notmatch '^(y|yes|j|ja)$') { exit 2 }; $p=Get-ExecutionPolicy; if ($p -eq 'AllSigned') { throw 'AllSigned policy requires a signed installer. Ask your administrator.' }; if ($p -eq 'Restricted' -or $p -eq 'Undefined') { $gp=Get-ExecutionPolicy -List; if (($gp | Where-Object { $_.Scope -in @('MachinePolicy','UserPolicy') -and $_.ExecutionPolicy -ne 'Undefined' })) { throw 'Script execution is managed by Group Policy. Ask your administrator.' }; Write-Host 'PowerShell must allow local scripts to load your NEX profile.'; if ((Read-Host 'Set RemoteSigned for your account only? [Y/N]') -notmatch '^(y|yes|j|ja)$') { exit 2 }; Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force; if ((Get-ExecutionPolicy) -in @('Restricted','Undefined','AllSigned')) { throw 'The active execution policy does not allow this installer.' } }; Unblock-File -LiteralPath $f; & $f -Install; exit 0 } catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }"
set "NEX_RESULT=%ERRORLEVEL%"
echo.
if "%NEX_RESULT%"=="0" (
    echo Setup finished. Follow any component setup messages above.
    echo Open NEX Dashboard from the Start menu or reopen PowerShell.
) else if "%NEX_RESULT%"=="2" (
    echo Setup cancelled.
) else (
    echo Setup failed. See the error above.
)
pause
exit /b %NEX_RESULT%
