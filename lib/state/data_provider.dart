import 'package:flutter/foundation.dart';

import '../data/models/after_sale.dart';
import '../data/models/customer.dart';
import '../data/models/order_item.dart';
import '../data/models/order_status.dart';
import '../data/models/product.dart';
import '../data/models/shop_order.dart';
import '../data/repositories/after_sale_repository.dart';
import '../data/repositories/customer_repository.dart';
import '../data/repositories/order_repository.dart';
import '../data/repositories/product_repository.dart';
import '../data/sync/douyin_sync_service.dart';
import '../data/sync/sync_service.dart';

/// ============================================================================
/// 业务数据总状态
///
/// 设计思路（与「服装订单管家」保持一致）：
///   · 登录后一次性把本账号的客户 / 订单 / 商品 / 售后单全部读进内存；
///   · 列表的搜索、筛选、排序、统计全部在内存里算，翻页零延迟，断网照常用；
///   · 任何写操作都先落 SQLite，再由同步引擎异步推云端，
///     写完立刻更新内存并 notifyListeners，界面即时响应，不等网络。
///
/// 两条同步链路的刷新入口都在这里注册：
///   · [SyncService]        —— 本地 ⇄ Supabase 多端双向同步完成后刷新界面；
///   · [DouyinSyncService]  —— 抖店订单增量拉取完成后刷新界面。
/// ============================================================================
class DataProvider extends ChangeNotifier {
  DataProvider() {
    // 云端拉取到新数据后自动刷新界面
    SyncService.instance.addListener(_onSyncChanged);
    // 抖店订单同步完成后刷新界面
    DouyinSyncService.instance.onDataChanged = _onDouyinChanged;
  }

  final CustomerRepository _customerRepo = const CustomerRepository();
  final OrderRepository _orderRepo = const OrderRepository();
  final ProductRepository _productRepo = const ProductRepository();
  final AfterSaleRepository _afterSaleRepo = const AfterSaleRepository();

  String? _userId;
  bool _loading = false;
  bool _loaded = false;

  List<Customer> _customers = <Customer>[];
  List<ShopOrder> _orders = <ShopOrder>[];
  List<Product> _products = <Product>[];
  List<AfterSale> _afterSales = <AfterSale>[];

  // —— 订单列表的筛选条件（跨页面保持，返回列表时不丢失） ——
  String _orderKeyword = '';
  Set<OrderStatus> _orderStatusFilter = <OrderStatus>{};
  OrderSortBy _orderSortBy = OrderSortBy.createdDesc;
  OrderSource? _orderSourceFilter;
  bool _orderOnlyUnshipped = false;
  DateTime? _orderFrom;
  DateTime? _orderTo;

  // —— 客户列表关键字 ——
  String _customerKeyword = '';

  // —— 商品列表筛选 ——
  String _productKeyword = '';
  String? _productCategory;
  bool _productOnlyActive = false;

  // —— 售后单列表筛选 ——
  String _afterSaleKeyword = '';
  Set<AfterSaleStage> _afterSaleStageFilter = <AfterSaleStage>{};
  Set<AfterSaleType> _afterSaleTypeFilter = <AfterSaleType>{};

  DateTime? _lastSyncPhaseAt;
  DateTime? _lastDouyinSyncAt;

  // ---------------------------------------------------------------------------
  // 只读访问
  // ---------------------------------------------------------------------------
  bool get loading => _loading;

  bool get loaded => _loaded;

  String? get userId => _userId;

  List<Customer> get customers => _customers;

  List<ShopOrder> get orders => _orders;

  List<Product> get products => _products;

  List<AfterSale> get afterSales => _afterSales;

  String get orderKeyword => _orderKeyword;

  Set<OrderStatus> get orderStatusFilter => _orderStatusFilter;

  OrderSortBy get orderSortBy => _orderSortBy;

  OrderSource? get orderSourceFilter => _orderSourceFilter;

  bool get orderOnlyUnshipped => _orderOnlyUnshipped;

