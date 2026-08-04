/// ============================================================================
/// SharedPreferences 键名集中登记处
///
/// 全部走这里，避免字符串散落各处写错。
/// ============================================================================
library;

class PrefKeys {
  PrefKeys._();

  // —— Supabase ——
  static const String supabaseUrl = 'supabase.url';
  static const String supabaseAnonKey = 'supabase.anonKey';

  // —— 账号 ——
  static const String rememberLogin = 'auth.remember';
  static const String lastEmail = 'auth.lastEmail';

  /// 用户主动选择「只在本机使用」
  static const String localModeEnabled = 'auth.localMode';

  // —— 外观 ——
  static const String themeMode = 'ui.themeMode';

  // —— 抖店开放平台 ——
  static const String douyinAppKey = 'douyin.appKey';
  static const String douyinAppSecret = 'douyin.appSecret';
  static const String douyinShopId = 'douyin.shopId';

  /// 授权码模式下换取的 access_token / refresh_token
  static const String douyinAccessToken = 'douyin.accessToken';
  static const String douyinRefreshToken = 'douyin.refreshToken';
  static const String douyinTokenExpireAt = 'douyin.tokenExpireAt';
  static const String douyinAuthShopName = 'douyin.authShopName';

  /// 是否启用抖店自动同步
  static const String douyinAutoSync = 'douyin.autoSync';

  /// 自动同步周期（秒）
  static const String douyinSyncInterval = 'douyin.syncInterval';

  /// 订单增量拉取水位线（毫秒时间戳）
  static const String douyinWatermark = 'douyin.watermark';

  /// 最近一次抖店同步时间与结果摘要
  static const String douyinLastSyncAt = 'douyin.lastSyncAt';
  static const String douyinLastSyncMsg = 'douyin.lastSyncMsg';

  // —— Supabase 云同步 ——
  static const String cloudAutoSync = 'sync.auto';
  static const String cloudLastSyncAt = 'sync.lastSyncAt';

  /// 各业务表的云端拉取水位线，实际键为 `sync.pull.<table>`
  static String cloudPullWatermark(String table) => 'sync.pull.$table';

  // —— 使用偏好 ——
  /// 上次选择的物流公司，下次发货默认带出
  static const String lastLogisticsCode = 'ship.lastLogistics';

  /// 订单列表默认排序
  static const String orderSortBy = 'orders.sortBy';
}
