; Inno Setup script - 抖店订单管理器 (Douyin Order Manager)
; 安装 Inno Setup 6 后，运行 scripts\build_installer.bat 即可生成 installer\doudian_shop_setup.exe
; 或命令行： "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss

#define MyAppName "抖店订单管理器"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Douyin Shop"
#define MyAppURL "https://example.com"
#define MyAppExeName "doudian_shop.exe"

[Setup]
; 唯一标识，用于区分卸载/升级。需要更换时可用 Inno Setup 的 /GEN 生成新 GUID
AppId={{7E5C2A1B-3D4F-4C8A-9B6E-1F2A3B4C5D6E}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
; 当前为本地/自签构建，不强制管理员；如需安装到 Program Files 全局可改 admin
PrivilegesRequired=lowest
OutputDir=installer
OutputBaseFilename=doudian_shop_setup
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "chinese"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; 捆绑 Visual C++ 运行库，避免目标机器缺 VC++ 导致程序一启动就闪退/打不开。
; 请将官方 vcredist_x64.exe 下载到 installer\ 目录（约 25MB）：
;   https://learn.microsoft.com/zh-cn/cpp/windows/latest-supported-vc-redist
; 选 "X64" 的 vc_redist.x64.exe，放到 C:\doudian\installer\vcredist_x64.exe
Source: "installer\vcredist_x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall; Check: not VCInstalled

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加任务:"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "启动 {#MyAppName}"; Flags: nowait postinstall skipifsilent
; 若目标机器未安装 VC++ 运行库，则静默安装（已装则跳过）
Filename: "{tmp}\vcredist_x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "正在安装 Visual C++ 运行库..."; Check: not VCInstalled

[Code]
// 检测 VC++ 2015-2022 x64 运行库是否已安装
function VCInstalled: Boolean;
var
  Installed: Cardinal;
begin
  Result := False;
  if RegQueryDWordValue(HKLM, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Installed', Installed) then
    Result := (Installed = 1);
end;
