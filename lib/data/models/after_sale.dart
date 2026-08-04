import 'sync_meta.dart';

/// ============================================================================
/// 售后类型
/// ============================================================================
enum AfterSaleType {
  /// 仅退款
  refundOnly,

  /// 退货退款
  returnRefund,

  /// 换货
  exchange,

  /// 补发
  reship,
}

extension AfterSaleTypeX on AfterSaleType {
  String get code {
    switch (this) {
      case AfterSaleType.refundOnly:
        return 'refund_only';
      case AfterSaleType.returnRefund:
        return 'return_refund';
      case AfterSaleType.exchange:
        return 'exchange';
      case AfterSaleType.reship:
        return 'reship';
    }
  }

  String get label {
    switch (this) {
      case AfterSaleType.refundOnly:
        return '仅退款';
      case AfterSaleType.returnRefund:
        return '退货退款';
      case AfterSaleType.exchange:
        return '换货';
      case AfterSaleType.reship:
        return '补发';
    }
  }

  static AfterSaleType fromCode(Object? value) {
    switch ('${value ?? ''}') {
      case 'return_refund':
        return AfterSaleType.returnRefund;
      case 'exchange':
        return AfterSaleType.exchange;
      case 'reship':
        return AfterSaleType.reship;
      default:
        return AfterSaleType.refundOnly;
    }
  }

  /// 抖店售后类型码映射（0 仅退款 / 1 退货退款 / 2 换货 / 3 补发）
  static AfterSaleType fromDouyin(Object? value) {
    final int v = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    switch (v) {
      case 1:
        return AfterSaleType.returnRefund;
      case 2:
        return AfterSaleType.exchange;
      case 3:
        return AfterSaleType.reship;
      default:
        return AfterSaleType.refundOnly;
    }
  }

  static const List<AfterSaleType> values = AfterSaleType.values;
}

/// ============================================================================
/// 售后处理进度
/// ============================================================================
enum AfterSaleStage {
  /// 待商家处理
  pending,

  /// 处理中（已同意，等待买家寄回 / 平台退款中）
  processing,

  /// 已完成
  finished,

  /// 已驳回
  rejected,
}

extension AfterSaleStageX on AfterSaleStage {
  String get code {
    switch (this) {
      case AfterSaleStage.pending:
        return 'pending';
      case AfterSaleStage.processing:
        return 'processing';
      case AfterSaleStage.finished:
        return 'finished';
      case AfterSaleStage.rejected:
        return 'rejected';
    }
  }

  String get label {
    switch (this) {
      case AfterSaleStage.pending:
        return '待处理';
      case AfterSaleStage.processing:
        return '处理中';
      case AfterSaleStage.finished:
        return '已完成';
      case AfterSaleStage.rejected:
        return '已驳回';
    }
  }

  bool get isOpen =>
      this == AfterSaleStage.pending || this == AfterSaleStage.processing;

  static AfterSaleStage fromCode(Object? value) {
    switch ('${value ?? ''}') {
      case 'processing':
        return AfterSaleStage.processing;
      case 'finished':
        return AfterSaleStage.finished;
      case 'rejected':
        return AfterSaleStage.rejected;
      default:
        return AfterSaleStage.pending;
    }
  }

  static const List<AfterSaleStage> values = AfterSaleStage.values;
}

/// ============================================================================
/// 售后单
///
/// 抖店同步下来的退款/退货单，以及商家自己登记的线下售后，统一在这里管理。
/// ============================================================================
class AfterSale {
  const AfterSale({
    required this.id,
    required this.userId,
    required this.orderNo,
    required this.type,
    required this.stage,
    this.orderId,
    this.afterSaleNo,
    this.buyerNick,
    this.productSummary,
    this.reason,
    this.refundAmount = 0,
    this.progressNote,
    this.returnTrackingNo,
    required this.applyTime,
    this.finishTime,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.syncState = SyncState.pending,
  });

  final String id;
  final String userId;

  /// 关联的本地订单主键
  final String? orderId;

  /// 抖音订单号（冗余，便于售后单独立展示与搜索）
  final String orderNo;

  /// 抖店售后单号
  final String? afterSaleNo;

  final AfterSaleType type;
  final AfterSaleStage stage;

  final String? buyerNick;
  final String? productSummary;

  /// 售后原因
  final String? reason;

  /// 退款金额
  final double refundAmount;

  /// 处理进度备注（商家自己记录的跟进过程）
  final String? progressNote;

  /// 买家退回商品的快递单号
  final String? returnTrackingNo;

  final DateTime applyTime;
  final DateTime? finishTime;

  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final SyncState syncState;

  String get searchIndex => <String>[
        orderNo,
        afterSaleNo ?? '',
        buyerNick ?? '',
        productSummary ?? '',
        reason ?? '',
        progressNote ?? '',
        returnTrackingNo ?? '',
      ].join(' ').toLowerCase();

