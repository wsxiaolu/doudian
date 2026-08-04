import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/widgets/app_button.dart';

/// ============================================================================
/// 空状态占位
///
/// 列表没有数据时不要给用户一片空白，而是给出「为什么空」＋「下一步做什么」。
/// 入场用淡入 + 轻微上浮，与全局动效语言保持一致。
/// ============================================================================
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;

  /// 主操作按钮文案，为空则不显示按钮
  final String? actionLabel;
  final VoidCallback? onAction;

  /// 紧凑模式：用于卡片内部的小面积留白
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: AppDuration.normal,
      curve: AppCurves.enter,
      builder: (BuildContext context, double v, Widget? child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 12), child: child),
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: compact ? AppSpacing.lg : AppSpacing.xxxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: compact ? 52 : 72,
                height: compact ? 52 : 72,
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.border),
                ),
                child: Icon(
                  icon,
                  size: compact ? 24 : 32,
                  color: c.textTertiary,
                ),
              ),
              SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: compact ? t.titleSmall : t.titleMedium,
              ),
              if (message != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xxs),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: t.bodySmall?.copyWith(color: c.textTertiary),
                  ),
                ),
              ],
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: actionLabel!,
                  icon: Icons.add_rounded,
                  size: AppButtonSize.small,
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// 加载占位：骨架条
/// ----------------------------------------------------------------------------
class LoadingPlaceholder extends StatelessWidget {
  const LoadingPlaceholder({super.key, this.text = '正在加载数据…'});

  final String text;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(c.accent),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(text, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
