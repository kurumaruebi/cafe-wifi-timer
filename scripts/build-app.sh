#!/bin/bash
# CafeWiFiTimer.app（メニューバーアプリのバンドル）をビルドする。
# Xcode不要。Swift Package Manager でビルドし、.app 構造を組み立てる。
#
# 位置情報（SSID判定に必要）の許可ダイアログを出すには、
# Info.plist と署名済みの .app バンドルが必要なため、このスクリプトを使う。
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="CafeWiFiTimer"
BUNDLE_ID="com.cafewifitimer.app"
BUILD_DIR=".build/release"
APP_DIR="build/${APP_NAME}.app"

echo "==> リリースビルド中..."
swift build -c release

echo "==> .app バンドルを作成中..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# Info.plist を生成
cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>CafeWiFiTimer</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <!-- Dockに出さずメニューバーのみに常駐 -->
    <key>LSUIElement</key>
    <true/>
    <!-- 位置情報の用途説明（SSID判定にのみ使用） -->
    <key>NSLocationUsageDescription</key>
    <string>接続中のWi-Fi（SSID）を判定して、無料Wi-Fiの残り時間を表示するために使用します。位置情報を外部に送信することはありません。</string>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>接続中のWi-Fi（SSID）を判定して、無料Wi-Fiの残り時間を表示するために使用します。位置情報を外部に送信することはありません。</string>
</dict>
</plist>
PLIST

echo "==> アドホック署名中..."
# ローカル実行用のアドホック署名。これにより位置情報の認可が機能する。
codesign --force --deep --sign - "${APP_DIR}"

echo ""
echo "✅ 完了: ${APP_DIR}"
echo ""
echo "起動するには:"
echo "  open ${APP_DIR}"
echo ""
echo "アプリケーションに入れるには:"
echo "  cp -r ${APP_DIR} /Applications/"
