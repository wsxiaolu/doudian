import 'package:intl/intl.dart';

/// ============================================================================
/// 金额 / 日期 / 文本 格式化工具
/// 统一出口，避免各页面各写一套导致展示不一致。
/// ============================================================================
class Fmt {
  Fmt._();

  // ---------------------------------------------------------------------------
  // 金额
  // ---------------------------------------------------------------------------
  static final NumberFormat _money = NumberFormat('#,##0.00', 'zh_CN');
  static final NumberFormat _moneyInt = NumberFormat('#,##0', 'zh_CN');

  /// 标准金额：1234.5 → ¥1,234.50
  static String money(num? value, {bool withSymbol = true}) {
    final double v = (value ?? 0).toDouble();
    final String text = _money.format(v);
    return withSymbol ? '¥$text' : text;
  }

  /// 紧凑金额（用于首页大数字）：12345.6 → ¥1.23万
  static String moneyCompact(num? value, {bool withSymbol = true}) {
    final double v = (value ?? 0).toDouble();
    final String symbol = withSymbol ? '¥' : '';
    final double abs = v.abs();
    if (abs >= 100000000) {
      return '$symbol${(v / 100000000).toStringAsFixed(2)}亿';
    }
    if (abs >= 10000) {
      return '$symbol${(v / 10000).toStringAsFixed(2)}万';
    }
    return '$symbol${_money.format(v)}';
  }

  /// 整数金额（无小数）
  static String moneyInt(num? value, {bool withSymbol = true}) {
    final double v = (value ?? 0).toDouble();
    return '${withSymbol ? '¥' : ''}${_moneyInt.format(v)}';
  }

  /// 数量
  static String count(num? value) => _moneyInt.format((value ?? 0).toDouble());

  // ---------------------------------------------------------------------------
  // 日期
  // ---------------------------------------------------------------------------
  static final DateFormat _ymd = DateFormat('yyyy-MM-dd');
  static final DateFormat _ymdCn = DateFormat('yyyy年M月d日');
  static final DateFormat _md = DateFormat('M月d日');
  static final DateFormat _ymdHm = DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat _hm = DateFormat('HH:mm');

  static String date(DateTime? d) => d == null ? '—' : _ymd.format(d);

  static String dateCn(DateTime? d) => d == null ? '—' : _ymdCn.format(d);

  static String monthDay(DateTime? d) => d == null ? '—' : _md.format(d);

  static String dateTime(DateTime? d) => d == null ? '—' : _ymdHm.format(d);

  static String time(DateTime? d) => d == null ? '—' : _hm.format(d);

  /// 聊天/记录用的智能时间：今天显示时分，昨天显示「昨天 HH:mm」，更早显示日期
  static String smartTime(DateTime? d) {
    if (d == null) return '—';
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime target = DateTime(d.year, d.month, d.day);
    final int diff = today.difference(target).inDays;
    if (diff == 0) return _hm.format(d);
    if (diff == 1) return '昨天 ${_hm.format(d)}';
    if (diff < 7 && diff > 0) return '$diff 天前';
    if (d.year == now.year) return _md.format(d);
    return _ymd.format(d);
  }

  /// 距离截止日期的天数（正数=还剩，负数=已逾期）
  static int daysUntil(DateTime? due) {
    if (due == null) return 9999;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime target = DateTime(due.year, due.month, due.day);
    return target.difference(today).inDays;
  }

  /// 交期文案：今天到期 / 还剩 3 天 / 已逾期 5 天
  static String dueDescription(DateTime? due) {
    if (due == null) return '未设定交期';
    final int days = daysUntil(due);
    if (days == 0) return '今天到期';
    if (days == 1) return '明天到期';
    if (days > 1) return '还剩 $days 天';
    return '已逾期 ${-days} 天';
  }

  // ---------------------------------------------------------------------------
  // 文本
  // ---------------------------------------------------------------------------

  /// 取姓名首字作为头像文字
  static String initial(String? name) {
    final String n = (name ?? '').trim();
    if (n.isEmpty) return '客';
    return n.characters.first;
  }

  /// 手机号脱敏：138****8888
  static String maskPhone(String? phone) {
    final String p = (phone ?? '').trim();
    if (p.length < 7) return p;
    return '${p.substring(0, 3)}****${p.substring(p.length - 4)}';
  }

  /// 超长文本截断
  static String ellipsis(String? text, int max) {
    final String t = (text ?? '').trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }
}

/// String.characters 需要 characters 包，Flutter SDK 已内置传递依赖
extension _CharactersCompat on String {
  Iterable<String> get characters sync* {
    for (final int rune in runes) {
      yield String.fromCharCode(rune);
    }
  }
}
