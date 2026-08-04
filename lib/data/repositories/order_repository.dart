import '../../core/config/app_config.dart';
import '../../core/utils/stable_id.dart';
import '../local/order_dao.dart';
import '../models/order_item.dart';
import '../models/order_status.dart';
import '../models/product.dart';
import '../models/shop_order.dart';
import '../models/sync_meta.dart';
import '../sync/douyin_sync_service.dart';
import '../sync/sync_service.dart';

/// ----------------------------------------------------------------------------
/// 建单 / 改单时用的商品行草稿
///
/// 界面上编辑的是草稿，保存时再由仓储统一生成主键、补时间戳，
/// 避免 UI 层直接构造带同步字段的实体。
/// ----------------------------------------------------------------------------
class OrderItemDraft {
  OrderItemDraft({
    this.productId,
    required this.productName,
    this.spec,
    this.skuCode,
    this.quantity = 1,
    this.salePrice = 0,
    this.costPrice = 0,
  });

  /// 从商品档案挑选时快速构造
  factory OrderItemDraft.fromProduct(Product product, {int quantity = 1}) {
    return OrderItemDraft(
      productId: product.id,
      productName: product.name,
      spec: product.spec,
      skuCode: product.skuCode,
      quantity: quantity,
      salePrice: product.salePrice,
      costPrice: product.costPrice,
    );
  }

  String? productId;
  String productName;
  String? spec;
  String? skuCode;
  int quantity;
  double salePrice;
  double costPrice;

  double get lineTotal => salePrice * quantity;

  OrderItemDraft copy() => OrderItemDraft(
        productId: productId,
        productName: productName,
        spec: spec,
        skuCode: skuCode,
        quantity: quantity,
        salePrice: salePrice,
        costPrice: costPrice,
      );

  static OrderItemDraft fromItem(OrderItem item) => OrderItemDraft(
        productId: item.productId,
        productName: item.productName,
        spec: item.spec,
        skuCode: item.outerSkuId,
        quantity: item.quantity,
        salePrice: item.salePrice,
        costPrice: item.costPrice,
      );
}

/// ============================================================================
/// 订单仓储
///
/// 职责：
///   · 手工订单的增删改（抖店订单由 DouyinSyncService 负责写入）
///   · 发货：本地状态流转 + 快递单号回传抖店
///   · 列表的筛选与排序（纯内存运算，翻页零延迟）
/// ============================================================================
class OrderRepository {
  const OrderRepository();

  static const OrderDao _dao = OrderDao();

  Future<List<ShopOrder>> loadAll(String userId) => _dao.findAllWithItems(userId);

  Future<ShopOrder?> loadOne(String id) => _dao.findByIdWithItems(id);

  // ---------------------------------------------------------------------------
  // 手工建单 / 改单
  // ---------------------------------------------------------------------------
  Future<ShopOrder> create({
    required String userId,
    String? orderNo,
    required OrderStatus status,
    String? customerId,
    String? buyerNick,
    String? receiverName,
    String? receiverPhone,
    String? receiverAddress,
    required List<OrderItemDraft> items,
    double postAmount = 0,
    double discountAmount = 0,
    DateTime? orderTime,
    String? buyerWords,
    String? remark,
  }) async {
    final DateTime now = DateTime.now();
    final String no = (orderNo ?? '').trim().isEmpty
        ? _generateManualNo(now)
        : orderNo!.trim();
    final String id = StableId.random();

    final List<OrderItem> entities = _buildItems(
      userId: userId,
      orderId: id,
      drafts: items,
      now: now,
    );
    final ({double total, int count}) sum = _sumUp(entities);
    final double payAmount =
        (sum.total + postAmount - discountAmount).clamp(0, double.infinity);

    final ShopOrder order = ShopOrder(
      id: id,
      userId: userId,
      orderNo: no,
      status: status,
      source: OrderSource.manual,
      customerId: customerId,
      buyerNick: _clean(buyerNick),
      receiverName: _clean(receiverName),
      receiverPhone: _clean(receiverPhone),
      receiverAddress: _clean(receiverAddress),
      productSummary: _summaryOf(entities),
      itemCount: sum.count,
      totalAmount: sum.total,
      payAmount: payAmount,
      postAmount: postAmount,
      discountAmount: discountAmount,
      buyerWords: _clean(buyerWords),
      remark: _clean(remark),
      orderTime: orderTime ?? now,
      payTime: status == OrderStatus.pendingPayment ? null : (orderTime ?? now),
      createdAt: now,
      updatedAt: now,
      syncState: SyncState.pending,
      items: entities,
    );

    await _dao.saveWithItems(order);
    SyncService.instance.scheduleSync();
    return order;
  }

