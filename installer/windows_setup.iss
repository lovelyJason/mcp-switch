; ==================== MCP Switch Windows Installer Script ====================
; Compiled with Inno Setup 6.x
;
; Features:
; - Package Flutter build artifacts (including all DLLs)
; - Create Start menu shortcuts
; - Create desktop shortcut (optional)
; - Auto-install Visual C++ Redistributable if missing
; - Support uninstall
; ===========================================================================

#define MyAppName "MCP Switch"
#define MyAppNameEn "MCPSwitch"
; Version will be replaced by CI workflow from pubspec.yaml
#define MyAppVersion "0.0.0"
#define MyAppPublisher "MCP Switch Team"
#define MyAppURL "https://github.com/user/mcp-switch"
#define MyAppExeName "mcp_switch.exe"

; VC++ Redistributable download URL (x64, latest version)
#define VCRedistURL "https://aka.ms/vs/17/release/vc_redist.x64.exe"

[Setup]
; App basic info - IMPORTANT: Generate a unique AppId for your app!
; You can use https://www.guidgenerator.com/ to generate a new GUID
AppId={{B2C3D4E5-F6A7-8901-BCDE-F23456789012}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; Install directory
DefaultDirName={autopf}\{#MyAppNameEn}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

; Output settings
OutputDir=..\build\installer
OutputBaseFilename=MCPSwitch_Setup_{#MyAppVersion}
; SetupIconFile=..\assets\icons\app_icon.ico  ; TODO: uncomment after adding custom icon
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes

; Permission settings (admin required for VC++ Redist install)
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog

; UI settings
WizardStyle=modern
DisableWelcomePage=no
ShowLanguageDialog=auto

; Architecture
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
; English only, GitHub Actions Inno Setup may not have Chinese language pack
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "vcredist"; Description: "Install Visual C++ Runtime (required if missing)"; GroupDescription: "Dependencies:"; Check: not VCRedistInstalled; Flags: checkedonce

[Files]
; Copy entire Release directory (including exe, dll, data folder, etc.)
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Include VC++ Redistributable installer (downloaded in workflow)
Source: "..\build\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall; Tasks: vcredist

[Icons]
; Start menu shortcut
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
; Desktop shortcut (user choice)
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Install VC++ Redistributable silently if user selected the task
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing Visual C++ Runtime..."; Flags: waituntilterminated; Tasks: vcredist
; Run app after install (optional)
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Clean user data directory on uninstall (optional, use with caution)
; Type: filesandordirs; Name: "{userappdata}\mcp-switch"

[Code]
// Force close running application before install/upgrade
function InitializeSetup(): Boolean;
var
  ResultCode: Integer;
begin
  // Kill mcp_switch.exe if running (silent, ignore errors)
  Exec('taskkill', '/F /IM mcp_switch.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  // Small delay to ensure file handles are released
  Sleep(500);
  Result := True;
end;

// Force close running application before uninstall
function InitializeUninstall(): Boolean;
var
  ResultCode: Integer;
begin
  Exec('taskkill', '/F /IM mcp_switch.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Sleep(500);
  Result := True;
end;

// Check if Visual C++ Redistributable is already installed
function VCRedistInstalled: Boolean;
var
  RegKey: String;
begin
  // Check for VC++ 2015-2022 Redistributable (x64)
  // Registry key exists if installed
  RegKey := 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64';
  Result := RegKeyExists(HKEY_LOCAL_MACHINE, RegKey);

  if not Result then
  begin
    // Also check WOW6432Node for 32-bit registry view
    RegKey := 'SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x64';
    Result := RegKeyExists(HKEY_LOCAL_MACHINE, RegKey);
  end;

  if Result then
    Log('VC++ Redistributable is already installed')
  else
    Log('VC++ Redistributable is NOT installed, will install');
end;
