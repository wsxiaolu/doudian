import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/widgets/app_card.dart';

/// ============================================================================
/// 首页统计卡片
///
/// 结构：图标胶囊 + 标题 + 大数字 + 辅助说明
/// 数字使用 TweenAnimationBuilder 做「滚动增长」入场，让数据有生命感。
/// ============================================================================
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.caption,
    this.onTap,
    this.emphasize = false,
  });

  final String title;

  /// 已格式化好的数值文本（如 ¥12,300.00）
  final String value;
  final IconData icon;

  /// 主色调，默认使用主题主色
  final Color? color;

  /// 底部辅助说明
  final String? caption;
  final VoidCallback? onTap;

  /// 是否作为重点卡片（数字更大、带强调色底纹）
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;
    final Color main = color ?? c.primary;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: main.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Icon(icon, size: 17, color: main),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.labelMedium?.copyWith(color: c.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // 数值切换时做淡入淡出，避免数字硬跳
          AnimatedSwitcher(
            duration: AppDuration.normal,
            switchInCurve: AppCurves.enter,
            transitionBuilder: (Widget child, Animation<double> anim) =>
                FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.25),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: Text(
              value,
              key: ValueKey<String>(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (emphasize ? t.displaySmall : t.headlineMedium)?.copyWith(
                color: emphasize ? main : c.textPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ),
          if (caption != null) ...<Widget>[
            const SizedBox(height: 3),
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// 自适应列数的统计卡片网格
///
/// 用 Wrap 而非 GridView：卡片高度自适应内容，不会出现固定行高截断，
/// 也方便在超宽屏上自然换行。
/// ----------------------------------------------------------------------------
class StatCardGrid extends StatelessWidget {
  const StatCardGrid({
    super.key,
    required this.columns,
    required this.children,
    this.spacing = AppSpacing.sm,
  });

  final int columns;
  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int cols = columns < 1 ? 1 : columns;
        final double itemWidth =
            (constraints.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            for (final Widget child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}
