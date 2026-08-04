import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/app_icon_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../state/data_provider.dart';
import '../../data/models/product.dart';

/// ============================================================================
/// 新建 / 编辑商品档案
///
/// 维护名称、规格、商家编码、分类、成本价、售价、库存与上下架状态。
/// 商家编码（SKU）与抖店 outer_sku_id 对应后，可为同步下来的订单自动补成本。
/// ============================================================================
class ProductEditPage extends StatefulWidget {
  const ProductEditPage({super.key, this.product});

  /// 传 null 表示新建，传入则进入编辑模式
  final Product? product;

  @override
  State<ProductEditPage> createState() => _ProductEditPageState();
}

class _ProductEditPageState extends State<ProductEditPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _spec = TextEditingController();
  final TextEditingController _sku = TextEditingController();
  final TextEditingController _category = TextEditingController();
  final TextEditingController _cost = TextEditingController();
  final TextEditingController _sale = TextEditingController();
  final TextEditingController _stock = TextEditingController();
  final TextEditingController _remark = TextEditingController();
  late bool _active;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final Product? p = widget.product;
    if (p != null) {
      _name.text = p.name;
      _spec.text = p.spec ?? '';
      _sku.text = p.skuCode ?? '';
      _category.text = p.category ?? '';
      _cost.text = p.costPrice > 0 ? p.costPrice.toString() : '';
      _sale.text = p.salePrice > 0 ? p.salePrice.toString() : '';
      _stock.text = p.stock.toString();
      _remark.text = p.remark ?? '';
      _active = p.isActive;
    } else {
      _active = true;
      _stock.text = '0';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _spec.dispose();
    _sku.dispose();
    _category.dispose();
    _cost.dispose();
    _sale.dispose();
    _stock.dispose();
    _remark.dispose();
    super.dispose();
  }

  String? _trim(TextEditingController c) {
    final String v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_name.text.trim().isEmpty) {
      AppFeedback.toast(context, '请填写商品名称', type: ToastType.warning);
      return;
    }
    setState(() => _busy = true);
    final DataProvider data = context.read<DataProvider>();
    try {
      if (widget.product == null) {
        await data.createProduct(
          name: _name.text.trim(),
          spec: _trim(_spec),
          skuCode: _trim(_sku),
          category: _trim(_category),
          costPrice: double.tryParse(_cost.text) ?? 0,
          salePrice: double.tryParse(_sale.text) ?? 0,
          stock: int.tryParse(_stock.text) ?? 0,
          remark: _trim(_remark),
        );
      } else {
        await data.updateProduct(
          widget.product!,
          name: _name.text.trim(),
          spec: _trim(_spec),
          skuCode: _trim(_sku),
          category: _trim(_category),
          costPrice: double.tryParse(_cost.text) ?? 0,
          salePrice: double.tryParse(_sale.text) ?? 0,
          stock: int.tryParse(_stock.text) ?? 0,
          remark: _trim(_remark),
          isActive: _active,
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
    final Product? p = widget.product;
    if (p == null) return;
    final bool ok = await AppFeedback.confirm(
      context: context,
      title: '删除商品',
      message: '删除后将从本地移除，并同步到云端（可软删除恢复）。',
      confirmText: '删除',
      danger: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok) return;
    await context.read<DataProvider>().deleteProduct(p);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;
    final bool editing = widget.product != null;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text(editing ? '编辑商品' : '新建商品', style: t.titleLarge),
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
              title: '基本信息',
              icon: Icons.info_outline_rounded,
              child: Column(
                children: <Widget>[
                  AppTextField(
                    label: '商品名称',
                    hint: '必填',
                    controller: _name,
                    required: true,
                    validator: (String? v) =>
                        (v ?? '').trim().isEmpty ? '请填写商品名称' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: '规格',
                    hint: '如 白色/XL',
                    controller: _spec,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: '商家编码 / SKU',
                    hint: '与抖店 outer_sku_id 对应可自动匹配成本',
                    controller: _sku,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: '分类',
                    hint: '如 上衣 / 裤装',
                    controller: _category,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 价格与库存
            AppSectionCard(
              title: '价格与库存',
              icon: Icons.sell_outlined,
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: AppTextField(
                          label: '成本价',
                          hint: '0.00',
                          controller: _cost,
                          prefixIcon: Icons.attach_money_rounded,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: AppInputFormatters.money,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppTextField(
                          label: '售价',
                          hint: '0.00',
                          controller: _sale,
                          prefixIcon: Icons.sell_rounded,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: AppInputFormatters.money,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: '库存数量',
                    hint: '0',
                    controller: _stock,
                    prefixIcon: Icons.inventory_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: AppInputFormatters.integer,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: <Widget>[
                      Text('上架销售', style: t.bodyMedium),
                      const Spacer(),
                      Switch(
                        value: _active,
                        activeColor: c.success,
                        onChanged: (bool v) => setState(() => _active = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 备注
            AppSectionCard(
              title: '备注',
              icon: Icons.notes_rounded,
              child: AppTextField(
                label: '备注',
                controller: _remark,
                maxLines: 2,
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
            label: '保存商品',
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
