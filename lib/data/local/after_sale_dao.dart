import 'package:sqflite/sqflite.dart';

import '../models/after_sale.dart';
import 'app_database.dart';
import 'base_dao.dart';

/// ============================================================================
/// 售后单数据访问
/// ============================================================================
class AfterSaleDao extends BaseDao<AfterSale> {
  const AfterSaleDao();

  @override
  String get table => AppDatabase.tableAfterSales;

  @override
  String get defaultOrderBy => 'apply_time DESC';

  @override
  Map<String, Object?> encode(AfterSale e) => e.toDb();

  @override
  AfterSale decode(Map<String, Object?> row) => AfterSale.fromDb(row);

  @override
  String idOf(AfterSale e) => e.id;

  @override
  int updatedAtOf(AfterSale e) => e.updatedAt.millisecondsSinceEpoch;

  /// 按抖店售后单号查找，避免重复同步
  Future<AfterSale?> findByAfterSaleNo(String userId, String no) async {
    if (no.trim().isEmpty) return null;
    final Database d = await db;
    final List<Map<String, Object?>> rows = await d.query(
      table,
      where: 'user_id = ? AND after_sale_no = ?',
      whereArgs: <Object?>[userId, no.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return decode(rows.first);
  }

  /// 某订单关联的售后单
  Future<List<AfterSale>> findByOrder(String orderId) async {
    final Database d = await db;
    final List<Map<String, Object?>> rows = await d.query(
      table,
      where: 'order_id = ? AND is_deleted = 0',
      whereArgs: <Object?>[orderId],
      orderBy: 'apply_time DESC',
    );
    return rows.map(decode).toList();
  }

  /// 待处理 + 处理中的数量（工作台角标）
  Future<int> openCount(String userId) async {
    final Database d = await db;
    final List<Map<String, Object?>> rows = await d.rawQuery(
      'SELECT COUNT(*) AS c FROM $table '
      "WHERE user_id = ? AND is_deleted = 0 AND stage IN ('pending','processing')",
      <Object?>[userId],
    );
    if (rows.isEmpty) return 0;
    final Object? c = rows.first['c'];
    return c is num ? c.toInt() : int.tryParse('$c') ?? 0;
  }
}
