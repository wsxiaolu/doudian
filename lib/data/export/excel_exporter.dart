import 'package:excel/excel.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/after_sale.dart';
import '../../data/models/customer.dart';
import '../../data/models/order_item.dart';
import '../../data/models/order_status.dart';
import '../../data/models/product.dart';
import '../../data/models/shop_order.dart';

/// ============================================================================
/// Excel 报表导出
///
/// 把当前账号的订单 / 订单明细 / 商品 / 客户 / 售后 导出为一份多 sheet 的
/// .xlsx 文件，列严格对齐各 model 的 [toRemote] 字段（即 Supabase 列名的中文版），
/// 方便商家做对账、盘点与二次分析。
///
/// 设计：
///   · 纯构建逻辑，不碰 UI、不落盘、不弹窗，保持数据层干净；
///   · 落盘与分享由调用方（设置页）完成，便于复用与测试；
///   · 数值用 [DoubleCellValue]/[IntCellValue]，Excel 里可直接求和筛选；
///   · 日期统一用 [Fmt.dateTime] 写成「yyyy-MM-dd HH:mm」字符串，避免时区/序列号歧义；
///   · 状态 / 来源 / 类型 / 进度 直接用中文 label，导出即人读。
/// ============================================================================
class ExcelExporter {
  ExcelExporter._();

  // ---------------------------------------------------------------------------
  // 工作表名
  // ---------------------------------------------------------------------------
  static const String _sheetOrders = '订单';
  static const String _sheetOrderItems = '订单明细';
  static const String _sheetProducts = '商品';
  static const String _sheetCustomers = '客户';
  static const String _sheetAfterSales = '售后';

  /// 构建完整 workbook（不含默认 Sheet1）
  static Excel buildWorkbook({
    required List<ShopOrder> orders,
    required List<Product> products,
    required List<Customer> customers,
    required List<AfterSale> afterSales,
  }) {
    final Excel excel = Excel.createExcel();
    // 默认会带一张 Sheet1，导出文件里不需要，删掉
    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');

    _writeOrders(excel, orders);
    _writeOrderItems(excel, orders);
    _writeProducts(excel, products);
    _writeCustomers(excel, customers);
    _writeAfterSales(excel, afterSales);

    return excel;
  }

  // ---------------------------------------------------------------------------
  // 各 sheet
  // ---------------------------------------------------------------------------
  static void _writeOrders(Excel excel, List<ShopOrder> orders) {
    const List<String> headers = <String>[
      '订单号',
      '状态',
      '来源',
      '买家昵称',
      '收件人',
      '电话',
      '省',
      '市',
      '区',
      '收货地址',
      '商品摘要',
      '件数',
      '订单总额',
      '实付金额',
      '运费',
      '优惠金额',
      '物流公司',
      '快递单号',
      '买家留言',
      '商家备注',
      '本地备注',
      '下单时间',
      '支付时间',
      '发货时间',
      '完成时间',
      '抖店更新时间',
    ];
    final List<List<dynamic>> rows = <List<dynamic>>[
      for (final ShopOrder o in orders)
        <dynamic>[
          o.orderNo,
          o.status.label,
          o.source.label,
          o.buyerNick ?? '',
          o.receiverName ?? '',
          o.receiverPhone ?? '',
          o.province ?? '',
          o.city ?? '',
          o.district ?? '',
          o.receiverAddress ?? '',
          o.productSummary ?? '',
          o.itemCount,
          o.totalAmount,
          o.payAmount,
          o.postAmount,
          o.discountAmount,
          o.logisticsName ?? '',
          o.trackingNo ?? '',
          o.buyerWords ?? '',
          o.sellerWords ?? '',
          o.remark ?? '',
          o.orderTime,
          o.payTime,
          o.shipTime,
          o.finishTime,
          o.douyinUpdateTime,
        ],
    ];
    _writeSheet(excel, _sheetOrders, headers, rows);
  }

