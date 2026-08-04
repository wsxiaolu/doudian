import 'sync_meta.dart';

/// ============================================================================
/// 订单商品明细行
///
/// 抖店一个主订单（order_id）下可以挂多个子订单（sku_order），
/// 这里一条 OrderItem 对应一个子订单 / 一个手动录入的商品行。
/// ============================================================================
class OrderItem {
  const OrderItem({
    required this.id,
    required this.userId,
    required this.orderId,
    required this.productName,
    this.skuOrderNo,
    this.productId,
    this.spec,
    this.skuId,
    this.outerSkuId,
    this.imageUrl,
    this.quantity = 1,
    this.salePrice = 0,
    this.payAmount = 0,
    this.costPrice = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.syncState = SyncState.pending,
  });

  final String id;
  final String userId;

  /// 所属订单主键（ShopOrder.id）
  final String orderId;

  /// 抖店子订单号
  final String? skuOrderNo;

  /// 关联的本地商品档案 id（手动选商品时写入）
  final String? productId;

  /// 商品名称
  final String productName;

  /// 规格描述，例如「白色 / XL」
  final String? spec;

  /// 抖店 sku_id
  final String? skuId;

  /// 商家编码（外部 SKU 编码）
  final String? outerSkuId;

  /// 商品主图
  final String? imageUrl;

  /// 数量
  final int quantity;

  /// 单价（售价）
  final double salePrice;

  /// 该商品行的买家实付
  final double payAmount;

  /// 成本单价（来自商品档案，用于毛利估算）
  final double costPrice;

  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final SyncState syncState;

  /// 该行应收金额
  double get lineTotal => salePrice * quantity;

  /// 该行成本
  double get lineCost => costPrice * quantity;

  /// 该行毛利（以实付为准）
  double get lineProfit => payAmount - lineCost;

  /// 「商品名 规格 ×数量」的一行摘要
  String get summary {
    final String s = (spec ?? '').trim();
    final String tail = s.isEmpty ? '' : ' [$s]';
    return '$productName$tail ×$quantity';
  }

  OrderItem copyWith({
    String? id,
    String? userId,
    String? orderId,
    String? skuOrderNo,
    String? productId,
    String? productName,
    String? spec,
    String? skuId,
    String? outerSkuId,
    String? imageUrl,
    int? quantity,
    double? salePrice,
    double? payAmount,
    double? costPrice,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    SyncState? syncState,
  }) {
    return OrderItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      orderId: orderId ?? this.orderId,
      skuOrderNo: skuOrderNo ?? this.skuOrderNo,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      spec: spec ?? this.spec,
      skuId: skuId ?? this.skuId,
      outerSkuId: outerSkuId ?? this.outerSkuId,
      imageUrl: imageUrl ?? this.imageUrl,
      quantity: quantity ?? this.quantity,
      salePrice: salePrice ?? this.salePrice,
      payAmount: payAmount ?? this.payAmount,
      costPrice: costPrice ?? this.costPrice,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncState: syncState ?? this.syncState,
    );
  }

  // ---------------------------------------------------------------------------
  // 本地 SQLite
  // ---------------------------------------------------------------------------
  Map<String, Object?> toDb() => <String, Object?>{
        'id': id,
        'user_id': userId,
        'order_id': orderId,
        'sku_order_no': skuOrderNo,
        'product_id': productId,
        'product_name': productName,
        'spec': spec,
        'sku_id': skuId,
        'outer_sku_id': outerSkuId,
        'image_url': imageUrl,
        'quantity': quantity,
        'sale_price': salePrice,
        'pay_amount': payAmount,
        'cost_price': costPrice,
        'created_at': DbValue.toMillis(createdAt),
        'updated_at': DbValue.toMillis(updatedAt),
        'is_deleted': DbValue.fromBool(isDeleted),
        'sync_state': syncState.code,
      };

  factory OrderItem.fromDb(Map<String, Object?> row) => OrderItem(
        id: '${row['id']}',
        userId: '${row['user_id']}',
        orderId: '${row['order_id']}',
        skuOrderNo: row['sku_order_no'] as String?,
        productId: row['product_id'] as String?,
        productName: '${row['product_name'] ?? ''}',
        spec: row['spec'] as String?,
        skuId: row['sku_id'] as String?,
        outerSkuId: row['outer_sku_id'] as String?,
        imageUrl: row['image_url'] as String?,
        quantity: DbValue.toInt(row['quantity'], 1),
        salePrice: DbValue.toDouble(row['sale_price']),
        payAmount: DbValue.toDouble(row['pay_amount']),
        costPrice: DbValue.toDouble(row['cost_price']),
        createdAt: DbValue.fromMillis(row['created_at']) ?? DateTime.now(),
        updatedAt: DbValue.fromMillis(row['updated_at']) ?? DateTime.now(),
        isDeleted: DbValue.toBool(row['is_deleted']),
        syncState: SyncStateX.fromCode(row['sync_state']),
      );

  // ---------------------------------------------------------------------------
  // Supabase
  // ---------------------------------------------------------------------------
  Map<String, dynamic> toRemote() => <String, dynamic>{
        'id': id,
        'user_id': userId,
        'order_id': orderId,
        'sku_order_no': skuOrderNo,
        'product_id': productId,
        'product_name': productName,
        'spec': spec,
        'sku_id': skuId,
        'outer_sku_id': outerSkuId,
        'image_url': imageUrl,
        'quantity': quantity,
        'sale_price': salePrice,
        'pay_amount': payAmount,
        'cost_price': costPrice,
        'created_at': DbValue.toIso(createdAt),
        'updated_at': DbValue.toIso(updatedAt),
        'is_deleted': isDeleted,
      };

  factory OrderItem.fromRemote(Map<String, dynamic> json) => OrderItem(
        id: '${json['id']}',
        userId: '${json['user_id']}',
        orderId: '${json['order_id']}',
        skuOrderNo: json['sku_order_no'] as String?,
        productId: json['product_id'] as String?,
        productName: '${json['product_name'] ?? ''}',
        spec: json['spec'] as String?,
        skuId: json['sku_id'] as String?,
        outerSkuId: json['outer_sku_id'] as String?,
        imageUrl: json['image_url'] as String?,
        quantity: DbValue.toInt(json['quantity'], 1),
        salePrice: DbValue.toDouble(json['sale_price']),
        payAmount: DbValue.toDouble(json['pay_amount']),
        costPrice: DbValue.toDouble(json['cost_price']),
        createdAt: DbValue.fromIso(json['created_at']) ?? DateTime.now(),
        updatedAt: DbValue.fromIso(json['updated_at']) ?? DateTime.now(),
        isDeleted: DbValue.toBool(json['is_deleted']),
        syncState: SyncState.synced,
      );
}
