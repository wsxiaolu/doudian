import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/models/order_status.dart';
import '../../data/models/after_sale.dart';
import '../../state/auth_provider.dart';
import '../../state/data_provider.dart';
import '../../ui/common/empty_state.dart';
import '../../ui/common/mini_chart.dart';
import '../../ui/common/stat_card.dart';

/// ============================================================================
/// 数据看板
///
/// 经营全貌一屏掌握：累计/本月/今日销售额、订单量、待发货、未结售后、
/// 退款总额、近 N 月营收走势、热销商品 TOP、订单状态分布、售后进度分布。
/// 全部基于 [DataProvider] 的内存统计，断网也能查看，数据一变即时刷新。
/// ============================================================================
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;
    final DataProvider data = context.watch<DataProvider>();
    final AuthProvider auth = context.watch<AuthProvider>();

    final DateTime now = DateTime.now();
    final DateTime monthStart = DateTime(now.year, now.month);
    final int monthOrderCount = data.orders
        .where((o) => !o.orderTime.isBefore(monthStart))
        .length;

    final List<({String label, double amount})> trend =
        data.monthlySalesTrend(months: AppConfig.statsMonthSpan);
    final List<({String name, int quantity, double amount})> top =
        data.topProducts(limit: 8);

    final Map<OrderStatus, int> statusCounts = data.statusCounts;
    final Map<AfterSaleStage, int> stageCounts = data.afterSaleStageCounts;

    final Widget body = ListView(
      padding: EdgeInsets.symmetric(
        horizontal: context.pagePadding,
        vertical: AppSpacing.md,
      ),
      children: <Widget>[
        Text(
          '${auth.profile?.displayName ?? '老板'} · 数据看板',
          style: t.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '覆盖全部订单与售后，按成交状态实时统计',
          style: t.bodySmall?.copyWith(color: c.textTertiary),
        ),
        const SizedBox(height: AppSpacing.lg),

        // —— 关键指标卡片 ——
        StatCardGrid(
          columns: context.statColumns,
          children: <Widget>[
            StatCard(
              title: '累计销售额',
              value: Fmt.moneyCompact(data.totalSales),
              icon: Icons.savings_rounded,
              caption: '有效成交合计',
              color: c.accent,
              emphasize: true,
            ),
            StatCard(
              title: '本月销售额',
              value: Fmt.moneyCompact(data.monthSales),
              icon: Icons.trending_up_rounded,
              caption: '实付金额',
              color: c.success,
            ),
            StatCard(
              title: '今日销售额',
              value: Fmt.moneyCompact(data.todayOrderAmount),
              icon: Icons.paid_rounded,
              caption: '实付金额',
              color: c.primary,
            ),
            StatCard(
              title: '本月订单',
              value: '$monthOrderCount',
              icon: Icons.receipt_long_rounded,
              caption: '笔',
              color: c.info,
            ),
            StatCard(
              title: '待发货',
              value: '${data.pendingShipCount}',
              icon: Icons.local_shipping_rounded,
              caption: data.shipOverdueCount > 0
                  ? '${data.shipOverdueCount} 笔已超时'
                  : '笔',
              color: data.shipOverdueCount > 0 ? c.warning : c.accent,
            ),
            StatCard(
              title: '未结售后',
              value: '${data.openAfterSaleCount}',
              icon: Icons.assignment_return_rounded,
              caption: '待处理 / 处理中',
              color: data.openAfterSaleCount > 0 ? c.danger : c.textTertiary,
            ),
            StatCard(
              title: '退款总额',
              value: Fmt.moneyCompact(data.totalRefundAmount),
              icon: Icons.price_change_rounded,
              caption: '售后退款合计',
              color: c.info,
            ),
            StatCard(
              title: '累计订单',
              value: '${data.orders.length}',
              icon: Icons.inventory_2_outlined,
              caption: '全部订单',
              color: c.primary,
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),

        // —— 营收走势 ——
        AppCard(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('近 ${AppConfig.statsMonthSpan} 个月销售额',
                  style: t.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              MiniRevenueChart(data: trend),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // —— 热销商品 ——
        AppSectionCard(
          title: '热销商品 TOP ${top.length}',
          icon: Icons.star_rounded,
          child: top.isEmpty
              ? const EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: '还没有销售数据',
                  message: '订单产生后，这里会按销量展示排名靠前的商品',
                  compact: true,
                )
              : Column(
                  children: <Widget>[
                    for (int i = 0; i < top.length; i++)
                      _TopProductRow(
                        rank: i + 1,
                        name: top[i].name,
                        quantity: top[i].quantity,
                        amount: top[i].amount,
                        maxQuantity: top.first.quantity,
                      ),
                  ],
                ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // —— 订单状态分布 ——
        AppSectionCard(
          title: '订单状态分布',
          icon: Icons.pie_chart_rounded,
          child: Column(
            children: <Widget>[
              for (final OrderStatus s in OrderStatusX.filterValues)
                _DistributionRow(
                  label: StatusChip(status: s),
                  count: statusCounts[s] ?? 0,
                  color: StatusChip.colorOf(context, s),
                  max: _maxOf(statusCounts.values),
                ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // —— 售后进度分布 ——
        AppSectionCard(
          title: '售后进度分布',
          icon: Icons.assignment_return_rounded,
          child: Column(
            children: <Widget>[
              for (final AfterSaleStage s in AfterSaleStageX.values)
                _DistributionRow(
                  label: AfterSaleStageChip(stage: s),
                  count: stageCounts[s] ?? 0,
                  color: AfterSaleStageChip.colorOf(context, s),
                  max: _maxOf(stageCounts.values),
                ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),
      ],
    );

    return Scaffold(
      backgroundColor: c.background,
      body: data.loaded
          ? body
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xxxl),
                child: CircularProgressIndicator(),
              ),
            ),
    );
  }

  static int _maxOf(Iterable<int> values) {
    int m = 0;
    for (final int v in values) {
      if (v > m) m = v;
    }
    return m;
  }
}

/// 热销商品单行：名次 + 名称 + 销量 + 金额 + 占比条
class _TopProductRow extends StatelessWidget {
  const _TopProductRow({
    required this.rank,
    required this.name,
    required this.quantity,
    required this.amount,
    required this.maxQuantity,
  });

  final int rank;
  final String name;
  final int quantity;
  final double amount;
  final int maxQuantity;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;
    final double ratio = maxQuantity > 0 ? quantity / maxQuantity : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rank <= 3 ? c.accentSoft : c.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  '$rank',
                  style: t.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: rank <= 3 ? c.accent : c.textTertiary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$quantity 件',
                style: t.labelMedium?.copyWith(color: c.textSecondary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                Fmt.money(amount),
                style: t.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: ratio),
            duration: AppDuration.page,
            curve: AppCurves.enter,
            builder: (_, double v, __) => FractionallySizedBox(
              widthFactor: v,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[c.accent, c.accentHover],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 分布条形行：标签 + 数量 + 占比条（状态分布 / 售后进度分布复用）
class _DistributionRow extends StatelessWidget {
  const _DistributionRow({
    required this.label,
    required this.count,
    required this.color,
    required this.max,
  });

  final Widget label;
  final int count;
  final Color color;
  final int max;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;
    final double ratio = max > 0 ? count / max : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              label,
              const Spacer(),
              Text(
                '$count',
                style: t.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: ratio),
            duration: AppDuration.page,
            curve: AppCurves.enter,
            builder: (_, double v, __) => FractionallySizedBox(
              widthFactor: v,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