  static void _writeOrderItems(Excel excel, List<ShopOrder> orders) {
    const List<String> headers = <String>[
      '主订单号',
      '子订单号',
      '商品名称',
      '规格',
      '数量',
      '单价',
      '实付',
      '成本',
      '毛利',
      'SKU ID',
      '商家编码',
      '图片',
    ];
    final List<List<dynamic>> rows = <List<dynamic>>[];
    for (final ShopOrder o in orders) {
      for (final OrderItem it in o.items) {
        rows.add(<dynamic>[
          o.orderNo,
          it.skuOrderNo ?? '',
          it.productName,
          it.spec ?? '',
          it.quantity,
          it.salePrice,
          it.payAmount,
          it.costPrice,
          it.lineProfit,
          it.skuId ?? '',
          it.outerSkuId ?? '',
          it.imageUrl ?? '',
        ]);
      }
    }
    _writeSheet(excel, _sheetOrderItems, headers, rows);
  }

  static void _writeProducts(Excel excel, List<Product> products) {
    const List<String> headers = <String>[
      '商品名称',
      '规格',
      '商家编码',
      '分类',
      '成本价',
      '售价',
      '库存',
      '是否上架',
      '备注',
      '创建时间',
      '更新时间',
    ];
    final List<List<dynamic>> rows = <List<dynamic>>[
      for (final Product p in products)
        <dynamic>[
          p.name,
          p.spec ?? '',
          p.skuCode ?? '',
          p.category ?? '',
          p.costPrice,
          p.salePrice,
          p.stock,
          p.isActive ? '是' : '否',
          p.remark ?? '',
          p.createdAt,
          p.updatedAt,
        ],
    ];
    _writeSheet(excel, _sheetProducts, headers, rows);
  }

  static void _writeCustomers(Excel excel, List<Customer> customers) {
    const List<String> headers = <String>[
      '姓名',
      '昵称',
      'OpenID',
      '电话',
      '地址',
      '来源',
      '备注',
      '创建时间',
      '更新时间',
    ];
    final List<List<dynamic>> rows = <List<dynamic>>[
      for (final Customer c in customers)
        <dynamic>[
          c.name,
          c.buyerNick ?? '',
          c.openId ?? '',
          c.phone ?? '',
          c.address ?? '',
          c.source.label,
          c.remark ?? '',
          c.createdAt,
          c.updatedAt,
        ],
    ];
    _writeSheet(excel, _sheetCustomers, headers, rows);
  }

  static void _writeAfterSales(Excel excel, List<AfterSale> afterSales) {
    const List<String> headers = <String>[
      '售后单号',
      '订单号',
      '类型',
      '进度',
      '买家昵称',
      '商品摘要',
      '原因',
      '退款金额',
      '处理进度备注',
      '退回快递单号',
      '申请时间',
      '完成时间',
      '创建时间',
    ];
    final List<List<dynamic>> rows = <List<dynamic>>[
      for (final AfterSale a in afterSales)
        <dynamic>[
          a.afterSaleNo ?? '',
          a.orderNo,
          a.type.label,
          a.stage.label,
          a.buyerNick ?? '',
          a.productSummary ?? '',
          a.reason ?? '',
          a.refundAmount,
          a.progressNote ?? '',
          a.returnTrackingNo ?? '',
          a.applyTime,
          a.finishTime,
          a.createdAt,
        ],
    ];
    _writeSheet(excel, _sheetAfterSales, headers, rows);
  }

  // ---------------------------------------------------------------------------
  // 通用写入
  // ---------------------------------------------------------------------------
  static void _writeSheet(
    Excel excel,
    String name,
    List<String> headers,
    List<List<dynamic>> rows,
  ) {
    final Sheet sheet = excel[name];
    for (int c = 0; c < headers.length; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .value = TextCellValue(headers[c]);
    }
    for (int r = 0; r < rows.length; r++) {
      final List<dynamic> row = rows[r];
      for (int c = 0; c < row.length; c++) {
        sheet
            .cell(CellIndex.indexByColumnRow(
              columnIndex: c,
              rowIndex: r + 1,
            ))
            .value = _cell(row[c]);
      }
    }
  }

  /// Dart 值 → Excel CellValue（按类型选择对应的包装类）
  static CellValue _cell(dynamic v) {
    if (v == null) return TextCellValue('');
    if (v is bool) return BoolCellValue(v);
    if (v is int) return IntCellValue(v);
    if (v is double) return DoubleCellValue(v);
    if (v is DateTime) return TextCellValue(Fmt.dateTime(v));
    return TextCellValue('$v');
  }
}
