#define MyAppName "Nayli Kiosk Desktop POS"
#define MyAppVersion "2.4.0"
#define MyAppPublisher "Nayli POS"
#define MyAppExeName "Nayli-Kiosk.exe"
#define MyAppId "{971D42B5-5B47-4410-A762-A0328D616C12}"

[Setup]
AppId={{#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL=https://nayli-pos.com
AppSupportURL=https://nayli-pos.com/support
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=..\..\build\installer
OutputBaseFilename=Nayli-Kiosk-Desktop-Setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
SetupIconFile=..\..\assets\images\app_icon.ico
LicenseFile=..\..\windows\License.rtf

; Auto-detect system language (Arabic, French, English)
ShowLanguageDialog=auto

; Seamless Upgrade Directives
UsePreviousAppDir=yes
DisableDirPage=auto
CloseApplications=yes
RestartApplications=no
PrivilegesRequired=admin
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}

[Languages]
Name: "arabic"; MessagesFile: "..\..\windows\Arabic.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "startup"; Description: "ØªØ´ØºÙŠÙ„ Ø§Ù„Ø¨Ø±Ù†Ø§Ù…Ø¬ ØªÙ„Ù‚Ø§Ø¦ÙŠØ§Ù‹ Ù…Ø¹ Windows / Lancer au dÃ©marrage"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; VC++ 2015-2022 Redistributable
Source: "..\..\windows\redist\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall ignoreversion nocompression; Check: FileExists(ExpandConstant('{src}\..\..\windows\redist\vc_redist.x64.exe'))

; Release Build Files
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: startup

[Run]
; 1. Install VC++ silently if needed
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/quiet /norestart"; StatusMsg: "Ø¬Ø§Ø±ÙŠ ØªØ«Ø¨ÙŠØª Ù…ÙƒØªØ¨Ø§Øª Ø§Ù„Ù†Ø¸Ø§Ù…... / Installation des composants systÃ¨me..."; Check: NeedsVCRedist; Flags: waituntilterminated

; 2. Launch Program
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
var
  IsUpdateMode: Boolean;

function NeedsVCRedist: Boolean;
var
  version: String;
begin
  Result := True;
  if not FileExists(ExpandConstant('{tmp}\vc_redist.x64.exe')) then
  begin
    Result := False;
    Exit;
  end;
  if RegQueryStringValue(HKLM,
    'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64',
    'Version', version) then
  begin
    Result := (CompareStr(version, 'v14.20.0') < 0);
  end;
end;

function InitializeSetup(): Boolean;
var
  InstalledVersion: String;
  InstalledPath: String;
begin
  Result := True;
  IsUpdateMode := False;

  // Check in 64-bit and 32-bit registry uninstall keys
  if RegQueryStringValue(HKLM, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppId}_is1', 'DisplayVersion', InstalledVersion) or
     RegQueryStringValue(HKCU, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppId}_is1', 'DisplayVersion', InstalledVersion) or
     RegQueryStringValue(HKLM, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppId}_is1', 'InstallLocation', InstalledPath) or
     RegQueryStringValue(HKCU, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppId}_is1', 'InstallLocation', InstalledPath) or
     FileExists(ExpandConstant('{autopf}\{#MyAppName}\{#MyAppExeName}')) then
  begin
    IsUpdateMode := True;
  end;
end;

procedure InitializeWizard();
begin
  if IsUpdateMode then
  begin
    if ActiveLanguage = 'arabic' then
    begin
      WizardForm.Caption := 'ØªØ­Ø¯ÙŠØ« Ø¨Ø±Ù†Ø§Ù…Ø¬ ' + '{#MyAppName}';
      WizardForm.WelcomeLabel1.Caption := 'Ù…Ø±Ø­Ø¨Ø§Ù‹ Ø¨Ùƒ ÙÙŠ Ù…Ø¹Ø§Ù„Ø¬ ØªØ­Ø¯ÙŠØ« ' + '{#MyAppName}';
      WizardForm.WelcomeLabel2.Caption := 'ØªÙ… Ø§ÙƒØªØ´Ø§Ù Ø¥ØµØ¯Ø§Ø± Ø³Ø§Ø¨Ù‚ Ù…Ù† Ø§Ù„Ø¨Ø±Ù†Ø§Ù…Ø¬ Ø¹Ù„Ù‰ Ø¬Ù‡Ø§Ø²Ùƒ.' + #13#10#13#10 +
                                          'Ø³ÙŠÙ‚ÙˆÙ… Ù‡Ø°Ø§ Ø§Ù„Ù…Ø¹Ø§Ù„Ø¬ Ø¨ØªØ­Ø¯ÙŠØ« Ù…Ù„ÙØ§Øª Ø§Ù„Ø¨Ø±Ù†Ø§Ù…Ø¬ Ø¥Ù„Ù‰ Ø§Ù„Ø¥ØµØ¯Ø§Ø± ' + '{#MyAppVersion}' + ' Ù…Ø¨Ø§Ø´Ø±Ø© Ø¯ÙˆÙ† Ø§Ù„Ø­Ø§Ø¬Ø© Ù„Ø¥Ù†ØªØ±Ù†Øª.' + #13#10#13#10 +
                                          'âœ… Ø§Ù„Ø­ÙØ§Ø¸ Ø§Ù„ØªØ§Ù… ÙˆØ§Ù„Ù…Ø¶Ù…ÙˆÙ† 100% Ø¹Ù„Ù‰ ÙƒØ§ÙØ© Ù‚ÙˆØ§Ø¹Ø¯ Ø§Ù„Ø¨ÙŠØ§Ù†Ø§Øª Ø§Ù„Ø³Ø§Ø¨Ù‚Ø©ØŒ Ø§Ù„Ù…Ø¨ÙŠØ¹Ø§ØªØŒ ÙˆØ§Ù„Ø³Ù„Ø¹.' + #13#10#13#10 +
                                          'Ø§Ø¶ØºØ· Ø¹Ù„Ù‰ Ø§Ù„ØªØ§Ù„ÙŠ Ù„Ø¨Ø¯Ø¡ Ø§Ù„ØªØ­Ø¯ÙŠØ«.';
      WizardForm.NextButton.Caption := 'ØªØ­Ø¯ÙŠØ« >';
    end
    else if ActiveLanguage = 'french' then
    begin
      WizardForm.Caption := 'Mise Ã  jour de ' + '{#MyAppName}';
      WizardForm.WelcomeLabel1.Caption := 'Bienvenue dans l''assistant de mise Ã  jour de ' + '{#MyAppName}';
      WizardForm.WelcomeLabel2.Caption := 'Une version prÃ©cÃ©dente a Ã©tÃ© dÃ©tectÃ©e sur votre systÃ¨me.' + #13#10#13#10 +
                                          'Cet assistant va mettre Ã  jour le programme vers la version ' + '{#MyAppVersion}' + '.' + #13#10#13#10 +
                                          'âœ… Vos bases de donnÃ©es, stocks et ventes seront intÃ©gralement prÃ©servÃ©s sans aucune modification.' + #13#10#13#10 +
                                          'Cliquez sur Suivant pour continuer.';
      WizardForm.NextButton.Caption := 'Mettre Ã  jour >';
    end
    else
    begin
      WizardForm.Caption := 'Update ' + '{#MyAppName}';
      WizardForm.WelcomeLabel1.Caption := 'Welcome to ' + '{#MyAppName}' + ' Update Wizard';
      WizardForm.WelcomeLabel2.Caption := 'A previous installation was detected on your system.' + #13#10#13#10 +
                                          'This wizard will update your application files to version ' + '{#MyAppVersion}' + '.' + #13#10#13#10 +
                                          'âœ… All your existing databases, store products, and sales are 100% preserved.' + #13#10#13#10 +
                                          'Click Next to proceed.';
      WizardForm.NextButton.Caption := 'Update >';
    end;
  end;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if IsUpdateMode and (CurPageID = wpReady) then
  begin
    if ActiveLanguage = 'arabic' then
    begin
      WizardForm.PageNameLabel.Caption := 'Ø¬Ø§Ù‡Ø² Ù„Ù„ØªØ­Ø¯ÙŠØ«';
      WizardForm.PageDescriptionLabel.Caption := 'Ø§Ù„Ø¨Ø±Ù†Ø§Ù…Ø¬ Ø¬Ø§Ù‡Ø² Ù„ØªØ·Ø¨ÙŠÙ‚ Ø§Ù„ØªØ­Ø¯ÙŠØ« Ø§Ù„Ø¬Ø¯ÙŠØ¯ Ø¯ÙˆÙ† Ø£ÙŠ Ù…Ø³Ø§Ø³ Ø¨Ø¨ÙŠØ§Ù†Ø§ØªÙƒ.';
      WizardForm.NextButton.Caption := 'ØªØ­Ø¯ÙŠØ«';
    end
    else if ActiveLanguage = 'french' then
    begin
      WizardForm.PageNameLabel.Caption := 'PrÃªt pour la mise Ã  jour';
      WizardForm.PageDescriptionLabel.Caption := 'Le programme est prÃªt Ã  appliquer la mise Ã  jour sans toucher Ã  vos donnÃ©es.';
      WizardForm.NextButton.Caption := 'Mettre Ã  jour';
    end
    else
    begin
      WizardForm.PageNameLabel.Caption := 'Ready to Update';
      WizardForm.PageDescriptionLabel.Caption := 'Setup is ready to begin updating program files on your computer.';
      WizardForm.NextButton.Caption := 'Update';
    end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssInstall then
  begin
    // Force kill any hanging background instances to avoid "File in use" error
    Exec('taskkill.exe', '/F /IM {#MyAppExeName}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Exec('taskkill.exe', '/F /IM nayli_kiosk.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Exec('taskkill.exe', '/F /IM Nayli-Fashion.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    DeleteFile(ExpandConstant('{app}\Nayli-Fashion.exe'));
  end;
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := False;
  if IsUpdateMode then
  begin
    if (PageID = wpLicense) or (PageID = wpSelectDir) or (PageID = wpSelectProgramGroup) or (PageID = wpSelectTasks) then
      Result := True;
  end;
end;

