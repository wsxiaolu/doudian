import '../../core/utils/stable_id.dart';
import '../local/customer_dao.dart';
import '../local/order_dao.dart';
import '../models/customer.dart';
import '../models/order_status.dart';
import '../models/sync_meta.dart';
import '../sync/sync_service.dart';

/// ============================================================================
/// 客户（买家）仓储
///
/// 所有写操作统一走这里：先落本地 SQLite，再通知同步引擎排队上云。
/// 界面永远只等本地写入，不等网络，因此断网时操作依然是即时的。
/// ============================================================================
class CustomerRepository {
  const CustomerRepository();

  static const CustomerDao _dao = CustomerDao();
  static const OrderDao _orderDao = OrderDao();

  Future<List<Customer>> loadAll(String userId) => _dao.findAll(userId);

  // ---------------------------------------------------------------------------
  // 增删改
  // ---------------------------------------------------------------------------
  Future<Customer> create({
    required String userId,
    required String name,
    String? buyerNick,
    String? phone,
    String? address,
    String? remark,
  }) async {
    final DateTime now = DateTime.now();
    final Customer customer = Customer(
      id: StableId.random(),
      userId: userId,
      name: name.trim(),
      buyerNick: _clean(buyerNick),
      phone: _clean(phone),
      address: _clean(address),
      remark: _clean(remark),
      source: OrderSource.manual,
      createdAt: now,
      updatedAt: now,
      syncState: SyncState.pending,
    );
    await _dao.upsert(customer);
    SyncService.instance.scheduleSync();
    return customer;
  }

  Future<Customer> update(
    Customer origin, {
    required String name,
    String? buyerNick,
    String? phone,
    String? address,
    String? remark,
  }) async {
    final Customer updated = origin.copyWith(
      name: name.trim(),
      buyerNick: _clean(buyerNick),
      phone: _clean(phone),
      address: _clean(address),
      remark: _clean(remark),
      updatedAt: DateTime.now(),
      syncState: SyncState.pending,
      clearPhone: _isBlank(phone),
      clearAddress: _isBlank(address),
      clearRemark: _isBlank(remark),
    );
    await _dao.upsert(updated);
    SyncService.instance.scheduleSync();
    return updated;
  }

  /// 删除客户：名下订单保留账目，仅解除关联
  Future<void> delete(Customer customer) async {
    await _dao.softDelete(customer.id);
    await _orderDao.detachCustomer(customer.id);
    SyncService.instance.scheduleSync();
  }

  // ---------------------------------------------------------------------------
  // 检索
  // ---------------------------------------------------------------------------
  List<Customer> search(List<Customer> source, String keyword) {
    final String kw = keyword.trim().toLowerCase();
    if (kw.isEmpty) return source;
    return source
        .where((Customer c) => c.searchIndex.contains(kw))
        .toList(growable: false);
  }

  static String? _clean(String? value) {
    final String v = (value ?? '').trim();
    return v.isEmpty ? null : v;
  }

  static bool _isBlank(String? value) => (value ?? '').trim().isEmpty;
}
