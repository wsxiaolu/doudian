import '../../core/utils/stable_id.dart';
import '../local/after_sale_dao.dart';
import '../models/after_sale.dart';
import '../models/sync_meta.dart';
import '../sync/sync_service.dart';

/// ============================================================================
/// 售后单仓储
///
/// 抖店同步下来的退款/退货单由 [DouyinSyncService] 直接写入；
/// 这里是「商家线下登记的售后 / 进度跟进」的统一入口，同样遵循
/// 「先落本地 SQLite，再通知同步引擎排队上云」的模式。
/// ============================================================================
class AfterSaleRepository {
  const AfterSaleRepository();

  static const AfterSaleDao _dao = AfterSaleDao();

  Future<List<AfterSale>> loadAll(String userId) => _dao.findAll(userId);

  /// 某订单关联的售后单（最新在前）
  Future<List<AfterSale>> ofOrder(String orderId) =>
      _dao.findByOrder(orderId);

  /// 待处理 + 处理中的数量（工作台角标用）
  Future<int> openCount(String userId) => _dao.openCount(userId);

  // ---------------------------------------------------------------------------
  // 增删改
  // ---------------------------------------------------------------------------
  Future<AfterSale> create({
    required String userId,
    required String orderNo,
    String? orderId,
    String? afterSaleNo,
    required AfterSaleType type,
    required AfterSaleStage stage,
    String? buyerNick,
    String? productSummary,
    String? reason,
    double refundAmount = 0,
    String? returnTrackingNo,
    String? progressNote,
  }) async {
    final DateTime now = DateTime.now();
    final AfterSale a = AfterSale(
      id: StableId.random(),
      userId: userId,
      orderNo: orderNo.trim(),
      orderId: orderId,
      afterSaleNo: _clean(afterSaleNo),
      type: type,
      stage: stage,
      buyerNick: _clean(buyerNick),
      productSummary: _clean(productSummary),
      reason: _clean(reason),
      refundAmount: refundAmount,
      returnTrackingNo: _clean(returnTrackingNo),
      progressNote: _clean(progressNote),
      applyTime: now,
      finishTime: stage == AfterSaleStage.finished ? now : null,
      createdAt: now,
      updatedAt: now,
      syncState: SyncState.pending,
    );
    await _dao.upsert(a);
    SyncService.instance.scheduleSync();
    return a;
  }

  Future<AfterSale> update(
    AfterSale origin, {
    AfterSaleType? type,
    AfterSaleStage? stage,
    String? reason,
    double? refundAmount,
    String? returnTrackingNo,
    String? progressNote,
  }) async {
    final AfterSaleStage s = stage ?? origin.stage;
    final AfterSale updated = origin.copyWith(
      type: type ?? origin.type,
      stage: s,
      reason: _clean(reason) ?? origin.reason,
      refundAmount: refundAmount ?? origin.refundAmount,
      returnTrackingNo: _clean(returnTrackingNo),
      progressNote: _clean(progressNote),
      updatedAt: DateTime.now(),
      syncState: SyncState.pending,
      clearReturnTracking: _isBlank(returnTrackingNo),
      clearFinishTime: s != AfterSaleStage.finished,
    );
    await _dao.upsert(updated);
    SyncService.instance.scheduleSync();
    return updated;
  }

  /// 仅推进处理进度（待处理 → 处理中 → 已完成 / 已驳回）
  Future<AfterSale> changeStage(
    AfterSale origin,
    AfterSaleStage stage,
  ) async {
    final AfterSale updated = origin.copyWith(
      stage: stage,
      updatedAt: DateTime.now(),
      syncState: SyncState.pending,
      clearFinishTime: stage != AfterSaleStage.finished,
    );
    await _dao.upsert(updated);
    SyncService.instance.scheduleSync();
    return updated;
  }

  Future<void> delete(AfterSale origin) async {
    await _dao.softDelete(origin.id);
    SyncService.instance.scheduleSync();
  }

  // ---------------------------------------------------------------------------
  // 检索
  // ---------------------------------------------------------------------------
  List<AfterSale> search(
    List<AfterSale> source, {
    String keyword = '',
    Set<AfterSaleStage> stages = const <AfterSaleStage>{},
    Set<AfterSaleType> types = const <AfterSaleType>{},
  }) {
    final String kw = keyword.trim().toLowerCase();
    return source.where((AfterSale a) {
      if (stages.isNotEmpty && !stages.contains(a.stage)) return false;
      if (types.isNotEmpty && !types.contains(a.type)) return false;
      if (kw.isEmpty) return true;
      return a.searchIndex.contains(kw);
    }).toList(growable: false);
  }

  static String? _clean(String? value) {
    final String v = (value ?? '').trim();
    return v.isEmpty ? null : v;
  }

  static bool _isBlank(String? value) => (value ?? '').trim().isEmpty;
}
