import 'package:sqflite/sqflite.dart';

import '../models/product.dart';
import 'app_database.dart';
import 'base_dao.dart';

/// ============================================================================
/// 商品档案数据访问
/// ============================================================================
class ProductDao extends BaseDao<Product> {
  const ProductDao();

  @override
  String get table => AppDatabase.tableProducts;

  @override
  String get defaultOrderBy => 'created_at DESC';

  @override
  Map<String, Object?> encode(Product e) => e.toDb();

  @override
  Product decode(Map<String, Object?> row) => Product.fromDb(row);

  @override
  String idOf(Product e) => e.id;

  @override
  int updatedAtOf(Product e) => e.updatedAt.millisecondsSinceEpoch;

  /// 按商家编码查找，用于抖店订单同步时自动补齐成本价
  Future<Product?> findBySkuCode(String userId, String skuCode) async {
    if (skuCode.trim().isEmpty) return null;
    final Database d = await db;
    final List<Map<String, Object?>> rows = await d.query(
      table,
      where: 'user_id = ? AND sku_code = ? AND is_deleted = 0',
      whereArgs: <Object?>[userId, skuCode.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return decode(rows.first);
  }

  /// 全部分类（去重）
  Future<List<String>> allCategories(String userId) async {
    final Database d = await db;
    final List<Map<String, Object?>> rows = await d.rawQuery(
      'SELECT DISTINCT category FROM $table '
      'WHERE user_id = ? AND is_deleted = 0 AND category IS NOT NULL '
      "AND TRIM(category) <> '' ORDER BY category",
      <Object?>[userId],
    );
    return rows
        .map((Map<String, Object?> e) => '${e['category']}')
        .where((String e) => e.trim().isNotEmpty)
        .toList();
  }
}
