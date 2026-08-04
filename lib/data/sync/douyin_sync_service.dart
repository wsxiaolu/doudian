import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../core/config/pref_keys.dart';
import '../local/after_sale_dao.dart';
import '../local/customer_dao.dart';
import '../local/order_dao.dart';
import '../local/product_dao.dart';
import '../models/after_sale.dart';
import '../models/customer.dart';
import '../models/order_status.dart';
import '../models/product.dart';
import '../models/shop_order.dart';
import '../models/sync_meta.dart';
import '../remote/douyin_api_service.dart';
import '../remote/douyin_order_mapper.dart';

/// 同步阶段
enum DouyinSyncPhase { idle, running, success, failed }

/// 单次同步结果
class DouyinSyncResult {
  const DouyinSyncResult({
    this.added = 0,
    this.updated = 0,
    this.afterSales = 0,
    this.customers = 0,
    this.success = true,
    this.message = '',
  });

  final int added;
  final int updated;
  final int afterSales;
  final int customers;
  final bool success;
  final String message;

  int get total => added + updated;

  String get summary {
    if (!success) return message;
    if (total == 0 && afterSales == 0) return '已是最新，无新增订单';
    final List<String> parts = <String>[];
    if (added > 0) parts.add('新增 $added 单');
    if (updated > 0) parts.add('更新 $updated 单');
    if (afterSales > 0) parts.add('售后 $afterSales 条');
    return parts.join('，');
  }
}

/// ============================================================================
/// 抖店订单自动同步服务
///
/// 【增量策略】
///   本地维护一条「水位线」= 上次成功同步时抓到的最大 update_time。
///   每次同步只拉 [水位线 - 重叠窗口, 现在] 区间内有变更的订单，
///   重叠窗口用来吸收抖店侧秒级时间抖动，避免漏单。
///
/// 【幂等策略】
///   订单主键由「账号 + 抖音订单号」派生出确定性 UUID（见 StableId），
///   因此同一笔订单无论被拉取多少次、被几台设备拉取，写入的都是同一行，
///   不会出现重复订单。
///
/// 【本地改动保护】
///   商家可能在本地补过备注、快递单号。回写时只覆盖平台侧权威字段
///   （状态、金额、收货信息），本地独有的字段一律保留。
/// ============================================================================
class DouyinSyncService extends ChangeNotifier {
  DouyinSyncService._internal();

  static final DouyinSyncService instance = DouyinSyncService._internal();

  static const OrderDao _orderDao = OrderDao();
  static const CustomerDao _customerDao = CustomerDao();
  static const ProductDao _productDao = ProductDao();
  static const AfterSaleDao _afterSaleDao = AfterSaleDao();
  static const DouyinOrderMapper _mapper = DouyinOrderMapper();

  final DouyinApiService _api = DouyinApiService.instance;

  String? _userId;
  Timer? _timer;
  bool _autoSync = false;
  int _intervalSeconds = AppConfig.defaultDouyinSyncIntervalSeconds;

  DouyinSyncPhase _phase = DouyinSyncPhase.idle;
  String _statusText = '未开始';
  DateTime? _lastSyncAt;
  DouyinSyncResult? _lastResult;

  /// 同步过程中的进度提示（例如「正在拉取第 3 页」）
  String _progressText = '';

  /// 数据变更回调，由 DataProvider 注册，同步完成后刷新界面
  VoidCallback? onDataChanged;

  DouyinSyncPhase get phase => _phase;

  String get statusText => _statusText;

  String get progressText => _progressText;

  DateTime? get lastSyncAt => _lastSyncAt;

  DouyinSyncResult? get lastResult => _lastResult;

  bool get autoSync => _autoSync;

  int get intervalSeconds => _intervalSeconds;

  bool get isRunning => _phase == DouyinSyncPhase.running;

  bool get isConfigured => _api.credentials.isConfigured;

  // ---------------------------------------------------------------------------
  // 生命周期
  // ---------------------------------------------------------------------------

