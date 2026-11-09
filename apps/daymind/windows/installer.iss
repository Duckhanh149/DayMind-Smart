[Setup]
AppId={{9E5EEAD6-DB82-48CC-A0C2-A3D0574DC18B}
AppName=DayMind SMART
AppVersion=0.3.0
AppPublisher=DayMind SMART
DefaultDirName={localappdata}\Programs\DayMind SMART
DefaultGroupName=DayMind SMART
PrivilegesRequired=lowest
MinVersion=10.0.17763
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\build\windows-installer
OutputBaseFilename=DayMind-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\daymind_smart.exe
CloseApplications=yes

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\DayMind SMART"; Filename: "{app}\daymind_smart.exe"
Name: "{autodesktop}\DayMind SMART"; Filename: "{app}\daymind_smart.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked

[Run]
Filename: "{app}\daymind_smart.exe"; Description: "Open DayMind SMART"; Flags: nowait postinstall skipifsilent
