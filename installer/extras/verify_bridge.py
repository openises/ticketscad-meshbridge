#!/usr/bin/env python3
"""
TicketsCAD Mesh Bridge -- Verify helper.

A self-diagnosis tool for non-technical responders. Run it from the
Start-menu / desktop shortcut after install. It checks, in order:

  1. Is the Windows service installed and RUNNING?
  2. Does the chosen COM port open (radio plugged in + CP210x driver)?
  3. Does the Server URL + Token authenticate? (poll_outbox 200 vs 401)

It reads the same config the service uses (bridge_config.ini next to
this script) so what it tests is exactly what the service runs.

No arguments needed -- just double-click the shortcut. Exit code 0 if
everything is healthy, non-zero otherwise (for scripting).
"""
import configparser
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CONFIG = os.path.join(HERE, "bridge_config.ini")
SERVICE_NAME = "TicketsCAD-MeshBridge"

GREEN = "[ OK ]"
RED = "[FAIL]"
WARN = "[WARN]"


def hr():
    print("-" * 60)


def read_config():
    cp = configparser.ConfigParser()
    if not os.path.exists(CONFIG):
        return None
    cp.read(CONFIG)
    if "bridge" not in cp:
        return None
    b = cp["bridge"]
    return {
        "port": b.get("port", "").strip(),
        "protocol": b.get("protocol", "meshtastic").strip(),
        "cad_url": b.get("cad_url", "").strip().rstrip("/"),
        "cad_token": b.get("cad_token", "").strip(),
    }


def check_service():
    """Query the Windows Service Control Manager for the service state."""
    try:
        import subprocess
        out = subprocess.run(
            ["sc", "query", SERVICE_NAME],
            capture_output=True, text=True, timeout=10
        )
        if "RUNNING" in out.stdout:
            print(f"{GREEN} Service '{SERVICE_NAME}' is installed and RUNNING.")
            return True
        if "STOPPED" in out.stdout:
            print(f"{RED} Service '{SERVICE_NAME}' is installed but STOPPED.")
            print("       Fix: open Services (services.msc), right-click")
            print(f"       '{SERVICE_NAME}', choose Start. Or reboot.")
            return False
        if "1060" in out.stdout or "does not exist" in out.stdout.lower():
            print(f"{RED} Service '{SERVICE_NAME}' is NOT installed.")
            print("       Fix: re-run the TicketsCAD Mesh Bridge installer.")
            return False
        print(f"{WARN} Could not determine service state:")
        print("       " + out.stdout.strip().replace("\n", "\n       "))
        return False
    except Exception as e:
        print(f"{WARN} Could not query the service: {e}")
        return False


def check_com(port):
    if not port:
        print(f"{WARN} No COM port configured -- skipping radio check.")
        return False
    try:
        import serial
    except Exception as e:
        print(f"{WARN} pyserial not available ({e}) -- skipping radio check.")
        return False
    # NOTE: if the service is RUNNING it already holds the port open, so a
    # second open here will fail with "Access is denied" -- that is actually
    # a GOOD sign (the radio exists and the service has it). We treat that
    # specific error as success.
    try:
        s = serial.Serial(port, timeout=1)
        s.close()
        print(f"{GREEN} COM port {port} opened (radio present; service not "
              f"holding it).")
        return True
    except Exception as e:
        msg = str(e).lower()
        if "access is denied" in msg or "permission" in msg:
            print(f"{GREEN} COM port {port} exists and is in use by the "
                  f"service (expected when running).")
            return True
        if "could not open port" in msg or "filenotfound" in msg \
                or "cannot find" in msg:
            print(f"{RED} COM port {port} could NOT be opened.")
            print("       Likely causes:")
            print("       - The radio is unplugged. Plug in the USB cable.")
            print("       - The Silicon Labs CP210x driver is not installed.")
            print("         Run 'Install CP210x Driver' from the Start menu.")
            print(f"       - {port} is the wrong port. Open Device Manager >")
            print("         Ports (COM & LPT) to see the correct COMx number,")
            print("         then re-run the installer to change it.")
            return False
        print(f"{RED} COM port {port} error: {e}")
        return False


def check_auth(cad_url, cad_token):
    if not cad_url or not cad_token:
        print(f"{WARN} No Server URL / Token configured -- skipping auth "
              f"check (bridge is in dry-run mode).")
        return False
    try:
        import requests
    except Exception as e:
        print(f"{WARN} requests not available ({e}) -- skipping auth check.")
        return False
    url = f"{cad_url}/api/mesh.php?action=poll_outbox"
    try:
        r = requests.get(
            url,
            headers={"Authorization": f"Bearer {cad_token}"},
            timeout=15,
        )
    except Exception as e:
        print(f"{RED} Could not reach the server at {cad_url}.")
        print(f"       Network error: {e}")
        print("       Fix: check the Server URL is correct and this PC has")
        print("       internet / LAN access to the TicketsCAD server.")
        return False

    if r.status_code == 200:
        print(f"{GREEN} Server {cad_url} authenticated the token (HTTP 200).")
        return True
    if r.status_code == 401:
        print(f"{RED} Server rejected the token (HTTP 401 Unauthorized).")
        print("       Fix: the Bearer Token is wrong or was revoked. Get a")
        print("       fresh token from the TicketsCAD admin UI and re-run the")
        print("       installer to update it.")
        return False
    if r.status_code == 404:
        print(f"{RED} Server returned 404 -- /api/mesh.php not found at "
              f"{cad_url}.")
        print("       Fix: the Server URL is probably wrong (missing path, or")
        print("       this build of TicketsCAD lacks the mesh endpoint).")
        return False
    print(f"{WARN} Server returned HTTP {r.status_code}.")
    print("       " + r.text[:200].replace("\n", " "))
    return False


def main():
    print()
    print("=" * 60)
    print("  TicketsCAD Mesh Bridge -- Verify")
    print("=" * 60)

    cfg = read_config()
    if cfg is None:
        print(f"{RED} No configuration found at:")
        print(f"       {CONFIG}")
        print("       The bridge may not be installed. Re-run the installer.")
        print()
        input("Press Enter to close...")
        return 2

    print(f"Server URL : {cfg['cad_url'] or '(not set -- dry-run)'}")
    print(f"COM port   : {cfg['port'] or '(not set)'}")
    print(f"Protocol   : {cfg['protocol']}")
    tok = cfg["cad_token"]
    print(f"Token      : {'*' * 8 + tok[-4:] if len(tok) > 4 else '(not set)'}")
    hr()

    r1 = check_service()
    hr()
    r2 = check_com(cfg["port"])
    hr()
    r3 = check_auth(cfg["cad_url"], cfg["cad_token"])
    hr()

    healthy = r1 and r2 and r3
    if healthy:
        print(f"{GREEN} ALL CHECKS PASSED -- the bridge is healthy.")
    else:
        print(f"{WARN} One or more checks failed. See the notes above each")
        print("       [FAIL] line for how to fix it. If stuck, send a photo")
        print("       of this window to your TicketsCAD administrator.")
    print()
    input("Press Enter to close...")
    return 0 if healthy else 1


if __name__ == "__main__":
    sys.exit(main())
