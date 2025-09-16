# 🔥 常駐熱重載使用指南

## 📖 概述

本專案提供多種熱重載解決方案，讓您在開發過程中享受無縫的程式碼更新體驗。

## 🛠️ 可用的熱重載工具

### 1. 熱重載管理器 (推薦)
```bash
# 啟動熱重載
./hot_reload_manager.sh start

# 停止熱重載
./hot_reload_manager.sh stop

# 重啟熱重載
./hot_reload_manager.sh restart

# 檢查狀態
./hot_reload_manager.sh status

# 查看日誌
./hot_reload_manager.sh logs
```

### 2. Attach 模式熱重載
```bash
# 連接到運行中的應用
./hot_reload_attach.sh
```

### 3. 原始熱重載腳本
```bash
# 傳統熱重載方式
./hot_reload_pixel9xl.sh
```

### 4. 常駐監控熱重載
```bash
# 帶自動重連功能的熱重載
./persistent_hot_reload.sh
```

## 🎯 VS Code 整合

### 啟動配置
在 VS Code 中按 `F5` 或使用以下配置：

- **🔥 Pixel 9 XL 熱重載** - 帶熱重載的除錯模式
- **🚀 Pixel 9 XL 一般運行** - 標準運行模式  
- **🧪 Pixel 9 XL 除錯模式** - 啟用斷言的除錯模式

### 任務快捷鍵
按 `Ctrl+Shift+P` (macOS: `Cmd+Shift+P`) 搜尋以下任務：

- **🔥 啟動常駐熱重載**
- **🛑 停止熱重載**
- **🔄 重啟熱重載**
- **📊 檢查熱重載狀態**
- **📋 查看熱重載日誌**

## 💡 使用建議

### 推薦工作流程

1. **啟動模擬器**
   ```bash
   flutter emulators --launch Pixel_9_Pro_XL
   ```

2. **啟動常駐熱重載**
   ```bash
   ./hot_reload_manager.sh start
   ```

3. **開始開發**
   - 修改程式碼會自動觸發熱重載
   - 在終端中按 `r` 進行手動熱重載
   - 按 `R` 進行熱重啟

4. **結束開發**
   ```bash
   ./hot_reload_manager.sh stop
   ```

### 熱重載快捷鍵

當熱重載啟動後，可以使用以下快捷鍵：

- `r` - 熱重載 (Hot Reload)
- `R` - 熱重啟 (Hot Restart)
- `h` - 顯示幫助資訊
- `c` - 清除螢幕
- `q` - 退出熱重載

## 🔧 故障排除

### 常見問題

#### 1. 熱重載無法啟動
```bash
# 檢查模擬器狀態
flutter devices

# 檢查應用是否安裝
adb shell pm list packages | grep podcast_player

# 重新安裝應用
flutter install -d emulator-5554
```

#### 2. 熱重載連接中斷
```bash
# 重啟熱重載
./hot_reload_manager.sh restart

# 或使用 attach 模式
./hot_reload_attach.sh
```

#### 3. 編譯錯誤
```bash
# 清理專案
flutter clean && flutter pub get

# 重新編譯
flutter run -d emulator-5554
```

### 日誌檢查

```bash
# 查看熱重載日誌
tail -f hot_reload.log

# 查看 Flutter 日誌
flutter logs

# 查看 ADB 日誌
adb logcat | grep flutter
```

## 📊 效能優化

### 熱重載效能提升

1. **使用 SSD 存儲**：確保專案位於 SSD 上
2. **關閉不必要的應用**：釋放系統資源
3. **使用 Attach 模式**：連接到已運行的應用更快
4. **避免大型資產變更**：圖片等資產變更需要熱重啟

### 記憶體管理

```bash
# 檢查模擬器記憶體使用
adb shell cat /proc/meminfo

# 清理模擬器緩存
adb shell pm clear com.example.podcast_player
```

## 🎮 進階功能

### 自動化腳本

您可以建立自己的自動化腳本：

```bash
#!/bin/bash
# 我的開發環境啟動腳本

echo "🚀 啟動開發環境..."

# 啟動模擬器
flutter emulators --launch Pixel_9_Pro_XL &

# 等待模擬器啟動
sleep 30

# 啟動熱重載
./hot_reload_manager.sh start

echo "✅ 開發環境就緒！"
```

### 多設備熱重載

```bash
# 為不同設備建立專用腳本
flutter run -d chrome --hot          # Web 版本
flutter run -d emulator-5554 --hot   # Android 模擬器
flutter run -d macos --hot           # macOS 版本
```

## 📝 注意事項

1. **熱重載限制**：
   - 無法重載 main() 函數變更
   - 無法重載全域變數初始化
   - 無法重載靜態欄位變更

2. **熱重啟場景**：
   - 新增 import 語句
   - 修改 main() 函數
   - 修改 initState() 方法

3. **最佳實踐**：
   - 保持程式碼結構穩定
   - 使用 StatefulWidget 進行狀態管理
   - 避免在建構函數中進行複雜操作

---

**開發愉快！** 🎉 如有問題，請查看日誌檔案或重啟相關服務。
