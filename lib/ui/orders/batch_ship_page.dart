import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/app_search_field.dart';
import '../../data/models/order_status.dart';
import '../../data/models/shop_order.dart';
import '../../state/data_provider.dart';

/// ============================================================================
/// 批量发货
///
/// 勾选多笔「待发货」订单，统一选择物流公司、逐单填入快递单号后一次提交。
/// 抖店订单会尝试把单号回传平台，回传失败的会在结果里汇总提示。
/// ============================================================================
class BatchShipPage extends StatefulWidget {
  const BatchShipPage({super.key});

  @override
  State<BatchShipPage> createState() => _BatchShipPageState();
}

class _BatchShipPageState extends State<BatchShipPage> {
  ({String code, String name}) _company = AppConfig.logisticsCompanies.first;
  final TextEditingController _keyword = TextEditingController();
  final Map<String, TextEditingController> _tracking =
      <String, TextEditingController>{};
  final Set<String> _checked = <String>{};
  bool _busy = false;

  @override
  void dispose() {
    _keyword.dispose();
    for (final TextEditingController c in _tracking.values) c.dispose();
    super.dispose();
  }

  List<ShopOrder> get _pending {
    final DataProvider data = context.read<DataProvider>();
    final String kw = _keyword.text.trim().toLowerCase();
    return data.orders.where((ShopOrder o) {
      if (o.status != OrderStatus.pendingShip) return false;
      if (kw.isEmpty) return true;
      return o.searchIndex.contains(kw);
    }).toList();
  }

  TextEditingController _trackingOf(String id) =>
      _tracking.putIfAbsent(id, () => TextEditingController());

  Future<void> _ship() async {
    final List<ShopOrder> pending = _pending;
    final Map<ShopOrder, ({String code, String name, String trackingNo})>
        entries =
        <ShopOrder, ({String code, String name, String trackingNo})>{};
    for (final ShopOrder o in pending) {
      if (!_checked.contains(o.id)) continue;
      final String no = _trackingOf(o.id).text.trim();
      if (no.isEmpty) continue;
      entries[o] = (code: _company.code, name: _company.name, trackingNo: no);
    }
    if (entries.isEmpty) {
      AppFeedback.toast(context, '请勾选订单并填写快递单号',
          type: ToastType.warning);
      return;
    }
    setState(() => _busy = true);
    try {
      final Map<String, String> failures =
          await context.read<DataProvider>().shipBatch(entries);
      if (mounted) {
        if (failures.isEmpty) {
          AppFeedback.toast(context, '已批量发货 ${entries.length} 单',
              type: ToastType.success);
          Navigator.of(context).pop();
        } else {
          AppFeedback.toast(
            context,
            '${entries.length - failures.length} 单成功，${failures.length} 单回传失败',
            type: ToastType.warning,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.toast(context, '批量发货失败：$e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;
    final List<ShopOrder> pending = _pending;
    final bool allChecked =
        pending.isNotEmpty && pending.every((ShopOrder o) => _checked.contains(o.id));

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text('批量发货', style: t.titleLarge),
        actions: <Widget>[
          if (pending.isNotEmpty)
            TextButton(
              onPressed: () => setState(() {
                if (allChecked) {
                  _checked.clear();
                } else {
                  _checked.addAll(pending.map((ShopOrder o) => o.id));
                }
              }),
              child: Text(allChecked ? '取消全选' : '全选'),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          // 顶部：物流 + 搜索
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.pagePadding,
              vertical: AppSpacing.md,
            ),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: <Widget>[
                  _CompanyField(
                    value: _company,
                    onChanged: (v) => setState(() => _company = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppSearchField(
                    hint: '搜索订单号 / 买家 / 收件人',
                    controller: _keyword,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ),

          // 列表
          Expanded(
            child: pending.isEmpty
                ? Center(
                    child: Text(
                      _keyword.text.isEmpty
                          ? '没有待发货的订单'
                          : '没有匹配的待发货订单',
                      style: t.bodyMedium?.copyWith(color: c.textTertiary),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.pagePadding,
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: pending.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (BuildContext ctx, int i) {
                      final ShopOrder o = pending[i];
                      final bool checked = _checked.contains(o.id);
                      return AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        borderColor: checked ? c.accent : null,
                        child: Column(
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Checkbox(
                                  value: checked,
                                  activeColor: c.accent,
                                  onChanged: (bool? v) => setState(() {
                                    if (v == true) {
                                      _checked.add(o.id);
                                    } else {
                                      _checked.remove(o.id);
                                    }
                                  }),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        o.productSummary ?? '订单',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: t.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${o.orderNo} · ${Fmt.money(o.payAmount)}',
                                        style: t.labelSmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            AppTextField(
                              label: '快递单号',
                              hint: '扫描或手动输入',
                              controller: _trackingOf(o.id),
                              prefixIcon: Icons.qr_code_rounded,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // 底部操作条
          SafeArea(
            child: Container(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: c.surfaceElevated,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: Row(
                children: <Widget>[
                  Text(
                    '已选 ${_checked.length} 单',
                    style: t.bodyMedium,
                  ),
                  const Spacer(),
                  AppButton(
                    label: '批量发货',
                    icon: Icons.local_shipping_rounded,
                    loading: _busy,
                    onPressed: _busy ? null : _ship,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 物流公司下拉
class _CompanyField extends StatelessWidget {
  const _CompanyField({required this.value, required this.onChanged});

  final ({String code, String name}) value;
  final ValueChanged<({String code, String name})> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Text('物流公司',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: c.textSecondary, fontWeight: FontWeight.w600)),
        ),
        Container(
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: c.border),
          ),
          child: DropdownButtonFormField<({String code, String name})>(
            value: value,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            ),
            items: AppConfig.logisticsCompanies
                .map((e) => DropdownMenuItem<({String code, String name})>(
                      value: e,
                      child: Text(e.name),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}
