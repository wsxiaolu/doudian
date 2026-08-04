import 'sync_meta.dart';

/// ============================================================================
/// 商品档案
///
/// 维护商品的名称、规格、成本、售价，新建线下订单时可以直接挑选带出价格，
/// 同时为订单毛利估算提供成本口径。
/// ============================================================================
class Product {
  const Product({
    required this.id,
    required this.userId,
    required this.name,
    this.spec,
    this.skuCode,
    this.category,
    this.imageUrl,
    this.costPrice = 0,
    this.salePrice = 0,
    this.stock = 0,
    this.remark,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.syncState = SyncState.pending,
  });

  final String id;
  final String userId;

  /// 商品名称
  final String name;

  /// 规格，例如「白色 / XL」
  final String? spec;

  /// 商家编码 / SKU 编码，与抖店 outer_sku_id 对应可实现自动匹配成本
  final String? skuCode;

  /// 分类
  final String? category;

  final String? imageUrl;

  /// 成本价
  final double costPrice;

  /// 售价
  final double salePrice;

  /// 库存（选填，仅做参考记录，不做强校验）
  final int stock;

  final String? remark;

  /// 是否上架启用
  final bool isActive;

  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final SyncState syncState;

  /// 毛利
  double get profit => salePrice - costPrice;

  /// 毛利率，售价为 0 时返回 null
  double? get profitRate => salePrice <= 0 ? null : profit / salePrice;

  /// 「商品名 [规格]」
  String get fullName {
    final String s = (spec ?? '').trim();
    return s.isEmpty ? name : '$name [$s]';
  }

  String get searchIndex =>
      '$name ${spec ?? ''} ${skuCode ?? ''} ${category ?? ''} ${remark ?? ''}'
          .toLowerCase();

  Product copyWith({
    String? id,
    String? userId,
    String? name,
    String? spec,
    String? skuCode,
    String? category,
    String? imageUrl,
    double? costPrice,
    double? salePrice,
    int? stock,
    String? remark,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    SyncState? syncState,
    bool clearSpec = false,
    bool clearSkuCode = false,
    bool clearCategory = false,
    bool clearRemark = false,
  }) {
    return Product(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      spec: clearSpec ? null : (spec ?? this.spec),
      skuCode: clearSkuCode ? null : (skuCode ?? this.skuCode),
      category: clearCategory ? null : (category ?? this.category),
      imageUrl: imageUrl ?? this.imageUrl,
      costPrice: costPrice ?? this.costPrice,
      salePrice: salePrice ?? this.salePrice,
      stock: stock ?? this.stock,
      remark: clearRemark ? null : (remark ?? this.remark),
      isActive: isActive ?? this.isActive,
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
        'name': name,
        'spec': spec,
        'sku_code': skuCode,
        'category': category,
        'image_url': imageUrl,
        'cost_price': costPrice,
        'sale_price': salePrice,
        'stock': stock,
        'remark': remark,
        'is_active': DbValue.fromBool(isActive),
        'created_at': DbValue.toMillis(createdAt),
        'updated_at': DbValue.toMillis(updatedAt),
        'is_deleted': DbValue.fromBool(isDeleted),
        'sync_state': syncState.code,
      };

  factory Product.fromDb(Map<String, Object?> row) => Product(
        id: '${row['id']}',
        userId: '${row['user_id']}',
        name: '${row['name'] ?? ''}',
        spec: row['spec'] as String?,
        skuCode: row['sku_code'] as String?,
        category: row['category'] as String?,
        imageUrl: row['image_url'] as String?,
        costPrice: DbValue.toDouble(row['cost_price']),
        salePrice: DbValue.toDouble(row['sale_price']),
        stock: DbValue.toInt(row['stock']),
        remark: row['remark'] as String?,
        isActive: DbValue.toBool(row['is_active'], true),
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
        'name': name,
        'spec': spec,
        'sku_code': skuCode,
        'category': category,
        'image_url': imageUrl,
        'cost_price': costPrice,
        'sale_price': salePrice,
        'stock': stock,
        'remark': remark,
        'is_active': isActive,
        'created_at': DbValue.toIso(createdAt),
        'updated_at': DbValue.toIso(updatedAt),
        'is_deleted': isDeleted,
      };

  factory Product.fromRemote(Map<String, dynamic> json) => Product(
        id: '${json['id']}',
        userId: '${json['user_id']}',
        name: '${json['name'] ?? ''}',
        spec: json['spec'] as String?,
        skuCode: json['sku_code'] as String?,
        category: json['category'] as String?,
        imageUrl: json['image_url'] as String?,
        costPrice: DbValue.toDouble(json['cost_price']),
        salePrice: DbValue.toDouble(json['sale_price']),
        stock: DbValue.toInt(json['stock']),
        remark: json['remark'] as String?,
        isActive: DbValue.toBool(json['is_active'], true),
        createdAt: DbValue.fromIso(json['created_at']) ?? DateTime.now(),
        updatedAt: DbValue.fromIso(json['updated_at']) ?? DateTime.now(),
        isDeleted: DbValue.toBool(json['is_deleted']),
        syncState: SyncState.synced,
      );
}
