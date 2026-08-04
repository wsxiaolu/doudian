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
import '../../data/models/order_item.dart';
import '../../data/models/customer.dart';
import '../../data/models/order_status.dart';
import '../../data/models/product.dart';
import '../../data/models/shop_order.dart';
import '../../data/repositories/order_repository.dart';
import '../../state/data_provider.dart';

/// ============================================================================
/// 新建 / 编辑订单
///
/// 支持手动录入线下订单：选择客户、填写收货信息、维护商品明细（可单条手填，
/// 也可从商品库一键带入售价与成本），系统自动按「商品合计 + 运费 - 优惠」算出实付。
/// 抖店同步下来的订单也能在此改本地字段（金额以平台为准）。
/// ============================================================================
class OrderEditPage extends StatefulWidget {
  const OrderEditPage({super.key, this.order});

  /// 传 null 表示新建，传入则进入编辑模式
  final ShopOrder? order;

  @override
  State<OrderEditPage> createState() => _OrderEditPageState();
}

class _OrderEditPageState extends State<OrderEditPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _orderNo = TextEditingController();
  final TextEditingController _buyerNick = TextEditingController();
  final TextEditingController _receiverName = TextEditingController();
  final TextEditingController _receiverPhone = TextEditingController();
  final TextEditingController _receiverAddress = TextEditingController();
  final TextEditingController _post = TextEditingController();
  final TextEditingController _discount = TextEditingController();
  final TextEditingController _orderTimeText = TextEditingController();
  final TextEditingController _buyerWords = TextEditingController();
  final TextEditingController _remark = TextEditingController();

  late OrderStatus _status;
  late DateTime _orderTime;
  Customer? _customer;
  bool _customerResolved = false;
  final List<OrderItemDraft> _items = <OrderItemDraft>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final ShopOrder? o = widget.order;
    if (o != null) {
      _status = o.status;
      _orderNo.text = o.orderNo;
      _buyerNick.text = o.buyerNick ?? '';
      _receiverName.text = o.receiverName ?? '';
      _receiverPhone.text = o.receiverPhone ?? '';
      _receiverAddress.text = o.receiverAddress ?? '';
      _post.text = o.postAmount > 0 ? o.postAmount.toString() : '';
      _discount.text = o.discountAmount > 0 ? o.discountAmount.toString() : '';
      _buyerWords.text = o.buyerWords ?? '';
      _remark.text = o.remark ?? '';
      _orderTime = o.orderTime;
      _items.addAll(o.items.map((OrderItem e) => OrderItemDraft.fromItem(e)));
    } else {
      _status = OrderStatus.pendingShip;
      _orderTime = DateTime.now();
      _items.add(OrderItemDraft(productName: ''));
    }
    _orderTimeText.text = Fmt.dateTime(_orderTime);
  }

  @override
  void dispose() {
    _orderNo.dispose();
    _buyerNick.dispose();
    _receiverName.dispose();
    _receiverPhone.dispose();
    _receiverAddress.dispose();
    _post.dispose();
    _discount.dispose();
    _orderTimeText.dispose();
    _buyerWords.dispose();
    _remark.dispose();
    super.dispose();
  }

  /// 编辑模式下把订单关联的客户解析出来（initState 拿不到 context）
  Customer? get _resolvedCustomer {
    if (!_customerResolved && widget.order?.customerId != null) {
      _customer = context.read<DataProvider>().customerById(widget.order!.customerId);
      _customerResolved = true;
    }
    return _customer;
  }

  double get _previewTotal {
    double sum = 0;
    for (final OrderItemDraft d in _items) {
      if (d.productName.trim().isEmpty) continue;
      sum += d.salePrice * (d.quantity <= 0 ? 1 : d.quantity);
    }
    final double post = double.tryParse(_post.text) ?? 0;
    final double disc = double.tryParse(_discount.text) ?? 0;
    return (sum + post - disc).clamp(0, double.infinity);
  }

  Future<void> _pickOrderTime() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _orderTime,
      firstDate: DateTime(2018),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && mounted) {
      setState(() {
        _orderTime = picked;
        _orderTimeText.text = Fmt.dateTime(picked);
      });
    }
  }

  Future<void> _pickCustomer() async {
    final DataProvider data = context.read<DataProvider>();
    final Customer? picked = await _CustomerPicker.show(context, data.customers);
    if (picked != null && mounted) {
      setState(() => _customer = picked);
    }
  }

  Future<void> _pickProduct() async {
    final DataProvider data = context.read<DataProvider>();
    if (data.products.isEmpty) {
      AppFeedback.toast(context, '还没有商品档案，先在「商品」里添加',
          type: ToastType.warning);
      return;
    }
    final Product? picked = await _ProductPicker.show(context, data.products);
    if (picked != null && mounted) {
      setState(() => _items.add(OrderItemDraft.fromProduct(picked)));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final List<OrderItemDraft> valid =
        _items.where((OrderItemDraft d) => d.productName.trim().isNotEmpty).toList();
    if (valid.isEmpty) {
      AppFeedback.toast(context, '请至少添加一个商品', type: ToastType.warning);
      return;
    }
    setState(() => _busy = true);
    final DataProvider data = context.read<DataProvider>();
    try {
      if (widget.order == null) {
        await data.createOrder(
          orderNo: _orderNo.text.trim().isEmpty ? null : _orderNo.text.trim(),
          status: _status,
          customerId: _customer?.id,
          buyerNick: _buyerNick.text.trim(),
          receiverName: _receiverName.text.trim(),
          receiverPhone: _receiverPhone.text.trim(),
          receiverAddress: _receiverAddress.text.trim(),
          items: valid,
          postAmount: double.tryParse(_post.text) ?? 0,
          discountAmount: double.tryParse(_discount.text) ?? 0,
          orderTime: _orderTime,
          buyerWords: _buyerWords.text.trim(),
          remark: _remark.text.trim(),
        );
      } else {
        await data.updateOrder(
          widget.order!,
          status: _status,
          customerId: _customer?.id,
          buyerNick: _buyerNick.text.trim(),
          receiverName: _receiverName.text.trim(),
          receiverPhone: _receiverPhone.text.trim(),
          receiverAddress: _receiverAddress.text.trim(),
          items: valid,
          postAmount: double.tryParse(_post.text) ?? 0,
          discountAmount: double.tryParse(_discount.text) ?? 0,
          orderTime: _orderTime,
          buyerWords: _buyerWords.text.trim(),
          remark: _remark.text.trim(),
          clearCustomer: _customer == null,
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
    final ShopOrder? o = widget.order;
    if (o == null) return;
    final bool ok = await AppFeedback.confirm(
      context: context,
      title: '删除订单',
      message: '删除后将从本地移除，并同步到云端（可软删除恢复）。',
      confirmText: '删除',
      danger: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok) return;
    await context.read<DataProvider>().deleteOrder(o);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;
    _resolvedCustomer; // 触发编辑态客户解析

    final bool editing = widget.order != null;
    final bool isDouyin = editing && widget.order!.source == OrderSource.douyin;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text(editing ? '编辑订单' : '新建订单', style: t.titleLarge),
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
                    label: '订单号',
                    hint: '留空将自动生成',
                    controller: _orderNo,
                    prefixIcon: Icons.tag_rounded,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: '买家昵称',
                    hint: '选客户后可自动带入',
                    controller: _buyerNick,
                    prefixIcon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppPickerField(
                    label: '关联客户',
                    value: _customer?.displayName,
                    hint: '点击选择（可选）',
                    icon: Icons.people_alt_outlined,
                    onTap: _pickCustomer,
                    onClear: _customer == null
                        ? null
                        : () => setState(() => _customer = null),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _StatusField(
                    value: _status,
                    onChanged: (OrderStatus v) => setState(() => _status = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppPickerField(
                    label: '下单时间',
                    value: Fmt.dateTime(_orderTime),
                    icon: Icons.event_rounded,
                    onTap: _pickOrderTime,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 收货信息
            AppSectionCard(
              title: '收货信息',
              icon: Icons.local_shipping_outlined,
              child: Column(
                children: <Widget>[
                  AppTextField(
                    label: '收件人',
                    controller: _receiverName,
                    prefixIcon: Icons.person_rounded,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: '联系电话',
                    controller: _receiverPhone,
                    prefixIcon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: '收货地址',
                    controller: _receiverAddress,
                    prefixIcon: Icons.map_outlined,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 商品明细
            AppSectionCard(
              title: '商品明细',
              icon: Icons.inventory_2_outlined,
              trailing: TextButton.icon(
                onPressed: _pickProduct,
                icon: const Icon(Icons.library_add_rounded, size: 16),
                label: const Text('从商品库选'),
              ),
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < _items.length; i++)
                    _ItemEditor(
                      key: ValueKey<int>(i),
                      draft: _items[i],
                      index: i,
                      onChanged: () => setState(() {}),
                      onRemove: () => setState(() => _items.removeAt(i)),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: '添加商品行',
                    variant: AppButtonVariant.outline,
                    icon: Icons.add_rounded,
                    expanded: true,
                    size: AppButtonSize.small,
                    onPressed: () =>
                        setState(() => _items.add(OrderItemDraft(productName: ''))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 金额
            AppSectionCard(
              title: '金额与小计',
              icon: Icons.paid_outlined,
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: AppTextField(
                          label: '运费',
                          hint: '0.00',
                          controller: _post,
                          prefixIcon: Icons.local_shipping_rounded,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: AppInputFormatters.money,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppTextField(
                          label: '优惠',
                          hint: '0.00',
                          controller: _discount,
                          prefixIcon: Icons.discount_rounded,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: AppInputFormatters.money,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text('预计实付',
                            style: t.bodyMedium
                                ?.copyWith(color: c.accent)),
                        Text(
                          Fmt.money(_previewTotal),
                          style: t.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: c.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isDouyin)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text('抖店订单金额以平台为准，此处仅作参考',
                          style: t.labelSmall),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 备注
            AppSectionCard(
              title: '备注',
              icon: Icons.notes_rounded,
              child: Column(
                children: <Widget>[
                  AppTextField(
                    label: '买家留言',
                    controller: _buyerWords,
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: '商家备注',
                    controller: _remark,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
      bottomNavigationBar: _SaveBar(busy: _busy, onSave: _save),
    );
  }
}

/// 底部保存条
class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.busy, required this.onSave});

  final bool busy;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return SafeArea(
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
          label: '保存订单',
          icon: Icons.save_rounded,
          expanded: true,
          loading: busy,
          onPressed: busy ? null : onSave,
        ),
      ),
    );
  }
}

/// 状态选择下拉
class _StatusField extends StatelessWidget {
  const _StatusField({required this.value, required this.onChanged});

  final OrderStatus value;
  final ValueChanged<OrderStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Text('订单状态',
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
          child: DropdownButtonFormField<OrderStatus>(
            value: value,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            ),
            items: OrderStatusX.filterValues
                .map((OrderStatus s) => DropdownMenuItem<OrderStatus>(
                      value: s,
                      child: Text(s.label),
                    ))
                .toList(),
            onChanged: (OrderStatus? v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}

/// 单个商品明细行编辑器（就地修改传入的 draft）
class _ItemEditor extends StatefulWidget {
  const _ItemEditor({
    super.key,
    required this.draft,
    required this.index,
    required this.onChanged,
    required this.onRemove,
  });

  final OrderItemDraft draft;
  final int index;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  late final TextEditingController _name;
  late final TextEditingController _spec;
  late final TextEditingController _qty;
  late final TextEditingController _price;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.draft.productName);
    _spec = TextEditingController(text: widget.draft.spec);
    _qty = TextEditingController(text: widget.draft.quantity.toString());
    _price = TextEditingController(
        text: widget.draft.salePrice == 0
            ? ''
            : widget.draft.salePrice.toString());
  }

  @override
  void dispose() {
    _name.dispose();
    _spec.dispose();
    _qty.dispose();
    _price.dispose();
    super.dispose();
  }

  void _sync() {
    widget.draft.productName = _name.text.trim();
    widget.draft.spec = _spec.text.trim();
    widget.draft.quantity = int.tryParse(_qty.text) ?? 1;
    widget.draft.salePrice = double.tryParse(_price.text) ?? 0;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text('${widget.index + 1}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: c.primary)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppTextField(
                  label: '商品名称',
                  hint: '必填',
                  controller: _name,
                  required: true,
                  validator: (String? v) =>
                      (v ?? '').trim().isEmpty ? '请填写商品名称' : null,
                  onChanged: (_) => _sync(),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded,
                    color: c.danger, size: 20),
                tooltip: '删除',
                onPressed: widget.onRemove,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                flex: 2,
                child: AppTextField(
                  label: '规格',
                  hint: '如 白色/XL',
                  controller: _spec,
                  onChanged: (_) => _sync(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppTextField(
                  label: '数量',
                  controller: _qty,
                  keyboardType: TextInputType.number,
                  inputFormatters: AppInputFormatters.integer,
                  onChanged: (_) => _sync(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppTextField(
                  label: '单价',
                  hint: '0.00',
                  controller: _price,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: AppInputFormatters.money,
                  onChanged: (_) => _sync(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 客户选择底部面板
class _CustomerPicker extends StatelessWidget {
  const _CustomerPicker({required this.customers});

  final List<Customer> customers;

  static Future<Customer?> show(
    BuildContext context,
    List<Customer> customers,
  ) {
    return AppFeedback.showSheet<Customer?>(
      context: context,
      title: '选择客户',
      child: _CustomerPicker(customers: customers),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    if (customers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: Text('还没有客户档案', style: Theme.of(context).textTheme.bodyMedium),
        ),
      );
    }
    return Column(
      children: <Widget>[
        for (final Customer cu in customers)
          ListTile(
            leading: CircleAvatar(
              backgroundColor: c.primarySoft,
              child: Text(Fmt.initial(cu.displayName),
                  style: TextStyle(color: c.primary, fontWeight: FontWeight.w700)),
            ),
            title: Text(cu.displayName),
            subtitle: cu.phone != null ? Text(Fmt.maskPhone(cu.phone)) : null,
            onTap: () => Navigator.of(context).pop(cu),
          ),
      ],
    );
  }
}

/// 商品库选择底部面板
class _ProductPicker extends StatelessWidget {
  const _ProductPicker({required this.products});

  final List<Product> products;

  static Future<Product?> show(
    BuildContext context,
    List<Product> products,
  ) {
    return AppFeedback.showSheet<Product?>(
      context: context,
      title: '从商品库选择',
      child: _ProductPicker(products: products),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    if (products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: Text('商品库为空', style: Theme.of(context).textTheme.bodyMedium),
        ),
      );
    }
    return Column(
      children: <Widget>[
        for (final Product p in products)
          ListTile(
            title: Text(p.fullName),
            subtitle: Text('售价 ${Fmt.money(p.salePrice)}'
                '${p.stock > 0 ? ' · 库存 ${p.stock}' : ''}'),
            trailing: Icon(Icons.chevron_right_rounded, color: c.textTertiary),
            onTap: () => Navigator.of(context).pop(p),
          ),
      ],
    );
  }
}
