import 'package:sqflite/sqflite.dart';

import '../models/sync_meta.dart';
import 'app_database.dart';

/// ============================================================================
/// 通用 DAO 基类
///
/// 五张业务表的读写逻辑高度一致（软删除 + 同步状态 + 最后写入者胜出），
/// 这里抽成泛型基类，子类只需要提供表名和序列化方法。
/// ============================================================================
abstract class BaseDao<T> {
  const BaseDao();

  /// 表名
  String get table;

  /// 默认排序字段
  String get defaultOrderBy => 'updated_at DESC';

  Map<String, Object?> encode(T entity);

  T decode(Map<String, Object?> row);

  String idOf(T entity);

  /// 实体的最后修改时间（毫秒），用于冲突判定
  int updatedAtOf(T entity);

  Future<Database> get db async => AppDatabase.instance.database;

  // ---------------------------------------------------------------------------
  // 查询
  // ---------------------------------------------------------------------------
  Future<List<T>> findAll(String userId, {String? orderBy}) async {
    final Database d = await db;
    final List<Map<String, Object?>> rows = await d.query(
      table,
      where: 'user_id = ? AND is_deleted = 0',
      whereArgs: <Object?>[userId],
      orderBy: orderBy ?? defaultOrderBy,
    );
    return rows.map(decode).toList();
  }

  Future<T?> findById(String id) async {
    final Database d = await db;
    final List<Map<String, Object?>> rows = await d.query(
      table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return decode(rows.first);
  }

  Future<int> countAll(String userId) async {
    final Database d = await db;
    final List<Map<String, Object?>> rows = await d.rawQuery(
      'SELECT COUNT(*) AS c FROM $table WHERE user_id = ? AND is_deleted = 0',
      <Object?>[userId],
    );
    return DbValue.toInt(rows.isEmpty ? 0 : rows.first['c']);
  }

  // ---------------------------------------------------------------------------
  // 写入
  // ---------------------------------------------------------------------------
  Future<void> upsert(T entity) async {
    final Database d = await db;
    await d.insert(
      table,
      encode(entity),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertAll(List<T> list) async {
    if (list.isEmpty) return;
    final Database d = await db;
    final Batch batch = d.batch();
    for (final T e in list) {
      batch.insert(
        table,
        encode(e),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// 软删除：标记 is_deleted，等待同步推送到云端
  Future<void> softDelete(String id) async {
    final Database d = await db;
    await d.update(
      table,
      <String, Object?>{
        'is_deleted': 1,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'sync_state': SyncState.pending.code,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> softDeleteAll(Iterable<String> ids) async {
    if (ids.isEmpty) return;
    final Database d = await db;
    final Batch batch = d.batch();
    final int now = DateTime.now().millisecondsSinceEpoch;
    for (final String id in ids) {
      batch.update(
        table,
        <String, Object?>{
          'is_deleted': 1,
          'updated_at': now,
          'sync_state': SyncState.pending.code,
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    }
    await batch.commit(noResult: true);
  }

  // ---------------------------------------------------------------------------
  // 同步相关
  // ---------------------------------------------------------------------------

  /// 取出所有待推送到云端的记录（含已软删除的）
  Future<List<T>> findPending(String userId) async {
    final Database d = await db;
    final List<Map<String, Object?>> rows = await d.query(
      table,
      where: 'user_id = ? AND sync_state = ?',
      whereArgs: <Object?>[userId, SyncState.pending.code],
    );
    return rows.map(decode).toList();
  }

  Future<int> pendingCount(String userId) async {
    final Database d = await db;
    final List<Map<String, Object?>> rows = await d.rawQuery(
      'SELECT COUNT(*) AS c FROM $table WHERE user_id = ? AND sync_state = ?',
      <Object?>[userId, SyncState.pending.code],
    );
    return DbValue.toInt(rows.isEmpty ? 0 : rows.first['c']);
  }

  Future<void> markSynced(Iterable<String> ids) async {
    if (ids.isEmpty) return;
    final Database d = await db;
    final Batch batch = d.batch();
    for (final String id in ids) {
      batch.update(
        table,
        <String, Object?>{'sync_state': SyncState.synced.code},
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    }
    await batch.commit(noResult: true);
  }

  /// 合并云端数据到本地
  ///
  /// 冲突策略：本地有未推送改动且本地时间不早于云端时，保留本地版本，
  /// 等下一轮 push 把本地改动推上去；其余情况一律以云端为准。
  Future<void> mergeFromRemote(List<T> remoteList) async {
    if (remoteList.isEmpty) return;
    final Database d = await db;

    // 先一次性把涉及到的本地行读出来，避免在循环里反复查库
    final Map<String, Map<String, Object?>> localMap =
        <String, Map<String, Object?>>{};
    const int chunk = 200;
    final List<String> ids = remoteList.map(idOf).toList();
    for (int i = 0; i < ids.length; i += chunk) {
      final List<String> part =
          ids.sublist(i, i + chunk > ids.length ? ids.length : i + chunk);
      final String placeholders = List<String>.filled(part.length, '?').join(',');
      final List<Map<String, Object?>> rows = await d.query(
        table,
        columns: <String>['id', 'updated_at', 'sync_state'],
        where: 'id IN ($placeholders)',
        whereArgs: part,
      );
      for (final Map<String, Object?> row in rows) {
        localMap['${row['id']}'] = row;
      }
    }

    final Batch batch = d.batch();
    for (final T remote in remoteList) {
      final Map<String, Object?>? local = localMap[idOf(remote)];
      if (local != null) {
        final int localUpdated = DbValue.toInt(local['updated_at']);
        final bool localPending =
            SyncStateX.fromCode(local['sync_state']) == SyncState.pending;
        if (localPending && localUpdated >= updatedAtOf(remote)) {
          continue;
        }
      }
      batch.insert(
        table,
        encode(remote),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}
