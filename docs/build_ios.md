# iOS 打包

> ⚠️ iOS 构建**只能在 macOS 上进行**（需要 Xcode）。以下命令在 macOS 终端执行。

目标：产出 **IPA**，经 Xcode Organizer / Transporter 上架 App Store，或走企业/TestFlight 分发。

## 1. 前置

- macOS + 最新 **Xcode**（含命令行工具：`xcode-select --install`）。
- 一个有效的 **Apple Developer 账号**与对应 **分发证书 / 描述文件（Provisioning Profile）**。
- 在 Apple Developer 后台登记 App 的 Bundle ID（默认 `com.example.doudianShop`，建议改为自有域名反向域名）。

## 2. 配置

```bash
flutter pub get
cd ios
pod install          # 拉取 iOS 原生依赖
cd ..
```

打开 `ios/Runner.xcworkspace` 确认：

- **Signing & Capabilities** 里选好 Team，Bundle Identifier 正确，勾选 Automatically manage signing。
- 如需推送/云消息再加对应 capability（当前版本不依赖）。

## 3. 构建 IPA

```bash
flutter build ios --release --no-codesign   # 仅出归档产物，签名交给 Xcode
# 或直接在 Xcode 里 Product → Archive（推荐，便于上传）
```

导出 IPA 两种方式：

- **Xcode**：Product → Archive → 在 Organizer 里 Distribute App → App Store / Ad Hoc / Enterprise。
- **命令行**（已有描述文件）：
  ```bash
  flutter build ipa --release
  # 产物在 build/ios/ipa/，再用 Transporter 上传或分发
  ```

## 4. 导出 Excel 在 iOS 上的差异

- iOS **不支持** `file_picker` 的目录选择，因此导出会走 **系统分享面板**（`SharePlus.shareXFiles`），
  用户可选择「存储到文件 / 隔空投送 / 微信」等目标，由系统决定落盘位置。功能等价，无需额外处理。

## 5. 权限说明

`ios/Runner/Info.plist` 需声明：

- `NSCameraUsageDescription` —— 扫码用（如启用 `mobile_scanner`）。
- 网络权限默认允许，无需额外声明。

## 6. 注意事项

- 真机调试需设备已加入该 Team 的 Devices 列表（Ad Hoc / 开发分发）。
- App Store 上架需过审核，确保抖店订单处理流程不涉及违规采集。
- 版本号在 `pubspec.yaml` 的 `version: 1.0.0+1`，与 Xcode 里的 Version / Build 对应。
- 若用 M 系列芯片，确保用 `arm64` 构建；Flutter 3.27 默认已支持。
