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
import '../../data/models/customer.dart';

/// ============================================================================
/// 新建 / 编辑客户（买家）档案
///
/// 维护收件人姓名、抖音昵称、电话、地址与备注。关联的订单在客户改名后
/// 会同步更新冗余的买家昵称，不会丢失历史账目。
/// ============================================================================
class CustomerEditPage extends StatefulWidget {
  const CustomerEditPage({super.key, this.customer});

  /// 传 null 表示新建，传入则进入编辑模式
  final Customer? customer;

  @override
  State<CustomerEditPage> createState() => _CustomerEditPageState();
}

class _CustomerEditPageState extends State<CustomerEditPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _nick = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _remark = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final Customer? cu = widget.customer;
    if (cu != null) {
      _name.text = cu.name;
      _nick.text = cu.buyerNick ?? '';
      _phone.text = cu.phone ?? '';
      _address.text = cu.address ?? '';
      _remark.text = cu.remark ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _nick.dispose();
    _phone.dispose();
    _address.dispose();
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
      AppFeedback.toast(context, '请填写收件人姓名', type: ToastType.warning);
      return;
    }
    setState(() => _busy = true);
    final DataProvider data = context.read<DataProvider>();
    try {
      if (widget.customer == null) {
        await data.createCustomer(
          name: _name.text.trim(),
          buyerNick: _trim(_nick),
          phone: _trim(_phone),
          address: _trim(_address),
          remark: _trim(_remark),
        );
      } else {
        await data.updateCustomer(
          widget.customer!,
          name: _name.text.trim(),
          buyerNick: _trim(_nick),
          phone: _trim(_phone),
          address: _trim(_address),
          remark: _trim(_remark),
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
    final Customer? cu = widget.customer;
    if (cu == null) return;
    final bool ok = await AppFeedback.confirm(
      context: context,
      title: '删除客户',
      message: '删除后名下订单会保留账目，仅解除关联；此操作会同步到云端。',
      confirmText: '删除',
      danger: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok) return;
    await context.read<DataProvider>().deleteCustomer(cu);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;
    final bool editing = widget.customer != null;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text(editing ? '编辑客户' : '新建客户', style: t.titleLarge),
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
                    label: '收件人姓名',
                    hint: '必填',
                    controller: _name,
                    required: true,
                    validator: (String? v) =>
                        (v ?? '').trim().isEmpty ? '请填写收件人姓名' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: '抖音昵称',
                    hint: '与抖店买家对应，便于自动归并',
                    controller: _nick,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: '联系电话',
                    hint: '手机号',
                    controller: _phone,
                    prefixIcon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                    inputFormatters: AppInputFormatters.phone,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 地址
            AppSectionCard(
              title: '收货地址',
              icon: Icons.map_outlined,
              child: AppTextField(
                label: '详细地址',
                hint: '省 / 市 / 区 / 街道',
                controller: _address,
                maxLines: 2,
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
            label: '保存客户',
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
