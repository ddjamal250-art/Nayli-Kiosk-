#define MyAppName "Nayli Kiosk Desktop POS"
#define MyAppVersion "2.1.0"
#define MyAppPublisher "Nayli Market Solutions"
#define MyAppExeName "Nayli-Kiosk.exe"
#define MyAppId "{971D42B5-5B47-4410-A762-A0328D616C12}"

[Setup]
AppId={{#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
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
Name: "startup"; Description: "تشغيل البرنامج تلقائياً مع Windows / Lancer au démarrage"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

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
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/quiet /norestart"; StatusMsg: "جاري تثبيت مكتبات النظام... / Installation des composants système..."; Check: NeedsVCRedist; Flags: waituntilterminated

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
      WizardForm.Caption := 'تحديث برنامج ' + '{#MyAppName}';
      WizardForm.WelcomeLabel1.Caption := 'مرحباً بك في معالج تحديث ' + '{#MyAppName}';
      WizardForm.WelcomeLabel2.Caption := 'تم اكتشاف إصدار سابق من البرنامج على جهازك.' + #13#10#13#10 +
                                          'سيقوم هذا المعالج بتحديث ملفات البرنامج إلى الإصدار ' + '{#MyAppVersion}' + ' مباشرة دون الحاجة لإنترنت.' + #13#10#13#10 +
                                          '✅ الحفاظ التام والمضمون 100% على كافة قواعد البيانات السابقة، المبيعات، والسلع.' + #13#10#13#10 +
                                          'اضغط على التالي لبدء التحديث.';
      WizardForm.NextButton.Caption := 'تحديث >';
    end
    else if ActiveLanguage = 'french' then
    begin
      WizardForm.Caption := 'Mise à jour de ' + '{#MyAppName}';
      WizardForm.WelcomeLabel1.Caption := 'Bienvenue dans l''assistant de mise à jour de ' + '{#MyAppName}';
      WizardForm.WelcomeLabel2.Caption := 'Une version précédente a été détectée sur votre système.' + #13#10#13#10 +
                                          'Cet assistant va mettre à jour le programme vers la version ' + '{#MyAppVersion}' + '.' + #13#10#13#10 +
                                          '✅ Vos bases de données, stocks et ventes seront intégralement préservés sans aucune modification.' + #13#10#13#10 +
                                          'Cliquez sur Suivant pour continuer.';
      WizardForm.NextButton.Caption := 'Mettre à jour >';
    end
    else
    begin
      WizardForm.Caption := 'Update ' + '{#MyAppName}';
      WizardForm.WelcomeLabel1.Caption := 'Welcome to ' + '{#MyAppName}' + ' Update Wizard';
      WizardForm.WelcomeLabel2.Caption := 'A previous installation was detected on your system.' + #13#10#13#10 +
                                          'This wizard will update your application files to version ' + '{#MyAppVersion}' + '.' + #13#10#13#10 +
                                          '✅ All your existing databases, store products, and sales are 100% preserved.' + #13#10#13#10 +
                                          'Click Next to proceed.';
      WizardForm.NextButton.Caption := 'Update >';
    end;
  end;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = wpLicense then
  begin
    WizardForm.LicenseMemo.BiDiMode := bdRightToLeft;
  end;

  if IsUpdateMode and (CurPageID = wpReady) then
  begin
    if ActiveLanguage = 'arabic' then
    begin
      WizardForm.PageNameLabel.Caption := 'جاهز للتحديث';
      WizardForm.PageDescriptionLabel.Caption := 'البرنامج جاهز لتطبيق التحديث الجديد دون أي مساس ببياناتك.';
      WizardForm.NextButton.Caption := 'تحديث';
    end
    else if ActiveLanguage = 'french' then
    begin
      WizardForm.PageNameLabel.Caption := 'Prêt pour la mise à jour';
      WizardForm.PageDescriptionLabel.Caption := 'Le programme est prêt à appliquer la mise à jour sans toucher à vos données.';
      WizardForm.NextButton.Caption := 'Mettre à jour';
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
  end;
end;
