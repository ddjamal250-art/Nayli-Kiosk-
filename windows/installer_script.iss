#define MyAppName "Nayli Market POS"
#define MyAppVersion "2.1.0"
#define MyAppPublisher "Nayli Kiosk"
#define MyAppExeName "nayli_kiosk.exe"
#define MyAppId "{5D0B2E1E-1456-4B82-B955-4B4DF9D5B468}"

[Setup]
AppId={{#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
MinVersion=6.1sp1
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
DefaultDirName={autopf}\NayliMarket
DisableProgramGroupPage=yes
LicenseFile=License.rtf
OutputDir=Output
OutputBaseFilename=NayliMarket_Setup_v{#MyAppVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
SetupIconFile=..\build\windows\x64\runner\Release\data\flutter_assets\assets\images\app_logo.ico
; We will use the built-in icon if it exists, otherwise fall back to runner\resources. 
; Let's just use the known one from before.
SetupIconFile=runner\resources\app_icon.ico

; Automatically detect system language (Arabic, French, English)
ShowLanguageDialog=auto

; Prevent running while app is active
CloseApplications=yes
CloseApplicationsFilter={#MyAppExeName}

; Automatically install for all users / administrative
PrivilegesRequired=admin
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}

[Languages]
Name: "arabic"; MessagesFile: "Arabic.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "startup"; Description: "تشغيل البرنامج تلقائياً مع Windows / Lancer au démarrage"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; VC++ 2015-2022 Redistributable
Source: "redist\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall ignoreversion nocompression

; Program Files
Source: "..\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: startup

[Run]
; 1. VC++
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/quiet /norestart"; StatusMsg: "Installing Visual C++ Redistributables... / جاري تثبيت المكتبات..."; Check: NeedsVCRedist; Flags: waituntilterminated

; 2. Run App
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

[Code]
var
  IsUpdateMode: Boolean;

function NeedsVCRedist: Boolean;
var
  version: String;
begin
  Result := True;
  if RegQueryStringValue(HKLM,
    'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64',
    'Version', version) then
  begin
    // إذا كان مثبّت بنسخة كافية، لا نثبته مرة أخرى
    Result := (CompareStr(version, 'v14.20.0') < 0);
  end;
end;

function InitializeSetup(): Boolean;
var
  InstalledPath: String;
begin
  Result := True;
  // Check in 64-bit and 32-bit registry uninstall keys
  IsUpdateMode := RegQueryStringValue(HKLM, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppId}_is1', 'InstallLocation', InstalledPath);
  if not IsUpdateMode then
    IsUpdateMode := RegQueryStringValue(HKCU, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppId}_is1', 'InstallLocation', InstalledPath);
  
  // If file already exists in previous installation or default directory
  if not IsUpdateMode then
    IsUpdateMode := FileExists(ExpandConstant('{autopf}\NayliMarket\{#MyAppExeName}'));
end;

procedure InitializeWizard();
begin
  if IsUpdateMode then
  begin
    // Dynamically change wizard texts depending on active language
    if ActiveLanguage = 'arabic' then
    begin
      WizardForm.Caption := 'تحديث برنامج ' + '{#MyAppName}';
      WizardForm.WelcomeLabel1.Caption := 'مرحباً بك في معالج تحديث ' + '{#MyAppName}';
      WizardForm.WelcomeLabel2.Caption := 'سيقوم هذا المعالج بتحديث البرنامج إلى الإصدار الأحدث دون المساس ببياناتك السابقة أو سجلاتك.' + #13#10#13#10 + 'اضغط على التالي للمتابعة وتطبيق التحديث.';
      WizardForm.NextButton.Caption := 'تحديث >';
    end
    else if ActiveLanguage = 'french' then
    begin
      WizardForm.Caption := 'Mise à jour de ' + '{#MyAppName}';
      WizardForm.WelcomeLabel1.Caption := 'Bienvenue dans l''assistant de mise à jour de ' + '{#MyAppName}';
      WizardForm.WelcomeLabel2.Caption := 'Cet assistant va mettre à jour le programme vers la dernière version sans altérer vos données ou bases de données existantes.' + #13#10#13#10 + 'Cliquez sur Suivant pour appliquer la mise à jour.';
      WizardForm.NextButton.Caption := 'Mettre à jour >';
    end
    else
    begin
      WizardForm.Caption := 'Update ' + '{#MyAppName}';
      WizardForm.WelcomeLabel1.Caption := 'Welcome to ' + '{#MyAppName}' + ' Update Wizard';
      WizardForm.WelcomeLabel2.Caption := 'This will update the program to the latest version while keeping all your existing database, sales, and settings intact.' + #13#10#13#10 + 'Click Next to apply the update.';
      WizardForm.NextButton.Caption := 'Update >';
    end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssInstall then
  begin
    Exec('taskkill.exe', '/F /IM nayli_kiosk.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
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
