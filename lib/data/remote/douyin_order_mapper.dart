import '../../core/utils/stable_id.dart';
import '../models/after_sale.dart';
import '../models/customer.dart';
import '../models/order_item.dart';
import '../models/order_status.dart';
import '../models/shop_order.dart';
import '../models/sync_meta.dart';

/// ============================================================================
/// 抖店 API 数据映射器
///
/// 把开放平台返回的原始 JSON 翻译成本地模型。
///
/// 抖店的返回字段在不同接口 / 不同版本之间存在别名（例如收件人可能叫
/// post_receiver，也可能叫 encrypt_post_receiver），这里统一做多字段兜底，
/// 尽最大可能把数据取全，取不到就留空而不是抛异常。
///
/// 另外注意：抖店所有金额字段单位是「分」，这里统一换算成「元」。
/// ============================================================================
class DouyinOrderMapper {
  const DouyinOrderMapper();

  /// 把一条 shop_order 映射为订单 + 明细
  ShopOrder mapOrder(
    Map<String, dynamic> json, {
    required String userId,
    String? customerId,
    /// 商家编码 → 成本价，用于自动补齐毛利口径
    Map<String, double> costBySkuCode = const <String, double>{},
  }) {
    final String orderNo = _firstString(json, <String>[
      'shop_order_id',
      'order_id',
      'shop_order_id_str',
      'p_id',
    ]);
    final String id = StableId.forOrder(userId, orderNo);
    final DateTime now = DateTime.now();

    final DateTime orderTime =
        _time(json, <String>['create_time', 'order_create_time']) ?? now;
    final DateTime? payTime = _time(json, <String>['pay_time']);
    final DateTime? shipTime =
        _time(json, <String>['ship_time', 'send_time', 'deliver_time']);
    final DateTime? finishTime =
        _time(json, <String>['finish_time', 'confirm_receipt_time']);
    final DateTime? updateTime = _time(json, <String>['update_time']);

    final OrderStatus status = OrderStatusX.fromDouyin(
      json['order_status'],
      mainStatus: json['main_status'],
    );

    // —— 收货信息 ——
    final ({String full, String? province, String? city, String? district})
        addr = _address(json);

    // —— 商品明细 ——
    final List<Map<String, dynamic>> skuList = _mapList(json, <String>[
      'sku_order_list',
      'sku_orders',
      'order_list',
    ]);
    final List<OrderItem> items = <OrderItem>[];
    for (int i = 0; i < skuList.length; i++) {
      items.add(_mapItem(
        skuList[i],
        userId: userId,
        orderId: id,
        index: i,
        costBySkuCode: costBySkuCode,
        fallbackTime: orderTime,
      ));
    }

    // 主订单金额缺失时，用明细汇总兜底
    final double payAmount = _money(json, <String>[
          'pay_amount',
          'order_amount',
          'total_amount',
        ]) ??
        items.fold<double>(0, (double s, OrderItem e) => s + e.payAmount);
    final double totalAmount = _money(json, <String>[
          'origin_amount',
          'total_amount',
          'order_amount',
        ]) ??
        items.fold<double>(0, (double s, OrderItem e) => s + e.lineTotal);
    final double postAmount =
        _money(json, <String>['post_amount', 'post_fee', 'freight']) ?? 0;
    final double discountAmount = _money(json, <String>[
          'promotion_amount',
          'discount_amount',
          'shop_discount_detail_amount',
        ]) ??
        0;

    final int itemCount = items.isEmpty
        ? _int(json, <String>['item_num', 'goods_count'])
        : items.fold<int>(0, (int s, OrderItem e) => s + e.quantity);

    // —— 物流 ——
    final String logisticsName = _firstString(json, <String>[
      'logistics_company',
      'express_company_name',
      'company_name',
    ]);
    final String trackingNo = _firstString(json, <String>[
      'logistics_code',
      'express_no',
      'tracking_no',
      'waybill_code',
    ]);
    final String logisticsCode = _firstString(json, <String>[
      'company_code',
      'logistics_company_code',
    ]);

    return ShopOrder(
      id: id,
      userId: userId,
      orderNo: orderNo,
      status: status,
      source: OrderSource.douyin,
      customerId: customerId,
      buyerNick: _buyerNick(json),
      receiverName: _nullIfEmpty(_receiver(json)),
      receiverPhone: _nullIfEmpty(_phone(json)),
      receiverAddress: _nullIfEmpty(addr.full),
      province: addr.province,
      city: addr.city,
      district: addr.district,
      productSummary: _summary(items),
      itemCount: itemCount,
      totalAmount: totalAmount,
      payAmount: payAmount,
      postAmount: postAmount,
      discountAmount: discountAmount,
      logisticsCode: _nullIfEmpty(logisticsCode),
      logisticsName: _nullIfEmpty(logisticsName),
      trackingNo: _nullIfEmpty(trackingNo),
      buyerWords: _nullIfEmpty(_firstString(json, <String>['buyer_words'])),
      sellerWords: _nullIfEmpty(_firstString(json, <String>['seller_words'])),
      orderTime: orderTime,
      payTime: payTime,
      shipTime: shipTime,
      finishTime: finishTime,
      douyinUpdateTime: updateTime,
      createdAt: orderTime,
      updatedAt: now,
      syncState: SyncState.pending,
      items: items,
    );
  }

