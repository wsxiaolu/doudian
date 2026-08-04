import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../animations/page_transitions.dart';
import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_typography.dart';

/// ============================================================================
/// 主题装配
///
/// 亮色 / 暗色两套 ThemeData 全部由 [AppColors] 令牌驱动，
/// 想调整整体观感只需要改 app_colors.dart，这里不需要动。
/// ============================================================================
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(AppColors.light, Brightness.light);

  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  // ---------------------------------------------------------------------------
  // 核心装配逻辑
  // ---------------------------------------------------------------------------
  static ThemeData _build(AppColors c, Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: c.primary,
      brightness: brightness,
    ).copyWith(
      primary: c.primary,
      onPrimary: isDark ? const Color(0xFF13191F) : Colors.white,
      primaryContainer: c.primarySoft,
      onPrimaryContainer: c.primary,
      secondary: c.accent,
      onSecondary: c.textOnAccent,
      secondaryContainer: c.accentSoft,
      onSecondaryContainer: c.accent,
      surface: c.surface,
      onSurface: c.textPrimary,
      surfaceContainerHighest: c.surfaceAlt,
      error: c.danger,
      onError: Colors.white,
      outline: c.border,
      outlineVariant: c.border,
      shadow: c.shadowSoft,
      surfaceTint: Colors.transparent, // 关闭 M3 的染色叠加，保持底色纯净
    );

    final TextTheme textTheme = AppTypography.buildTextTheme(
      primary: c.textPrimary,
      secondary: c.textSecondary,
      tertiary: c.textTertiary,
    );

    // 全平台统一转场动画
    const SmoothPageTransitionsBuilder smooth = SmoothPageTransitionsBuilder();
    const PageTransitionsTheme pageTransitions = PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: smooth,
        TargetPlatform.iOS: smooth,
        TargetPlatform.windows: smooth,
        TargetPlatform.macOS: smooth,
        TargetPlatform.linux: smooth,
        TargetPlatform.fuchsia: smooth,
      },
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.surface,
      dividerColor: c.border,
      splashFactory: InkRipple.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: c.primarySoft.withValues(alpha: 0.45),
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: pageTransitions,
      extensions: <ThemeExtension<dynamic>>[c],

      // ---------------- 顶部栏：极简、无阴影、与页面底色融为一体 ----------------
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineMedium,
        iconTheme: IconThemeData(color: c.textSecondary, size: 22),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),

      // ---------------- 图标 ----------------
      iconTheme: IconThemeData(color: c.textSecondary, size: 20),
      primaryIconTheme: IconThemeData(color: c.primary, size: 20),

      // ---------------- 分割线 ----------------
      dividerTheme: DividerThemeData(
        color: c.border,
        thickness: 1,
        space: 1,
      ),

      // ---------------- 输入框：无边框填充式，聚焦时主色描边 ----------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: c.textTertiary),
        labelStyle: textTheme.bodyMedium?.copyWith(color: c.textSecondary),
        floatingLabelStyle: textTheme.labelMedium?.copyWith(color: c.primary),
        prefixIconColor: c.textTertiary,
        suffixIconColor: c.textTertiary,
        border: OutlineInputBorder(
          borderRadius: AppRadius.fieldRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.fieldRadius,
          borderSide: BorderSide(color: c.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.fieldRadius,
          borderSide: BorderSide(color: c.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.fieldRadius,
          borderSide: BorderSide(color: c.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.fieldRadius,
          borderSide: BorderSide(color: c.danger, width: 1.6),
        ),
        errorStyle: textTheme.labelSmall?.copyWith(color: c.danger),
      ),

      // ---------------- 文本选中 ----------------
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accent,
        selectionColor: c.accent.withValues(alpha: 0.22),
        selectionHandleColor: c.accent,
      ),

      // ---------------- 按钮 ----------------
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.textOnAccent,
          disabledBackgroundColor: c.surfaceAlt,
          disabledForegroundColor: c.textTertiary,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: 15,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.xs)),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.borderStrong),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: 14,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: 15,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // ---------------- 悬浮按钮 ----------------
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.accent,
        foregroundColor: c.textOnAccent,
        elevation: 3,
        focusElevation: 3,
        hoverElevation: 6,
        highlightElevation: 2,
        splashColor: Colors.white24,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
        ),
      ),

      // ---------------- 底部导航（移动端） ----------------
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.primarySoft,
        elevation: 0,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? c.primary : c.textTertiary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          final bool selected = states.contains(WidgetState.selected);
          return (textTheme.labelSmall ?? const TextStyle()).copyWith(
            color: selected ? c.primary : c.textTertiary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
      ),

      // ---------------- 侧边导航（桌面端） ----------------
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.primarySoft,
        elevation: 0,
        useIndicator: true,
        selectedIconTheme: IconThemeData(color: c.primary, size: 22),
        unselectedIconTheme: IconThemeData(color: c.textTertiary, size: 22),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: c.primary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle:
            textTheme.labelMedium?.copyWith(color: c.textTertiary),
      ),

      // ---------------- 底部弹出面板 ----------------
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.surfaceElevated,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: c.borderStrong,
        dragHandleSize: const Size(38, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.sheetRadius,
        ),
      ),

      // ---------------- 标签 Chip ----------------
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceAlt,
        selectedColor: c.primarySoft,
        disabledColor: c.surfaceAlt,
        side: BorderSide(color: c.border),
        labelStyle: textTheme.labelMedium ?? const TextStyle(),
        secondaryLabelStyle: textTheme.labelMedium ?? const TextStyle(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
        ),
      ),

      // ---------------- 开关 ----------------
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return isDark ? c.textTertiary : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) return c.accent;
          return c.surfaceAlt;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) return c.accent;
          return c.borderStrong;
        }),
      ),

      // ---------------- 加载指示器 ----------------
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.surfaceAlt,
        circularTrackColor: Colors.transparent,
      ),

      // ---------------- 提示气泡 ----------------
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? c.surfaceElevated : const Color(0xFF2C343D),
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        textStyle: textTheme.labelSmall?.copyWith(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        waitDuration: const Duration(milliseconds: 400),
      ),

      // ---------------- 轻提示 ----------------
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? c.surfaceElevated : const Color(0xFF2C343D),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: c.accent,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
        ),
      ),

      // ---------------- 列表项 ----------------
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 4,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
        ),
      ),

      // ---------------- 弹出菜单 ----------------
      popupMenuTheme: PopupMenuThemeData(
        color: c.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: c.shadowMedium,
        textStyle: textTheme.bodyMedium?.copyWith(color: c.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: c.border),
        ),
      ),
    );
  }
}
