#!/bin/bash

# Android 測試環境設置腳本
# 此腳本用於驗證 Android 開發環境是否正確配置

echo "🚀 Android 測試環境驗證腳本"
echo "================================"

# 設定環境變數
export ANDROID_HOME=~/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools

echo "📱 檢查 Flutter 環境..."
flutter doctor -v

echo ""
echo "📱 檢查可用的模擬器..."
flutter emulators

echo ""
echo "📱 檢查連接的設備..."
flutter devices

echo ""
echo "🔧 ADB 設備狀態..."
adb devices

echo ""
echo "📱 啟動 Pixel 9 Pro XL 模擬器..."
flutter emulators --launch Pixel_9_Pro_XL_API_36 &

echo "⏳ 等待模擬器啟動 (30 秒)..."
sleep 30

echo ""
echo "📱 檢查模擬器是否已就緒..."
adb devices

echo ""
echo "📱 最終設備檢查..."
flutter devices

echo ""
echo "✅ 如果看到 emulator-5554 設備狀態為 'device'，表示環境設置成功！"
echo "🚀 可以使用以下命令測試專案："
echo "   flutter run"
echo ""
echo "🚗 Android Auto 模擬器可使用："
echo "   flutter emulators --launch Android_Auto_API_34"
