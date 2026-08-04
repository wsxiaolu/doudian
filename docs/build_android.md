# Android 打包

目标：产出可安装的 **Release APK**（或上架用的 AAB）。

## 1. 前置

- Flutter 3.27 + Android SDK（API 34+ 构建工具）。
- 一个用于签名的 **上传密钥**（首次构建必须，丢了无法同包名更新）。

## 2. 配置签名

在 `android/key.properties`（**不要提交进 git**）填入：

```properties
storePassword=你的密钥库密码
keyPassword=你的密钥密码
keyAlias=upload
storeFile=../upload-keystore.jks
```

并把 `upload-keystore.jks` 放到 `android/app/` 下（路径相对 `storeFile`）。
`android/app/build.gradle` 已按 Flutter 默认模板读取 `key.properties`，无需额外改动。

> 生成密钥库（仅首次）：
> ```bash
> keytool -genkey -v -keystore android/app/upload-keystore.jks \
>   -keyalg RSA -keysize 2048 -validity 10000 -alias upload
> ```

## 3. 构建 Release

```bash
flutter pub get
flutter build apk --release          # 产出 build/app/outputs/flutter-apk/app-release.apk
# 上架 Google Play 推荐用 AAB：
flutter build appbundle --release    # 产出 build/app/outputs/bundle/release/app-release.aab
```

- APK 直装：`adb install build/app/outputs/flutter-apk/app-release.apk`
- AAB 上传 Google Play / 国内商店后台。

## 4. 权限说明

`android/app/src/main/AndroidManifest.xml` 需包含：

- `INTERNET` —— 云端同步与抖店 API（Release 默认有）。
- 相机权限（`CAMERA`）—— `mobile_scanner` 扫码用；建议声明为**运行时动态申请**，并在设置页说明用途。
- 存储权限 —— 导出 Excel 时通过系统分享/目录选择落盘，Android 11+ 用分区存储，一般无需 `WRITE_EXTERNAL_STORAGE`。

> 若扫码功能不需要，可直接移除 `mobile_scanner` 依赖与相机权限，包体更小。

## 5. 注意事项

- 版本号在 `pubspec.yaml` 的 `version: 1.0.0+1`，每次上架递增构建号（+ 后面那位）。
- 真机测试建议先用 `--release` 或 `--profile` 验证，debug 与 release 在原生依赖行为上可能不同。
- 国内分发（非商店）注意部分厂商对未知来源安装的限制，按系统提示授权即可。
