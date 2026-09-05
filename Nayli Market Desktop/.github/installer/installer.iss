#define MyAppName "Nayli Kiosk Desktop POS"
#define MyAppVersion "2.0.0"
#define MyAppPublisher "Nayli Market Solutions"
#define MyAppExeName "Nayli-Kiosk.exe"

[Setup]
AppId={{D821F244-6C0D-4C92-9F9C-A63E0124B8A1}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=..\..\build\installer
OutputBaseFilename=Nayli-Kiosk-Desktop-Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
SetupIconFile=..\..\assets\images\app_icon.ico

; Seamless Upgrade Directives
UsePreviousAppDir=yes
DisableDirPage=auto
CloseApplications=yes
RestartApplications=no

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "تشغيل برنامج نايلي كيوسك Nayli Kiosk"; Flags: nowait postinstall skipifsilent

[Code]
function InitializeSetup(): Boolean;
var
  InstalledVersion: String;
begin
  Result := True;
  if RegQueryStringValue(HKLM, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#SetupSetting("AppId")}_is1', 'DisplayVersion', InstalledVersion) or
     RegQueryStringValue(HKCU, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#SetupSetting("AppId")}_is1', 'DisplayVersion', InstalledVersion) then
  begin
    MsgBox('تم اكتشاف نسخة سابقة من برنامج (' + '{#MyAppName}' + ') مثبتة على هذا الحاسوب.' + #13#10 + #13#10 +
           'الإصدار المثبت: ' + InstalledVersion + #13#10 +
           'الإصدار الجديد: ' + '{#MyAppVersion}' + #13#10 + #13#10 +
           'سيتم الآن تحديث ملفات البرنامج تلقائياً فوق الإصدار القديم مع الحفاظ التام والكامل على جميع بيانات المحل، المخزون، والديون دون أي تغيير أو مساس بها.',
           mbInformation, MB_OK);
  end;
end;