  Future<ShopOrder> update(
    ShopOrder origin, {
    required OrderStatus status,
    String? customerId,
    String? buyerNick,
    String? receiverName,
    String? receiverPhone,
    String? receiverAddress,
    required List<OrderItemDraft> items,
    double postAmount = 0,
    double discountAmount = 0,
    DateTime? orderTime,
    String? buyerWords,
    String? remark,
    bool clearCustomer = false,
  }) async {
    final DateTime now = DateTime.now();
    final List<OrderItem> entities = _buildItems(
      userId: origin.userId,
      orderId: origin.id,
      drafts: items,
      now: now,
      createdAt: origin.createdAt,
    );
    final ({double total, int count}) sum = _sumUp(entities);

    // 抖店同步下来的订单只允许改本地字段，金额一律以平台为准
    final bool isDouyin = origin.source == OrderSource.douyin;
    final double payAmount = isDouyin
        ? origin.payAmount
        : (sum.total + postAmount - discountAmount).clamp(0, double.infinity);

    final ShopOrder updated = origin.copyWith(
      status: status,
      customerId: customerId,
      buyerNick: _clean(buyerNick),
      receiverName: _clean(receiverName),
      receiverPhone: _clean(receiverPhone),
      receiverAddress: _clean(receiverAddress),
      productSummary: _summaryOf(entities),
      itemCount: sum.count,
      totalAmount: isDouyin ? origin.totalAmount : sum.total,
      payAmount: payAmount,
      postAmount: isDouyin ? origin.postAmount : postAmount,
      discountAmount: isDouyin ? origin.discountAmount : discountAmount,
      buyerWords: _clean(buyerWords),
      remark: _clean(remark),
      orderTime: orderTime ?? origin.orderTime,
      updatedAt: now,
      syncState: SyncState.pending,
      items: entities,
      clearCustomer: clearCustomer,
      clearRemark: _isBlank(remark),
    );

    await _dao.saveWithItems(updated);
    SyncService.instance.scheduleSync();
    return updated;
  }

  Future<ShopOrder> changeStatus(ShopOrder origin, OrderStatus status) async {
    final DateTime now = DateTime.now();
    final ShopOrder updated = origin.copyWith(
      status: status,
      payTime: status == OrderStatus.pendingPayment
          ? origin.payTime
          : (origin.payTime ?? now),
      shipTime: status == OrderStatus.shipped ? (origin.shipTime ?? now) : origin.shipTime,
      finishTime:
          status == OrderStatus.completed ? (origin.finishTime ?? now) : origin.finishTime,
      updatedAt: now,
      syncState: SyncState.pending,
    );
    await _dao.upsert(updated);
    SyncService.instance.scheduleSync();
    return updated;
  }

  Future<void> delete(ShopOrder order) async {
    await _dao.deleteWithItems(order.id);
    SyncService.instance.scheduleSync();
  }

  // ---------------------------------------------------------------------------
  // 发货
  // ---------------------------------------------------------------------------

  /// 单笔发货
  ///
  /// 本地状态先落库（保证断网也能记录），再尝试把单号回传抖店。
  /// 回传失败时把原因抛出去提示商家，本地状态不回滚。
  Future<({ShopOrder order, String? uploadError})> ship(
    ShopOrder origin, {
    required String companyCode,
    required String companyName,
    required String trackingNo,
  }) async {
    final DateTime now = DateTime.now();
    final ShopOrder updated = origin.copyWith(
      status: OrderStatus.shipped,
      logisticsCode: companyCode,
      logisticsName: companyName,
      trackingNo: trackingNo.trim(),
      shipTime: now,
      updatedAt: now,
      syncState: SyncState.pending,
    );
    await _dao.upsert(updated);
    SyncService.instance.scheduleSync();

    String? uploadError;
    try {
      await DouyinSyncService.instance.uploadLogistics(
        order: updated,
        companyCode: companyCode,
        trackingNo: trackingNo.trim(),
      );
    } catch (e) {
      uploadError = '$e';
    }
    return (order: updated, uploadError: uploadError);
  }

