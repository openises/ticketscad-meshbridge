@echo off
REM ===========================================================================
REM  Remove the TicketsCAD Meshtastic mesh bridge Windows service.
REM  Run as Administrator.
REM ===========================================================================
setlocal
set DIR=%~dp0
if %DIR:~-1%==\ set DIR=%DIR:~0,-1%
set NSSM=%DIR%\nssm.exe
set SVC=TicketsCAD-MeshBridge

"%NSSM%" stop %SVC%
"%NSSM%" remove %SVC% confirm
echo Service %SVC% removed.
endlocal
