import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/app_config.dart';
import '../../core/config/pref_keys.dart';
import '../local/after_sale_dao.dart';
import '../local/app_database.dart';
import '../local/base_dao.dart';
import '../local/customer_dao.dart';
import '../local/order_dao.dart';
import '../local/order_item_dao.dart';
import '../local/product_dao.dart';
import '../models/after_sale.dart';
import '../models/customer.dart';
import '../models/order_item.dart';
import '../models/product.dart';
import '../models/shop_order.dart';
import '../remote/supabase_service.dart';

/// 同步阶段状态
enum SyncPhase {
  /// 空闲
  idle,

  /// 正在同步
  running,

  /// 上一次同步成功
  success,

  /// 上一次同步失败
  failed,

  /// 未配置云端 / 未登录，纯本地模式
  offlineOnly,
}

/// ============================================================================
/// Supabase 双向同步引擎
///
/// 同步策略（离线优先 + 最后写入者胜出）：
///   ① PUSH —— 把本地 sync_state=pending 的记录（含软删除）批量 upsert 到云端；
///   ② PULL —— 拉取云端 updated_at 大于「上次同步水位线」的记录合并进本地；
///   ③ 合并冲突时，如果本地仍有未上传改动且时间更新，则保留本地，等下一轮推送。
///
/// 表的推送顺序遵循 [AppDatabase.syncTables]：
///   客户 → 商品 → 订单 → 订单明细 → 售后单，
///   保证被引用方先落库，云端加了外键约束时也不会失败。
///
/// 触发时机：
///   · App 启动完成后
///   · 网络从断开恢复到连通时
///   · 每 60 秒轮询一次（可在设置里关闭）
///   · 用户下拉刷新 / 点击手动同步
///   · 每次本地写操作之后（防抖合并，避免频繁请求）
/// ============================================================================
class SyncService extends ChangeNotifier {
  SyncService._internal();

  static final SyncService instance = SyncService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _pollTimer;
  Timer? _debounceTimer;

  SyncPhase _phase = SyncPhase.idle;
  String? _lastError;
  DateTime? _lastSuccessAt;
  int _pendingCount = 0;
  bool _online = true;
  bool _autoSyncEnabled = true;
  String? _userId;

  /// 五张业务表的同步单元（顺序即推送顺序）
  late final List<_TableSync<dynamic>> _units = <_TableSync<dynamic>>[
    _TableSync<Customer>(
      table: AppDatabase.tableCustomers,
      label: '客户',
      dao: const CustomerDao(),
      toRemote: (Customer e) => e.toRemote(),
      fromRemote: Customer.fromRemote,
    ),
    _TableSync<Product>(
      table: AppDatabase.tableProducts,
      label: '商品',
      dao: const ProductDao(),
      toRemote: (Product e) => e.toRemote(),
      fromRemote: Product.fromRemote,
    ),
    _TableSync<ShopOrder>(
      table: AppDatabase.tableOrders,
      label: '订单',
      dao: const OrderDao(),
      toRemote: (ShopOrder e) => e.toRemote(),
      fromRemote: ShopOrder.fromRemote,
    ),
    _TableSync<OrderItem>(
      table: AppDatabase.tableOrderItems,
      label: '订单明细',
      dao: const OrderItemDao(),
      toRemote: (OrderItem e) => e.toRemote(),
      fromRemote: OrderItem.fromRemote,
    ),
    _TableSync<AfterSale>(
      table: AppDatabase.tableAfterSales,
      label: '售后单',
      dao: const AfterSaleDao(),
      toRemote: (AfterSale e) => e.toRemote(),
      fromRemote: AfterSale.fromRemote,
    ),
  ];

  // ---------------------------------------------------------------------------
  // 对外只读状态
  // ---------------------------------------------------------------------------
  SyncPhase get phase => _phase;

  String? get lastError => _lastError;

  DateTime? get lastSuccessAt => _lastSuccessAt;

