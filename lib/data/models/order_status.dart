/// ============================================================================
/// 订单状态
///
/// 与抖店开放平台的 order_status / main_status 做了双向映射，
/// 同时兼容手动录入的线下订单（线下订单不会有抖音状态码）。
/// ============================================================================
library;

enum OrderStatus {
  /// 待支付
  pendingPayment,

  /// 待发货（已支付，备货中）
  pendingShip,

  /// 已发货（待收货）
  shipped,

  /// 已完成
  completed,

  /// 售后 / 退款中
  afterSale,

  /// 已取消 / 已关闭
  cancelled,
}

extension OrderStatusX on OrderStatus {
  /// 持久化用的稳定字符串码（不要改，改了会影响历史数据）
  String get code {
    switch (this) {
      case OrderStatus.pendingPayment:
        return 'pending_payment';
      case OrderStatus.pendingShip:
        return 'pending_ship';
      case OrderStatus.shipped:
        return 'shipped';
      case OrderStatus.completed:
        return 'completed';
      case OrderStatus.afterSale:
        return 'after_sale';
      case OrderStatus.cancelled:
        return 'cancelled';
    }
  }

  String get label {
    switch (this) {
      case OrderStatus.pendingPayment:
        return '待支付';
      case OrderStatus.pendingShip:
        return '待发货';
      case OrderStatus.shipped:
        return '已发货';
      case OrderStatus.completed:
        return '已完成';
      case OrderStatus.afterSale:
        return '售后退款';
      case OrderStatus.cancelled:
        return '已取消';
    }
  }

  /// 该状态下订单是否还算「有效成交」（用于销售额统计）
  bool get countsAsSales =>
      this == OrderStatus.pendingShip ||
      this == OrderStatus.shipped ||
      this == OrderStatus.completed;

  /// 是否可以执行发货动作
  bool get canShip => this == OrderStatus.pendingShip;

  /// 是否属于已终结状态
  bool get isClosed =>
      this == OrderStatus.completed || this == OrderStatus.cancelled;

  static OrderStatus fromCode(Object? value) {
    switch ('${value ?? ''}') {
      case 'pending_payment':
        return OrderStatus.pendingPayment;
      case 'pending_ship':
        return OrderStatus.pendingShip;
      case 'shipped':
        return OrderStatus.shipped;
      case 'completed':
        return OrderStatus.completed;
      case 'after_sale':
        return OrderStatus.afterSale;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pendingPayment;
    }
  }

  /// 抖店 order_status 码 → 本地状态
  ///
  /// 抖店开放平台定义：
  ///   1 = 在线支付订单未付款 / 货到付款订单未发货
  ///   2 = 已支付（备货中，待发货）
  ///   3 = 已发货（待收货，含部分发货）
  ///   4 = 已取消
  ///   5 = 已完成
  ///   105 = 已关闭
  static OrderStatus fromDouyin(Object? orderStatus, {Object? mainStatus}) {
    final int s = _asInt(orderStatus);
    switch (s) {
      case 1:
        return OrderStatus.pendingPayment;
      case 2:
        return OrderStatus.pendingShip;
      case 3:
        return OrderStatus.shipped;
      case 4:
      case 105:
        return OrderStatus.cancelled;
      case 5:
      case 6:
        return OrderStatus.completed;
    }
    // 兜底再看 main_status（1 待支付 / 2 待发货 / 3 已发货 / 4 已完成 / 5 已关闭）
    final int m = _asInt(mainStatus);
    switch (m) {
      case 1:
        return OrderStatus.pendingPayment;
      case 2:
        return OrderStatus.pendingShip;
      case 3:
        return OrderStatus.shipped;
      case 4:
        return OrderStatus.completed;
      case 5:
        return OrderStatus.cancelled;
    }
    return OrderStatus.pendingPayment;
  }

  static int _asInt(Object? value) {
    if (value == null) return -1;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? -1;
  }

  /// 手动创建线下订单时可选的状态
  static const List<OrderStatus> manualValues = <OrderStatus>[
    OrderStatus.pendingPayment,
    OrderStatus.pendingShip,
    OrderStatus.shipped,
    OrderStatus.completed,
  ];

  /// 订单列表顶部筛选条使用的顺序
  static const List<OrderStatus> filterValues = <OrderStatus>[
    OrderStatus.pendingPayment,
    OrderStatus.pendingShip,
    OrderStatus.shipped,
    OrderStatus.completed,
    OrderStatus.afterSale,
    OrderStatus.cancelled,
  ];
}

/// ----------------------------------------------------------------------------
/// 订单来源
/// ----------------------------------------------------------------------------
enum OrderSource {
  /// 抖店 API 自动同步
  douyin,

  /// 手动录入的线下订单
  manual,
}

extension OrderSourceX on OrderSource {
  String get code => this == OrderSource.douyin ? 'douyin' : 'manual';

  String get label => this == OrderSource.douyin ? '抖店同步' : '手动录入';

  static OrderSource fromCode(Object? value) =>
      '${value ?? ''}' == 'douyin' ? OrderSource.douyin : OrderSource.manual;
}

/// ----------------------------------------------------------------------------
/// 订单列表排序方式
/// ----------------------------------------------------------------------------
enum OrderSortBy {
  /// 下单时间倒序（默认）
  createdDesc,

  /// 下单时间正序
  createdAsc,

  /// 实付金额从高到低
  amountDesc,

  /// 实付金额从低到高
  amountAsc,
}

extension OrderSortByX on OrderSortBy {
  String get code {
    switch (this) {
      case OrderSortBy.createdDesc:
        return 'created_desc';
      case OrderSortBy.createdAsc:
        return 'created_asc';
      case OrderSortBy.amountDesc:
        return 'amount_desc';
      case OrderSortBy.amountAsc:
        return 'amount_asc';
    }
  }

  String get label {
    switch (this) {
      case OrderSortBy.createdDesc:
        return '最新下单';
      case OrderSortBy.createdAsc:
        return '最早下单';
      case OrderSortBy.amountDesc:
        return '金额从高到低';
      case OrderSortBy.amountAsc:
        return '金额从低到高';
    }
  }

  static OrderSortBy fromCode(Object? value) {
    switch ('${value ?? ''}') {
      case 'created_asc':
        return OrderSortBy.createdAsc;
      case 'amount_desc':
        return OrderSortBy.amountDesc;
      case 'amount_asc':
        return OrderSortBy.amountAsc;
      default:
        return OrderSortBy.createdDesc;
    }
  }
}
