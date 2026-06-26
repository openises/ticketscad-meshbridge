TicketsCAD Meshtastic Mesh Bridge
=================================

WHAT THIS IS
------------
This installs a small background "bridge" that listens to your Meshtastic
radio over its USB cable and forwards what it hears to your TicketsCAD
server. It runs automatically as a Windows service -- you do not need to
keep a window open, and it restarts itself if it ever crashes or after a
reboot.

WHAT YOU NEED BEFORE INSTALLING
-------------------------------
  1. Your TicketsCAD Server URL  (your administrator gives you this,
     e.g. https://training.ticketscad.com)
  2. A Bearer Token              (also from your administrator, from the
     TicketsCAD admin UI)
  3. The Meshtastic radio plugged into a USB port on this PC.

HOW TO INSTALL
--------------
  1. Double-click "TicketsCAD-MeshBridge-Setup.exe".
  2. If Windows asks "Do you want to allow this app to make changes?",
     click YES. (Installing a service needs administrator rights -- this
     is normal.)
  3. On the "USB driver" page, leave the CP210x driver box CHECKED unless
     your administrator told you the driver is already installed.
  4. On the "Bridge Configuration" page, enter your Server URL, paste your
     Bearer Token, and pick the COM port for the radio.
       - Not sure which COM port? Open Device Manager > Ports (COM & LPT)
         with the radio plugged in. The "Silicon Labs CP210x" device shows
         the COMx number to use.
  5. Click Install. When it finishes, the bridge is already running.

HOW TO CHECK IT IS WORKING
--------------------------
Use the "Verify TicketsCAD Bridge" shortcut (on your desktop and in the
Start menu). It checks three things and tells you, in plain language, how
to fix anything that is wrong:
   - Is the service running?
   - Does the radio's COM port open?
   - Does the server accept your token?

CHANGING SETTINGS LATER
-----------------------
Re-run the installer to change the URL, token, or COM port. To stop or
start the service manually, open Services (press Windows+R, type
services.msc, Enter), find "TicketsCAD Meshtastic Mesh Bridge", and use
the Start/Stop buttons.

UNINSTALLING
------------
Use "Add or Remove Programs" in Windows Settings, or the
"Uninstall TicketsCAD Mesh Bridge" Start-menu shortcut. This stops and
removes the service and deletes the files.

LOGS
----
If you need to send your administrator a log, it is in:
   <install folder>\logs\bridge.log
(The default install folder is
   C:\Program Files\TicketsCAD-MeshBridge )
