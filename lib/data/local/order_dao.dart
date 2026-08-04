import 'package:sqflite/sqflite.dart';

import '../models/order_item.dart';
import '../models/shop_order.dart';
import '../models/sync_meta.dart';
import 'app_database.dart';
import 'base_dao.dart';
import 'order_item_dao.dart';

/// ============================================================================
/// 订单表数据访问
///
/// 订单主表与明细表分开存储，这里负责把两者装配成完整的 [ShopOrder]。
/// ============================================================================
class OrderDao extends BaseDao<ShopOrder> {
  const OrderDao();

  static const OrderItemDao _itemDao = OrderItemDao();

  @override
  String get table => AppDatabase.tableOrders;

  @override
  String get defaultOrderBy => 'order_time DESC';

  @override
  Map<String, Object?> encode(ShopOrder e) => e.toDb();

  @override
  ShopOrder decode(Map<String, Object?> row) => ShopOrder.fromDb(row);

  @override
  String idOf(ShopOrder e) => e.id;

  @override
  int updatedAtOf(ShopOrder e) => e.updatedAt.millisecondsSinceEpoch;

  // ---------------------------------------------------------------------------
  // 带明细的查询
  // ---------------------------------------------------------------------------

  /// 查询全部订单并装配商品明细
  Future<List<ShopOrder>> findAllWithItems(String userId) async {
    final Database d = await db;
    final List<Map<String, Object?>> rows = await d.query(
      table,
      where: 'user_id = ? AND is_deleted = 0',
      whereArgs: <Object?>[userId],
      orderBy: 'order_time DESC',
    );
    if (rows.isEmpty) return <ShopOrder>[];

    final List<ShopOrder> orders = rows.map(decode).toList();
    final Map<String, List<OrderItem>> itemMap = await _itemDao.findByOrders(
      userId,
      orders.map((ShopOrder e) => e.id).toList(),
    );
    return orders
        .map((ShopOrder o) =>
            o.copyWith(items: itemMap[o.id] ?? const <OrderItem>[]))
        .toList();
  }

  Future<ShopOrder?> findByIdWithItems(String id) async {
    final ShopOrder? order = await findById(id);
    if (order == null) return null;
    final List<OrderItem> items = await _itemDao.findByOrder(id);
    return order.copyWith(items: items);
  }

  /// 按抖音订单号查找（同步时判断是新增还是更新）
  Future<ShopOrder?> findByOrderNo(String userId, String orderNo) async {
    final Database d = await db;
    final List<Map<String, Object?>> rows = await d.query(
      table,
      where: 'user_id = ? AND order_no = ?',
      whereArgs: <Object?>[userId, orderNo],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return decode(rows.first);
  }

  /// 批量按订单号查询，返回 orderNo → ShopOrder 映射
  Future<Map<String, ShopOrder>> findByOrderNos(
    String userId,
    List<String> orderNos,
  ) async {
    final Map<String, ShopOrder> result = <String, ShopOrder>{};
    if (orderNos.isEmpty) return result;

    final Database d = await db;
    const int chunk = 300;
    for (int i = 0; i < orderNos.length; i += chunk) {
      final List<String> part = orderNos.sublist(
          i, i + chunk > orderNos.length ? orderNos.length : i + chunk);
      final String placeholders =
          List<String>.filled(part.length, '?').join(',');
      final List<Map<String, Object?>> rows = await d.query(
        table,
        where: 'user_id = ? AND order_no IN ($placeholders)',
        whereArgs: <Object?>[userId, ...part],
      );
      for (final Map<String, Object?> row in rows) {
        final ShopOrder o = decode(row);
        result[o.orderNo] = o;
      }
    }
    return result;
  }

  /// 某客户的全部历史订单
  Future<List<ShopOrder>> findByCustomer(
    String userId,
    String customerId,
  ) async {
    final Database d = await db;
    final List<Map<String, Object?>> rows = await d.query(
      table,
      where: 'user_id = ? AND customer_id = ? AND is_deleted = 0',
      whereArgs: <Object?>[userId, customerId],
      orderBy: 'order_time DESC',
    );
    return rows.map(decode).toList();
  }

  // ---------------------------------------------------------------------------
  // 写入
  // ---------------------------------------------------------------------------

  /// 保存订单及其明细（整体覆盖式写入）
  Future<void> saveWithItems(ShopOrder order) async {
    await upsert(order);
    await _itemDao.replaceForOrder(order.id, order.items);
  }

  /// 批量保存（抖店同步时用，一次事务提交，速度快很多）
  Future<void> saveAllWithItems(List<ShopOrder> orders) async {
    if (orders.isEmpty) return;
    final Database d = await db;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final Batch batch = d.batch();

    for (final ShopOrder o in orders) {
      batch.insert(
        table,
        o.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      // 明细整体替换：先软删旧的，再写新的
      batch.update(
        AppDatabase.tableOrderItems,
        <String, Object?>{
          'is_deleted': 1,
          'updated_at': now,
          'sync_state': SyncState.pending.code,
        },
        where: 'order_id = ? AND is_deleted = 0',
        whereArgs: <Object?>[o.id],
      );
      for (final OrderItem item in o.items) {
        batch.insert(
          AppDatabase.tableOrderItems,
          item.toDb(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
    await batch.commit(noResult: true);
  }

  /// 删除订单（连带明细）
  Future<void> deleteWithItems(String id) async {
    await softDelete(id);
    await _itemDao.softDeleteByOrder(id);
  }

  /// 批量标记发货
  ///
  /// [entries] 为 订单 id → (物流编码, 物流名称, 快递单号)
  Future<void> markShippedBatch(
    Map<String, ({String code, String name, String trackingNo})> entries,
  ) async {
    if (entries.isEmpty) return;
    final Database d = await db;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final Batch batch = d.batch();

    entries.forEach((String id,
        ({String code, String name, String trackingNo}) info) {
      batch.update(
        table,
        <String, Object?>{
          'status': 'shipped',
          'logistics_code': info.code,
          'logistics_name': info.name,
          'tracking_no': info.trackingNo,
          'ship_time': now,
          'updated_at': now,
          'sync_state': SyncState.pending.code,
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
    await batch.commit(noResult: true);
  }

  /// 客户被删除后断开订单引用
  Future<void> detachCustomer(String customerId) async {
    final Database d = await db;
    await d.update(
      table,
      <String, Object?>{
        'customer_id': null,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'sync_state': SyncState.pending.code,
      },
      where: 'customer_id = ?',
      whereArgs: <Object?>[customerId],
    );
  }

  /// 抖店订单增量同步用：本地已记录的最大 douyin_update_time
  Future<DateTime?> maxDouyinUpdateTime(String userId) async {
    final Database d = await db;
    final List<Map<String, Object?>> rows = await d.rawQuery(
      'SELECT MAX(douyin_update_time) AS m FROM $table '
      "WHERE user_id = ? AND source = 'douyin'",
      <Object?>[userId],
    );
    if (rows.isEmpty) return null;
    final Object? m = rows.first['m'];
    if (m == null) return null;
    return DbValue.fromMillis(m);
  }
}
