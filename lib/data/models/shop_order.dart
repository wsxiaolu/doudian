import '../../core/config/app_config.dart';
import 'order_item.dart';
import 'order_status.dart';
import 'sync_meta.dart';

/// ============================================================================
/// 订单实体
///
/// 同时承载两类订单：
///   · 抖店 API 自动同步下来的线上订单（source = douyin）
///   · 商家手工录入的线下订单（source = manual）
///
/// 商品明细放在 [OrderItem] 里，主表只冗余一份 [productSummary] 供列表展示与搜索。
/// ============================================================================
class ShopOrder {
  const ShopOrder({
    required this.id,
    required this.userId,
    required this.orderNo,
    required this.status,
    this.source = OrderSource.manual,
    this.customerId,
    this.buyerNick,
    this.receiverName,
    this.receiverPhone,
    this.receiverAddress,
    this.province,
    this.city,
    this.district,
    this.productSummary,
    this.itemCount = 0,
    this.totalAmount = 0,
    this.payAmount = 0,
    this.postAmount = 0,
    this.discountAmount = 0,
    this.logisticsCode,
    this.logisticsName,
    this.trackingNo,
    this.buyerWords,
    this.sellerWords,
    this.remark,
    required this.orderTime,
    this.payTime,
    this.shipTime,
    this.finishTime,
    this.douyinUpdateTime,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.syncState = SyncState.pending,
    this.items = const <OrderItem>[],
  });

  /// 本地主键（UUID）。抖店订单用「douyin 订单号」派生的稳定 UUID，保证多端一致
  final String id;
  final String userId;

  /// 抖音订单号 / 手动单号
  final String orderNo;

  final OrderStatus status;
  final OrderSource source;

  /// 关联客户档案
  final String? customerId;

  /// 买家昵称
  final String? buyerNick;

  /// 收件人
  final String? receiverName;

  /// 收件人手机号（抖店可能返回密文，原样保存）
  final String? receiverPhone;

  /// 完整收货地址
  final String? receiverAddress;

  final String? province;
  final String? city;
  final String? district;

  /// 商品摘要，例如「纯棉T恤 [白/XL] ×2 等 2 件」
  final String? productSummary;

  /// 商品总件数
  final int itemCount;

  /// 订单总额（商品原价合计）
  final double totalAmount;

  /// 买家实付
  final double payAmount;

  /// 运费
  final double postAmount;

  /// 优惠金额
  final double discountAmount;

  /// 物流公司编码 / 名称
  final String? logisticsCode;
  final String? logisticsName;

  /// 快递单号
  final String? trackingNo;

  /// 买家留言 / 商家备注
  final String? buyerWords;
  final String? sellerWords;

  /// 本地备注
  final String? remark;

  /// 下单时间
  final DateTime orderTime;
  final DateTime? payTime;
  final DateTime? shipTime;
  final DateTime? finishTime;

  /// 抖店侧最后更新时间，用于增量同步水位线
  final DateTime? douyinUpdateTime;

  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final SyncState syncState;

  /// 商品明细（不落主表，由 OrderDao 组装）
  final List<OrderItem> items;

  // ---------------------------------------------------------------------------
  // 派生属性
  // ---------------------------------------------------------------------------

  /// 是否已填写快递单号
  bool get hasTracking => (trackingNo ?? '').trim().isNotEmpty;

  /// 是否可以执行「标记发货」
  bool get canShip => status.canShip;

  /// 待发货是否已经超时（超过配置的小时数仍未发货）
  bool get isShipOverdue {
    if (status != OrderStatus.pendingShip) return false;
    final DateTime base = payTime ?? orderTime;
    return DateTime.now().difference(base).inHours >=
        AppConfig.shipWarningHours;
  }

  /// 订单毛利（实付 - 成本合计），无成本数据时返回 null
  double? get profit {
    if (items.isEmpty) return null;
    final bool anyCost = items.any((OrderItem e) => e.costPrice > 0);
    if (!anyCost) return null;
    final double cost =
        items.fold<double>(0, (double s, OrderItem e) => s + e.lineCost);
    return payAmount - cost;
  }

  /// 短单号，列表里显示尾 8 位
  String get shortNo =>
      orderNo.length <= 8 ? orderNo : orderNo.substring(orderNo.length - 8);

  /// 收件人 + 电话的一行展示
  String get receiverLine {
    final List<String> parts = <String>[
      if ((receiverName ?? '').trim().isNotEmpty) receiverName!.trim(),
      if ((receiverPhone ?? '').trim().isNotEmpty) receiverPhone!.trim(),
    ];
    return parts.join(' · ');
  }

  /// 搜索索引：订单号 / 昵称 / 收件人 / 电话 / 地址 / 商品 / 快递单号
  String get searchIndex => <String>[
        orderNo,
        buyerNick ?? '',
        receiverName ?? '',
        receiverPhone ?? '',
        receiverAddress ?? '',
        productSummary ?? '',
        trackingNo ?? '',
        remark ?? '',
      ].join(' ').toLowerCase();

