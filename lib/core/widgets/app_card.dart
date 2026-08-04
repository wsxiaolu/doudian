import 'package:flutter/material.dart';

import '../animations/animated_tap.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// ============================================================================
/// 基础卡片
///
/// 视觉规范：
///   · 适中圆角 16
///   · 极轻的白→浅灰微渐变，让平面有呼吸感
///   · 柔和大扩散低透明度阴影，绝不出现厚重黑影
///   · 桌面端鼠标移入时阴影加深并微微上浮
/// ============================================================================
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin,
    this.onTap,
    this.onLongPress,
    this.radius = AppRadius.md,
    this.borderColor,
    this.background,
    this.useGradient = true,
    this.showShadow = true,
    this.width,
    this.height,
    this.accentBarColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;
  final Color? borderColor;
  final Color? background;

  /// 是否使用微渐变
  final bool useGradient;
  final bool showShadow;
  final double? width;
  final double? height;

  /// 左侧强调色竖条（订单状态标识用）
  final Color? accentBarColor;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final BorderRadius radius = BorderRadius.circular(widget.radius);

    Widget content = AnimatedContainer(
      duration: AppDuration.fast,
      curve: AppCurves.enter,
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: widget.useGradient ? null : (widget.background ?? c.surface),
        gradient: widget.useGradient
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.background != null
                    ? <Color>[widget.background!, widget.background!]
                    : c.cardGradient,
              )
            : null,
        borderRadius: radius,
        border: Border.all(
          color: widget.borderColor ??
              (_hovered ? c.borderStrong : c.border),
          width: 1,
        ),
        boxShadow: widget.showShadow
            ? (_hovered
                ? AppShadows.hover(c.shadowMedium)
                : AppShadows.card(c.shadowSoft))
            : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: <Widget>[
            if (widget.accentBarColor != null)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 3.5, color: widget.accentBarColor),
              ),
            Padding(padding: widget.padding, child: widget.child),
          ],
        ),
      ),
    );

    if (widget.onTap != null || widget.onLongPress != null) {
      content = MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedTap(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          enableHoverLift: false,
          scaleDown: 0.985,
          child: content,
        ),
      );
    }

    return content;
  }
}

/// ----------------------------------------------------------------------------
/// 分组容器：给一组内容加上标题与卡片背景
/// ----------------------------------------------------------------------------
class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return AppCard(
      padding: padding,
      margin: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 17, color: c.primary),
                const SizedBox(width: AppSpacing.xs),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}
