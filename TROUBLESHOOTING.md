# TicketsCAD Mesh Bridge — Troubleshooting

This guide is for when the bridge isn't working — the radio won't connect, the
service won't start, or the **Verify Bridge** tool reports a failure. It's
written in plain language; you don't need to know Python.

The single most useful thing you can do before anything else is **read the
bridge log** (see [Reading the bridge log](#reading-the-bridge-log) below). As
of v0.1.4 the log tells you, in one line, *why* a connection failed and what to
do about it.

Most connection problems come down to one of four things:

1. **Wrong COM port** — the radio is on a different COM number than configured.
2. **Another program is holding the port** — only one program can use a serial
   port at a time.
3. **A driver problem** — Windows doesn't have (or has the wrong) USB driver for
   the radio's USB-to-serial chip.
4. **Firmware vs. library mismatch** — a very old radio firmware can fail the
   handshake.

Each is covered below.

---

## Find the radio's COM port

Windows assigns each USB serial radio a **COM number** (COM3, COM7, COM11, …).
The bridge needs the right one. It can change after you move the radio to a
different USB port, change a driver, or plug in other USB-serial devices.

1. Press **Win + X** → **Device Manager**.
2. Expand **Ports (COM & LPT)**.
3. Plug the radio in (if it isn't already). A new entry appears — note its
   `COMx` number. The name usually hints at the chip:
   - **Silicon Labs CP210x USB to UART Bridge (COMx)** → a CP2102 radio.
   - **USB-SERIAL CH340 (COMx)** → a CH340 radio.

If the COM number differs from what the bridge is configured for, **re-run the
installer** and pick the correct port on the Bridge Configuration page.

> Tip: unplug the radio and watch which entry disappears — that's the one.

---

## One program per port

A serial (COM) port can only be held open by **one program at a time**. If the
bridge service is running and holding the port, then the Meshtastic app, the web
client, the web flasher, or a serial monitor (PuTTY, Arduino IDE) **cannot also
open it** — and vice versa.

Symptoms in the log:

```
[meshtastic COM7] port is in use or access denied — close any other app using it ...
```

Fixes:

- **Close the other program.** The usual culprits are the **Meshtastic desktop
  app**, **client.meshtastic.org** in a browser (it talks to the radio over the
  serial/Web Serial connection), the **web flasher**, or a **serial monitor**.
- **To flash new firmware**, you must stop the bridge first so it releases the
  port:
  ```powershell
  nssm stop TicketsCAD-MeshBridge
  # ... flash the radio with the Meshtastic flasher ...
  nssm start TicketsCAD-MeshBridge
  ```
  (`nssm.exe` lives in the install folder,
  `C:\Program Files\TicketsCAD-MeshBridge\`.)
- **"Permission denied" / "Access is denied" while flashing** usually means the
  **bridge still holds the port** — that's working as intended. Stop the service
  (above) and try again.

---

## Driver issues

The radio talks to Windows through a **USB-to-serial chip**. Two are common, and
they need *different* drivers:

| Chip | Driver | USB hardware ID |
|------|--------|-----------------|
| **CP2102 / CP210x** (Silicon Labs) | Silicon Labs CP210x VCP driver | `VID_10C4` |
| **CH340 / CH341** (WCH) | WCH CH340 driver | `VID_1A86` |

### Identify the chip

In **Device Manager**, the device name often says it outright
("Silicon Labs CP210x…", "USB-SERIAL CH340…"). To be certain, right-click the
device → **Properties** → **Details** tab → **Hardware Ids**. Look for the
`VID_xxxx` value and match it to the table above.

### "No driver" / device under "Other devices"

If the radio shows up under **Other devices** with a yellow warning triangle
(instead of under **Ports (COM & LPT)**), Windows has **no driver** for it:

- **CP2102 radios:** the installer can install the Silicon Labs CP210x driver —
  re-run the installer and tick the **CP210x driver** box (it's **off by
  default**, see the clone caveat below). Or use the **Install CP210x Driver**
  Start-menu shortcut.
- **CH340 radios:** download the CH340 driver from WCH and install it. The
  bundled installer does **not** ship the CH340 driver.

### Clone CP2102 caveat

Many low-cost boards use **clone CP2102 chips**. The **official Silicon Labs
driver may refuse to bind** to a clone, leaving the radio without a COM port even
after a "successful" driver install. This is exactly why the installer leaves the
**CP210x driver task OFF by default** — installing the official driver over a
working clone can *break* a port that was already fine.

If you installed the CP210x driver and the radio's COM port disappeared, remove
the driver you just added:

1. List recently-installed third-party drivers, newest first:
   ```powershell
   Get-ChildItem C:\Windows\INF\oem*.inf | Sort-Object LastWriteTime -Descending
   ```
   The most recently modified `oemNN.inf` is almost certainly the one you just
   installed.
2. Remove it (replace `NN` with the number from above):
   ```powershell
   pnputil /delete-driver oemNN.inf /uninstall /force
   ```
3. Unplug and replug the radio. Re-check **Device Manager → Ports (COM & LPT)**.

---

## Firmware ↔ library compatibility

The bridge bundles a specific version of the Meshtastic Python library
(**meshtastic-python**). A radio running **very old firmware** can fail to
complete the connection handshake with a newer library.

As of v0.1.4 **both versions are written to the log**, so you can compare them:

- At startup: `meshtastic-python library version 2.7.9`
- On a successful connect:
  `[meshtastic COM7] connected to <node name> (!849ad914) firmware 2.x.x`

If the radio never answers the handshake, the log says:

```
[meshtastic COM7] opened the port but the radio did not answer the handshake — ...
   ... If the firmware is very old, reflash current Meshtastic firmware
   (bundled meshtastic-python is v2.7.9).
```

**Fix:** reflash the radio with **current Meshtastic firmware** using the
[Meshtastic web flasher](https://flasher.meshtastic.org/) or the desktop app.
Remember to **stop the bridge first** so it releases the port (see
[One program per port](#one-program-per-port)). After flashing, give the radio
~15 seconds to boot before expecting it to connect.

---

## Reading the bridge log

The log is the primary diagnostic. The service writes it to:

```
C:\Program Files\TicketsCAD-MeshBridge\logs\bridge.log
```

(If you installed to a custom or per-user folder, the `logs\bridge.log` file is
under that install folder instead.)

To watch it live in PowerShell:

```powershell
Get-Content "C:\Program Files\TicketsCAD-MeshBridge\logs\bridge.log" -Tail 20 -Wait
```

### What the key lines mean

| Log line | Meaning |
|----------|---------|
| `meshtastic-python library version 2.7.9` | The bundled library version (logged once at startup). Compare with the radio firmware. |
| `connected to <name> (!hexid) firmware 2.x.x` | **Success.** The radio answered; you'll see its node name and firmware. |
| `port is in use or access denied …` | Another program holds the port. See [One program per port](#one-program-per-port). |
| `port not found — check the COM number …` | The configured COM port doesn't exist. See [Find the radio's COM port](#find-the-radios-com-port). |
| `opened the port but the radio did not answer the handshake …` | The port opened but no Meshtastic radio responded — wrong device, powered off, still booting, or firmware too old. |
| `no adapters started (attempt N) — … retrying in Ns` | Nothing connected yet; the bridge is **retrying on its own** with backoff (5s → up to 60s). It does **not** give up — fix the underlying cause and it will connect on the next attempt. |

> **The bridge self-recovers.** As of v0.1.4, when no radio connects the bridge
> waits and retries (5s, then 10s, 20s, …up to 60s) instead of exiting. So a
> radio that's rebooting, or a port that's momentarily busy, will connect on its
> own once the condition clears — you don't have to restart the service.

---

## The "Verify Bridge" tool

After install there's a **Verify Bridge** shortcut on the desktop and Start
menu. Double-click it; it runs three checks against the **same configuration the
service uses** and prints a plain-language result for each:

1. **Service running?** — Is the `TicketsCAD-MeshBridge` Windows service
   installed and in the RUNNING state? If STOPPED, start it from `services.msc`;
   if NOT installed, re-run the installer.
2. **COM port opens?** — Can the radio's port be opened? Note: if the service is
   running it already holds the port, so the verify tool will report
   *"in use by the service (expected when running)"* — that's a **good** result,
   not an error. A real failure ("could not be opened") means the radio is
   unplugged, the driver is missing, or the COM number is wrong.
3. **Server authenticates the token?** — It calls
   `<Server URL>/api/mesh.php?action=poll_outbox` with your Bearer token. HTTP
   200 = good. HTTP 401 = wrong/revoked token (get a fresh one from the admin
   UI). HTTP 404 = wrong Server URL or a TicketsCAD build without the mesh
   endpoint. A network error = the URL is unreachable from this PC.

If all three pass, the bridge is healthy. If one fails, the note under each
`[FAIL]` line tells you how to fix it.

---

## Service won't start

If the `TicketsCAD-MeshBridge` service won't start (or starts then stops):

1. **Read the log first** — `C:\Program Files\TicketsCAD-MeshBridge\logs\bridge.log`
   (see above). The classified connection line usually explains it directly.
2. **Check the service state** in `services.msc`, or:
   ```powershell
   sc query TicketsCAD-MeshBridge
   ```
3. **Path-with-spaces bug** — older builds had a service-start failure when the
   bridge was installed under a path containing spaces (e.g.
   `C:\Program Files\…`). **This is fixed as of v0.1.3.** If you're on an older
   build, update to the latest installer from the
   [Releases](../../releases) page.
4. If the service starts but immediately exits, the most common cause is that
   **no radio connected at all** — but as of v0.1.4 the bridge **retries instead
   of exiting**, so a clean exit now points to a genuine fatal error in the log
   rather than a missing radio.

---

If you're still stuck, grab the last ~40 lines of
`C:\Program Files\TicketsCAD-MeshBridge\logs\bridge.log` and a screenshot of the
**Verify Bridge** window, and send them to your TicketsCAD administrator.