  /// 批量发货
  ///
  /// [entries] 为 订单 → (物流编码, 物流名称, 快递单号)。
  /// 返回回传失败的订单号与原因，供界面汇总提示。
  Future<Map<String, String>> shipBatch(
    Map<ShopOrder, ({String code, String name, String trackingNo})> entries,
  ) async {
    if (entries.isEmpty) return <String, String>{};

    final Map<String, ({String code, String name, String trackingNo})> byId =
        <String, ({String code, String name, String trackingNo})>{
      for (final MapEntry<ShopOrder,
              ({String code, String name, String trackingNo})> e
          in entries.entries)
        e.key.id: e.value,
    };
    await _dao.markShippedBatch(byId);
    SyncService.instance.scheduleSync();

    final Map<String, String> failures = <String, String>{};
    for (final MapEntry<ShopOrder,
            ({String code, String name, String trackingNo})> e
        in entries.entries) {
      try {
        await DouyinSyncService.instance.uploadLogistics(
          order: e.key,
          companyCode: e.value.code,
          trackingNo: e.value.trackingNo,
        );
      } catch (err) {
        failures[e.key.orderNo] = '$err';
      }
    }
    return failures;
  }

  // ---------------------------------------------------------------------------
  // 筛选与排序（内存运算）
  // ---------------------------------------------------------------------------
  List<ShopOrder> filterAndSort(
    List<ShopOrder> source, {
    String keyword = '',
    Set<OrderStatus> statuses = const <OrderStatus>{},
    OrderSource? source0,
    DateTime? from,
    DateTime? to,
    bool onlyUnshipped = false,
    OrderSortBy sortBy = OrderSortBy.createdDesc,
  }) {
    final String kw = keyword.trim().toLowerCase();
    final List<ShopOrder> list = source.where((ShopOrder o) {
      if (statuses.isNotEmpty && !statuses.contains(o.status)) return false;
      if (source0 != null && o.source != source0) return false;
      if (onlyUnshipped && o.status != OrderStatus.pendingShip) return false;
      if (from != null && o.orderTime.isBefore(from)) return false;
      if (to != null && !o.orderTime.isBefore(to)) return false;
      if (kw.isEmpty) return true;
      return o.searchIndex.contains(kw);
    }).toList();

    switch (sortBy) {
      case OrderSortBy.createdDesc:
        list.sort((ShopOrder a, ShopOrder b) =>
            b.orderTime.compareTo(a.orderTime));
      case OrderSortBy.createdAsc:
        list.sort((ShopOrder a, ShopOrder b) =>
            a.orderTime.compareTo(b.orderTime));
      case OrderSortBy.amountDesc:
        list.sort((ShopOrder a, ShopOrder b) =>
            b.payAmount.compareTo(a.payAmount));
      case OrderSortBy.amountAsc:
        list.sort((ShopOrder a, ShopOrder b) =>
            a.payAmount.compareTo(b.payAmount));
    }
    return list;
  }

  // ---------------------------------------------------------------------------
  // 内部工具
  // ---------------------------------------------------------------------------
  List<OrderItem> _buildItems({
    required String userId,
    required String orderId,
    required List<OrderItemDraft> drafts,
    required DateTime now,
    DateTime? createdAt,
  }) {
    final List<OrderItem> list = <OrderItem>[];
    for (int i = 0; i < drafts.length; i++) {
      final OrderItemDraft d = drafts[i];
      if (d.productName.trim().isEmpty) continue;
      list.add(OrderItem(
        // 用「订单 id + 行序号」派生，编辑订单时同一行主键保持稳定
        id: StableId.forOrderItem(orderId, 'manual-$i'),
        userId: userId,
        orderId: orderId,
        productId: d.productId,
        productName: d.productName.trim(),
        spec: _clean(d.spec),
        outerSkuId: _clean(d.skuCode),
        quantity: d.quantity <= 0 ? 1 : d.quantity,
        salePrice: d.salePrice,
        payAmount: d.salePrice * (d.quantity <= 0 ? 1 : d.quantity),
        costPrice: d.costPrice,
        createdAt: createdAt ?? now,
        updatedAt: now,
        syncState: SyncState.pending,
      ));
    }
    return list;
  }

  ({double total, int count}) _sumUp(List<OrderItem> items) {
    double total = 0;
    int count = 0;
    for (final OrderItem e in items) {
      total += e.lineTotal;
      count += e.quantity;
    }
    return (total: total, count: count);
  }

  String _summaryOf(List<OrderItem> items) {
    if (items.isEmpty) return '';
    final String head = items.first.summary;
    if (items.length == 1) return head;
    return '$head 等 ${items.length} 款';
  }

  /// 手工单号：MN + yyyyMMddHHmmss
  String _generateManualNo(DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'MN${now.year}${two(now.month)}${two(now.day)}'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  static String? _clean(String? value) {
    final String v = (value ?? '').trim();
    return v.isEmpty ? null : v;
  }

  static bool _isBlank(String? value) => (value ?? '').trim().isEmpty;

  /// 待发货超时预警阈值（小时），供界面展示文案使用
  static int get shipWarningHours => AppConfig.shipWarningHours;
}
