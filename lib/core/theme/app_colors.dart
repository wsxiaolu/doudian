import 'package:flutter/material.dart';

/// ============================================================================
/// 配色令牌
///
/// 设计基调：现代极简轻奢商务风
///   · 主色  —— 低饱和「雾感灰蓝」，冷静、克制、有档次
///   · 强调色 —— 柔和「暖橘」，只用于按钮、提醒、重点数字，形成温度对比
///   · 底色  —— 浅灰白（亮色）/ 低亮度炭灰（暗色，杜绝纯黑）
///
/// 使用方式：`context.colors.accent`（见文件底部的 BuildContext 扩展）
/// ============================================================================

class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primary,
    required this.primaryHover,
    required this.primarySoft,
    required this.accent,
    required this.accentHover,
    required this.accentSoft,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceElevated,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnAccent,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
    required this.shadowSoft,
    required this.shadowMedium,
    required this.cardGradient,
    required this.heroGradient,
  });

  // —— 主色系 ——
  final Color primary; // 雾感灰蓝主色
  final Color primaryHover; // 悬停/按下态
  final Color primarySoft; // 主色浅底（标签、选中背景）

  // —— 强调色 ——
  final Color accent; // 柔和暖橘
  final Color accentHover;
  final Color accentSoft; // 暖橘浅底

  // —— 背景与容器 ——
  final Color background; // 页面底色
  final Color surface; // 卡片、面板
  final Color surfaceAlt; // 次级容器（输入框、分组底）
  final Color surfaceElevated; // 浮层：弹窗、菜单

  // —— 描边 ——
  final Color border;
  final Color borderStrong;

  // —— 文字 ——
  final Color textPrimary; // 标题、金额
  final Color textSecondary; // 正文
  final Color textTertiary; // 辅助说明、占位
  final Color textOnAccent; // 强调色按钮上的文字

  // —— 语义色（订单状态等） ——
  final Color success; // 已完成
  final Color successSoft;
  final Color warning; // 待付款
  final Color warningSoft;
  final Color danger; // 逾期未收款
  final Color dangerSoft;
  final Color info; // 生产中
  final Color infoSoft;

  // —— 阴影：轻薄柔和，绝不厚重 ——
  final Color shadowSoft;
  final Color shadowMedium;

  // —— 渐变 ——
  final List<Color> cardGradient; // 卡片微渐变
  final List<Color> heroGradient; // 首页头图/重点卡片渐变

  // ===========================================================================
  // 亮色主题
  // ===========================================================================
  static const AppColors light = AppColors(
    primary: Color(0xFF5F7D95),
    primaryHover: Color(0xFF4E6B82),
    primarySoft: Color(0xFFE9EFF4),
    accent: Color(0xFFE29268),
    accentHover: Color(0xFFD3814F),
    accentSoft: Color(0xFFFBEEE4),
    background: Color(0xFFF5F7F9),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF0F3F6),
    surfaceElevated: Color(0xFFFFFFFF),
    border: Color(0xFFE6EAEF),
    borderStrong: Color(0xFFD3DAE2),
    textPrimary: Color(0xFF1E252D),
    textSecondary: Color(0xFF66727F),
    textTertiary: Color(0xFF9BA5B0),
    textOnAccent: Color(0xFFFFFFFF),
    success: Color(0xFF5E9B7E),
    successSoft: Color(0xFFE8F2ED),
    warning: Color(0xFFD79A54),
    warningSoft: Color(0xFFFBF1E3),
    danger: Color(0xFFC0736F),
    dangerSoft: Color(0xFFFAEBEA),
    info: Color(0xFF5F7D95),
    infoSoft: Color(0xFFE9EFF4),
    shadowSoft: Color(0x0A1E2D3D),
    shadowMedium: Color(0x141E2D3D),
    cardGradient: [Color(0xFFFFFFFF), Color(0xFFFBFCFD)],
    heroGradient: [Color(0xFF6C8AA3), Color(0xFF52708A)],
  );

  // ===========================================================================
  // 暗色主题（低亮度炭灰，不用纯黑）
  // ===========================================================================
  static const AppColors dark = AppColors(
    primary: Color(0xFF8FAEC6),
    primaryHover: Color(0xFFA3BED3),
    primarySoft: Color(0xFF25313C),
    accent: Color(0xFFE9A87F),
    accentHover: Color(0xFFF2B991),
    accentSoft: Color(0xFF3A2E26),
    background: Color(0xFF16181B),
    surface: Color(0xFF1D2024),
    surfaceAlt: Color(0xFF23272C),
    surfaceElevated: Color(0xFF262A2F),
    border: Color(0xFF2C3137),
    borderStrong: Color(0xFF3A4048),
    textPrimary: Color(0xFFE9ECEF),
    textSecondary: Color(0xFFA6AEB8),
    textTertiary: Color(0xFF737C86),
    textOnAccent: Color(0xFF221A14),
    success: Color(0xFF7FB89A),
    successSoft: Color(0xFF1F2C27),
    warning: Color(0xFFD9AB6E),
    warningSoft: Color(0xFF302820),
    danger: Color(0xFFD08B87),
    dangerSoft: Color(0xFF312422),
    info: Color(0xFF8FAEC6),
    infoSoft: Color(0xFF25313C),
    shadowSoft: Color(0x33000000),
    shadowMedium: Color(0x4D000000),
    cardGradient: [Color(0xFF212529), Color(0xFF1C1F23)],
    heroGradient: [Color(0xFF33465A), Color(0xFF263442)],
  );

  @override
  AppColors copyWith({
    Color? primary,
    Color? primaryHover,
    Color? primarySoft,
    Color? accent,
    Color? accentHover,
    Color? accentSoft,
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceElevated,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textOnAccent,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? info,
    Color? infoSoft,
    Color? shadowSoft,
    Color? shadowMedium,
    List<Color>? cardGradient,
    List<Color>? heroGradient,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      primaryHover: primaryHover ?? this.primaryHover,
      primarySoft: primarySoft ?? this.primarySoft,
      accent: accent ?? this.accent,
      accentHover: accentHover ?? this.accentHover,
      accentSoft: accentSoft ?? this.accentSoft,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textOnAccent: textOnAccent ?? this.textOnAccent,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
      shadowSoft: shadowSoft ?? this.shadowSoft,
      shadowMedium: shadowMedium ?? this.shadowMedium,
      cardGradient: cardGradient ?? this.cardGradient,
      heroGradient: heroGradient ?? this.heroGradient,
    );
  }

  /// 主题切换时的颜色插值 —— 让亮暗切换是「渐变」而不是「闪一下」
  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    List<Color> lerpList(List<Color> a, List<Color> b) {
      return List<Color>.generate(
        a.length,
        (i) => Color.lerp(a[i], b[i], t) ?? a[i],
      );
    }

    return AppColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryHover: Color.lerp(primaryHover, other.primaryHover, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentHover: Color.lerp(accentHover, other.accentHover, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textOnAccent: Color.lerp(textOnAccent, other.textOnAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSoft: Color.lerp(infoSoft, other.infoSoft, t)!,
      shadowSoft: Color.lerp(shadowSoft, other.shadowSoft, t)!,
      shadowMedium: Color.lerp(shadowMedium, other.shadowMedium, t)!,
      cardGradient: lerpList(cardGradient, other.cardGradient),
      heroGradient: lerpList(heroGradient, other.heroGradient),
    );
  }
}

/// 语法糖：任何 Widget 里直接写 `context.colors.accent`
extension AppColorsX on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