  DateTime? get orderFrom => _orderFrom;

  DateTime? get orderTo => _orderTo;

  String get customerKeyword => _customerKeyword;

  String get productKeyword => _productKeyword;

  String? get productCategory => _productCategory;

  bool get productOnlyActive => _productOnlyActive;

  String get afterSaleKeyword => _afterSaleKeyword;

  Set<AfterSaleStage> get afterSaleStageFilter => _afterSaleStageFilter;

  Set<AfterSaleType> get afterSaleTypeFilter => _afterSaleTypeFilter;

  /// 按当前筛选条件计算出的订单列表
  List<ShopOrder> get visibleOrders => _orderRepo.filterAndSort(
        _orders,
        keyword: _orderKeyword,
        statuses: _orderStatusFilter,
        source0: _orderSourceFilter,
        onlyUnshipped: _orderOnlyUnshipped,
        from: _orderFrom,
        to: _orderTo,
        sortBy: _orderSortBy,
      );

  /// 按关键字过滤后的客户列表
  List<Customer> get visibleCustomers =>
      _customerRepo.search(_customers, _customerKeyword);

  /// 按关键字 / 分类过滤后的商品列表
  List<Product> get visibleProducts => _productRepo.search(
        _products,
        keyword: _productKeyword,
        category: _productCategory,
        onlyActive: _productOnlyActive,
      );

  /// 按关键字 / 进度 / 类型过滤后的售后单列表
  List<AfterSale> get visibleAfterSales => _afterSaleRepo.search(
        _afterSales,
        keyword: _afterSaleKeyword,
        stages: _afterSaleStageFilter,
        types: _afterSaleTypeFilter,
      );

