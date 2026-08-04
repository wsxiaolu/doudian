import 'package:flutter/material.dart';

import '../../data/models/after_sale.dart';
import '../../data/models/order_status.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// ============================================================================
/// 订单状态标签
/// 每种状态各配一套「浅底 + 同色文字 + 小圆点」的低调配色
/// ============================================================================
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.status,
    this.compact = false,
  });

  final OrderStatus status;
  final bool compact;

  /// 状态 → 主色
  static Color colorOf(BuildContext context, OrderStatus status) {
    final AppColors c = context.colors;
    switch (status) {
      case OrderStatus.pendingPayment:
        return c.warning;
      case OrderStatus.pendingShip:
        return c.accent;
      case OrderStatus.shipped:
        return c.info;
      case OrderStatus.completed:
        return c.success;
      case OrderStatus.afterSale:
        return c.danger;
      case OrderStatus.cancelled:
        return c.textTertiary;
    }
  }

  /// 状态 → 浅底色
  static Color softColorOf(BuildContext context, OrderStatus status) {
    final AppColors c = context.colors;
    switch (status) {
      case OrderStatus.pendingPayment:
        return c.warningSoft;
      case OrderStatus.pendingShip:
        return c.accentSoft;
      case OrderStatus.shipped:
        return c.infoSoft;
      case OrderStatus.completed:
        return c.successSoft;
      case OrderStatus.afterSale:
        return c.dangerSoft;
      case OrderStatus.cancelled:
        return c.surfaceAlt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color main = colorOf(context, status);
    final Color soft = softColorOf(context, status);

    return AnimatedContainer(
      duration: AppDuration.fast,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: main.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: main, shape: BoxShape.circle),
          ),
          SizedBox(width: compact ? 5 : 6),
          Text(
            status.label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: main,
            ),
          ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// 通用小标签（面料、收款方式等）
/// ----------------------------------------------------------------------------
class SoftTag extends StatelessWidget {
  const SoftTag({
    super.key,
    required this.text,
    this.icon,
    this.color,
    this.background,
  });

  final String text;
  final IconData? icon;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Color fg = color ?? c.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? c.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.25,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// 售后进度标签
/// ----------------------------------------------------------------------------
class AfterSaleStageChip extends StatelessWidget {
  const AfterSaleStageChip({super.key, required this.stage, this.compact = false});

  final AfterSaleStage stage;
  final bool compact;

  /// 进度 → 主色
  static Color colorOf(BuildContext context, AfterSaleStage stage) {
    final AppColors c = context.colors;
    switch (stage) {
      case AfterSaleStage.pending:
        return c.warning;
      case AfterSaleStage.processing:
        return c.info;
      case AfterSaleStage.finished:
        return c.success;
      case AfterSaleStage.rejected:
        return c.danger;
    }
  }

  /// 进度 → 浅底色
  static Color softColorOf(BuildContext context, AfterSaleStage stage) {
    final AppColors c = context.colors;
    switch (stage) {
      case AfterSaleStage.pending:
        return c.warningSoft;
      case AfterSaleStage.processing:
        return c.infoSoft;
      case AfterSaleStage.finished:
        return c.successSoft;
      case AfterSaleStage.rejected:
        return c.dangerSoft;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color main = colorOf(context, stage);
    final Color soft = softColorOf(context, stage);

    return AnimatedContainer(
      duration: AppDuration.fast,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: main.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: main, shape: BoxShape.circle),
          ),
          SizedBox(width: compact ? 5 : 6),
          Text(
            stage.label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: main,
            ),
          ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// 可切换的筛选标签（订单列表顶部的状态筛选）
/// ----------------------------------------------------------------------------
class FilterChipButton extends StatelessWidget {
  const FilterChipButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Color main = color ?? c.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: AppDuration.fast,
          curve: AppCurves.enter,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? main.withValues(alpha: 0.13) : c.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? main.withValues(alpha: 0.45) : c.border,
              width: selected ? 1.3 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedDefaultTextStyle(
                duration: AppDuration.fast,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.2,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? main : c.textSecondary,
                ),
                child: Text(label),
              ),
              if (count != null && count! > 0) ...<Widget>[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected
                        ? main.withValues(alpha: 0.18)
                        : c.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: selected ? main : c.textTertiary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
