import 'package:sqflite/sqflite.dart';

import '../models/order_item.dart';
import '../models/sync_meta.dart';
import 'app_database.dart';
import 'base_dao.dart';

/// ============================================================================
/// 订单商品明细数据访问
/// ============================================================================
class OrderItemDao extends BaseDao<OrderItem> {
  const OrderItemDao();

  @override
  String get table => AppDatabase.tableOrderItems;

  @override
  String get defaultOrderBy => 'created_at ASC';

  @override
  Map<String, Object?> encode(OrderItem e) => e.toDb();

  @override
  OrderItem decode(Map<String, Object?> row) => OrderItem.fromDb(row);

  @override
  String idOf(OrderItem e) => e.id;

  @override
  int updatedAtOf(OrderItem e) => e.updatedAt.millisecondsSinceEpoch;

  /// 查某个订单下的全部明细
  Future<List<OrderItem>> findByOrder(String orderId) async {
    final Database d = await db;
    final List<Map<String, Object?>> rows = await d.query(
      table,
      where: 'order_id = ? AND is_deleted = 0',
      whereArgs: <Object?>[orderId],
      orderBy: 'created_at ASC',
    );
    return rows.map(decode).toList();
  }

  /// 批量按订单分组查明细（订单列表一次性装配，避免 N+1 查询）
  Future<Map<String, List<OrderItem>>> findByOrders(
    String userId,
    List<String> orderIds,
  ) async {
    final Map<String, List<OrderItem>> result = <String, List<OrderItem>>{};
    if (orderIds.isEmpty) return result;

    final Database d = await db;
    const int chunk = 300;
    for (int i = 0; i < orderIds.length; i += chunk) {
      final List<String> part = orderIds.sublist(
          i, i + chunk > orderIds.length ? orderIds.length : i + chunk);
      final String placeholders =
          List<String>.filled(part.length, '?').join(',');
      final List<Map<String, Object?>> rows = await d.query(
        table,
        where: 'order_id IN ($placeholders) AND is_deleted = 0',
        whereArgs: part,
        orderBy: 'created_at ASC',
      );
      for (final Map<String, Object?> row in rows) {
        final OrderItem item = decode(row);
        result.putIfAbsent(item.orderId, () => <OrderItem>[]).add(item);
      }
    }
    return result;
  }

  /// 账号下全部有效明细（统计商品销量时用）
  Future<List<OrderItem>> findAllItems(String userId) async {
    final Database d = await db;
    final List<Map<String, Object?>> rows = await d.query(
      table,
      where: 'user_id = ? AND is_deleted = 0',
      whereArgs: <Object?>[userId],
    );
    return rows.map(decode).toList();
  }

  /// 用新明细整体替换某订单的明细（编辑订单时使用）
  Future<void> replaceForOrder(String orderId, List<OrderItem> items) async {
    final Database d = await db;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final Batch batch = d.batch();

    // 旧明细统一软删除，保证云端也能同步到删除动作
    batch.update(
      table,
      <String, Object?>{
        'is_deleted': 1,
        'updated_at': now,
        'sync_state': SyncState.pending.code,
      },
      where: 'order_id = ? AND is_deleted = 0',
      whereArgs: <Object?>[orderId],
    );

    for (final OrderItem item in items) {
      batch.insert(
        table,
        item.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// 订单被删除时连带软删除其明细
  Future<void> softDeleteByOrder(String orderId) async {
    final Database d = await db;
    await d.update(
      table,
      <String, Object?>{
        'is_deleted': 1,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'sync_state': SyncState.pending.code,
      },
      where: 'order_id = ? AND is_deleted = 0',
      whereArgs: <Object?>[orderId],
    );
  }
}