  /// 登录成功后挂载
  Future<void> attach(String userId) async {
    _userId = userId;
    await _api.loadCredentials();

    final SharedPreferences sp = await SharedPreferences.getInstance();
    _autoSync = sp.getBool(PrefKeys.douyinAutoSync) ?? true;
    _intervalSeconds = sp.getInt(PrefKeys.douyinSyncInterval) ??
        AppConfig.defaultDouyinSyncIntervalSeconds;
    final int? last = sp.getInt(PrefKeys.douyinLastSyncAt);
    if (last != null) {
      _lastSyncAt = DateTime.fromMillisecondsSinceEpoch(last);
    }
    _statusText = _api.credentials.isConfigured ? '待同步' : '未配置抖店应用';
    notifyListeners();

    _restartTimer();
  }

  void detach() {
    _timer?.cancel();
    _timer = null;
    _userId = null;
    _phase = DouyinSyncPhase.idle;
    _progressText = '';
    notifyListeners();
  }

  /// 开关自动同步
  Future<void> setAutoSync(bool value) async {
    _autoSync = value;
    final SharedPreferences sp = await SharedPreferences.getInstance();
    await sp.setBool(PrefKeys.douyinAutoSync, value);
    _restartTimer();
    notifyListeners();
  }

  /// 设置同步周期（秒）
  Future<void> setInterval(int seconds) async {
    _intervalSeconds = seconds;
    final SharedPreferences sp = await SharedPreferences.getInstance();
    await sp.setInt(PrefKeys.douyinSyncInterval, seconds);
    _restartTimer();
    notifyListeners();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = null;
    if (!_autoSync || _userId == null) return;
    if (!_api.credentials.isConfigured) return;

    _timer = Timer.periodic(
      Duration(seconds: _intervalSeconds),
      (_) => syncNow(silent: true),
    );
  }

