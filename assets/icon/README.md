# App 圖示素材放置說明

請將下列檔案放在本資料夾，然後執行指令產生各平台圖示：

- ios-icon-1024.png
  - iOS 用 1024x1024 PNG，無圓角，背景可透明。
  - 建議邊界保留 10% 安全區，避免被系統角落裁切。

- adaptive-foreground.png
  - Android 自適應圖示「前景」圖層，建議 432x432 PNG（透明底）。
  - 請將 LOGO/符號置中，四周預留安全邊界（至少 12%）。

（可選）adaptive-background.png
- 若不想用純色背景，可改用圖片背景，並在 pubspec.yaml 將
  `adaptive_icon_background: "#0F0F10"` 改為
  `adaptive_icon_background: "assets/icon/adaptive-background.png"`。

產生指令
- flutter pub get
- flutter pub run flutter_launcher_icons

產出位置
- Android：`android/app/src/main/res/mipmap-*`（ic_launcher）
- iOS：`ios/Runner/Assets.xcassets/AppIcon.appiconset`

