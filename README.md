# TicketsCAD Meshtastic / MeshCore Mesh Bridge

A small Windows background service that connects a [Meshtastic](https://meshtastic.org/)
(or MeshCore) radio over its USB serial port to a [TicketsCAD](https://github.com/openises)
server. Messages heard on the mesh are forwarded into TicketsCAD, and outbound
dispatch traffic is sent back out over the radio, via the server's
`api/mesh.php` bearer-token endpoint.

It is packaged as a single `Setup.exe` so a non-technical responder can install
it without touching Python, pip, or the command line. The installer bundles a
self-contained Python 3.12 runtime (with all dependencies pre-installed), the
bridge script, the [NSSM](https://nssm.cc/) service wrapper, and the Silicon
Labs CP210x USB driver. On install it registers an autostarting Windows service
and (optionally) installs the radio's USB driver.

## Download the installer

Grab the latest `TicketsCAD-MeshBridge-Setup-v<version>.exe` from the
[**Releases**](../../releases) page. The filename includes the version so you
can keep multiple versions side by side. That is the file end users run — they
do not need this source tree.

> **Windows SmartScreen:** the installer is not code-signed, so on first run
> Windows may show *"Windows protected your PC"*. Click **More info → Run
> anyway** to proceed. The installer is built in public CI from this repository
> (see the **Actions** tab), so you can verify exactly how it was produced.

## Install flow (what the end user does)

1. Double-click the `TicketsCAD-MeshBridge-Setup-v<version>.exe` you downloaded.
   If Windows shows *"Windows protected your PC"*, click **More info → Run anyway**.
2. Approve the Windows UAC prompt (installing a service needs administrator
   rights — this is expected).
3. On the **USB driver** page, the CP210x driver box is **unchecked by default**.
   Only tick it if the radio shows **no COM port** in Device Manager — the
   official Silicon Labs driver can replace a working one and may not support
   clone CP2102 chips found in some low-cost boards.
4. On the **Bridge Configuration** page, enter:
   - **Server URL** — e.g. `https://your-ticketscad-server.example`
   - **Bearer Token** — issued from the TicketsCAD admin UI
   - **COM port** — pick the detected port for the radio (or type it)
5. Click Install. When it finishes, the bridge is already running as the
   `TicketsCAD-MeshBridge` Windows service (Automatic start, restart-on-failure).

After install, a **Verify Bridge** shortcut (desktop + Start menu) runs a
plain-language self-diagnosis: is the service running, does the COM port open,
and does the server accept the token.

To change the URL, token, or COM port later, re-run the installer.

## Build it yourself

You do not need to build the installer to use it — download it from Releases.
But if you want to build from source:

### In CI (the normal path)

Push a version tag and GitHub Actions builds and publishes the installer:

```
git tag -a v0.1.0 -m "v0.1.0"
git push origin v0.1.0
```

The [`build-installer`](.github/workflows/build-installer.yml) workflow
(runs on `windows-latest`):

1. Silently installs Python 3.12.10 into `build\python312`.
2. `pip install -r installer/requirements-frozen.txt` into that runtime.
3. Assembles `installer\payload\` = the Python bundle + `bridge_v2.py` + `nssm.exe`.
4. Installs Inno Setup and compiles `installer\TicketsCAD-MeshBridge.iss`
   (version injected from the tag via `ISCC /DAppVersion=...`).
5. Publishes a GitHub Release with `TicketsCAD-MeshBridge-Setup.exe` attached.

It can also be run manually via **workflow_dispatch** from the Actions tab.

### Locally (for development)

Requirements: Windows, [Inno Setup 6](https://jrsoftware.org/isinfo.php) on
`PATH`, and Python 3.12.

```
REM 1. Build the bundled Python runtime
py -3.12 -m venv build\python312-tmp   REM or install a fresh 3.12 into build\python312
build\python312\python.exe -m pip install -r installer\requirements-frozen.txt

REM 2. Assemble the payload the .iss expects
mkdir installer\payload
xcopy /E /I build\python312 installer\payload\python312
copy bridge_v2.py installer\payload\
copy nssm.exe       installer\payload\

REM 3. Compile (version optional; defaults to 0.0.0-dev if omitted)
ISCC /DAppVersion=0.1.0 installer\TicketsCAD-MeshBridge.iss
REM -> installer\output\TicketsCAD-MeshBridge-Setup.exe
```

## Repository layout

| Path | What it is |
|------|------------|
| `bridge_v2.py` | The bridge itself. **This repo is the canonical home of `bridge_v2.py` going forward.** |
| `verify_bridge.py` | Post-install self-diagnosis tool (also under `installer/extras/`). |
| `install-service.bat` / `uninstall-service.bat` | Manual NSSM service install/remove (the Setup.exe does this for you). Edit the `SET` lines before running as Administrator. |
| `nssm.exe` | The [NSSM](https://nssm.cc/) service wrapper (64-bit), committed as a stable redistributable. |
| `installer/TicketsCAD-MeshBridge.iss` | Inno Setup script defining the wizard, files, service registration, and driver task. |
| `installer/requirements-frozen.txt` | Exact pinned Python dependencies bundled into the installer. |
| `installer/extras/` | Verify tool, end-user README, and the Silicon Labs CP210x USB driver package. |
| `.github/workflows/build-installer.yml` | The CI build + Release workflow. |

Build artifacts — the `python312/` runtime bundle, `installer/payload/`, and the
built `*-Setup.exe` — are generated by CI and are git-ignored.

## Configuration

The bridge takes its settings from command-line arguments (`--port`,
`--protocol`, `--cad-url`, `--cad-token`), which the installer wires into the
NSSM service definition and mirrors into `bridge_config.ini` for the verify
tool. **No tokens or server URLs are stored in this repository** — they are
entered at install time.

## License / project

Part of the [Open ISES](https://github.com/openises) TicketsCAD project —
open-source computer-aided dispatch for volunteer fire, ARES/RACES, CERT, EMS,
and campus-security teams.