  OrderItem _mapItem(
    Map<String, dynamic> json, {
    required String userId,
    required String orderId,
    required int index,
    required Map<String, double> costBySkuCode,
    required DateTime fallbackTime,
  }) {
    final String skuOrderNo = _firstString(json, <String>[
      'order_id',
      'sku_order_id',
      'sku_order_id_str',
    ]);
    final String key = skuOrderNo.isNotEmpty ? skuOrderNo : 'idx-$index';
    final String outerSku = _firstString(json, <String>[
      'code',
      'outer_sku_id',
      'out_sku_id',
      'outer_product_id',
    ]);

    final int qty = _int(json, <String>['item_num', 'num', 'quantity']);
    final double payAmount = _money(json, <String>['pay_amount']) ?? 0;
    final double salePrice = _money(json, <String>[
          'origin_amount',
          'sku_price',
          'price',
        ]) ??
        (qty > 0 ? payAmount / qty : payAmount);

    return OrderItem(
      id: StableId.forOrderItem(orderId, key),
      userId: userId,
      orderId: orderId,
      skuOrderNo: _nullIfEmpty(skuOrderNo),
      productName: _firstString(json, <String>[
        'product_name',
        'name',
        'title',
      ]).trim().isEmpty
          ? '未命名商品'
          : _firstString(json, <String>['product_name', 'name', 'title']),
      spec: _nullIfEmpty(_spec(json)),
      skuId: _nullIfEmpty(_firstString(json, <String>['sku_id', 'sku_id_str'])),
      outerSkuId: _nullIfEmpty(outerSku),
      imageUrl: _nullIfEmpty(
          _firstString(json, <String>['product_pic', 'pic', 'image'])),
      quantity: qty <= 0 ? 1 : qty,
      // origin_amount 是该行的总价，换算成单价
      salePrice: qty > 1 && salePrice > payAmount ? salePrice / qty : salePrice,
      payAmount: payAmount,
      costPrice: costBySkuCode[outerSku] ?? 0,
      createdAt: fallbackTime,
      updatedAt: DateTime.now(),
      syncState: SyncState.pending,
    );
  }

  /// 从订单里提炼买家档案
  Customer? mapCustomer(Map<String, dynamic> json, {required String userId}) {
    final String openId = _firstString(json, <String>[
      'doudian_open_id',
      'open_id',
      'buyer_open_id',
    ]);
    final String nick = _buyerNick(json) ?? '';
    final String receiver = _receiver(json);
    final String phone = _phone(json);

    if (openId.isEmpty && receiver.isEmpty && nick.isEmpty && phone.isEmpty) {
      return null;
    }

    final ({String full, String? province, String? city, String? district})
        addr = _address(json);
    final DateTime now = DateTime.now();

    final Customer draft = Customer(
      id: 'temp',
      userId: userId,
      name: receiver.isEmpty ? (nick.isEmpty ? '匿名买家' : nick) : receiver,
      buyerNick: _nullIfEmpty(nick),
      openId: _nullIfEmpty(openId),
      phone: _nullIfEmpty(phone),
      address: _nullIfEmpty(addr.full),
      source: OrderSource.douyin,
      createdAt: _time(json, <String>['create_time']) ?? now,
      updatedAt: now,
      syncState: SyncState.pending,
    );
    return draft.copyWith(
      id: StableId.forCustomer(userId, draft.mergeKey),
    );
  }