  AfterSale copyWith({
    String? id,
    String? userId,
    String? orderId,
    String? orderNo,
    String? afterSaleNo,
    AfterSaleType? type,
    AfterSaleStage? stage,
    String? buyerNick,
    String? productSummary,
    String? reason,
    double? refundAmount,
    String? progressNote,
    String? returnTrackingNo,
    DateTime? applyTime,
    DateTime? finishTime,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    SyncState? syncState,
    bool clearFinishTime = false,
    bool clearReturnTracking = false,
  }) {
    return AfterSale(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      orderId: orderId ?? this.orderId,
      orderNo: orderNo ?? this.orderNo,
      afterSaleNo: afterSaleNo ?? this.afterSaleNo,
      type: type ?? this.type,
      stage: stage ?? this.stage,
      buyerNick: buyerNick ?? this.buyerNick,
      productSummary: productSummary ?? this.productSummary,
      reason: reason ?? this.reason,
      refundAmount: refundAmount ?? this.refundAmount,
      progressNote: progressNote ?? this.progressNote,
      returnTrackingNo: clearReturnTracking
          ? null
          : (returnTrackingNo ?? this.returnTrackingNo),
      applyTime: applyTime ?? this.applyTime,
      finishTime: clearFinishTime ? null : (finishTime ?? this.finishTime),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncState: syncState ?? this.syncState,
    );
  }

  // ---------------------------------------------------------------------------
  // 本地 SQLite
  // ---------------------------------------------------------------------------
  Map<String, Object?> toDb() => <String, Object?>{
        'id': id,
        'user_id': userId,
        'order_id': orderId,
        'order_no': orderNo,
        'after_sale_no': afterSaleNo,
        'type': type.code,
        'stage': stage.code,
        'buyer_nick': buyerNick,
        'product_summary': productSummary,
        'reason': reason,
        'refund_amount': refundAmount,
        'progress_note': progressNote,
        'return_tracking_no': returnTrackingNo,
        'apply_time': DbValue.toMillis(applyTime),
        'finish_time': DbValue.toMillis(finishTime),
        'created_at': DbValue.toMillis(createdAt),
        'updated_at': DbValue.toMillis(updatedAt),
        'is_deleted': DbValue.fromBool(isDeleted),
        'sync_state': syncState.code,
      };

  factory AfterSale.fromDb(Map<String, Object?> row) => AfterSale(
        id: '${row['id']}',
        userId: '${row['user_id']}',
        orderId: row['order_id'] as String?,
        orderNo: '${row['order_no'] ?? ''}',
        afterSaleNo: row['after_sale_no'] as String?,
        type: AfterSaleTypeX.fromCode(row['type']),
        stage: AfterSaleStageX.fromCode(row['stage']),
        buyerNick: row['buyer_nick'] as String?,
        productSummary: row['product_summary'] as String?,
        reason: row['reason'] as String?,
        refundAmount: DbValue.toDouble(row['refund_amount']),
        progressNote: row['progress_note'] as String?,
        returnTrackingNo: row['return_tracking_no'] as String?,
        applyTime: DbValue.fromMillis(row['apply_time']) ?? DateTime.now(),
        finishTime: DbValue.fromMillis(row['finish_time']),
        createdAt: DbValue.fromMillis(row['created_at']) ?? DateTime.now(),
        updatedAt: DbValue.fromMillis(row['updated_at']) ?? DateTime.now(),
        isDeleted: DbValue.toBool(row['is_deleted']),
        syncState: SyncStateX.fromCode(row['sync_state']),
      );

  // ---------------------------------------------------------------------------
  // Supabase
  // ---------------------------------------------------------------------------
  Map<String, dynamic> toRemote() => <String, dynamic>{
        'id': id,
        'user_id': userId,
        'order_id': orderId,
        'order_no': orderNo,
        'after_sale_no': afterSaleNo,
        'type': type.code,
        'stage': stage.code,
        'buyer_nick': buyerNick,
        'product_summary': productSummary,
        'reason': reason,
        'refund_amount': refundAmount,
        'progress_note': progressNote,
        'return_tracking_no': returnTrackingNo,
        'apply_time': DbValue.toIso(applyTime),
        'finish_time': DbValue.toIso(finishTime),
        'created_at': DbValue.toIso(createdAt),
        'updated_at': DbValue.toIso(updatedAt),
        'is_deleted': isDeleted,
      };

  factory AfterSale.fromRemote(Map<String, dynamic> json) => AfterSale(
        id: '${json['id']}',
        userId: '${json['user_id']}',
        orderId: json['order_id'] as String?,
        orderNo: '${json['order_no'] ?? ''}',
        afterSaleNo: json['after_sale_no'] as String?,
        type: AfterSaleTypeX.fromCode(json['type']),
        stage: AfterSaleStageX.fromCode(json['stage']),
        buyerNick: json['buyer_nick'] as String?,
        productSummary: json['product_summary'] as String?,
        reason: json['reason'] as String?,
        refundAmount: DbValue.toDouble(json['refund_amount']),
        progressNote: json['progress_note'] as String?,
        returnTrackingNo: json['return_tracking_no'] as String?,
        applyTime: DbValue.fromIso(json['apply_time']) ?? DateTime.now(),
        finishTime: DbValue.fromIso(json['finish_time']),
        createdAt: DbValue.fromIso(json['created_at']) ?? DateTime.now(),
        updatedAt: DbValue.fromIso(json['updated_at']) ?? DateTime.now(),
        isDeleted: DbValue.toBool(json['is_deleted']),
        syncState: SyncState.synced,
      );
}
