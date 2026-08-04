/// ============================================================================
/// 全局静态配置
///
/// 这里只放「编译期常量 / 出厂默认值」。所有可以被用户在设置页改写的项，
/// 运行时一律以 SharedPreferences 中的值为准（见 PrefKeys）。
/// ============================================================================
library;

class AppConfig {
  AppConfig._();

  // —— 品牌 ——
  static const String appName = '抖店订单管家';
  static const String appSlogan = '订单自动同步 · 发货一键搞定';
  static const String appVersion = '1.0.0';

  // —— Supabase 出厂默认值 ——
  // 打包分发前可以在这里填好，用户开箱即用；
  // 留空则首次启动进入「本地模式」，由用户在设置页自行填写。
  static const String defaultSupabaseUrl = '';
  static const String defaultSupabaseAnonKey = '';

  // —— 抖店开放平台 ——
  /// 抖店开放平台网关地址（正式环境）
  static const String douyinGateway = 'https://openapi-fxg.jinritemai.com';

  /// 抖店开放平台默认 API 版本
  static const String douyinApiVersion = '2';

  /// 出厂默认应用凭据（留空，由用户在设置页填写）
  static const String defaultDouyinAppKey = '';
  static const String defaultDouyinAppSecret = '';
  static const String defaultDouyinShopId = '';

  /// 单次拉取订单的分页大小（抖店上限 100）
  static const int douyinPageSize = 50;

  /// 单次同步最多翻多少页，防止首次全量同步时无限拉取
  static const int douyinMaxPages = 40;

  /// 首次同步默认回溯天数
  static const int douyinInitialBackfillDays = 30;

  /// 增量同步时水位线向前重叠的分钟数
  /// 抖店订单的 update_time 存在秒级抖动，重叠一段可避免漏单
  static const int douyinWatermarkOverlapMinutes = 10;

  // —— 同步节奏 ——
  /// 抖店订单默认自动同步周期（秒）
  static const int defaultDouyinSyncIntervalSeconds = 300;

  /// 可选的同步周期档位（秒）
  static const List<int> douyinSyncIntervalOptions = <int>[
    60,
    180,
    300,
    600,
    1800,
    3600,
  ];

  /// Supabase 云端同步轮询周期（秒）
  static const int cloudSyncIntervalSeconds = 60;

  // —— 业务参数 ——
  /// 待发货超过多少小时高亮预警
  static const int shipWarningHours = 24;

  /// 统计页默认展示的月份数
  static const int statsMonthSpan = 6;

  /// 本地列表分页大小
  static const int listPageSize = 60;

  // —— 常用物流公司（可在发货面板里直接选） ——
  static const List<({String code, String name})> logisticsCompanies =
      <({String code, String name})>[
    (code: 'jd', name: '京东物流'),
    (code: 'shunfeng', name: '顺丰速运'),
    (code: 'zhongtong', name: '中通快递'),
    (code: 'yuantong', name: '圆通速递'),
    (code: 'yunda', name: '韵达速递'),
    (code: 'shentong', name: '申通快递'),
    (code: 'jitu', name: '极兔速递'),
    (code: 'youzhengguonei', name: '邮政快递包裹'),
    (code: 'ems', name: 'EMS'),
    (code: 'debangwuliu', name: '德邦快递'),
    (code: 'huitongkuaidi', name: '百世快递'),
    (code: 'other', name: '其他'),
  ];
}
