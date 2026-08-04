import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

/// ============================================================================
/// 主键生成工具
///
/// 抖店订单会被多台设备各自拉取一遍，如果每台设备都用随机 UUID 当主键，
/// 同一笔订单在云端就会变成好几行。
///
/// 因此凡是「有天然唯一业务键」的记录（订单号、子订单号、买家 open_id），
/// 一律用业务键派生出确定性 UUID —— 任何设备算出来的结果都一样，
/// upsert 到 Supabase 时天然幂等。
/// ============================================================================
class StableId {
  StableId._();

  static const Uuid _uuid = Uuid();

  /// 随机 UUID v4，用于手动新建的记录
  static String random() => _uuid.v4();

  /// 由命名空间 + 业务键派生确定性 UUID
  ///
  /// 用 md5 摘要重排成标准 UUID v4 格式（版本位与变体位按 RFC 4122 置位），
  /// 保证结果既稳定又符合 Postgres uuid 类型的格式要求。
  static String derive(String namespace, String businessKey) {
    final List<int> digest =
        md5.convert(utf8.encode('$namespace::$businessKey')).bytes;
    final List<int> bytes = List<int>.from(digest);

    // version = 4
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // variant = RFC 4122
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int start, int end) => bytes
        .sublist(start, end)
        .map((int b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }

  /// 抖店主订单 → 本地订单主键
  static String forOrder(String userId, String orderNo) =>
      derive('order:$userId', orderNo);

  /// 抖店子订单 → 本地明细主键
  static String forOrderItem(String orderId, String skuKey) =>
      derive('item:$orderId', skuKey);

  /// 买家归并键 → 本地客户主键
  static String forCustomer(String userId, String mergeKey) =>
      derive('customer:$userId', mergeKey);

  /// 抖店售后单 → 本地售后主键
  static String forAfterSale(String userId, String afterSaleNo) =>
      derive('aftersale:$userId', afterSaleNo);
}
