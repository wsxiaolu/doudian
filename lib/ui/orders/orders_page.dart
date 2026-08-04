import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_search_field.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/models/order_status.dart';
import '../../data/models/shop_order.dart';
import '../../state/data_provider.dart';
import '../common/empty_state.dart';
import 'batch_ship_page.dart';
import 'order_detail_page.dart';
import 'order_edit_page.dart';
import 'scan_page.dart';

/// ============================================================================
/// 订单列表
///
/// 顶部搜索 + 状态筛选 + 来源筛选 + 排序；卡片网格（桌面多列，手机单列）。
/// 提供「批量发货」「扫码发货」快捷入口。
/// ============================================================================
class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final DataProvider data = context.watch<DataProvider>();

    final List<ShopOrder> orders = data.visibleOrders;

    return Scaffold(
      backgroundColor: c.background,
      body: RefreshIndicator(
        onRefresh: () => data.refresh(),
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: context.pagePadding,
            vertical: AppSpacing.md,
          ),
          children: <Widget>[
            AppSearchField(
              hint: '搜索订单号 / 买家 / 收件人 / 商品 / 快递单号',
              onChanged: data.setOrderKeyword,
            ),
            const SizedBox(height: AppSpacing.md),

            // 状态筛选
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (final OrderStatus s in OrderStatusX.filterValues)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: FilterChipButton(
                        label: s.label,
                        count: data.statusCounts[s] ?? 0,
                        selected: data.orderStatusFilter.contains(s),
                        color: StatusChip.colorOf(context, s),
                        onTap: () => data.toggleOrderStatus(s),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // 来源筛选 + 排序
            Row(
              children: <Widget>[
                _SourceChip(
                  label: '全部',
                  selected: data.orderSourceFilter == null,
                  onTap: () => data.setOrderSourceFilter(null),
                ),
                _SourceChip(
                  label: '抖店',
                  selected: data.orderSourceFilter == OrderSource.douyin,
                  onTap: () => data.setOrderSourceFilter(OrderSource.douyin),
                ),
                _SourceChip(
                  label: '手动',
                  selected: data.orderSourceFilter == OrderSource.manual,
                  onTap: () => data.setOrderSourceFilter(OrderSource.manual),
                ),
                const Spacer(),
                _SortMenu(current: data.orderSortBy),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // 快捷操作
            Row(
              children: <Widget>[
                Expanded(
                  child: _QuickAction(
                    icon: Icons.playlist_add_check_rounded,
                    label: '批量发货',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<dynamic>(
                        builder: (_) => const BatchShipPage(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.qr_code_scanner_rounded,
                    label: '扫码发货',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<dynamic>(builder: (_) => const ScanPage()),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            if (orders.isEmpty)
              EmptyState(
                icon: Icons.receipt_long_outlined,
                title: '没有匹配的订单',
                message: data.orderKeyword.isNotEmpty ||
                        data.orderStatusFilter.isNotEmpty
                    ? '试试调整搜索或筛选条件'
                    : '抖店订单会自动同步，也可以新建线下订单',
                actionLabel: data.orderKeyword.isEmpty &&
                        data.orderStatusFilter.isEmpty
                    ? '新建订单'
                    : null,
                onAction: data.orderKeyword.isEmpty &&
                        data.orderStatusFilter.isEmpty
                    ? () => Navigator.of(context).push(
                          MaterialPageRoute<dynamic>(
                            builder: (_) => const OrderEditPage(),
                          ),
                        )
                    : null,
              )
            else
              _OrderGrid(orders: orders),

            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

/// 订单卡片网格（响应式列数）
class _OrderGrid extends StatelessWidget {
  const _OrderGrid({required this.orders});

  final List<ShopOrder> orders;

  @override
  Widget build(BuildContext context) {
    final int cols = context.listColumns;
    final double spacing = AppSpacing.sm;
    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        final double w =
            (constraints.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            for (int i = 0; i < orders.length; i++)
              SizedBox(
                width: w,
                child: _OrderCard(order: orders[i]),
              ),
          ],
        );
      },
    );
  }
}

/// 订单卡片
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final ShopOrder order;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;
    final ShopOrder o = order;

    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<dynamic>(builder: (_) => OrderDetailPage(order: o)),
      ),
      accentBarColor: StatusChip.colorOf(context, o.status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  o.productSummary ?? '订单',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              StatusChip(status: o.status, compact: true),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            o.orderNo,
            style: t.labelSmall?.copyWith(color: c.textTertiary),
          ),
          const SizedBox(height: 4),
          Text(
            (o.buyerNick ?? o.receiverName ?? '—'),
            style: t.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  Fmt.money(o.payAmount),
                  style: t.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.accent,
                  ),
                ),
              ),
              if (o.source == OrderSource.douyin)
                const SoftTag(text: '抖店', icon: Icons.cloud_rounded)
              else
                const SoftTag(text: '手动', icon: Icons.edit_rounded),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            Fmt.smartTime(o.orderTime),
            style: t.labelSmall,
          ),
          if (o.isShipOverdue)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.warningSoft,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '待发货已超时',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: c.warning),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 来源筛选小标签
class _SourceChip extends StatelessWidget {
  const _SourceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? c.primary.withValues(alpha: 0.12) : c.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: selected
                    ? c.primary.withValues(alpha: 0.45)
                    : c.border,
                width: selected ? 1.3 : 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? c.primary : c.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 排序菜单
class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.current});

  final OrderSortBy current;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return PopupMenuButton<OrderSortBy>(
      icon: Icon(Icons.sort_rounded, color: c.textSecondary, size: 20),
      tooltip: '排序',
      onSelected: (OrderSortBy v) =>
          context.read<DataProvider>().setOrderSortBy(v),
      itemBuilder: (BuildContext ctx) => <PopupMenuEntry<OrderSortBy>>[
        for (final OrderSortBy v in OrderSortBy.values)
          CheckedPopupMenuItem<OrderSortBy>(
            value: v,
            checked: v == current,
            child: Text(v.label),
          ),
      ],
    );
  }
}

/// 快捷操作按钮
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 18, color: c.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}
