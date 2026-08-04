import 'package:flutter/material.dart';

/// ============================================================================
/// 字体排印令牌
///
/// 原则：清晰无衬线 + 字号层级拉开 + 重点金额/日期醒目突出。
/// 不引入网络字体，直接使用各平台优质中文无衬线系统字体，保证首屏零等待。
/// ============================================================================

class AppTypography {
  AppTypography._();

  /// 系统字体回退链：Windows / macOS / iOS / Android 全覆盖
  static const List<String> fontFallback = <String>[
    'PingFang SC', // macOS / iOS
    'HarmonyOS Sans SC', // 部分安卓
    'MiSans', // 小米
    'Source Han Sans CN',
    'Noto Sans SC',
    'Microsoft YaHei UI', // Windows
    'Microsoft YaHei',
    'Segoe UI',
    'Roboto',
    'Helvetica Neue',
    'Arial',
  ];

  /// 数字专用字号：金额、统计数字使用等宽数字，避免跳动
  static const List<FontFeature> tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static TextTheme buildTextTheme({
    required Color primary,
    required Color secondary,
    required Color tertiary,
  }) {
    TextStyle base(
      double size,
      FontWeight weight,
      Color color, {
      double height = 1.4,
      double letterSpacing = 0,
    }) {
      return TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
        fontFamilyFallback: fontFallback,
      );
    }

    return TextTheme(
      // —— 超大数字：首页营收总额 ——
      displayLarge: base(38, FontWeight.w700, primary, height: 1.15,
          letterSpacing: -0.8),
      displayMedium: base(30, FontWeight.w700, primary, height: 1.18,
          letterSpacing: -0.6),
      displaySmall: base(26, FontWeight.w600, primary, height: 1.2,
          letterSpacing: -0.4),

      // —— 页面 / 区块标题 ——
      headlineLarge: base(22, FontWeight.w600, primary, height: 1.3),
      headlineMedium: base(19, FontWeight.w600, primary, height: 1.3),
      headlineSmall: base(17, FontWeight.w600, primary, height: 1.35),

      // —— 卡片标题 / 列表主文案 ——
      titleLarge: base(16, FontWeight.w600, primary, height: 1.4),
      titleMedium: base(15, FontWeight.w600, primary, height: 1.4),
      titleSmall: base(14, FontWeight.w600, secondary, height: 1.4),

      // —— 正文 ——
      bodyLarge: base(15, FontWeight.w400, primary, height: 1.55),
      bodyMedium: base(14, FontWeight.w400, secondary, height: 1.55),
      bodySmall: base(13, FontWeight.w400, tertiary, height: 1.5),

      // —— 辅助 / 标签 ——
      labelLarge: base(14, FontWeight.w600, primary, height: 1.3,
          letterSpacing: 0.1),
      labelMedium: base(12.5, FontWeight.w500, secondary, height: 1.3,
          letterSpacing: 0.2),
      labelSmall: base(11.5, FontWeight.w500, tertiary, height: 1.3,
          letterSpacing: 0.3),
    );
  }
}

/// 金额、日期等「重点数字」的专用样式生成器
extension MoneyTextStyle on TextStyle {
  /// 转成等宽数字样式，金额刷新时不会左右跳动
  TextStyle get tabular => copyWith(fontFeatures: AppTypography.tabularFigures);
}