  /// 售后单映射
  AfterSale mapAfterSale(
    Map<String, dynamic> json, {
    required String userId,
    String? orderId,
  }) {
    final String afterSaleNo = _firstString(json, <String>[
      'aftersale_id',
      'after_sale_id',
      'aftersale_id_str',
    ]);
    final String orderNo = _firstString(json, <String>[
      'shop_order_id',
      'order_id',
      'sku_order_id',
    ]);
    final DateTime now = DateTime.now();
    final DateTime applyTime =
        _time(json, <String>['apply_time', 'create_time']) ?? now;

    return AfterSale(
      id: afterSaleNo.isEmpty
          ? StableId.forAfterSale(userId, '$orderNo-${applyTime.millisecondsSinceEpoch}')
          : StableId.forAfterSale(userId, afterSaleNo),
      userId: userId,
      orderId: orderId,
      orderNo: orderNo,
      afterSaleNo: _nullIfEmpty(afterSaleNo),
      type: AfterSaleTypeX.fromDouyin(
          json['aftersale_type'] ?? json['after_sale_type']),
      stage: _afterSaleStage(json),
      buyerNick: _buyerNick(json),
      productSummary:
          _nullIfEmpty(_firstString(json, <String>['product_name', 'name'])),
      reason: _nullIfEmpty(_firstString(json, <String>[
        'reason_text',
        'aftersale_reason',
        'reason',
      ])),
      refundAmount: _money(json, <String>['refund_amount', 'apply_amount']) ?? 0,
      returnTrackingNo: _nullIfEmpty(
          _firstString(json, <String>['logistics_code', 'return_logistics_code'])),
      applyTime: applyTime,
      finishTime: _time(json, <String>['finish_time', 'end_time']),
      createdAt: applyTime,
      updatedAt: now,
      syncState: SyncState.pending,
    );
  }

  static AfterSaleStage _afterSaleStage(Map<String, dynamic> json) {
    // 抖店 aftersale_status：常见取值 6=待商家处理 / 7=processing / 12=成功 / 11=拒绝
    final int s = _asInt(json['aftersale_status'] ?? json['after_sale_status']);
    switch (s) {
      case 6:
      case 5:
        return AfterSaleStage.pending;
      case 7:
      case 8:
      case 9:
        return AfterSaleStage.processing;
      case 12:
      case 14:
        return AfterSaleStage.finished;
      case 11:
      case 13:
        return AfterSaleStage.rejected;
      default:
        return AfterSaleStage.pending;
    }
  }

  // ---------------------------------------------------------------------------
  // 字段兜底解析
  // ---------------------------------------------------------------------------

  static String _summary(List<OrderItem> items) {
    if (items.isEmpty) return '';
    final String head = items.first.summary;
    if (items.length == 1) return head;
    return '$head 等 ${items.length} 种商品';
  }

  static String? _buyerNick(Map<String, dynamic> json) {
    final String v = _firstString(json, <String>[
      'nick_name',
      'buyer_nick',
      'user_nick',
      'buyer_name',
      'nickname',
    ]);
    return v.trim().isEmpty ? null : v.trim();
  }

  static String _receiver(Map<String, dynamic> json) {
    final String direct = _firstString(json, <String>[
      'post_receiver',
      'receiver_name',
      'post_receiver_name',
      'encrypt_post_receiver',
    ]);
    if (direct.isNotEmpty) return direct;
    final Object? addr = json['post_addr'];
    if (addr is Map) {
      return _firstString(
          Map<String, dynamic>.from(addr), <String>['receiver', 'name']);
    }
    return '';
  }

