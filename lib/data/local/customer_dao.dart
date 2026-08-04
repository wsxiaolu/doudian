import 'package:sqflite/sqflite.dart';

import '../models/customer.dart';
import 'app_database.dart';
import 'base_dao.dart';

/// ============================================================================
/// 客户表数据访问
/// ============================================================================
class CustomerDao extends BaseDao<Customer> {
  const CustomerDao();

  @override
  String get table => AppDatabase.tableCustomers;

  @override
  String get defaultOrderBy => 'created_at DESC';

  @override
  Map<String, Object?> encode(Customer e) => e.toDb();

  @override
  Customer decode(Map<String, Object?> row) => Customer.fromDb(row);

  @override
  String idOf(Customer e) => e.id;

  @override
  int updatedAtOf(Customer e) => e.updatedAt.millisecondsSinceEpoch;

  /// 按抖音 open_id 精确查找
  Future<Customer?> findByOpenId(String userId, String openId) async {
    if (openId.trim().isEmpty) return null;
    final Database d = await db;
    final List<Map<String, Object?>> rows = await d.query(
      table,
      where: 'user_id = ? AND open_id = ? AND is_deleted = 0',
      whereArgs: <Object?>[userId, openId.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return decode(rows.first);
  }

  /// 按手机号查找（抖店未返回 open_id 时的兜底归并键）
  Future<Customer?> findByPhone(String userId, String phone) async {
    if (phone.trim().isEmpty) return null;
    final Database d = await db;
    final List<Map<String, Object?>> rows = await d.query(
      table,
      where: 'user_id = ? AND phone = ? AND is_deleted = 0',
      whereArgs: <Object?>[userId, phone.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return decode(rows.first);
  }

  /// 按昵称 + 收件人查找
  Future<Customer?> findByNickAndName(
    String userId,
    String? nick,
    String name,
  ) async {
    final Database d = await db;
    final List<Map<String, Object?>> rows = await d.query(
      table,
      where:
          'user_id = ? AND IFNULL(buyer_nick, \'\') = ? AND name = ? AND is_deleted = 0',
      whereArgs: <Object?>[userId, (nick ?? '').trim(), name.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return decode(rows.first);
  }
}
