# App 圖示設計規格（Podcast Player）

## 品牌方向
- 關鍵意象：播放、聲波、耳機、麥克風（避免過度複雜）
- 性格：穩重、專注、清晰（避免過亮或雜訊背景）
- 建議色票：
  - 主色：#0F0F10（深灰，Android 自適應背景預設）
  - 輔色：#4F8DF5（高亮可讀、對比佳）
  - 強調：#FFB547（操作重點）

## iOS 規格
- 畫布：1024×1024 PNG，無圓角、可透明。
- 安全區：四周保留 ≥10%（約 102px）避免圓角裁切吞字。
- 不建議：過多小字、小細節、邊緣對比不足。

## Android 規格（Adaptive Icon）
- 前景（foreground）：432×432 PNG，透明背景，圖形置中。
- 背景（background）：
  - 單色：#0F0F10（pubspec.yaml 已預設），或
  - 圖片：108×108 或向量填滿（改用 `adaptive-background.png`）。
- 安全區：前景四周預留 ≥12% 空白，確保各設備遮罩（圓形、方形、波浪）不裁切主體。

## 匯出與產生
- 將下列檔案放入 `assets/icon/`：
  - `ios-icon-1024.png`
  - `adaptive-foreground.png`
  - （可選）`adaptive-background.png`
- 執行：
  - `flutter pub get`
  - `flutter pub run flutter_launcher_icons`

## 檢查清單
- 在深色/淺色桌面對比是否足夠
- 小尺寸（48×48、32×32）辨識是否清晰
- Android 圓形遮罩是否裁切到關鍵元素
- iOS 自動加圓角後視覺平衡是否良好
