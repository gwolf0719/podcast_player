/// 這個檔案負責：
/// - 定義全局應用的視覺主題（僅明亮模式）
/// - 供 `MaterialApp.theme` 使用，統一顏色與元件風格
///
/// 輸入：無（純常數樣式）
/// 輸出：`ThemeData`（明亮模式）
import 'package:flutter/material.dart';

class AppTheme {
  /// 明亮模式主題
  /// 採用 Material 3 與以 indigo 為基底的色系
  static ThemeData get light => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      );
}
