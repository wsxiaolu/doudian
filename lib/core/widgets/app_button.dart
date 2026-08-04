import 'package:flutter/material.dart';

import '../animations/animated_tap.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// 按钮视觉层级
enum AppButtonVariant {
  /// 强调色实心 —— 页面主操作（保存、登记收款）
  primary,

  /// 主色实心 —— 次一级主操作
  secondary,

  /// 描边 —— 取消、次要操作
  outline,

  /// 纯文字 —— 弱操作
  ghost,

  /// 危险操作 —— 删除
  danger,
}

/// ============================================================================
/// 统一按钮
///
/// 内置：加载态、图标、宽度撑满、柔和点按缩放反馈
/// ============================================================================
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expanded = false,
    this.size = AppButtonSize.medium,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool expanded;
  final AppButtonSize size;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final bool disabled = onPressed == null || loading;

    late final Color bg;
    late final Color fg;
    late final Color? borderColor;

    switch (variant) {
      case AppButtonVariant.primary:
        bg = c.accent;
        fg = c.textOnAccent;
        borderColor = null;
      case AppButtonVariant.secondary:
        bg = c.primary;
        fg = Colors.white;
        borderColor = null;
      case AppButtonVariant.outline:
        bg = Colors.transparent;
        fg = c.textPrimary;
        borderColor = c.borderStrong;
      case AppButtonVariant.ghost:
        bg = Colors.transparent;
        fg = c.primary;
        borderColor = null;
      case AppButtonVariant.danger:
        bg = c.dangerSoft;
        fg = c.danger;
        borderColor = c.danger.withValues(alpha: 0.35);
    }

    final EdgeInsets padding = switch (size) {
      AppButtonSize.small => const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      AppButtonSize.medium => const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      AppButtonSize.large => const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
    };
    final double fontSize = switch (size) {
      AppButtonSize.small => 13,
      AppButtonSize.medium => 14.5,
      AppButtonSize.large => 15.5,
    };
    final double iconSize = switch (size) {
      AppButtonSize.small => 15,
      AppButtonSize.medium => 17,
      AppButtonSize.large => 19,
    };

    final Widget content = AnimatedContainer(
      duration: AppDuration.fast,
      curve: AppCurves.enter,
      padding: padding,
      decoration: BoxDecoration(
        color: disabled ? bg.withValues(alpha: 0.45) : bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: borderColor != null
            ? Border.all(
                color: disabled
                    ? borderColor.withValues(alpha: 0.4)
                    : borderColor,
              )
            : null,
        boxShadow: (variant == AppButtonVariant.primary && !disabled)
            ? <BoxShadow>[
                BoxShadow(
                  color: c.accent.withValues(alpha: 0.28),
                  blurRadius: 16,
                  spreadRadius: -4,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          // 加载态与图标之间做柔和切换，不会突兀跳变
          AnimatedSwitcher(
            duration: AppDuration.fast,
            transitionBuilder: (Widget child, Animation<double> anim) =>
                FadeTransition(
              opacity: anim,
              child: ScaleTransition(scale: anim, child: child),
            ),
            child: loading
                ? SizedBox(
                    key: const ValueKey<String>('loading'),
                    width: iconSize,
                    height: iconSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(fg),
                    ),
                  )
                : (icon != null
                    ? Icon(icon,
                        key: ValueKey<IconData>(icon!),
                        size: iconSize,
                        color: disabled ? fg.withValues(alpha: 0.6) : fg)
                    : const SizedBox.shrink(key: ValueKey<String>('none'))),
          ),
          if (loading || icon != null) const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: disabled ? fg.withValues(alpha: 0.6) : fg,
              height: 1.2,
            ),
          ),
        ],
      ),
    );

    final Widget wrapped = AnimatedTap(
      onTap: disabled ? null : onPressed,
      scaleDown: 0.96,
      enableHoverLift: !disabled,
      hoverLift: 1.5,
      child: content,
    );

    return expanded ? SizedBox(width: double.infinity, child: wrapped) : wrapped;
  }
}

enum AppButtonSize { small, medium, large }

/// ----------------------------------------------------------------------------
/// 圆形图标按钮（顶部栏、卡片角标常用）
/// ----------------------------------------------------------------------------
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 38,
    this.iconSize = 19,
    this.color,
    this.background,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color? color;
  final Color? background;

  /// 右上角小红点数字，0 表示不显示
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;

    Widget button = AnimatedTap(
      onTap: onPressed,
      scaleDown: 0.9,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background ?? c.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: c.border),
        ),
        child: Icon(icon, size: iconSize, color: color ?? c.textSecondary),
      ),
    );

    if (badgeCount > 0) {
      button = Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          button,
          Positioned(
            right: -3,
            top: -3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              constraints: const BoxConstraints(minWidth: 17),
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: c.surface, width: 1.5),
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: c.textOnAccent,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