  ShopOrder copyWith({
    String? id,
    String? userId,
    String? orderNo,
    OrderStatus? status,
    OrderSource? source,
    String? customerId,
    String? buyerNick,
    String? receiverName,
    String? receiverPhone,
    String? receiverAddress,
    String? province,
    String? city,
    String? district,
    String? productSummary,
    int? itemCount,
    double? totalAmount,
    double? payAmount,
    double? postAmount,
    double? discountAmount,
    String? logisticsCode,
    String? logisticsName,
    String? trackingNo,
    String? buyerWords,
    String? sellerWords,
    String? remark,
    DateTime? orderTime,
    DateTime? payTime,
    DateTime? shipTime,
    DateTime? finishTime,
    DateTime? douyinUpdateTime,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    SyncState? syncState,
    List<OrderItem>? items,
    bool clearCustomer = false,
    bool clearTracking = false,
    bool clearRemark = false,
  }) {
    return ShopOrder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      orderNo: orderNo ?? this.orderNo,
      status: status ?? this.status,
      source: source ?? this.source,
      customerId: clearCustomer ? null : (customerId ?? this.customerId),
      buyerNick: buyerNick ?? this.buyerNick,
      receiverName: receiverName ?? this.receiverName,
      receiverPhone: receiverPhone ?? this.receiverPhone,
      receiverAddress: receiverAddress ?? this.receiverAddress,
      province: province ?? this.province,
      city: city ?? this.city,
      district: district ?? this.district,
      productSummary: productSummary ?? this.productSummary,
      itemCount: itemCount ?? this.itemCount,
      totalAmount: totalAmount ?? this.totalAmount,
      payAmount: payAmount ?? this.payAmount,
      postAmount: postAmount ?? this.postAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      logisticsCode: clearTracking ? null : (logisticsCode ?? this.logisticsCode),
      logisticsName: clearTracking ? null : (logisticsName ?? this.logisticsName),
      trackingNo: clearTracking ? null : (trackingNo ?? this.trackingNo),
      buyerWords: buyerWords ?? this.buyerWords,
      sellerWords: sellerWords ?? this.sellerWords,
      remark: clearRemark ? null : (remark ?? this.remark),
      orderTime: orderTime ?? this.orderTime,
      payTime: payTime ?? this.payTime,
      shipTime: shipTime ?? this.shipTime,
      finishTime: finishTime ?? this.finishTime,
      douyinUpdateTime: douyinUpdateTime ?? this.douyinUpdateTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncState: syncState ?? this.syncState,
      items: items ?? this.items,
    );
  }

  // ---------------------------------------------------------------------------
  // 本地 SQLite
  // ---------------------------------------------------------------------------
  Map<String, Object?> toDb() => <String, Object?>{
        'id': id,
        'user_id': userId,
        'order_no': orderNo,
        'status': status.code,
        'source': source.code,
        'customer_id': customerId,
        'buyer_nick': buyerNick,
        'receiver_name': receiverName,
        'receiver_phone': receiverPhone,
        'receiver_address': receiverAddress,
        'province': province,
        'city': city,
        'district': district,
        'product_summary': productSummary,
        'item_count': itemCount,
        'total_amount': totalAmount,
        'pay_amount': payAmount,
        'post_amount': postAmount,
        'discount_amount': discountAmount,
        'logistics_code': logisticsCode,
        'logistics_name': logisticsName,
        'tracking_no': trackingNo,
        'buyer_words': buyerWords,
        'seller_words': sellerWords,
        'remark': remark,
        'order_time': DbValue.toMillis(orderTime),
        'pay_time': DbValue.toMillis(payTime),
        'ship_time': DbValue.toMillis(shipTime),
        'finish_time': DbValue.toMillis(finishTime),
        'douyin_update_time': DbValue.toMillis(douyinUpdateTime),
        'created_at': DbValue.toMillis(createdAt),
        'updated_at': DbValue.toMillis(updatedAt),
        'is_deleted': DbValue.fromBool(isDeleted),
        'sync_state': syncState.code,
      };

  factory ShopOrder.fromDb(
    Map<String, Object?> row, {
    List<OrderItem> items = const <OrderItem>[],
  }) =>
      ShopOrder(
        id: '${row['id']}',
        userId: '${row['user_id']}',
        orderNo: '${row['order_no'] ?? ''}',
        status: OrderStatusX.fromCode(row['status']),
        source: OrderSourceX.fromCode(row['source']),
        customerId: row['customer_id'] as String?,
        buyerNick: row['buyer_nick'] as String?,
        receiverName: row['receiver_name'] as String?,
        receiverPhone: row['receiver_phone'] as String?,
        receiverAddress: row['receiver_address'] as String?,
        province: row['province'] as String?,
        city: row['city'] as String?,
        district: row['district'] as String?,
        productSummary: row['product_summary'] as String?,
        itemCount: DbValue.toInt(row['item_count']),
        totalAmount: DbValue.toDouble(row['total_amount']),
        payAmount: DbValue.toDouble(row['pay_amount']),
        postAmount: DbValue.toDouble(row['post_amount']),
        discountAmount: DbValue.toDouble(row['discount_amount']),
        logisticsCode: row['logistics_code'] as String?,
        logisticsName: row['logistics_name'] as String?,
        trackingNo: row['tracking_no'] as String?,
        buyerWords: row['buyer_words'] as String?,
        sellerWords: row['seller_words'] as String?,
        remark: row['remark'] as String?,
        orderTime: DbValue.fromMillis(row['order_time']) ?? DateTime.now(),
        payTime: DbValue.fromMillis(row['pay_time']),
        shipTime: DbValue.fromMillis(row['ship_time']),
        finishTime: DbValue.fromMillis(row['finish_time']),
        douyinUpdateTime: DbValue.fromMillis(row['douyin_update_time']),
        createdAt: DbValue.fromMillis(row['created_at']) ?? DateTime.now(),
        updatedAt: DbValue.fromMillis(row['updated_at']) ?? DateTime.now(),
        isDeleted: DbValue.toBool(row['is_deleted']),
        syncState: SyncStateX.fromCode(row['sync_state']),
        items: items,
      );

  // ---------------------------------------------------------------------------
  // Supabase
  // ---------------------------------------------------------------------------
  Map<String, dynamic> toRemote() => <String, dynamic>{
        'id': id,
        'user_id': userId,
        'order_no': orderNo,
        'status': status.code,
        'source': source.code,
        'customer_id': customerId,
        'buyer_nick': buyerNick,
        'receiver_name': receiverName,
        'receiver_phone': receiverPhone,
        'receiver_address': receiverAddress,
        'province': province,
        'city': city,
        'district': district,
        'product_summary': productSummary,
        'item_count': itemCount,
        'total_amount': totalAmount,
        'pay_amount': payAmount,
        'post_amount': postAmount,
        'discount_amount': discountAmount,
        'logistics_code': logisticsCode,
        'logistics_name': logisticsName,
        'tracking_no': trackingNo,
        'buyer_words': buyerWords,
        'seller_words': sellerWords,
        'remark': remark,
        'order_time': DbValue.toIso(orderTime),
        'pay_time': DbValue.toIso(payTime),
        'ship_time': DbValue.toIso(shipTime),
        'finish_time': DbValue.toIso(finishTime),
        'douyin_update_time': DbValue.toIso(douyinUpdateTime),
        'created_at': DbValue.toIso(createdAt),
        'updated_at': DbValue.toIso(updatedAt),
        'is_deleted': isDeleted,
      };

  factory ShopOrder.fromRemote(Map<String, dynamic> json) => ShopOrder(
        id: '${json['id']}',
        userId: '${json['user_id']}',
        orderNo: '${json['order_no'] ?? ''}',
        status: OrderStatusX.fromCode(json['status']),
        source: OrderSourceX.fromCode(json['source']),
        customerId: json['customer_id'] as String?,
        buyerNick: json['buyer_nick'] as String?,
        receiverName: json['receiver_name'] as String?,
        receiverPhone: json['receiver_phone'] as String?,
        receiverAddress: json['receiver_address'] as String?,
        province: json['province'] as String?,
        city: json['city'] as String?,
        district: json['district'] as String?,
        productSummary: json['product_summary'] as String?,
        itemCount: DbValue.toInt(json['item_count']),
        totalAmount: DbValue.toDouble(json['total_amount']),
        payAmount: DbValue.toDouble(json['pay_amount']),
        postAmount: DbValue.toDouble(json['post_amount']),
        discountAmount: DbValue.toDouble(json['discount_amount']),
        logisticsCode: json['logistics_code'] as String?,
        logisticsName: json['logistics_name'] as String?,
        trackingNo: json['tracking_no'] as String?,
        buyerWords: json['buyer_words'] as String?,
        sellerWords: json['seller_words'] as String?,
        remark: json['remark'] as String?,
        orderTime: DbValue.fromIso(json['order_time']) ?? DateTime.now(),
        payTime: DbValue.fromIso(json['pay_time']),
        shipTime: DbValue.fromIso(json['ship_time']),
        finishTime: DbValue.fromIso(json['finish_time']),
        douyinUpdateTime: DbValue.fromIso(json['douyin_update_time']),
        createdAt: DbValue.fromIso(json['created_at']) ?? DateTime.now(),
        updatedAt: DbValue.fromIso(json['updated_at']) ?? DateTime.now(),
        isDeleted: DbValue.toBool(json['is_deleted']),
        syncState: SyncState.synced,
      );
}
