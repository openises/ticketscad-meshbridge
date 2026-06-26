@echo off
REM ===========================================================================
REM  Install the TicketsCAD Meshtastic mesh bridge as an autostarting Windows
REM  service via NSSM. Run as Administrator.
REM
REM  This script is the manual/standalone equivalent of what the Setup.exe
REM  installer does for you. Edit the four SET lines below for your install,
REM  then run this file (right-click -> Run as administrator).
REM
REM  Reversible: run uninstall-service.bat to remove the service.
REM ===========================================================================
setlocal

REM --- Folder this script lives in (the bridge install dir) ---
set DIR=%~dp0
if %DIR:~-1%==\ set DIR=%DIR:~0,-1%

REM --- EDIT THESE for your installation -------------------------------------
set PORT=COM3
set CAD_URL=https://your-ticketscad-server.example
set CAD_TOKEN=PASTE_YOUR_BEARER_TOKEN_HERE
REM -------------------------------------------------------------------------

set NSSM=%DIR%\nssm.exe
set PY=%DIR%\python312\python.exe
set SVC=TicketsCAD-MeshBridge

"%NSSM%" stop %SVC% 2>nul
"%NSSM%" remove %SVC% confirm 2>nul

REM Use the bare script name (resolved via AppDirectory below); NSSM drops the
REM quotes around an inline "install" arg, so a full path with a space breaks it.
"%NSSM%" install %SVC% "%PY%" bridge_v2.py --port %PORT% --protocol meshtastic --cad-url %CAD_URL% --cad-token %CAD_TOKEN%
"%NSSM%" set %SVC% AppDirectory "%DIR%"
"%NSSM%" set %SVC% DisplayName "TicketsCAD Meshtastic Mesh Bridge"
"%NSSM%" set %SVC% Description "Bridges a Meshtastic radio to a TicketsCAD instance via api/mesh.php bearer token."
"%NSSM%" set %SVC% Start SERVICE_AUTO_START
"%NSSM%" set %SVC% AppStdout "%DIR%\logs\bridge.log"
"%NSSM%" set %SVC% AppStderr "%DIR%\logs\bridge.log"
"%NSSM%" set %SVC% AppRotateFiles 1
"%NSSM%" set %SVC% AppRotateBytes 5242880
REM Restart-on-failure: wait 15s before throttling, restart after 10s
"%NSSM%" set %SVC% AppThrottle 15000
"%NSSM%" set %SVC% AppExit Default Restart
"%NSSM%" set %SVC% AppRestartDelay 10000
"%NSSM%" set %SVC% AppEnvironmentExtra PYTHONUNBUFFERED=1
"%NSSM%" start %SVC%
echo Service %SVC% installed and started.
endlocal