  // ---------------------------------------------------------------------------
  // 加载
  // ---------------------------------------------------------------------------
  Future<void> load(String userId, {bool force = false}) async {
    if (_loading) return;
    if (_loaded && _userId == userId && !force) return;

    _userId = userId;
    _loading = true;
    notifyListeners();

    try {
      final List<Object> results = await Future.wait<Object>(<Future<Object>>[
        _customerRepo.loadAll(userId),
        _orderRepo.loadAll(userId),
        _productRepo.loadAll(userId),
        _afterSaleRepo.loadAll(userId),
      ]);
      _customers = results[0] as List<Customer>;
      _orders = results[1] as List<ShopOrder>;
      _products = results[2] as List<Product>;
      _afterSales = results[3] as List<AfterSale>;
      _loaded = true;
    } catch (e) {
      debugPrint('[Data] 加载本地数据失败: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 下拉刷新：先本地重读，再触发一次云端同步
  Future<void> refresh({bool withSync = true}) async {
    final String? uid = _userId;
    if (uid == null) return;
    if (withSync) {
      await SyncService.instance.syncAll(manual: true);
    }
    await load(uid, force: true);
  }

  /// 退出登录时清空内存，避免下一个账号看到上一个账号的数据
  void clear() {
    _userId = null;
    _loaded = false;
    _customers = <Customer>[];
    _orders = <ShopOrder>[];
    _products = <Product>[];
    _afterSales = <AfterSale>[];
    _resetOrderFilters();
    _customerKeyword = '';
    _productKeyword = '';
    _productCategory = null;
    _productOnlyActive = false;
    _afterSaleKeyword = '';
    _afterSaleStageFilter = <AfterSaleStage>{};
    _afterSaleTypeFilter = <AfterSaleType>{};
    notifyListeners();
  }

  void _onSyncChanged() {
    final SyncService sync = SyncService.instance;
    // 每次同步成功后，重新读一遍本地库，把云端拉下来的改动呈现出来
    if (sync.phase == SyncPhase.success &&
        sync.lastSuccessAt != null &&
        sync.lastSuccessAt != _lastSyncPhaseAt) {
      _lastSyncPhaseAt = sync.lastSuccessAt;
      final String? uid = _userId;
      if (uid != null && _loaded) load(uid, force: true);
    }
  }

  void _onDouyinChanged() {
    final DateTime now = DateTime.now();
    // 抖店同步可能写入新订单 / 售后单，重读本地库刷新界面
    if (_lastDouyinSyncAt == null ||
        now.difference(_lastDouyinSyncAt!) > const Duration(milliseconds: 400)) {
      _lastDouyinSyncAt = now;
      final String? uid = _userId;
      if (uid != null && _loaded) load(uid, force: true);
    }
  }

  // ---------------------------------------------------------------------------
  // 订单筛选条件
  // ---------------------------------------------------------------------------
  void _resetOrderFilters() {
    _orderKeyword = '';
    _orderStatusFilter = <OrderStatus>{};
    _orderSortBy = OrderSortBy.createdDesc;
    _orderSourceFilter = null;
    _orderOnlyUnshipped = false;
    _orderFrom = null;
    _orderTo = null;
  }

  void setOrderKeyword(String value) {
    if (_orderKeyword == value) return;
    _orderKeyword = value;
    notifyListeners();
  }

  void toggleOrderStatus(OrderStatus status) {
    final Set<OrderStatus> next = <OrderStatus>{..._orderStatusFilter};
    if (!next.remove(status)) next.add(status);
    _orderStatusFilter = next;
    notifyListeners();
  }

  void clearOrderStatusFilter() {
    if (_orderStatusFilter.isEmpty) return;
    _orderStatusFilter = <OrderStatus>{};
    notifyListeners();
  }

  void setOrderSortBy(OrderSortBy sortBy) {
    if (_orderSortBy == sortBy) return;
    _orderSortBy = sortBy;
    notifyListeners();
  }

  void setOrderSourceFilter(OrderSource? source) {
    if (_orderSourceFilter == source) return;
    _orderSourceFilter = source;
    notifyListeners();
  }

  void setOrderOnlyUnshipped(bool value) {
    if (_orderOnlyUnshipped == value) return;
    _orderOnlyUnshipped = value;
    notifyListeners();
  }

  void setOrderDateRange(DateTime? from, DateTime? to) {
    _orderFrom = from;
    _orderTo = to;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 客户筛选条件
  // ---------------------------------------------------------------------------
  void setCustomerKeyword(String value) {
    if (_customerKeyword == value) return;
    _customerKeyword = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 商品筛选条件
  // ---------------------------------------------------------------------------
  void setProductKeyword(String value) {
    if (_productKeyword == value) return;
    _productKeyword = value;
    notifyListeners();
  }

  void setProductCategory(String? value) {
    if (_productCategory == value) return;
    _productCategory = value;
    notifyListeners();
  }

  void setProductOnlyActive(bool value) {
    if (_productOnlyActive == value) return;
    _productOnlyActive = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 售后单筛选条件
  // ---------------------------------------------------------------------------
  void setAfterSaleKeyword(String value) {
    if (_afterSaleKeyword == value) return;
    _afterSaleKeyword = value;
    notifyListeners();
  }

  void toggleAfterSaleStage(AfterSaleStage stage) {
    final Set<AfterSaleStage> next = <AfterSaleStage>{..._afterSaleStageFilter};
    if (!next.remove(stage)) next.add(stage);
    _afterSaleStageFilter = next;
    notifyListeners();
  }

  void toggleAfterSaleType(AfterSaleType type) {
    final Set<AfterSaleType> next = <AfterSaleType>{..._afterSaleTypeFilter};
    if (!next.remove(type)) next.add(type);
    _afterSaleTypeFilter = next;
    notifyListeners();
  }

  void clearAfterSaleFilters() {
    _afterSaleKeyword = '';
    _afterSaleStageFilter = <AfterSaleStage>{};
    _afterSaleTypeFilter = <AfterSaleType>{};
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 客户
  // ---------------------------------------------------------------------------
  Customer? customerById(String? id) {
    if (id == null) return null;
    for (final Customer c in _customers) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<Customer> createCustomer({
    required String name,
    String? buyerNick,
    String? phone,
    String? address,
    String? remark,
  }) async {
    final Customer created = await _customerRepo.create(
      userId: _requireUser(),
      name: name,
      buyerNick: buyerNick,
      phone: phone,
      address: address,
      remark: remark,
    );
    _customers = <Customer>[created, ..._customers];
    notifyListeners();
    return created;
  }

  Future<Customer> updateCustomer(
    Customer origin, {
    required String name,
    String? buyerNick,
    String? phone,
    String? address,
    String? remark,
  }) async {
    final Customer updated = await _customerRepo.update(
      origin,
      name: name,
      buyerNick: buyerNick,
      phone: phone,
      address: address,
      remark: remark,
    );
    _customers = _customers
        .map((Customer c) => c.id == updated.id ? updated : c)
        .toList(growable: false);

    // 姓名 / 昵称变了，内存里关联订单的冗余客户名也要跟着改
    if (origin.name != updated.name ||
        origin.buyerNick != updated.buyerNick) {
      _orders = _orders
          .map((ShopOrder o) => o.customerId == updated.id
              ? o.copyWith(buyerNick: updated.buyerNick)
              : o)
          .toList(growable: false);
    }
    notifyListeners();
    return updated;
  }

  Future<void> deleteCustomer(Customer customer) async {
    await _customerRepo.delete(customer);
    _customers = _customers
        .where((Customer c) => c.id != customer.id)
        .toList(growable: false);
    // 名下订单保留账目，仅解除关联
    _orders = _orders
        .map((ShopOrder o) =>
            o.customerId == customer.id ? o.copyWith(clearCustomer: true) : o)
        .toList(growable: false);
    notifyListeners();
  }

  /// 某客户的历史订单（内存过滤，不查库）
  List<ShopOrder> ordersOfCustomer(String customerId) => _orders
      .where((ShopOrder o) => o.customerId == customerId)
      .toList(growable: false);

  // ---------------------------------------------------------------------------
  // 订单
  // ---------------------------------------------------------------------------
  ShopOrder? orderById(String id) {
    for (final ShopOrder o in _orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  Future<ShopOrder> createOrder({
    String? orderNo,
    required OrderStatus status,
    String? customerId,
    String? buyerNick,
    String? receiverName,
    String? receiverPhone,
    String? receiverAddress,
    required List<OrderItemDraft> items,
    double postAmount = 0,
    double discountAmount = 0,
    DateTime? orderTime,
    String? buyerWords,
    String? remark,
  }) async {
    final ShopOrder created = await _orderRepo.create(
      userId: _requireUser(),
      orderNo: orderNo,
      status: status,
      customerId: customerId,
      buyerNick: buyerNick,
      receiverName: receiverName,
      receiverPhone: receiverPhone,
      receiverAddress: receiverAddress,
      items: items,
      postAmount: postAmount,
      discountAmount: discountAmount,
      orderTime: orderTime,
      buyerWords: buyerWords,
      remark: remark,
    );
    _orders = <ShopOrder>[created, ..._orders];
    notifyListeners();
    return created;
  }

  Future<ShopOrder> updateOrder(
    ShopOrder origin, {
    required OrderStatus status,
    String? customerId,
    String? buyerNick,
    String? receiverName,
    String? receiverPhone,
    String? receiverAddress,
    required List<OrderItemDraft> items,
    double postAmount = 0,
    double discountAmount = 0,
    DateTime? orderTime,
    String? buyerWords,
    String? remark,
    bool clearCustomer = false,
  }) async {
    final ShopOrder updated = await _orderRepo.update(
      origin,
      status: status,
      customerId: customerId,
      buyerNick: buyerNick,
      receiverName: receiverName,
      receiverPhone: receiverPhone,
      receiverAddress: receiverAddress,
      items: items,
      postAmount: postAmount,
      discountAmount: discountAmount,
      orderTime: orderTime,
      buyerWords: buyerWords,
      remark: remark,
      clearCustomer: clearCustomer,
    );
    _replaceOrder(updated);
    return updated;
  }

  Future<ShopOrder> changeOrderStatus(
    ShopOrder origin,
    OrderStatus status,
  ) async {
    final ShopOrder updated = await _orderRepo.changeStatus(origin, status);
    _replaceOrder(updated);
    return updated;
  }

  Future<void> deleteOrder(ShopOrder order) async {
    await _orderRepo.delete(order);
    _orders =
        _orders.where((ShopOrder o) => o.id != order.id).toList(growable: false);
    notifyListeners();
  }

  /// 单笔发货：本地状态先落库，失败原因通过 uploadError 返回（本地不回滚）
  Future<({ShopOrder order, String? uploadError})> shipOrder(
    ShopOrder origin, {
    required String companyCode,
    required String companyName,
    required String trackingNo,
  }) async {
    final ({ShopOrder order, String? uploadError}) result =
        await _orderRepo.ship(
      origin,
      companyCode: companyCode,
      companyName: companyName,
      trackingNo: trackingNo,
    );
    _replaceOrder(result.order);
    return result;
  }

  /// 批量发货，返回回传失败的订单号与原因
  Future<Map<String, String>> shipBatch(
    Map<ShopOrder, ({String code, String name, String trackingNo})> entries,
  ) async {
    final Map<String, String> failures = await _orderRepo.shipBatch(entries);
    // 批量发货后重读本地（状态已在 DAO 层批量更新）
    if (_userId != null) await load(_userId!, force: true);
    return failures;
  }

  void _replaceOrder(ShopOrder updated) {
    _orders = _orders
        .map((ShopOrder o) => o.id == updated.id ? updated : o)
        .toList(growable: false);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 商品
  // ---------------------------------------------------------------------------
  Product? productById(String? id) {
    if (id == null) return null;
    for (final Product p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<List<String>> productCategories() =>
      _productRepo.categories(_requireUser());

  Future<Product> createProduct({
    required String name,
    String? spec,
    String? skuCode,
    String? category,
    double costPrice = 0,
    double salePrice = 0,
    int stock = 0,
    String? remark,
  }) async {
    final Product created = await _productRepo.create(
      userId: _requireUser(),
      name: name,
      spec: spec,
      skuCode: skuCode,
      category: category,
      costPrice: costPrice,
      salePrice: salePrice,
      stock: stock,
      remark: remark,
    );
    _products = <Product>[created, ..._products];
    notifyListeners();
    return created;
  }

  Future<Product> updateProduct(
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
    final Product updated = await _productRepo.update(
      origin,
      name: name,
      spec: spec,
      skuCode: skuCode,
      category: category,
      costPrice: costPrice,
      salePrice: salePrice,
      stock: stock,
      remark: remark,
      isActive: isActive,
    );
    _products = _products
        .map((Product p) => p.id == updated.id ? updated : p)
        .toList(growable: false);
    notifyListeners();
    return updated;
  }

  Future<Product> toggleProductActive(Product origin) async {
    final Product updated = await _productRepo.toggleActive(origin);
    _products = _products
        .map((Product p) => p.id == updated.id ? updated : p)
        .toList(growable: false);
    notifyListeners();
    return updated;
  }

  Future<void> deleteProduct(Product product) async {
    await _productRepo.delete(product);
    _products = _products
        .where((Product p) => p.id != product.id)
        .toList(growable: false);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 售后单
  // ---------------------------------------------------------------------------
  AfterSale? afterSaleById(String? id) {
    if (id == null) return null;
    for (final AfterSale a in _afterSales) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// 某订单关联的售后单（内存过滤，最新在前）
  List<AfterSale> afterSalesOfOrder(String orderId) => _afterSales
      .where((AfterSale a) => a.orderId == orderId)
      .toList(growable: false);

  Future<AfterSale> createAfterSale({
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
    final AfterSale created = await _afterSaleRepo.create(
      userId: _requireUser(),
      orderNo: orderNo,
      orderId: orderId,
      afterSaleNo: afterSaleNo,
      type: type,
      stage: stage,
      buyerNick: buyerNick,
      productSummary: productSummary,
      reason: reason,
      refundAmount: refundAmount,
      returnTrackingNo: returnTrackingNo,
      progressNote: progressNote,
    );
    _afterSales = <AfterSale>[created, ..._afterSales];
    notifyListeners();
    return created;
  }

  Future<AfterSale> updateAfterSale(
    AfterSale origin, {
    AfterSaleType? type,
    AfterSaleStage? stage,
    String? reason,
    double? refundAmount,
    String? returnTrackingNo,
    String? progressNote,
  }) async {
    final AfterSale updated = await _afterSaleRepo.update(
      origin,
      type: type,
      stage: stage,
      reason: reason,
      refundAmount: refundAmount,
      returnTrackingNo: returnTrackingNo,
      progressNote: progressNote,
    );
    _replaceAfterSale(updated);
    return updated;
  }

  Future<AfterSale> changeAfterSaleStage(
    AfterSale origin,
    AfterSaleStage stage,
  ) async {
    final AfterSale updated = await _afterSaleRepo.changeStage(origin, stage);
    _replaceAfterSale(updated);
    return updated;
  }

  Future<void> deleteAfterSale(AfterSale origin) async {
    await _afterSaleRepo.delete(origin);
    _afterSales = _afterSales
        .where((AfterSale a) => a.id != origin.id)
        .toList(growable: false);
    notifyListeners();
  }

  void _replaceAfterSale(AfterSale updated) {
    _afterSales = _afterSales
        .map((AfterSale a) => a.id == updated.id ? updated : a)
        .toList(growable: false);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 统计（工作台 / 数据工具模块）
  // ---------------------------------------------------------------------------

  /// 今日新增订单数
  int get todayOrderCount {
    final DateTime now = DateTime.now();
    final DateTime start = DateTime(now.year, now.month, now.day);
    return _orders
        .where((ShopOrder o) => !o.orderTime.isBefore(start))
        .length;
  }

  /// 今日新增订单总额（实付）
  double get todayOrderAmount {
    final DateTime now = DateTime.now();
    final DateTime start = DateTime(now.year, now.month, now.day);
    double sum = 0;
    for (final ShopOrder o in _orders) {
      if (!o.orderTime.isBefore(start)) sum += o.payAmount;
    }
    return sum;
  }

  /// 本月订单总额（实付）
  double get monthOrderAmount {
    final DateTime now = DateTime.now();
    final DateTime start = DateTime(now.year, now.month);
    final DateTime end = DateTime(now.year, now.month + 1);
    double sum = 0;
    for (final ShopOrder o in _orders) {
      if (!o.orderTime.isBefore(start) && o.orderTime.isBefore(end)) {
        sum += o.payAmount;
      }
    }
    return sum;
  }

  /// 累计销售额（计入成交的状态：待发货 / 已发货 / 已完成）
  double get totalSales {
    double sum = 0;
    for (final ShopOrder o in _orders) {
      if (o.status.countsAsSales) sum += o.payAmount;
    }
    return sum;
  }

  /// 本月销售额（计入成交状态的实付合计）
  double get monthSales {
    final DateTime now = DateTime.now();
    final DateTime start = DateTime(now.year, now.month);
    final DateTime end = DateTime(now.year, now.month + 1);
    double sum = 0;
    for (final ShopOrder o in _orders) {
      if (o.status.countsAsSales &&
          !o.orderTime.isBefore(start) &&
          o.orderTime.isBefore(end)) {
        sum += o.payAmount;
      }
    }
    return sum;
  }

  /// 待发货订单数（红点）
  int get pendingShipCount =>
      _orders.where((ShopOrder o) => o.status == OrderStatus.pendingShip).length;

  /// 待发货且已超时的订单数
  int get shipOverdueCount =>
      _orders.where((ShopOrder o) => o.isShipOverdue).length;

  /// 售后未结单数量（待处理 + 处理中）
  int get openAfterSaleCount => _afterSales
      .where((AfterSale a) => a.stage.isOpen && !a.isDeleted)
      .length;

  /// 各状态订单数量（筛选栏角标）
  Map<OrderStatus, int> get statusCounts {
    final Map<OrderStatus, int> map = <OrderStatus, int>{
      for (final OrderStatus s in OrderStatusX.filterValues) s: 0,
    };
    for (final ShopOrder o in _orders) {
      if (o.isDeleted) continue;
      map[o.status] = (map[o.status] ?? 0) + 1;
    }
    return map;
  }

  /// 各售后进度数量
  Map<AfterSaleStage, int> get afterSaleStageCounts {
    final Map<AfterSaleStage, int> map = <AfterSaleStage, int>{
      for (final AfterSaleStage s in AfterSaleStageX.values) s: 0,
    };
    for (final AfterSale a in _afterSales) {
      if (a.isDeleted) continue;
      map[a.stage] = (map[a.stage] ?? 0) + 1;
    }
    return map;
  }

  /// 退款总额（售后单的退款金额合计）
  double get totalRefundAmount {
    double sum = 0;
    for (final AfterSale a in _afterSales) {
      if (a.isDeleted) continue;
      sum += a.refundAmount;
    }
    return sum;
  }

  /// 最近订单（工作台展示）
  List<ShopOrder> recentOrders({int limit = 5}) {
    final List<ShopOrder> list = <ShopOrder>[..._orders];
    list.sort((ShopOrder a, ShopOrder b) =>
        b.orderTime.compareTo(a.orderTime));
    return list.take(limit).toList(growable: false);
  }

  /// 近 N 个月的销售额走势（工作台迷你图表）
  List<({String label, double amount})> monthlySalesTrend({int months = 6}) {
    final DateTime now = DateTime.now();
    final List<({String label, double amount})> result =
        <({String label, double amount})>[];
    for (int i = months - 1; i >= 0; i--) {
      final DateTime start = DateTime(now.year, now.month - i);
      final DateTime end = DateTime(now.year, now.month - i + 1);
      double sum = 0;
      for (final ShopOrder o in _orders) {
        if (o.status.countsAsSales &&
            !o.orderTime.isBefore(start) &&
            o.orderTime.isBefore(end)) {
          sum += o.payAmount;
        }
      }
      result.add((label: '${start.month}月', amount: sum));
    }
    return result;
  }

  /// 按商品统计销量 top（销量 = 各订单明细数量合计）
  List<({String name, int quantity, double amount})> topProducts(
      {int limit = 5}) {
    final Map<String, int> qtyMap = <String, int>{};
    final Map<String, double> amountMap = <String, double>{};
    for (final ShopOrder o in _orders) {
      for (final OrderItem item in o.items) {
        final String key = item.productName.trim().isEmpty
            ? '未命名商品'
            : item.productName.trim();
        qtyMap[key] = (qtyMap[key] ?? 0) + item.quantity;
        amountMap[key] = (amountMap[key] ?? 0) + item.payAmount;
      }
    }
    final List<({String name, int quantity, double amount})> list = qtyMap.entries
        .map((MapEntry<String, int> e) => (
              name: e.key,
              quantity: e.value,
              amount: amountMap[e.key] ?? 0,
            ))
        .toList();
    list.sort((a, b) => b.quantity.compareTo(a.quantity));
    return list.take(limit).toList(growable: false);
  }

  String _requireUser() {
    final String? uid = _userId;
    if (uid == null) {
      throw StateError('尚未绑定账号，请先登录');
    }
    return uid;
  }

  @override
  void dispose() {
    SyncService.instance.removeListener(_onSyncChanged);
    DouyinSyncService.instance.onDataChanged = null;
    super.dispose();
  }
}