  /// 待上传条数，用于界面上的小红点提示
  int get pendingCount => _pendingCount;

  bool get isOnline => _online;

  bool get isRunning => _phase == SyncPhase.running;

  bool get autoSyncEnabled => _autoSyncEnabled;

  /// 云端可用 = 已配置 Supabase + 已登录
  bool get cloudAvailable =>
      SupabaseService.instance.isConfigured &&
      SupabaseService.instance.currentUserId != null;

  /// 状态说明文案，直接给界面用
  String get statusText {
    if (!SupabaseService.instance.isConfigured) return '本地模式（未连接云端）';
    if (SupabaseService.instance.currentUserId == null) return '未登录';
    if (!_online) return '离线中 · 待上传 $_pendingCount 条';
    switch (_phase) {
      case SyncPhase.running:
        return '正在同步…';
      case SyncPhase.failed:
        return '同步失败 · 待上传 $_pendingCount 条';
      case SyncPhase.success:
      case SyncPhase.idle:
      case SyncPhase.offlineOnly:
        if (_pendingCount > 0) return '待上传 $_pendingCount 条';
        return _lastSuccessAt == null ? '尚未同步' : '已同步';
    }
  }

  // ---------------------------------------------------------------------------
  // 生命周期
  // ---------------------------------------------------------------------------

  /// 绑定当前账号并启动自动同步
  Future<void> attach(String userId) async {
    _userId = userId;
    await refreshPendingCount();
    _startWatchers();
    // 启动后延迟 1.2 秒同步，避开首屏渲染高峰
    _debounce(const Duration(milliseconds: 1200));
  }

  /// 退出登录时解绑
  void detach() {
    _userId = null;
    _pollTimer?.cancel();
    _connectivitySub?.cancel();
    _debounceTimer?.cancel();
    _pollTimer = null;
    _connectivitySub = null;
    _phase = SyncPhase.idle;
    _pendingCount = 0;
    notifyListeners();
  }

  void setAutoSync(bool enabled) {
    _autoSyncEnabled = enabled;
    if (enabled) {
      _startWatchers();
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
    notifyListeners();
  }

  void _startWatchers() {
    // —— 网络状态监听：断网 → 联网 时立即补一次同步 ——
    _connectivitySub ??= _connectivity.onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final bool nowOnline =
          results.any((ConnectivityResult r) => r != ConnectivityResult.none);
      final bool recovered = !_online && nowOnline;
      _online = nowOnline;
      notifyListeners();
      if (recovered && _autoSyncEnabled) {
        debugPrint('[Sync] 网络已恢复，触发同步');
        _debounce(const Duration(milliseconds: 600));
      }
    });

