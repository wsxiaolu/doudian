import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/app_icon_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/models/after_sale.dart';
import '../../data/models/order_item.dart';
import '../../data/models/order_status.dart';
import '../../data/models/shop_order.dart';
import '../../state/auth_provider.dart';
import '../../state/data_provider.dart';
import '../aftersales/after_sale_edit_page.dart';
import '../orders/order_edit_page.dart';

/// ============================================================================
/// 订单详情
///
/// 展示订单完整信息、商品明细、关联售后，并提供：发货、流转状态、编辑、删除。
/// 数据始终从 [DataProvider] 按 id 实时取最新，保证操作后界面同步刷新。
/// ============================================================================
class OrderDetailPage extends StatelessWidget {
  const OrderDetailPage({super.key, required this.order});

  final ShopOrder order;

  @override
  Widget build(BuildContext context) {
    final DataProvider data = context.watch<DataProvider>();
    final ShopOrder? live = data.orderById(order.id);
    if (live == null) {
      // 已被删除
      Future<void>.microtask(() => Navigator.of(context).maybePop());
      return const Scaffold();
    }
    final ShopOrder o = live;

    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;
    final AuthProvider auth = context.watch<AuthProvider>();

    final List<AfterSale> after = data.afterSalesOfOrder(o.id);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text('订单详情', style: t.titleLarge),
        actions: <Widget>[
          AppIconButton(
            icon: Icons.edit_outlined,
            tooltip: '编辑',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<dynamic>(builder: (_) => OrderEditPage(order: o)),
            ),
          ),
          AppIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: '删除',
            color: c.danger,
            onPressed: () => _delete(context, o),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: context.pagePadding,
          vertical: AppSpacing.md,
        ),
        children: <Widget>[
          // 头部
          AppCard(
            accentBarColor: StatusChip.colorOf(context, o.status),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        o.productSummary ?? '订单',
                        style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    StatusChip(status: o.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(o.orderNo,
                    style: t.labelSmall?.copyWith(color: c.textTertiary)),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    _AmountBlock(label: '实付', value: Fmt.money(o.payAmount)),
                    _AmountBlock(label: '总额', value: Fmt.money(o.totalAmount)),
                    _AmountBlock(label: '运费', value: Fmt.money(o.postAmount)),
                    if (o.discountAmount > 0)
                      _AmountBlock(
                        label: '优惠', value: '-${Fmt.money(o.discountAmount)}'),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const Divider(),
                _InfoRow(icon: Icons.source_outlined, label: '来源',
                    value: o.source.label),
                if (o.hasTracking)
                  _InfoRow(icon: Icons.local_shipping_rounded, label: '物流',
                      value: '${o.logisticsName ?? ''} ${o.trackingNo ?? ''}'),
                _InfoRow(icon: Icons.access_time_rounded, label: '下单',
                    value: Fmt.dateTime(o.orderTime)),
                if (o.payTime != null)
                  _InfoRow(icon: Icons.paid_rounded, label: '付款',
                      value: Fmt.dateTime(o.payTime)),
                if (o.shipTime != null)
                  _InfoRow(icon: Icons.local_shipping_rounded, label: '发货',
                      value: Fmt.dateTime(o.shipTime)),
                if (o.finishTime != null)
                  _InfoRow(icon: Icons.check_circle_outline_rounded, label: '完成',
                      value: Fmt.dateTime(o.finishTime)),
                if ((o.buyerNick ?? '').isNotEmpty)
                  _InfoRow(icon: Icons.person_outline_rounded, label: '买家',
                      value: o.buyerNick!),
                if ((o.receiverName ?? '').isNotEmpty)
                  _InfoRow(icon: Icons.location_on_outlined, label: '收件人',
                      value: '${o.receiverName} ${o.receiverPhone ?? ''}'),
                if ((o.receiverAddress ?? '').isNotEmpty)
                  _InfoRow(icon: Icons.map_outlined, label: '地址',
                      value: o.receiverAddress!),
                if ((o.remark ?? '').isNotEmpty)
                  _InfoRow(icon: Icons.notes_rounded, label: '备注',
                      value: o.remark!),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 商品明细
          AppCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('商品明细', style: t.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                ...o.items.map((OrderItem it) => _ItemRow(item: it)),
                if (o.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('（无明细）', style: t.labelSmall),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 关联售后
          if (after.isNotEmpty) ...<Widget>[
            AppCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('关联售后', style: t.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  ...after.map((AfterSale a) => _AfterSaleTile(a: a)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // 操作按钮
          Row(
            children: <Widget>[
              if (o.canShip)
                Expanded(
                  child: AppButton(
                    label: '发货',
                    icon: Icons.local_shipping_rounded,
                    onPressed: () => _ship(context, o),
                  ),
                )
              else
                Expanded(
                  child: AppButton(
                    label: '流转状态',
                    variant: AppButtonVariant.outline,
                    icon: Icons.swap_horiz_rounded,
                    onPressed: () => _changeStatus(context, o),
                  ),
                ),
              if (auth.status == AuthStatus.signedIn ||
                  !o.hasTracking) ...<Widget>[
                if (o.canShip || !o.hasTracking) const SizedBox(width: AppSpacing.sm),
                if (!o.canShip && o.hasTracking)
                  Expanded(
                    child: AppButton(
                      label: '流转状态',
                      variant: AppButtonVariant.outline,
                      icon: Icons.swap_horiz_rounded,
                      onPressed: () => _changeStatus(context, o),
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, ShopOrder o) async {
    final bool ok = await AppFeedback.confirm(
      context: context,
      title: '删除订单',
      message: '删除后将从本地移除，并同步到云端（可软删除恢复）。确定继续？',
      confirmText: '删除',
      danger: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok) return;
    await context.read<DataProvider>().deleteOrder(o);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _ship(BuildContext context, ShopOrder o) async {
    final ({ShopOrder order, String? uploadError})? res =
        await ShipSheet.show(context, o);
    if (res != null && context.mounted) {
      if (res.uploadError != null) {
        AppFeedback.toast(
          context, '已发货，但回传抖店失败：${res.uploadError}', type: ToastType.warning);
      } else {
        AppFeedback.toast(context, '发货成功', type: ToastType.success);
      }
    }
  }

  Future<void> _changeStatus(BuildContext context, ShopOrder o) async {
    final OrderStatus? next = await StatusSheet.show(context, o.status);
    if (next != null && context.mounted) {
      await context.read<DataProvider>().changeOrderStatus(o, next);
      AppFeedback.toast(context, '已更新为「${next.label}」', type: ToastType.success);
    }
  }
}

/// 金额小方块
class _AmountBlock extends StatelessWidget {
  const _AmountBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: TextStyle(fontSize: 11, color: c.textTertiary)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// 信息行
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 16, color: c.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 56,
            child: Text(label,
                style: TextStyle(fontSize: 12.5, color: c.textTertiary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13.5, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

/// 明细行
class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.productName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if ((item.spec ?? '').isNotEmpty)
                  Text(item.spec!,
                      style: TextStyle(fontSize: 12, color: c.textTertiary)),
              ],
            ),
          ),
          Text('×${item.quantity}', style: const TextStyle(fontSize: 13)),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: 92,
            child: Text(
              Fmt.money(item.payAmount),
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// 售后单行
class _AfterSaleTile extends StatelessWidget {
  const _AfterSaleTile({required this.a});

  final AfterSale a;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<dynamic>(builder: (_) => AfterSaleEditPage(afterSale: a)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('${a.type.label} · ${a.stage.label}'),
                    if ((a.reason ?? '').isNotEmpty)
                      Text(a.reason!,
                          style: TextStyle(fontSize: 12, color: c.textTertiary)),
                  ],
                ),
              ),
              Text(Fmt.money(a.refundAmount),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 发货底部面板
class ShipSheet extends StatefulWidget {
  const ShipSheet({super.key, required this.order});

  final ShopOrder order;

  /// 返回发货结果（含回传失败原因）
  static Future<({ShopOrder order, String? uploadError})?> show(
    BuildContext context,
    ShopOrder order,
  ) {
    return AppFeedback.showSheet<({ShopOrder order, String? uploadError})>(
      context: context,
      title: '订单发货',
      child: ShipSheet(order: order),
    );
  }

  @override
  State<ShipSheet> createState() => _ShipSheetState();
}

class _ShipSheetState extends State<ShipSheet> {
  ({String code, String name}) _company = AppConfig.logisticsCompanies.first;
  final TextEditingController _tracking = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // 记忆上次选择的物流公司
    SharedPreferences.getInstance().then((p) {
      final String? last = p.getString('ship.lastLogistics');
      if (last != null) {
        ({String code, String name})? found;
        for (final e in AppConfig.logisticsCompanies) {
          if (e.code == last) {
            found = e;
            break;
          }
        }
        if (found != null && mounted) setState(() => _company = found!);
      }
    });
  }

  @override
  void dispose() {
    _tracking.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Column(
      children: <Widget>[
        DropdownButtonFormField<({String code, String name})>(
          value: _company,
          decoration: InputDecoration(
            labelText: '物流公司',
            filled: true,
            fillColor: c.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide.none,
            ),
          ),
          items: AppConfig.logisticsCompanies
              .map((e) => DropdownMenuItem<({String code, String name})>(
                    value: e,
                    child: Text(e.name),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _company = v!),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: '快递单号',
          hint: '扫描或手动输入',
          controller: _tracking,
          prefixIcon: Icons.qr_code_rounded,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: '确认发货',
          expanded: true,
          loading: _loading,
          onPressed: _loading
              ? null
              : () async {
                  final String no = _tracking.text.trim();
                  if (no.isEmpty) {
                    AppFeedback.toast(context, '请填写快递单号',
                        type: ToastType.warning);
                    return;
                  }
                  setState(() => _loading = true);
                  await SharedPreferences.getInstance().then(
                    (p) => p.setString('ship.lastLogistics', _company.code),
                  );
                  final res = await context.read<DataProvider>().shipOrder(
                    widget.order,
                    companyCode: _company.code,
                    companyName: _company.name,
                    trackingNo: no,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop(res);
                  }
                },
        ),
      ],
    );
  }
}

/// 状态流转面板
class StatusSheet extends StatelessWidget {
  const StatusSheet({super.key, required this.current});

  final OrderStatus current;

  static Future<OrderStatus?> show(BuildContext context, OrderStatus current) {
    return AppFeedback.showSheet<OrderStatus>(
      context: context,
      title: '流转订单状态',
      child: StatusSheet(current: current),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Column(
      children: <Widget>[
        for (final OrderStatus s in OrderStatusX.filterValues)
          ListTile(
            leading: StatusChip(status: s, compact: true),
            title: Text(s.label),
            trailing: s == current
                ? Icon(Icons.check_rounded, color: c.primary)
                : null,
            onTap: () => Navigator.of(context).pop(s),
          ),
      ],
    );
  }
}
