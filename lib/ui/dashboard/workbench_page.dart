import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/models/shop_order.dart';
import '../../state/auth_provider.dart';
import '../../state/data_provider.dart';
import '../../ui/common/empty_state.dart';
import '../../ui/common/mini_chart.dart';
import '../../ui/common/stat_card.dart';
import '../../ui/orders/order_detail_page.dart';

/// ============================================================================
/// 工作台首页
///
/// 一眼掌握经营概况：今日/本月订单与销售额、待发货、未结售后，
/// 近 6 个月营收走势，以及最近订单快捷入口。
/// ============================================================================
class WorkbenchPage extends StatelessWidget {
  const WorkbenchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;
    final DataProvider data = context.watch<DataProvider>();
    final AuthProvider auth = context.watch<AuthProvider>();

    final String title = data.loaded
        ? '${auth.profile?.displayName ?? '老板'} · 经营概览'
        : '经营概览';

    return Scaffold(
      backgroundColor: c.background,
      body: DataProviderLoading(
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: context.pagePadding,
            vertical: AppSpacing.md,
          ),
          children: <Widget>[
            Text(title, style: t.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '数据实时同步自本地与云端，断网也能照常查看',
              style: t.bodySmall?.copyWith(color: c.textTertiary),
            ),
            const SizedBox(height: AppSpacing.lg),

            // —— 统计卡片 ——
            StatCardGrid(
              columns: context.statColumns,
              children: <Widget>[
                StatCard(
                  title: '今日订单',
                  value: '${data.todayOrderCount}',
                  icon: Icons.receipt_long_rounded,
                  caption: '笔',
                  color: c.primary,
                ),
                StatCard(
                  title: '今日销售额',
                  value: Fmt.moneyCompact(data.todayOrderAmount),
                  icon: Icons.paid_rounded,
                  caption: '实付金额',
                  color: c.accent,
                ),
                StatCard(
                  title: '本月销售额',
                  value: Fmt.moneyCompact(data.monthSales),
                  icon: Icons.trending_up_rounded,
                  caption: '实付金额',
                  color: c.success,
                ),
                StatCard(
                  title: '累计销售额',
                  value: Fmt.moneyCompact(data.totalSales),
                  icon: Icons.savings_rounded,
                  caption: '有效成交',
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
                  caption: '待处理/处理中',
                  color: data.openAfterSaleCount > 0 ? c.danger : c.textTertiary,
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
                  MiniRevenueChart(
                    data: data.monthlySalesTrend(months: AppConfig.statsMonthSpan),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // —— 最近订单 ——
            AppCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text('最近订单', style: t.titleMedium),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          // 跳到订单页（由 AppShell 控制索引，这里用回调不够直接，
                          // 但工作台不持有导航索引，故用最近订单的快捷查看足够）
                        },
                        child: const Text('查看全部'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (data.recentOrders(limit: 6).isEmpty)
                    const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: '还没有订单',
                      message: '抖店订单会自动同步，也可以手动新建线下订单',
                      compact: true,
                    )
                  else
                    ...data.recentOrders(limit: 6).map(
                      (o) => _RecentOrderTile(order: o),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

/// 最近订单单行
class _RecentOrderTile extends StatelessWidget {
  const _RecentOrderTile({required this.order});

  final ShopOrder order;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;
    final ShopOrder o = order;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<dynamic>(
            builder: (_) => OrderDetailPage(order: o),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(o.productSummary ?? '订单',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      '${o.orderNo} · ${Fmt.smartTime(o.orderTime)}',
                      style: t.labelSmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(Fmt.money(o.payAmount),
                      style: t.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700, color: c.textPrimary)),
                  const SizedBox(height: 3),
                  StatusChip(status: o.status, compact: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 数据未就绪时的占位
class DataProviderLoading extends StatelessWidget {
  const DataProviderLoading({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final DataProvider data = context.watch<DataProvider>();
    if (data.loaded) return child;
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxxl),
        child: CircularProgressIndicator(),
      ),
    );
  }
}