  // ---------------------------------------------------------------------------
  // 水位线
  // ---------------------------------------------------------------------------
  Future<DateTime?> _readWatermark() async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    final int? v = sp.getInt(PrefKeys.douyinWatermark);
    return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);
  }

  Future<void> _writeWatermark(DateTime value) async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    await sp.setInt(PrefKeys.douyinWatermark, value.millisecondsSinceEpoch);
  }

  /// 重置水位线，下次同步会重新全量回溯
  Future<void> resetWatermark() async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    await sp.remove(PrefKeys.douyinWatermark);
    _statusText = '已重置同步进度，下次将全量回溯';
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 同步主流程
  // ---------------------------------------------------------------------------

  /// 立即同步
  ///
  /// [silent] 为 true 时是定时器触发的后台同步，失败不做强提示。
  /// [fullBackfill] 为 true 时忽略水位线，按下单时间全量回溯。
  Future<DouyinSyncResult> syncNow({
    bool silent = false,
    bool fullBackfill = false,
    int? backfillDays,
  }) async {
    final String? userId = _userId;
    if (userId == null) {
      return const DouyinSyncResult(success: false, message: '未登录，无法同步');
    }
    if (isRunning) {
      return const DouyinSyncResult(success: false, message: '同步正在进行中');
    }
    if (!_api.credentials.isConfigured) {
      const DouyinSyncResult r =
          DouyinSyncResult(success: false, message: '尚未配置抖店应用，请先到设置页填写');
      _phase = DouyinSyncPhase.failed;
      _statusText = r.message;
      _lastResult = r;
      notifyListeners();
      return r;
    }

    _phase = DouyinSyncPhase.running;
    _statusText = '正在同步…';
    _progressText = '正在连接抖店开放平台';
    notifyListeners();

    try {
      final DouyinSyncResult result = await _runSync(
        userId,
        fullBackfill: fullBackfill,
        backfillDays: backfillDays,
      );

      _phase = DouyinSyncPhase.success;
      _lastResult = result;
      _lastSyncAt = DateTime.now();
      _statusText = result.summary;
      _progressText = '';

      final SharedPreferences sp = await SharedPreferences.getInstance();
      await sp.setInt(
          PrefKeys.douyinLastSyncAt, _lastSyncAt!.millisecondsSinceEpoch);
      await sp.setString(PrefKeys.douyinLastSyncMsg, result.summary);

      notifyListeners();
      onDataChanged?.call();
      return result;
    } catch (e) {
      final String msg =
          e is DouyinApiException ? e.toString() : '同步失败：$e';
      final DouyinSyncResult r =
          DouyinSyncResult(success: false, message: msg);
      _phase = DouyinSyncPhase.failed;
      _lastResult = r;
      _statusText = msg;
      _progressText = '';
      notifyListeners();
      return r;
    }
  }

  Future<DouyinSyncResult> _runSync(
    String userId, {
    required bool fullBackfill,
    int? backfillDays,
  }) async {
    final DateTime now = DateTime.now();
    final DateTime? watermark = fullBackfill ? null : await _readWatermark();

    // 时间窗口
    final DateTime windowStart;
    final bool useCreateTime;
    if (watermark == null) {
      final int days = backfillDays ?? AppConfig.douyinInitialBackfillDays;
      windowStart = now.subtract(Duration(days: days));
      useCreateTime = true;
    } else {
      windowStart = watermark.subtract(
        const Duration(minutes: AppConfig.douyinWatermarkOverlapMinutes),
      );
      useCreateTime = false;
    }

    // 商家编码 → 成本价，供毛利估算
    final Map<String, double> costMap = await _buildCostMap(userId);

    final List<Map<String, dynamic>> rawOrders = <Map<String, dynamic>>[];
    DateTime maxUpdateTime = watermark ?? windowStart;

    for (int page = 0; page < AppConfig.douyinMaxPages; page++) {
      _progressText = '正在拉取第 ${page + 1} 页订单…';
      notifyListeners();

      final Map<String, dynamic> data = await _api.searchOrders(
        createTimeStart: useCreateTime ? windowStart : null,
        createTimeEnd: useCreateTime ? now : null,
        updateTimeStart: useCreateTime ? null : windowStart,
        updateTimeEnd: useCreateTime ? null : now,
        page: page,
        size: AppConfig.douyinPageSize,
      );

      final List<Map<String, dynamic>> list = _extractOrderList(data);
      if (list.isEmpty) break;
      rawOrders.addAll(list);

      // 不足一页说明已经取完
      if (list.length < AppConfig.douyinPageSize) break;
    }

    if (rawOrders.isEmpty) {
      // 即使没有订单，也把水位线推进到当前时刻，避免下次重复扫描空区间
      await _writeWatermark(now);
      final int asCount = await _syncAfterSales(userId, windowStart, now);
      return DouyinSyncResult(afterSales: asCount);
    }

    _progressText = '正在归档 ${rawOrders.length} 笔订单…';
    notifyListeners();

    // —— 1. 归档买家 ——
    final Map<String, Customer> customerByKey = <String, Customer>{};
    for (final Map<String, dynamic> raw in rawOrders) {
      final Customer? c = _mapper.mapCustomer(raw, userId: userId);
      if (c == null) continue;
      customerByKey[c.id] = c;
    }
    final int customerCount =
        await _mergeCustomers(userId, customerByKey.values.toList());

    // —— 2. 映射订单并与本地已有记录合并 ——
    final List<String> orderNos = <String>[];
    final List<ShopOrder> mapped = <ShopOrder>[];
    for (final Map<String, dynamic> raw in rawOrders) {
      final ShopOrder order = _mapper.mapOrder(
        raw,
        userId: userId,
        costBySkuCode: costMap,
      );
      if (order.orderNo.isEmpty) continue;

      // 关联买家
      final Customer? c = _mapper.mapCustomer(raw, userId: userId);
      mapped.add(c == null ? order : order.copyWith(customerId: c.id));
      orderNos.add(order.orderNo);

      final DateTime? ut = order.douyinUpdateTime;
      if (ut != null && ut.isAfter(maxUpdateTime)) maxUpdateTime = ut;
    }

    final Map<String, ShopOrder> localMap =
        await _orderDao.findByOrderNos(userId, orderNos);

    int added = 0;
    int updated = 0;
    final List<ShopOrder> toSave = <ShopOrder>[];

    for (final ShopOrder remote in mapped) {
      final ShopOrder? local = localMap[remote.orderNo];
      if (local == null) {
        added++;
        toSave.add(remote);
        continue;
      }

      // 平台侧无变化则跳过，减少无谓写库
      final DateTime? localUt = local.douyinUpdateTime;
      final DateTime? remoteUt = remote.douyinUpdateTime;
      final bool unchanged = localUt != null &&
          remoteUt != null &&
          !remoteUt.isAfter(localUt) &&
          local.status == remote.status;
      if (unchanged) continue;

      updated++;
      toSave.add(_mergeWithLocal(local: local, remote: remote));
    }

    if (toSave.isNotEmpty) {
      await _orderDao.saveAllWithItems(toSave);
    }

    // —— 3. 售后单 ——
    final int afterSaleCount = await _syncAfterSales(userId, windowStart, now);

    // —— 4. 推进水位线 ——
    // 用「本次抓到的最大 update_time」而不是 now，避免因为分页截断而漏单
    final DateTime nextWatermark =
        maxUpdateTime.isAfter(now) ? now : maxUpdateTime;
    await _writeWatermark(nextWatermark);

    return DouyinSyncResult(
      added: added,
      updated: updated,
      afterSales: afterSaleCount,
      customers: customerCount,
    );
  }

  /// 合并策略：平台权威字段以抖店为准，本地独有字段予以保留
  ShopOrder _mergeWithLocal({
    required ShopOrder local,
    required ShopOrder remote,
  }) {
    // 抖店已回传物流就用抖店的，否则保留本地手工填写的快递信息
    final bool remoteHasLogistics = (remote.trackingNo ?? '').isNotEmpty;

    return remote.copyWith(
      // 本地备注、客户关联、手工物流信息不能被覆盖
      remark: local.remark,
      customerId: remote.customerId ?? local.customerId,
      trackingNo: remoteHasLogistics ? remote.trackingNo : local.trackingNo,
      logisticsCode:
          remoteHasLogistics ? remote.logisticsCode : local.logisticsCode,
      logisticsName:
          remoteHasLogistics ? remote.logisticsName : local.logisticsName,
      shipTime: remote.shipTime ?? local.shipTime,
      createdAt: local.createdAt,
      updatedAt: DateTime.now(),
      syncState: SyncState.pending,
    );
  }

  /// 买家归档：已存在则补齐信息，不存在则新建
  Future<int> _mergeCustomers(String userId, List<Customer> incoming) async {
    if (incoming.isEmpty) return 0;

    int touched = 0;
    final List<Customer> toSave = <Customer>[];

    for (final Customer c in incoming) {
      Customer? exist = await _customerDao.findById(c.id);
      // 主键没命中时，再按 open_id / 手机号兜底找一次（例如早期手工建过档）
      exist ??= await _customerDao.findByOpenId(userId, c.openId ?? '');
      exist ??= await _customerDao.findByPhone(userId, c.phone ?? '');

      if (exist == null) {
        toSave.add(c);
        touched++;
        continue;
      }

      // 只补空字段，不覆盖商家手工维护过的资料
      final Customer merged = exist.copyWith(
        buyerNick: (exist.buyerNick ?? '').isEmpty ? c.buyerNick : exist.buyerNick,
        openId: (exist.openId ?? '').isEmpty ? c.openId : exist.openId,
        phone: (exist.phone ?? '').isEmpty ? c.phone : exist.phone,
        address: (exist.address ?? '').isEmpty ? c.address : exist.address,
        updatedAt: DateTime.now(),
        syncState: SyncState.pending,
      );
      // 内容确实变了才写库
      if (merged.buyerNick != exist.buyerNick ||
          merged.openId != exist.openId ||
          merged.phone != exist.phone ||
          merged.address != exist.address) {
        toSave.add(merged);
        touched++;
      }
    }

    if (toSave.isNotEmpty) {
      await _customerDao.upsertAll(toSave);
    }
    return touched;
  }

  /// 拉取售后单
  Future<int> _syncAfterSales(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      _progressText = '正在同步售后单…';
      notifyListeners();

      final Map<String, dynamic> data = await _api.afterSaleList(
        startTime: start,
        endTime: end,
        page: 0,
        size: AppConfig.douyinPageSize,
      );

      final List<Map<String, dynamic>> list = _extractAfterSaleList(data);
      if (list.isEmpty) return 0;

      final List<AfterSale> items = <AfterSale>[];
      for (final Map<String, dynamic> raw in list) {
        final AfterSale a = _mapper.mapAfterSale(raw, userId: userId);
        if (a.orderNo.isEmpty) continue;

        // 关联到本地订单
        final ShopOrder? order =
            await _orderDao.findByOrderNo(userId, a.orderNo);
        items.add(order == null ? a : a.copyWith(orderId: order.id));

        // 订单侧同步打上「售后」状态，方便在订单列表一眼看出
        if (order != null &&
            a.stage.isOpen &&
            order.status != OrderStatus.afterSale) {
          await _orderDao.upsert(order.copyWith(
            status: OrderStatus.afterSale,
            updatedAt: DateTime.now(),
            syncState: SyncState.pending,
          ));
        }
      }

      if (items.isNotEmpty) {
        await _afterSaleDao.upsertAll(items);
      }
      return items.length;
    } catch (_) {
      // 售后接口未开通权限时不影响主流程
      return 0;
    }
  }

  /// 商家编码 → 成本价
  Future<Map<String, double>> _buildCostMap(String userId) async {
    final List<Product> products = await _productDao.findAll(userId);
    final Map<String, double> map = <String, double>{};
    for (final Product p in products) {
      final String code = (p.skuCode ?? '').trim();
      if (code.isEmpty || p.costPrice <= 0) continue;
      map[code] = p.costPrice;
    }
    return map;
  }

  // ---------------------------------------------------------------------------
  // 发货回传
  // ---------------------------------------------------------------------------

  /// 把发货信息回传给抖店
  ///
  /// 抖店订单才需要回传；线下手工单直接返回成功。
  /// 回传失败不阻断本地发货动作，仅把失败原因抛给调用方提示。
  Future<void> uploadLogistics({
    required ShopOrder order,
    required String companyCode,
    required String trackingNo,
  }) async {
    if (order.source != OrderSource.douyin) return;
    if (!_api.credentials.isConfigured) return;

    // 优先用子订单号回传，没有则用主订单号
    final String targetId = order.items.isNotEmpty &&
            (order.items.first.skuOrderNo ?? '').isNotEmpty
        ? order.items.first.skuOrderNo!
        : order.orderNo;

    await _api.uploadLogistics(
      orderId: targetId,
      companyCode: companyCode,
      trackingNo: trackingNo,
    );
  }

  // ---------------------------------------------------------------------------
  // 返回体解析
  // ---------------------------------------------------------------------------
  static List<Map<String, dynamic>> _extractOrderList(
      Map<String, dynamic> data) {
    for (final String key in <String>[
      'shop_order_list',
      'list',
      'order_list',
      'data',
    ]) {
      final Object? v = data[key];
      if (v is List) {
        return v
            .whereType<Map>()
            .map((Map e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (v is Map && v['shop_order_list'] is List) {
        return (v['shop_order_list'] as List)
            .whereType<Map>()
            .map((Map e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return <Map<String, dynamic>>[];
  }

  static List<Map<String, dynamic>> _extractAfterSaleList(
      Map<String, dynamic> data) {
    for (final String key in <String>[
      'items',
      'list',
      'aftersale_list',
      'after_sale_list',
      'data',
    ]) {
      final Object? v = data[key];
      if (v is List) {
        return v
            .whereType<Map>()
            .map((Map e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return <Map<String, dynamic>>[];
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
