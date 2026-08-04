import 'sync_meta.dart';

/// ============================================================================
/// 用户资料实体
/// 对应 Supabase 表 `public.user_profiles`，本地也缓存一份供离线展示
/// ============================================================================
class UserProfile {
  const UserProfile({
    required this.id,
    this.email,
    this.displayName,
    this.shopName,
    this.phone,
    this.avatarUrl,
    required this.updatedAt,
    this.isLocalOnly = false,
  });

  /// 与 Supabase auth.users.id 一致；离线本地账号则为固定值 'local-user'
  final String id;

  final String? email;

  /// 昵称
  final String? displayName;

  /// 工厂 / 店铺名称（导出对账单时会用到）
  final String? shopName;

  final String? phone;
  final String? avatarUrl;
  final DateTime updatedAt;

  /// 是否为「未连接云端」的本地账号
  final bool isLocalOnly;

  /// 展示名兜底顺序：昵称 → 邮箱前缀 → 默认
  String get shownName {
    if ((displayName ?? '').trim().isNotEmpty) return displayName!.trim();
    final String mail = email ?? '';
    if (mail.contains('@')) return mail.split('@').first;
    return isLocalOnly ? '本地用户' : '未命名用户';
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    String? shopName,
    String? phone,
    String? avatarUrl,
    DateTime? updatedAt,
    bool? isLocalOnly,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      shopName: shopName ?? this.shopName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      updatedAt: updatedAt ?? this.updatedAt,
      isLocalOnly: isLocalOnly ?? this.isLocalOnly,
    );
  }

  Map<String, Object?> toDb() => <String, Object?>{
        'id': id,
        'email': email,
        'display_name': displayName,
        'shop_name': shopName,
        'phone': phone,
        'avatar_url': avatarUrl,
        'updated_at': DbValue.toMillis(updatedAt),
        'is_local_only': DbValue.fromBool(isLocalOnly),
      };

  factory UserProfile.fromDb(Map<String, Object?> row) => UserProfile(
        id: '${row['id']}',
        email: row['email'] as String?,
        displayName: row['display_name'] as String?,
        shopName: row['shop_name'] as String?,
        phone: row['phone'] as String?,
        avatarUrl: row['avatar_url'] as String?,
        updatedAt: DbValue.fromMillis(row['updated_at']) ?? DateTime.now(),
        isLocalOnly: DbValue.toBool(row['is_local_only']),
      );

  /// 上传到 Supabase 时不带 email（邮箱由 auth 体系管理）
  Map<String, dynamic> toRemote() => <String, dynamic>{
        'id': id,
        'display_name': displayName,
        'shop_name': shopName,
        'phone': phone,
        'avatar_url': avatarUrl,
        'updated_at': DbValue.toIso(updatedAt),
      };

  factory UserProfile.fromRemote(
    Map<String, dynamic> json, {
    String? email,
  }) =>
      UserProfile(
        id: '${json['id']}',
        email: email,
        displayName: json['display_name'] as String?,
        shopName: json['shop_name'] as String?,
        phone: json['phone'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        updatedAt: DbValue.fromIso(json['updated_at']) ?? DateTime.now(),
      );
}
