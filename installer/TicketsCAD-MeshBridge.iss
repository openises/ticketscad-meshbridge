; ============================================================================
;  TicketsCAD Meshtastic Mesh Bridge -- Windows Installer (Inno Setup 6)
;
;  One setup.exe for a non-technical responder. The wizard collects:
;     * Server URL   (e.g. https://training.ticketscad.com)
;     * Bearer Token (issued from the TicketsCAD admin UI)
;     * COM port     (dropdown of detected ports, or free-text)
;
;  On install it:
;     1. Copies a self-contained Python + the bridge + nssm.exe to
;        {autopf}\TicketsCAD-MeshBridge  (Program Files).
;     2. Writes bridge_config.ini with the entered values.
;     3. Registers a Windows service (NSSM) running the bridge with those
;        values, set Automatic + restart-on-failure, then starts it.
;     4. Optionally installs the Silicon Labs CP210x USB driver.
;     5. Drops a "Verify Bridge" Start-menu/desktop shortcut for self-diagnosis.
;
;  Uninstall stops + removes the service, then deletes the files.
;
;  Build:  ISCC.exe TicketsCAD-MeshBridge.iss
;  Output: installer\output\TicketsCAD-MeshBridge-Setup.exe
; ============================================================================

#define MyAppName "TicketsCAD Meshtastic Mesh Bridge"
; Version is injected from the build tag via:  ISCC /DAppVersion=1.2.3
; Falls back to a dev marker for ad-hoc local compiles.
#ifdef AppVersion
  #define MyAppVersion AppVersion
#else
  #define MyAppVersion "0.0.0-dev"
#endif
#define MyAppPublisher "TicketsCAD"
#define MyServiceName "TicketsCAD-MeshBridge"

[Setup]
AppId={{8F3A2C71-6D4E-4B9A-9C2E-MESHBRIDGE001}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\TicketsCAD-MeshBridge
DefaultGroupName=TicketsCAD Mesh Bridge
DisableProgramGroupPage=yes
DisableDirPage=no
; Service install requires admin -- request elevation (the UAC prompt is normal).
PrivilegesRequired=admin
OutputDir=output
OutputBaseFilename=TicketsCAD-MeshBridge-Setup-v{#MyAppVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayName={#MyAppName}
; Don't let the user run two copies fighting over the COM port:
AppMutex=TicketsCAD-MeshBridge-Installer

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopverify"; Description: "Create a desktop shortcut for ""Verify Bridge"""; GroupDescription: "Shortcuts:"
Name: "installdriver"; Description: "Install the Silicon Labs CP210x USB driver - ONLY if the radio shows no COM port. Leave unchecked if your device already works: the official driver may not support clone CP2102 chips used in some low-cost boards."; GroupDescription: "USB driver:"; Flags: unchecked

[Files]
; --- The self-contained Python interpreter (deps pre-installed, no venv) ---
Source: "payload\python312\*"; DestDir: "{app}\python312"; Flags: ignoreversion recursesubdirs createallsubdirs
; --- The bridge itself + the NSSM service wrapper ---
Source: "payload\bridge_v2.py"; DestDir: "{app}"; Flags: ignoreversion
Source: "payload\nssm.exe"; DestDir: "{app}"; Flags: ignoreversion
; --- Verify helper (self-diagnosis) ---
Source: "extras\verify_bridge.py"; DestDir: "{app}"; Flags: ignoreversion
Source: "extras\Verify Bridge.bat"; DestDir: "{app}"; Flags: ignoreversion
; --- CP210x driver package (extracted into a subfolder; installed on demand) ---
Source: "extras\cp210x\*"; DestDir: "{app}\cp210x"; Flags: ignoreversion recursesubdirs createallsubdirs; Tasks: installdriver; Check: CP210xPresent
; --- Readme ---
Source: "extras\INSTALL-README.txt"; DestDir: "{app}"; Flags: ignoreversion isreadme

[Dirs]
Name: "{app}\logs"

[Icons]
Name: "{group}\Verify Bridge"; Filename: "{app}\Verify Bridge.bat"; WorkingDir: "{app}"; IconFilename: "{sys}\shell32.dll"; IconIndex: 23
Name: "{group}\Bridge Logs"; Filename: "{app}\logs"
Name: "{group}\Uninstall TicketsCAD Mesh Bridge"; Filename: "{uninstallexe}"
Name: "{commondesktop}\Verify TicketsCAD Bridge"; Filename: "{app}\Verify Bridge.bat"; WorkingDir: "{app}"; IconFilename: "{sys}\shell32.dll"; IconIndex: 23; Tasks: desktopverify

[Run]
; 1. (optional) Install the CP210x driver silently before the service starts.
Filename: "{app}\cp210x\silabser_install.bat"; StatusMsg: "Installing Silicon Labs CP210x USB driver..."; Flags: runhidden waituntilterminated; Tasks: installdriver; Check: CP210xPresent
; 2. Register + start the service. All the heavy lifting is in code (see
;    RegisterService below) so it can use the wizard values. We just call it.
; (Handled in CurStepChanged -> ssPostInstall.)

[UninstallRun]
; Stop + remove the service BEFORE files are deleted.
Filename: "{app}\nssm.exe"; Parameters: "stop {#MyServiceName}"; Flags: runhidden; RunOnceId: "StopMeshSvc"
Filename: "{app}\nssm.exe"; Parameters: "remove {#MyServiceName} confirm"; Flags: runhidden; RunOnceId: "RemoveMeshSvc"

[Code]
var
  CfgPage: TWizardPage;
  EdtUrl: TNewEdit;
  EdtToken: TNewEdit;
  CmbPort: TNewComboBox;
  LblUrl, LblToken, LblPort, LblHint: TNewStaticText;

{ ---- Detect serial ports from the registry (HARDWARE\DEVICEMAP\SERIALCOMM) ---- }
procedure PopulateComPorts;
var
  Names: TArrayOfString;
  Value: string;
  i: Integer;
begin
  CmbPort.Items.Clear;
  if RegGetValueNames(HKLM, 'HARDWARE\DEVICEMAP\SERIALCOMM', Names) then
  begin
    for i := 0 to GetArrayLength(Names) - 1 do
    begin
      if RegQueryStringValue(HKLM, 'HARDWARE\DEVICEMAP\SERIALCOMM', Names[i], Value) then
        CmbPort.Items.Add(Value);
    end;
  end;
  { Always offer a few common ones so the field is never empty/unusable }
  if CmbPort.Items.IndexOf('COM3') < 0 then CmbPort.Items.Add('COM3');
  if CmbPort.Items.IndexOf('COM4') < 0 then CmbPort.Items.Add('COM4');
  if CmbPort.Items.IndexOf('COM5') < 0 then CmbPort.Items.Add('COM5');
  if CmbPort.Items.Count > 0 then
    CmbPort.ItemIndex := 0;
end;

procedure InitializeWizard;
begin
  CfgPage := CreateCustomPage(wpSelectTasks,
    'Bridge Configuration',
    'Enter the connection details from your TicketsCAD administrator.');

  LblUrl := TNewStaticText.Create(WizardForm);
  LblUrl.Parent := CfgPage.Surface;
  LblUrl.Top := 8;
  LblUrl.Caption := 'Server URL (e.g. https://training.ticketscad.com):';

  EdtUrl := TNewEdit.Create(WizardForm);
  EdtUrl.Parent := CfgPage.Surface;
  EdtUrl.Top := LblUrl.Top + LblUrl.Height + 2;
  EdtUrl.Width := CfgPage.SurfaceWidth;
  EdtUrl.Text := 'https://';

  LblToken := TNewStaticText.Create(WizardForm);
  LblToken.Parent := CfgPage.Surface;
  LblToken.Top := EdtUrl.Top + EdtUrl.Height + 12;
  LblToken.Caption := 'Bearer Token (paste the token from the admin UI):';

  EdtToken := TNewEdit.Create(WizardForm);
  EdtToken.Parent := CfgPage.Surface;
  EdtToken.Top := LblToken.Top + LblToken.Height + 2;
  EdtToken.Width := CfgPage.SurfaceWidth;
  EdtToken.Text := '';

  LblPort := TNewStaticText.Create(WizardForm);
  LblPort.Parent := CfgPage.Surface;
  LblPort.Top := EdtToken.Top + EdtToken.Height + 12;
  LblPort.Caption := 'COM port for the radio (pick the detected port, or type it):';

  CmbPort := TNewComboBox.Create(WizardForm);
  CmbPort.Parent := CfgPage.Surface;
  CmbPort.Top := LblPort.Top + LblPort.Height + 2;
  CmbPort.Width := 160;
  CmbPort.Style := csDropDown;  { editable: lets the user type a port too }

  LblHint := TNewStaticText.Create(WizardForm);
  LblHint.Parent := CfgPage.Surface;
  LblHint.Top := CmbPort.Top + CmbPort.Height + 14;
  LblHint.Width := CfgPage.SurfaceWidth;
  LblHint.AutoSize := False;
  LblHint.Height := 60;
  LblHint.WordWrap := True;
  LblHint.Caption :=
    'Tip: if you are not sure which COM port, open Device Manager > Ports ' +
    '(COM & LPT) with the radio plugged in. The Silicon Labs device shows ' +
    'the COMx number. If the list is empty, plug in the radio and install ' +
    'the CP210x driver (offered on the previous page), then come back.';

  PopulateComPorts;
end;

{ ---- Validate the config page before letting the user continue ---- }
function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if (CfgPage <> nil) and (CurPageID = CfgPage.ID) then
  begin
    if (Trim(EdtUrl.Text) = '') or (Trim(EdtUrl.Text) = 'https://') then
    begin
      MsgBox('Please enter the Server URL.', mbError, MB_OK);
      Result := False; Exit;
    end;
    if Trim(EdtToken.Text) = '' then
    begin
      if MsgBox('No Bearer Token entered. The bridge will run in DRY-RUN '
        + 'mode (it will not send anything to the server). Continue anyway?',
        mbConfirmation, MB_YESNO) <> IDYES then
      begin
        Result := False; Exit;
      end;
    end;
    if Trim(CmbPort.Text) = '' then
    begin
      MsgBox('Please choose or type the COM port for the radio.', mbError, MB_OK);
      Result := False; Exit;
    end;
  end;
end;

{ ---- Only attempt to install the driver if its payload was bundled ---- }
function CP210xPresent: Boolean;
begin
  Result := FileExists(ExpandConstant('{src}\extras\cp210x\silabser_install.bat'))
    or FileExists(ExpandConstant('{tmp}\cp210x\silabser_install.bat'));
end;

{ ---- Write bridge_config.ini (source of truth for the verify helper) ---- }
procedure WriteConfigIni;
var
  Path, S: string;
begin
  Path := ExpandConstant('{app}\bridge_config.ini');
  S := '; Auto-written by the installer. Edit + restart the service to change.' + #13#10;
  S := S + '[bridge]' + #13#10;
  S := S + 'cad_url=' + Trim(EdtUrl.Text) + #13#10;
  S := S + 'cad_token=' + Trim(EdtToken.Text) + #13#10;
  S := S + 'port=' + Trim(CmbPort.Text) + #13#10;
  S := S + 'protocol=meshtastic' + #13#10;
  SaveStringToFile(Path, S, False);
  // verify_bridge.py lives in the app dir and reads this same ini
end;

{ ---- Run an NSSM command, return True on success ---- }
function RunNssm(const Params: string): Boolean;
var
  Code: Integer;
begin
  Result := Exec(ExpandConstant('{app}\nssm.exe'), Params, '',
    SW_HIDE, ewWaitUntilTerminated, Code);
end;

{ ---- Register + configure + start the Windows service ---- }
procedure RegisterService;
var
  Py, Bridge, AppDir, Url, Token, Port, Params: string;
  Code: Integer;
begin
  Py     := ExpandConstant('{app}\python312\python.exe');
  Bridge := ExpandConstant('{app}\bridge_v2.py');
  AppDir := ExpandConstant('{app}');
  Url    := Trim(EdtUrl.Text);
  Token  := Trim(EdtToken.Text);
  Port   := Trim(CmbPort.Text);

  { Clean slate -- remove any prior instance }
  Exec(ExpandConstant('{app}\nssm.exe'), 'stop {#MyServiceName}', '', SW_HIDE, ewWaitUntilTerminated, Code);
  Exec(ExpandConstant('{app}\nssm.exe'), 'remove {#MyServiceName} confirm', '', SW_HIDE, ewWaitUntilTerminated, Code);

  { Build AppParameters. Use the BARE script name (resolved via AppDirectory,
    set below) rather than the full path -- NSSM drops the quotes when the app
    args are passed inline with "install", so a full path containing a space
    (e.g. C:\Program Files\...) gets split and Python sees only "C:\Program". }
  Params := 'bridge_v2.py --port ' + Port + ' --protocol meshtastic';
  if (Url <> '') and (Token <> '') then
    Params := Params + ' --cad-url ' + Url + ' --cad-token ' + Token;

  { install <svc> <python.exe> <args...> }
  Exec(ExpandConstant('{app}\nssm.exe'),
    'install {#MyServiceName} "' + Py + '" ' + Params,
    '', SW_HIDE, ewWaitUntilTerminated, Code);

  RunNssm('set {#MyServiceName} AppDirectory "' + AppDir + '"');
  RunNssm('set {#MyServiceName} DisplayName "TicketsCAD Meshtastic Mesh Bridge"');
  RunNssm('set {#MyServiceName} Description "Bridges a Meshtastic radio (' + Port + ') to TicketsCAD via api/mesh.php."');
  RunNssm('set {#MyServiceName} Start SERVICE_AUTO_START');
  RunNssm('set {#MyServiceName} AppStdout "' + AppDir + '\logs\bridge.log"');
  RunNssm('set {#MyServiceName} AppStderr "' + AppDir + '\logs\bridge.log"');
  RunNssm('set {#MyServiceName} AppRotateFiles 1');
  RunNssm('set {#MyServiceName} AppRotateBytes 5242880');
  RunNssm('set {#MyServiceName} AppThrottle 15000');
  RunNssm('set {#MyServiceName} AppExit Default Restart');
  RunNssm('set {#MyServiceName} AppRestartDelay 10000');
  RunNssm('set {#MyServiceName} AppEnvironmentExtra PYTHONUNBUFFERED=1');

  { Start it now }
  if not RunNssm('start {#MyServiceName}') then
    MsgBox('The bridge service was installed but did not start. Plug in the '
      + 'radio and use the "Verify Bridge" shortcut to diagnose, or start it '
      + 'from Services (services.msc).', mbInformation, MB_OK);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    WriteConfigIni;
    RegisterService;
  end;
end;
