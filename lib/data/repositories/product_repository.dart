import '../../core/utils/stable_id.dart';
import '../local/product_dao.dart';
import '../models/product.dart';
import '../models/sync_meta.dart';
import '../sync/sync_service.dart';

/// ============================================================================
/// 商品档案仓储
///
/// 商品档案的两个用途：
///   ① 手工建单时快速挑选商品，自动带出售价；
///   ② 通过「商家编码」与抖店订单的 outer_sku_id 对应，给同步下来的订单
///      自动补上成本价，从而估算毛利。
/// ============================================================================
class ProductRepository {
  const ProductRepository();

  static const ProductDao _dao = ProductDao();

  Future<List<Product>> loadAll(String userId) =>
      _dao.findAll(userId, orderBy: 'updated_at DESC');

  Future<List<String>> categories(String userId) => _dao.allCategories(userId);

  // ---------------------------------------------------------------------------
  // 增删改
  // ---------------------------------------------------------------------------
  Future<Product> create({
    required String userId,
    required String name,
    String? spec,
    String? skuCode,
    String? category,
    double costPrice = 0,
    double salePrice = 0,
    int stock = 0,
    String? remark,
  }) async {
    final DateTime now = DateTime.now();
    final Product product = Product(
      id: StableId.random(),
      userId: userId,
      name: name.trim(),
      spec: _clean(spec),
      skuCode: _clean(skuCode),
      category: _clean(category),
      costPrice: costPrice,
      salePrice: salePrice,
      stock: stock,
      remark: _clean(remark),
      createdAt: now,
      updatedAt: now,
      syncState: SyncState.pending,
    );
    await _dao.upsert(product);
    SyncService.instance.scheduleSync();
    return product;
  }

  Future<Product> update(
    Product origin, {
    required String name,
    String? spec,
    String? skuCode,
    String? category,
    required double costPrice,
    required double salePrice,
    required int stock,
    String? remark,
    bool? isActive,
  }) async {
    final Product updated = origin.copyWith(
      name: name.trim(),
      spec: _clean(spec),
      skuCode: _clean(skuCode),
      category: _clean(category),
      costPrice: costPrice,
      salePrice: salePrice,
      stock: stock,
      remark: _clean(remark),
      isActive: isActive,
      updatedAt: DateTime.now(),
      syncState: SyncState.pending,
      clearSpec: _isBlank(spec),
      clearSkuCode: _isBlank(skuCode),
      clearCategory: _isBlank(category),
      clearRemark: _isBlank(remark),
    );
    await _dao.upsert(updated);
    SyncService.instance.scheduleSync();
    return updated;
  }

  /// 上架 / 下架
  Future<Product> toggleActive(Product origin) async {
    final Product updated = origin.copyWith(
      isActive: !origin.isActive,
      updatedAt: DateTime.now(),
      syncState: SyncState.pending,
    );
    await _dao.upsert(updated);
    SyncService.instance.scheduleSync();
    return updated;
  }

  Future<void> delete(Product product) async {
    await _dao.softDelete(product.id);
    SyncService.instance.scheduleSync();
  }

  // ---------------------------------------------------------------------------
  // 检索
  // ---------------------------------------------------------------------------
  List<Product> search(
    List<Product> source, {
    String keyword = '',
    String? category,
    bool onlyActive = false,
  }) {
    final String kw = keyword.trim().toLowerCase();
    return source.where((Product p) {
      if (onlyActive && !p.isActive) return false;
      if (category != null &&
          category.isNotEmpty &&
          (p.category ?? '') != category) {
        return false;
      }
      if (kw.isEmpty) return true;
      return p.searchIndex.contains(kw);
    }).toList(growable: false);
  }

  static String? _clean(String? value) {
    final String v = (value ?? '').trim();
    return v.isEmpty ? null : v;
  }

  static bool _isBlank(String? value) => (value ?? '').trim().isEmpty;
}
