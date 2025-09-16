#!/bin/bash

# Pixel 9 XL 模擬器熱重載啟動腳本
# 此腳本專門用於在 Pixel 9 XL 模擬器上啟動熱重載功能

echo "🚀 啟動 Podcast Player 熱重載模式"
echo "📱 目標設備：Pixel 9 XL (emulator-5554)"
echo "================================"

# 設定環境變數
export ANDROID_HOME=~/Library/Android/sdk
export ANDROID_SDK_ROOT=~/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools

# 檢查模擬器狀態
echo "📱 檢查模擬器狀態..."
adb devices

echo ""
echo "📱 檢查 Flutter 設備..."
flutter devices

echo ""
echo "🔥 啟動熱重載模式..."
echo "💡 提示："
echo "   - 按 'r' 鍵進行熱重載"
echo "   - 按 'R' 鍵進行熱重啟"
echo "   - 按 'q' 鍵退出"
echo "   - 按 'h' 鍵查看所有可用命令"
echo ""

# 啟動熱重載
flutter run -d emulator-5554 --hot