    // —— 定时轮询兜底 ——
    if (_autoSyncEnabled) {
      _pollTimer ??= Timer.periodic(
        const Duration(seconds: AppConfig.cloudSyncIntervalSeconds),
        (_) => syncAll(),
      );
    }
  }

  /// 本地写操作之后调用：合并短时间内的多次写入，只触发一次同步
  void scheduleSync() {
    refreshPendingCount();
    if (!_autoSyncEnabled) return;
    _debounce(const Duration(seconds: 3));
  }

  void _debounce(Duration delay) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () => syncAll());
  }

  // ---------------------------------------------------------------------------
  // 核心：执行一次完整双向同步
  // ---------------------------------------------------------------------------
  Future<bool> syncAll({bool manual = false}) async {
    final String? userId = _userId;
    if (userId == null) return false;

    if (!cloudAvailable) {
      _phase = SyncPhase.offlineOnly;
      notifyListeners();
      return false;
    }
    if (_phase == SyncPhase.running) return false;

    _phase = SyncPhase.running;
    _lastError = null;
    notifyListeners();

    try {
      // ① 先推送本地改动，保证本地是「最新的一方」
      for (final _TableSync<dynamic> unit in _units) {
        await unit.push(userId);
      }
      // ② 再拉取云端增量
      for (final _TableSync<dynamic> unit in _units) {
        await unit.pull(userId);
      }

      _lastSuccessAt = DateTime.now();
      _phase = SyncPhase.success;
      _online = true;
      await refreshPendingCount();
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = SupabaseService.describeError(e);
      _phase = SyncPhase.failed;
      final String text = e.toString();
      if (text.contains('SocketException') ||
          text.contains('Failed host lookup')) {
        _online = false;
      }
      debugPrint('[Sync] 同步失败: $_lastError');
      await refreshPendingCount();
      notifyListeners();
      return false;
    }
  }

  /// 重新统计待上传条数
  Future<void> refreshPendingCount() async {
    final String? userId = _userId;
    if (userId == null) {
      _pendingCount = 0;
      return;
    }
    try {
      int total = 0;
      for (final _TableSync<dynamic> unit in _units) {
        total += await unit.dao.pendingCount(userId);
      }
      _pendingCount = total;
      notifyListeners();
    } catch (_) {
      // 数据库尚未就绪时忽略
    }
  }

  /// 重置全部水位线，下次同步会全量拉取（用于「强制从云端恢复」）
  Future<void> resetWatermarks() async {
    for (final String table in AppDatabase.syncTables) {
      await AppDatabase.instance
          .setValue(PrefKeys.cloudPullWatermark(table), '');
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _connectivitySub?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// ============================================================================
/// 单张表的同步单元
///
/// 五张业务表的推拉逻辑完全一致，抽象成泛型单元，
/// 新增业务表时只要在 [SyncService._units] 里加一行即可。
/// ============================================================================
class _TableSync<T> {
  const _TableSync({
    required this.table,
    required this.label,
    required this.dao,
    required this.toRemote,
    required this.fromRemote,
  });

  final String table;
  final String label;
  final BaseDao<T> dao;
  final Map<String, dynamic> Function(T entity) toRemote;
  final T Function(Map<String, dynamic> json) fromRemote;

  /// 本地 → 云端
  Future<int> push(String userId) async {
    final List<T> pending = await dao.findPending(userId);
    if (pending.isEmpty) return 0;

    await SupabaseService.instance.pushRows(
      table: table,
      rows: pending.map(toRemote).toList(),
    );
    await dao.markSynced(pending.map(dao.idOf));
    debugPrint('[Sync] 已上传$label ${pending.length} 条');
    return pending.length;
  }

  /// 云端 → 本地
  Future<int> pull(String userId) async {
    final DateTime since = await _readWatermark();
    final List<Map<String, dynamic>> rows =
        await SupabaseService.instance.fetchUpdatedSince(
      table: table,
      userId: userId,
      since: since,
    );
    if (rows.isEmpty) return 0;

    await dao.mergeFromRemote(rows.map(fromRemote).toList());
    await _writeWatermark(rows);
    debugPrint('[Sync] 已拉取$label ${rows.length} 条');
    return rows.length;
  }

  /// 读取本表的同步水位线（上次拉取到的最大 updated_at）
  Future<DateTime> _readWatermark() async {
    final String? raw = await AppDatabase.instance
        .getValue(PrefKeys.cloudPullWatermark(table));
    if (raw == null || raw.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// 以本批数据里最大的 updated_at 作为新水位线
  Future<void> _writeWatermark(List<Map<String, dynamic>> rows) async {
    DateTime max = DateTime.fromMillisecondsSinceEpoch(0);
    for (final Map<String, dynamic> row in rows) {
      final DateTime? t = DateTime.tryParse('${row['updated_at']}');
      if (t != null && t.isAfter(max)) max = t;
    }
    if (max.millisecondsSinceEpoch > 0) {
      await AppDatabase.instance.setValue(
        PrefKeys.cloudPullWatermark(table),
        max.toUtc().toIso8601String(),
      );
    }
  }
}
