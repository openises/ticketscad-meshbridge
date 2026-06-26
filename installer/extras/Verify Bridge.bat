@echo off
REM Launches the TicketsCAD Mesh Bridge verify helper using the bundled
REM Python. Double-click this (or the Start-menu shortcut) to self-diagnose.
setlocal
set DIR=%~dp0
"%DIR%python312\python.exe" "%DIR%verify_bridge.py"
endlocal
