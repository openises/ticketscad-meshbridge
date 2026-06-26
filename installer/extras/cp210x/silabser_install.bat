@echo off
REM Installs the Silicon Labs CP210x USB-to-UART (VCP) driver silently.
REM Uses the in-box Windows pnputil tool. Requires admin (the installer
REM already runs elevated when it calls this).
setlocal
set DIR=%~dp0
echo Installing Silicon Labs CP210x driver from %DIR%silabser.inf ...
pnputil /add-driver "%DIR%silabser.inf" /install
echo Done (exit code %errorlevel%).
endlocal
exit /b 0
