#!/usr/bin/env bash
# ============================================================================
# 抖店订单管家 · 一键构建（macOS，仅用于打 iOS 包）
# 在 macOS 终端运行：bash scripts/build_ios.sh
# 前置：Xcode + CocoaPods + 已配置签名（Team / Provisioning Profile）
# ============================================================================
set -e
cd "$(dirname "$0")/.."

echo "[1/3] flutter pub get"
flutter pub get

echo "[2/3] pod install"
(cd ios && pod install)

echo "[3/3] build ios release"
# 先出归档产物（不带签名，签名交给 Xcode Organizer）
flutter build ios --release --no-codesign
# 如已配好描述文件，可直接出 IPA（失败不影响上面的产物）
flutter build ipa --release || echo "ipa 步骤跳过，请用 Xcode Organizer / Transporter 上传"

echo "Done. 产物在 build/ios/ ；用 Xcode Organizer 或 Transporter 上架/分发。"
