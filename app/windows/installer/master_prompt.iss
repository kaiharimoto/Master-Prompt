; Inno Setup script for Master Prompt.
;
; Built by CI on windows-latest; see .github/workflows/ci.yml. Compile with:
;
;   ISCC /DAppVersion=0.1.0.42 /DBuildDir=..\..\build\windows\x64\runner\Release ^
;        /DOutputDir=..\..\..\out /DOutputBase=MasterPromptSetup-42-a1b2c3d ^
;        master_prompt.iss
;
; Two properties matter more than anything else here.
;
; **Per-user, so there is no UAC prompt.** PrivilegesRequired=lowest makes
; {autopf} resolve to %LOCALAPPDATA%\Programs, which the user already owns.
; Installing to Program Files would need elevation on every update, which is
; the opposite of the one-click update this exists to serve.
;
; **AppId never changes.** It, together with the install directory, is what
; makes the next install an upgrade rather than a second copy sitting beside
; the first. Change it and every user ends up with two Master Prompts and two
; uninstall entries.

#define AppName "Master Prompt"
#define AppExe "MasterPrompt.exe"
#define AppPublisher "Master Prompt"
#define AppUrl "https://github.com/kaiharimoto/Master-Prompt"

#ifndef AppVersion
  #define AppVersion "0.1.0.0"
#endif
#ifndef BuildDir
  #define BuildDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\..\out"
#endif
#ifndef OutputBase
  #define OutputBase "MasterPromptSetup"
#endif

[Setup]
AppId={{8B1F2C4E-6D3A-4E57-9C0B-2A7E5D91F4C3}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}/issues
AppUpdatesURL={#AppUrl}/releases/tag/dev
VersionInfoVersion={#AppVersion}

; Per-user. No administrator, no UAC prompt, no elevation on update.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
DisableDirPage=auto

; Windows' own list of installed programs, so it can be removed the ordinary
; way rather than by deleting a folder.
UninstallDisplayName={#AppName}
UninstallDisplayIcon={app}\{#AppExe}

OutputDir={#OutputDir}
OutputBaseFilename={#OutputBase}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; Replaces a running copy instead of failing with "file in use". The app closes
; itself before spawning a silent update, but a user who runs the installer by
; hand with the app open should not have to think about it.
CloseApplications=yes
CloseApplicationsFilter=*.exe,*.dll
; The relaunch is ours, via [Run] below, so Restart Manager must not also try.
RestartApplications=no
SetupMutex=MasterPromptSetupMutex

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; \
  GroupDescription: "Shortcuts:"; Flags: unchecked

; A resume scheduled five hours out does not survive a reboot, and nothing
; happens while the app is shut. Starting with Windows is the whole fix, it
; needs no code at all, and this is where people expect to find the choice.
; Unticked, because an app that adds itself to startup uninvited is a
; different kind of rude.
Name: "startup"; Description: "Start Master Prompt when I sign in"; \
  GroupDescription: "Long runs:"; Flags: unchecked

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; \
  Tasks: desktopicon
Name: "{autostartup}\{#AppName}"; Filename: "{app}\{#AppExe}"; \
  Tasks: startup

[Run]
; The ordinary end-of-wizard tick box. Suppressed in a silent install.
Filename: "{app}\{#AppExe}"; Description: "Start {#AppName}"; \
  Flags: nowait postinstall skipifsilent

; The silent update's relaunch. The app spawns this installer with
; /relaunch=1, so it reopens itself when the copy is finished — that is the
; whole difference between "one click" and "find the app again afterwards".
Filename: "{app}\{#AppExe}"; Flags: nowait runasoriginaluser; \
  Check: WantsRelaunch

[Code]
function WantsRelaunch: Boolean;
begin
  Result := ExpandConstant('{param:relaunch|0}') = '1';
end;
