import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/app_text_field.dart';
import '../../data/models/order_status.dart';
import '../../data/models/shop_order.dart';
import '../../state/data_provider.dart';

/// ============================================================================
/// 扫码发货
///
/// 移动端：调用摄像头扫描快递单号 / 订单条码，自动填入单号；
/// 桌面端：摄像头不可用，自动降级为「手动输入单号 + 扫码枪键盘输入」。
/// 扫描或输入单号后，在待发货列表里点选目标订单即可一键发货。
/// ============================================================================
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  ({String code, String name}) _company = AppConfig.logisticsCompanies.first;
  final TextEditingController _tracking = TextEditingController();
  MobileScannerController? _scanner;
  String? _selectedOrderId;
  DateTime? _lastScan;
  bool _busy = false;

  /// 是否支持摄像头扫码（仅 Android / iOS）
  bool get _canScan {
    final TargetPlatform p = defaultTargetPlatform;
    return p == TargetPlatform.android || p == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    if (_canScan) _scanner = MobileScannerController();
  }

  @override
  void dispose() {
    _tracking.dispose();
    _scanner?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;
    final DateTime now = DateTime.now();
    if (_lastScan != null && now.difference(_lastScan!) < const Duration(seconds: 2)) {
      return;
    }
    _lastScan = now;
    if (mounted) {
      _tracking.text = code;
      setState(() {});
      AppFeedback.toast(context, '已扫描单号', type: ToastType.info);
    }
  }

  List<ShopOrder> get _pending {
    final DataProvider data = context.read<DataProvider>();
    return data.orders
        .where((ShopOrder o) => o.status == OrderStatus.pendingShip)
        .toList();
  }

  Future<void> _ship() async {
    final String no = _tracking.text.trim();
    if (no.isEmpty) {
      AppFeedback.toast(context, '请扫描或输入快递单号', type: ToastType.warning);
      return;
    }
    if (_selectedOrderId == null) {
      AppFeedback.toast(context, '请选择要发货的订单', type: ToastType.warning);
      return;
    }
    final ShopOrder? order = context.read<DataProvider>().orderById(_selectedOrderId!);
    if (order == null) return;
    setState(() => _busy = true);
    try {
      final ({ShopOrder order, String? uploadError}) res =
          await context.read<DataProvider>().shipOrder(
        order,
        companyCode: _company.code,
        companyName: _company.name,
        trackingNo: no,
      );
      if (mounted) {
        if (res.uploadError != null) {
          AppFeedback.toast(context, '已发货，但回传抖店失败：${res.uploadError}',
              type: ToastType.warning);
        } else {
          AppFeedback.toast(context, '发货成功', type: ToastType.success);
          _tracking.clear();
          setState(() => _selectedOrderId = null);
        }
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.toast(context, '发货失败：$e', type: ToastType.error);
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

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text('扫码发货', style: t.titleLarge),
      ),
      body: Column(
        children: <Widget>[
          // 扫码 / 降级提示
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.pagePadding,
              vertical: AppSpacing.md,
            ),
            child: _canScan
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Stack(
                      children: <Widget>[
                        SizedBox(
                          height: 280,
                          child: MobileScanner(
                            controller: _scanner!,
                            onDetect: _onDetect,
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            color: Colors.black.withValues(alpha: 0.45),
                            child: const Center(
                              child: Text(
                                '将快递单号 / 订单条码对准取景框',
                                style: TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.computer_rounded,
                            color: c.textSecondary, size: 22),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            '当前设备（桌面端）不支持摄像头扫码，请用扫码枪扫描，'
                            '或直接在下方手动输入快递单号。',
                            style: t.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          // 物流 + 单号
          Container(
            padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: <Widget>[
                  _CompanyField(
                    value: _company,
                    onChanged: (v) => setState(() => _company = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: '快递单号',
                    hint: '扫描或手动输入',
                    controller: _tracking,
                    prefixIcon: Icons.qr_code_rounded,
                  ),
                ],
              ),
            ),
          ),

          // 选择目标订单
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.pagePadding,
              AppSpacing.md,
              context.pagePadding,
              AppSpacing.xs,
            ),
            child: Row(
              children: <Widget>[
                Text('选择待发货订单',
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${pending.length} 笔', style: t.labelSmall),
              ],
            ),
          ),
          Expanded(
            child: pending.isEmpty
                ? Center(
                    child: Text('没有待发货的订单',
                        style: t.bodyMedium?.copyWith(color: c.textTertiary)),
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
                      final bool selected = _selectedOrderId == o.id;
                      return AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        borderColor: selected ? c.accent : null,
                        accentBarColor: selected ? c.accent : null,
                        onTap: () => setState(() => _selectedOrderId = o.id),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    o.productSummary ?? '订单',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${o.orderNo} · ${Fmt.money(o.payAmount)}'
                                    '${o.buyerNick != null ? ' · ${o.buyerNick}' : ''}',
                                    style: t.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                            if (selected)
                              Icon(Icons.check_circle_rounded,
                                  color: c.accent, size: 22),
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
              child: AppButton(
                label: '确认发货',
                icon: Icons.local_shipping_rounded,
                expanded: true,
                loading: _busy,
                onPressed: _busy ? null : _ship,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 物流公司下拉（与批量发货共用同款交互）
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