  static String _phone(Map<String, dynamic> json) {
    return _firstString(json, <String>[
      'post_tel',
      'receiver_phone',
      'encrypt_post_tel',
      'tel',
      'mobile',
    ]);
  }

  /// 解析收货地址，抖店用 province/city/town/street 四级 + detail
  static ({String full, String? province, String? city, String? district})
      _address(Map<String, dynamic> json) {
    final Object? raw = json['post_addr'];
    if (raw is! Map) {
      final String flat = _firstString(json, <String>[
        'receiver_address',
        'address',
        'encrypt_post_addr',
      ]);
      return (full: flat, province: null, city: null, district: null);
    }

    final Map<String, dynamic> addr = Map<String, dynamic>.from(raw);
    String part(String key) {
      final Object? node = addr[key];
      if (node is Map) return '${node['name'] ?? ''}';
      return '${node ?? ''}';
    }

    final String province = part('province');
    final String city = part('city');
    final String town = part('town');
    final String street = part('street');
    final String detail = _firstString(addr, <String>[
      'detail',
      'encrypt_detail',
      'address_detail',
    ]);

    final String full =
        <String>[province, city, town, street, detail].where((String e) {
      return e.trim().isNotEmpty;
    }).join(' ');

    return (
      full: full,
      province: _nullIfEmpty(province),
      city: _nullIfEmpty(city),
      district: _nullIfEmpty(town),
    );
  }

  /// 规格：抖店返回 spec 数组 [{name: 颜色, value: 白色}]
  static String _spec(Map<String, dynamic> json) {
    final Object? spec = json['spec'];
    if (spec is List) {
      final List<String> parts = <String>[];
      for (final Object? e in spec) {
        if (e is Map) {
          final String name = '${e['name'] ?? ''}'.trim();
          final String value = '${e['value'] ?? ''}'.trim();
          if (value.isEmpty) continue;
          parts.add(name.isEmpty ? value : '$name:$value');
        } else if (e != null) {
          parts.add('$e');
        }
      }
      if (parts.isNotEmpty) return parts.join(' / ');
    }
    return _firstString(json, <String>['spec_desc', 'sku_spec', 'sku_name']);
  }

  static List<Map<String, dynamic>> _mapList(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final String key in keys) {
      final Object? v = json[key];
      if (v is List && v.isNotEmpty) {
        return v
            .whereType<Map>()
            .map((Map e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return <Map<String, dynamic>>[];
  }

  static String _firstString(Map<String, dynamic> json, List<String> keys) {
    for (final String key in keys) {
      final Object? v = json[key];
      if (v == null) continue;
      final String s = '$v'.trim();
      if (s.isEmpty || s == 'null' || s == '0') continue;
      return s;
    }
    return '';
  }

  /// 金额：抖店单位是「分」，这里换算成「元」；字段不存在返回 null
  static double? _money(Map<String, dynamic> json, List<String> keys) {
    for (final String key in keys) {
      final Object? v = json[key];
      if (v == null) continue;
      if (v is num) return v / 100.0;
      final num? parsed = num.tryParse('$v');
      if (parsed != null) return parsed / 100.0;
    }
    return null;
  }

  static int _int(Map<String, dynamic> json, List<String> keys) {
    for (final String key in keys) {
      final Object? v = json[key];
      if (v == null) continue;
      if (v is num) return v.toInt();
      final int? parsed = int.tryParse('$v');
      if (parsed != null) return parsed;
    }
    return 0;
  }

  /// Unix 秒 → DateTime（部分字段可能是毫秒，这里自动识别）
  static DateTime? _time(Map<String, dynamic> json, List<String> keys) {
    for (final String key in keys) {
      final Object? v = json[key];
      if (v == null) continue;
      final int? raw = v is num ? v.toInt() : int.tryParse('$v');
      if (raw == null || raw <= 0) continue;
      // 大于 1e12 认为是毫秒
      final int millis = raw > 100000000000 ? raw : raw * 1000;
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }
    return null;
  }

  static int _asInt(Object? value) {
    if (value == null) return -1;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? -1;
  }

  static String? _nullIfEmpty(String? v) {
    final String s = (v ?? '').trim();
    return s.isEmpty ? null : s;
  }
}
