/// ============================================================================
/// 同步元信息
///
/// 每一张业务表都带这几个字段，构成「离线优先 + 双向同步」的基础：
///   updatedAt   —— 最后修改时间，冲突时以「时间更新者」为准
///   isDeleted   —— 软删除。多端删除也能同步，不会出现「删了又冒出来」
///   syncPending —— 本地是否有尚未推送到云端的改动
/// ============================================================================
library;

/// 本地记录的同步状态
enum SyncState {
  /// 已与云端一致
  synced,

  /// 本地有改动待上传
  pending,
}

extension SyncStateX on SyncState {
  int get code => this == SyncState.pending ? 1 : 0;

  static SyncState fromCode(Object? code) {
    final int v = code is int ? code : int.tryParse('${code ?? 0}') ?? 0;
    return v == 1 ? SyncState.pending : SyncState.synced;
  }
}

/// 时间与数据库存储值之间的互转工具
class DbValue {
  DbValue._();

  /// DateTime → 本地 SQLite 存储值（毫秒时间戳）
  static int? toMillis(DateTime? value) => value?.millisecondsSinceEpoch;

  /// 本地 SQLite 值 → DateTime
  static DateTime? fromMillis(Object? value) {
    if (value == null) return null;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    final int? parsed = int.tryParse('$value');
    return parsed == null ? null : DateTime.fromMillisecondsSinceEpoch(parsed);
  }

  /// DateTime → Supabase（ISO8601 UTC 字符串）
  static String? toIso(DateTime? value) => value?.toUtc().toIso8601String();

  /// Supabase 返回值 → DateTime（本地时区）
  static DateTime? fromIso(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    final DateTime? parsed = DateTime.tryParse('$value');
    return parsed?.toLocal();
  }

  /// 任意值 → double
  static double toDouble(Object? value, [double fallback = 0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
  }

  /// 任意值 → int
  static int toInt(Object? value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  /// 任意值 → bool（SQLite 用 0/1，Postgres 用 true/false）
  static bool toBool(Object? value, [bool fallback = false]) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final String s = '$value'.toLowerCase();
    return s == 'true' || s == '1' || s == 't';
  }

  /// bool → SQLite 存储值
  static int fromBool(bool value) => value ? 1 : 0;

  /// 空字符串统一转为 null，避免数据库里出现 '' 和 null 两种「空」
  static String? nullIfEmpty(String? value) {
    final String? v = value?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }
}
