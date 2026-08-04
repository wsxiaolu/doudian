import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/app_icon_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../state/data_provider.dart';
import '../../data/models/after_sale.dart';
import '../../data/models/shop_order.dart';

/// ============================================================================
/// 登记 / 编辑售后单
///
/// 支持手动登记线下售后，也可从订单选择关联。维护类型（仅退款 / 退货退款 /
/// 换货 / 补发）、处理进度、退款金额、退回快递单号与跟进备注。
/// ============================================================================
class AfterSaleEditPage extends StatefulWidget {
  const AfterSaleEditPage({super.key, this.afterSale});

  /// 传 null 表示新建，传入则进入编辑模式
  final AfterSale? afterSale;

  @override
  State<AfterSaleEditPage> createState() => _AfterSaleEditPageState();
}

class _AfterSaleEditPageState extends State<AfterSaleEditPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _orderNo = TextEditingController();
  final TextEditingController _buyerNick = TextEditingController();
  final TextEditingController _productSummary = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  final TextEditingController _refund = TextEditingController();
  final TextEditingController _returnTracking = TextEditingController();
  final TextEditingController _progress = TextEditingController();
  late AfterSaleType _type;
  late AfterSaleStage _stage;
  String? _orderId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final AfterSale? a = widget.afterSale;
    if (a != null) {
      _orderNo.text = a.orderNo;
      _orderId = a.orderId;
      _buyerNick.text = a.buyerNick ?? '';
      _productSummary.text = a.productSummary ?? '';
      _reason.text = a.reason ?? '';
      _refund.text = a.refundAmount > 0 ? a.refundAmount.toString() : '';
      _returnTracking.text = a.returnTrackingNo ?? '';
      _progress.text = a.progressNote ?? '';
      _type = a.type;
      _stage = a.stage;
    } else {
      _type = AfterSaleType.refundOnly;
      _stage = AfterSaleStage.pending;
    }
  }

  @override
  void dispose() {
    _orderNo.dispose();
    _buyerNick.dispose();
    _productSummary.dispose();
    _reason.dispose();
    _refund.dispose();
    _returnTracking.dispose();
    _progress.dispose();
    super.dispose();
  }

  String? _trim(TextEditingController c) {
    final String v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _pickOrder() async {
    final DataProvider data = context.read<DataProvider>();
    if (data.orders.isEmpty) {
      AppFeedback.toast(context, '还没有订单，可手动填写订单号',
          type: ToastType.warning);
      return;
    }
    final ShopOrder? picked = await _OrderPicker.show(context, data.orders);
    if (picked != null && mounted) {
      setState(() {
        _orderNo.text = picked.orderNo;
        _orderId = picked.id;
        if (_buyerNick.text.trim().isEmpty) {
          _buyerNick.text = picked.buyerNick ?? picked.receiverName ?? '';
        }
        if (_productSummary.text.trim().isEmpty) {
          _productSummary.text = picked.productSummary ?? '';
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_orderNo.text.trim().isEmpty) {
      AppFeedback.toast(context, '请填写订单号', type: ToastType.warning);
      return;
    }
    setState(() => _busy = true);
    final DataProvider data = context.read<DataProvider>();
    try {
      if (widget.afterSale == null) {
        await data.createAfterSale(
          orderNo: _orderNo.text.trim(),
          orderId: _orderId,
          type: _type,
          stage: _stage,
          buyerNick: _trim(_buyerNick),
          productSummary: _trim(_productSummary),
          reason: _trim(_reason),
          refundAmount: double.tryParse(_refund.text) ?? 0,
          returnTrackingNo: _trim(_returnTracking),
          progressNote: _trim(_progress),
        );
      } else {
        await data.updateAfterSale(
          widget.afterSale!,
          type: _type,
          stage: _stage,
          reason: _trim(_reason),
          refundAmount: double.tryParse(_refund.text) ?? 0,
          returnTrackingNo: _trim(_returnTracking),
          progressNote: _trim(_progress),
        );
      }
      if (mounted) {
        AppFeedback.toast(context, '已保存', type: ToastType.success);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.toast(context, '保存失败：$e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final AfterSale? a = widget.afterSale;
    if (a == null) return;
    final bool ok = await AppFeedback.confirm(
      context: context,
      title: '删除售后单',
      message: '删除后将同步到云端（可软删除恢复）。',
      confirmText: '删除',
      danger: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok) return;
    await context.read<DataProvider>().deleteAfterSale(a);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;
    final bool editing = widget.afterSale != null;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text(editing ? '编辑售后' : '登记售后', style: t.titleLarge),
        actions: <Widget>[
          if (editing)
            AppIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: '删除',
              color: c.danger,
              onPressed: _busy ? null : _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: context.pagePadding,
            vertical: AppSpacing.md,
          ),
          children: <Widget>[
            AppSectionCard(
              title: '关联订单',
              icon: Icons.receipt_long_outlined,
              trailing: TextButton.icon(
                onPressed: _pickOrder,
                icon: const Icon(Icons.search_rounded, size: 16),
                label: const Text('选择订单'),
              ),
              child: Column(
                children: <Widget>[
                  AppTextField(
                    label: '订单号',
                    hint: '必填，可手动填写或从订单选择',
                    controller: _orderNo,
                    required: true,
                    prefixIcon: Icons.tag_rounded,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: '买家昵称',
                    controller: _buyerNick,
                    prefixIcon: Icons.person_outline_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 类型与进度
            AppSectionCard(
              title: '售后类型与进度',
              icon: Icons.assignment_return_outlined,
              child: Column(
                children: <Widget>[
                  _TypeField(
                    value: _type,
                    onChanged: (AfterSaleType v) => setState(() => _type = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _StageField(
                    value: _stage,
                    onChanged: (AfterSaleStage v) => setState(() => _stage = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 商品与退款
            AppSectionCard(
              title: '商品与退款',
              icon: Icons.sell_outlined,
              child: Column(
                children: <Widget>[
                  AppTextField(
                    label: '商品摘要',
                    hint: '如 纯棉T恤 [白/XL] ×2',
                    controller: _productSummary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: '退款金额',
                    hint: '0.00',
                    controller: _refund,
                    prefixIcon: Icons.replay_rounded,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: AppInputFormatters.money,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: '退货快递单号',
                    controller: _returnTracking,
                    prefixIcon: Icons.local_shipping_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 原因与跟进
            AppSectionCard(
              title: '原因与跟进',
              icon: Icons.notes_rounded,
              child: Column(
                children: <Widget>[
                  AppTextField(
                    label: '售后原因',
                    controller: _reason,
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: '跟进备注',
                    hint: '记录处理过程，如「已同意退货，等待买家寄回」',
                    controller: _progress,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
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
          child: AppButton(
            label: '保存售后',
            icon: Icons.save_rounded,
            expanded: true,
            loading: _busy,
            onPressed: _busy ? null : _save,
          ),
        ),
      ),
    );
  }
}

/// 类型下拉
class _TypeField extends StatelessWidget {
  const _TypeField({required this.value, required this.onChanged});

  final AfterSaleType value;
  final ValueChanged<AfterSaleType> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Text('售后类型',
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
          child: DropdownButtonFormField<AfterSaleType>(
            value: value,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            ),
            items: AfterSaleTypeX.values
                .map((AfterSaleType ty) => DropdownMenuItem<AfterSaleType>(
                      value: ty,
                      child: Text(ty.label),
                    ))
                .toList(),
            onChanged: (AfterSaleType? v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}

/// 进度下拉
class _StageField extends StatelessWidget {
  const _StageField({required this.value, required this.onChanged});

  final AfterSaleStage value;
  final ValueChanged<AfterSaleStage> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Text('处理进度',
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
          child: DropdownButtonFormField<AfterSaleStage>(
            value: value,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            ),
            items: AfterSaleStageX.values
                .map((AfterSaleStage s) => DropdownMenuItem<AfterSaleStage>(
                      value: s,
                      child: Text(s.label),
                    ))
                .toList(),
            onChanged: (AfterSaleStage? v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}

/// 订单选择底部面板
class _OrderPicker extends StatelessWidget {
  const _OrderPicker({required this.orders});

  final List<ShopOrder> orders;

  static Future<ShopOrder?> show(
    BuildContext context,
    List<ShopOrder> orders,
  ) {
    return AppFeedback.showSheet<ShopOrder?>(
      context: context,
      title: '选择关联订单',
      child: _OrderPicker(orders: orders),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    if (orders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: Text('还没有订单', style: Theme.of(context).textTheme.bodyMedium),
        ),
      );
    }
    return Column(
      children: <Widget>[
        for (final ShopOrder o in orders)
          ListTile(
            title: Text(o.orderNo),
            subtitle: Text(
              '${o.productSummary ?? '订单'} · ${Fmt.money(o.payAmount)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Icon(Icons.chevron_right_rounded, color: c.textTertiary),
            onTap: () => Navigator.of(context).pop(o),
          ),
      ],
    );
  }
}
