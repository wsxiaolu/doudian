# Windows 打包

目标：产出可双击运行的 `抖店订单管家.exe` 及配套依赖文件，整体目录可压缩分发。

## 1. 前置

- Flutter 3.27 + 已装 **Visual Studio 2022**（勾选「使用 C++ 的桌面开发」工作负载，含 MSVC / Windows 10/11 SDK）。
- 在 **x64 本机工具命令提示符** 或 PowerShell 中执行（保证 `cl` 与 Windows SDK 在 PATH）。

```powershell
flutter doctor          # 确认 [√] Visual Studio 与 Windows 开发环境就绪
flutter pub get
```

## 2. 构建 Release

```powershell
flutter build windows --release
```

产物位于：

```
build\windows\x64\runner\Release\
├── doudian_shop.exe      # 主程序
├── *.dll                 # Flutter / 第三方原生依赖
├── data\                 # 资源（flutter_assets 等）
└── ...
```

> 整个 `Release` 目录需要**一起分发**，单独拷 exe 会因缺 dll / 资源而无法启动。

## 3. 可选：做成单个文件 / 安装包

- **单文件**：可用 [Inno Setup](https://jrsoftware.org/)、[NSIS](https://nsis.sourceforge.io/) 把 `Release` 目录打包成安装向导，最省心。
- **绿色版**：直接 zip 整个 `Release` 目录发给用户解压即用。
- 若需要内嵌运行库，可在打包脚本里把 VC++ Redistributable 一并静默安装。

## 4. 注意事项

- 桌面端扫码走「扫码枪模拟键盘输入」，`mobile_scanner` 仅在移动端启用，Windows 无需摄像头权限。
- 跨机器运行时若提示缺 `VCRUNTIME140.dll` 之类，让用户装一下 **Visual C++ Redistributable** 即可。
- 版本号在 `pubspec.yaml` 的 `version: 1.0.0+1`（前为展示版本，后为构建号）。
