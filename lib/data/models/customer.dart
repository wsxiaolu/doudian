import 'order_status.dart';
import 'sync_meta.dart';

/// ============================================================================
/// 客户（买家）实体
///
/// 对应本地表 `customers` 与 Supabase 表 `public.customers`。
///
/// 抖店同步下来的订单会自动归档买家：
///   · 优先按抖音 open_id 归并（同一买家换收件人也能认出来）
///   · 无 open_id 时按「手机号」归并，再无则按「昵称 + 收件人」归并
/// ============================================================================
class Customer {
  const Customer({
    required this.id,
    required this.userId,
    required this.name,
    this.buyerNick,
    this.openId,
    this.phone,
    this.address,
    this.remark,
    this.source = OrderSource.manual,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.syncState = SyncState.pending,
  });

  /// 主键，客户端生成 UUID v4，保证多端离线创建不冲突
  final String id;

  /// 归属账号
  final String userId;

  /// 收件人姓名（必填）
  final String name;

  /// 抖音买家昵称
  final String? buyerNick;

  /// 抖音买家 open_id（同一买家在同一店铺内唯一）
  final String? openId;

  /// 联系电话
  final String? phone;

  /// 收货地址
  final String? address;

  /// 备注
  final String? remark;

  /// 来源：抖店自动归档 / 手动创建
  final OrderSource source;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// 软删除标记
  final bool isDeleted;

  /// 本地同步状态（不上传云端）
  final SyncState syncState;

  /// 列表主标题：昵称优先，没有则用收件人
  String get displayName {
    final String nick = (buyerNick ?? '').trim();
    if (nick.isNotEmpty) return nick;
    return name.trim().isEmpty ? '未命名买家' : name.trim();
  }

  /// 检索用的拼接串，搜索时一次性匹配昵称/收件人/电话/地址/备注
  String get searchIndex =>
      '$name ${buyerNick ?? ''} ${phone ?? ''} ${address ?? ''} ${remark ?? ''}'
          .toLowerCase();

  /// 归档去重键：open_id > 手机号 > 昵称+姓名
  String get mergeKey {
    final String oid = (openId ?? '').trim();
    if (oid.isNotEmpty) return 'oid:$oid';
    final String p = (phone ?? '').trim();
    if (p.isNotEmpty) return 'phone:$p';
    return 'name:${(buyerNick ?? '').trim()}|${name.trim()}';
  }

  Customer copyWith({
    String? id,
    String? userId,
    String? name,
    String? buyerNick,
    String? openId,
    String? phone,
    String? address,
    String? remark,
    OrderSource? source,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    SyncState? syncState,
    bool clearPhone = false,
    bool clearAddress = false,
    bool clearRemark = false,
  }) {
    return Customer(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      buyerNick: buyerNick ?? this.buyerNick,
      openId: openId ?? this.openId,
      phone: clearPhone ? null : (phone ?? this.phone),
      address: clearAddress ? null : (address ?? this.address),
      remark: clearRemark ? null : (remark ?? this.remark),
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncState: syncState ?? this.syncState,
    );
  }

  // ---------------------------------------------------------------------------
  // 本地 SQLite 序列化
  // ---------------------------------------------------------------------------
  Map<String, Object?> toDb() => <String, Object?>{
        'id': id,
        'user_id': userId,
        'name': name,
        'buyer_nick': buyerNick,
        'open_id': openId,
        'phone': phone,
        'address': address,
        'remark': remark,
        'source': source.code,
        'created_at': DbValue.toMillis(createdAt),
        'updated_at': DbValue.toMillis(updatedAt),
        'is_deleted': DbValue.fromBool(isDeleted),
        'sync_state': syncState.code,
      };

  factory Customer.fromDb(Map<String, Object?> row) => Customer(
        id: '${row['id']}',
        userId: '${row['user_id']}',
        name: '${row['name'] ?? ''}',
        buyerNick: row['buyer_nick'] as String?,
        openId: row['open_id'] as String?,
        phone: row['phone'] as String?,
        address: row['address'] as String?,
        remark: row['remark'] as String?,
        source: OrderSourceX.fromCode(row['source']),
        createdAt: DbValue.fromMillis(row['created_at']) ?? DateTime.now(),
        updatedAt: DbValue.fromMillis(row['updated_at']) ?? DateTime.now(),
        isDeleted: DbValue.toBool(row['is_deleted']),
        syncState: SyncStateX.fromCode(row['sync_state']),
      );

  // ---------------------------------------------------------------------------
  // Supabase 序列化
  // ---------------------------------------------------------------------------
  Map<String, dynamic> toRemote() => <String, dynamic>{
        'id': id,
        'user_id': userId,
        'name': name,
        'buyer_nick': buyerNick,
        'open_id': openId,
        'phone': phone,
        'address': address,
        'remark': remark,
        'source': source.code,
        'created_at': DbValue.toIso(createdAt),
        'updated_at': DbValue.toIso(updatedAt),
        'is_deleted': isDeleted,
      };

  factory Customer.fromRemote(Map<String, dynamic> json) => Customer(
        id: '${json['id']}',
        userId: '${json['user_id']}',
        name: '${json['name'] ?? ''}',
        buyerNick: json['buyer_nick'] as String?,
        openId: json['open_id'] as String?,
        phone: json['phone'] as String?,
        address: json['address'] as String?,
        remark: json['remark'] as String?,
        source: OrderSourceX.fromCode(json['source']),
        createdAt: DbValue.fromIso(json['created_at']) ?? DateTime.now(),
        updatedAt: DbValue.fromIso(json['updated_at']) ?? DateTime.now(),
        isDeleted: DbValue.toBool(json['is_deleted']),
        // 从云端拉下来的数据天然就是「已同步」状态
        syncState: SyncState.synced,
      );
}
