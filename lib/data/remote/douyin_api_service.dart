import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../core/config/pref_keys.dart';

/// ============================================================================
/// 抖店开放平台调用异常
/// ============================================================================
class DouyinApiException implements Exception {
  DouyinApiException(this.message, {this.code, this.subCode, this.logId});

  final String message;
  final int? code;
  final String? subCode;
  final String? logId;

  @override
  String toString() {
    final StringBuffer sb = StringBuffer('抖店接口调用失败：$message');
    if (code != null) sb.write('（错误码 $code');
    if (subCode != null && subCode!.isNotEmpty) sb.write(' / $subCode');
    if (code != null) sb.write('）');
    return sb.toString();
  }
}

/// ============================================================================
/// 抖店应用凭据
/// ============================================================================
class DouyinCredentials {
  const DouyinCredentials({
    this.appKey = '',
    this.appSecret = '',
    this.shopId = '',
    this.accessToken = '',
    this.refreshToken = '',
    this.expireAt,
    this.shopName = '',
  });

  final String appKey;
  final String appSecret;
  final String shopId;
  final String accessToken;
  final String refreshToken;
  final DateTime? expireAt;
  final String shopName;

  /// 是否已填写基础三要素
  bool get isConfigured =>
      appKey.trim().isNotEmpty && appSecret.trim().isNotEmpty;

  /// 是否已拿到有效 token（提前 5 分钟视为过期）
  bool get hasValidToken {
    if (accessToken.trim().isEmpty) return false;
    if (expireAt == null) return true;
    return DateTime.now()
        .isBefore(expireAt!.subtract(const Duration(minutes: 5)));
  }

  DouyinCredentials copyWith({
    String? appKey,
    String? appSecret,
    String? shopId,
    String? accessToken,
    String? refreshToken,
    DateTime? expireAt,
    String? shopName,
  }) {
    return DouyinCredentials(
      appKey: appKey ?? this.appKey,
      appSecret: appSecret ?? this.appSecret,
      shopId: shopId ?? this.shopId,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expireAt: expireAt ?? this.expireAt,
      shopName: shopName ?? this.shopName,
    );
  }
}

/// ============================================================================
/// 抖店开放平台 API 客户端
///
/// 严格按照官方《API调用指南》实现，全程走官方 HTTP 接口，不做任何网页抓取。
///
/// 【签名规则】
///   1. 参与签名的公共参数：app_key、method、param_json、timestamp、v
///      （access_token、sign_method、sign 本身不参与签名）
///   2. 按参数名字典序排序后，按 `key + value` 直接拼接成一个长串
///   3. 前后各拼一次 app_secret：secret + 串 + secret
///   4. 用 hmac-sha256（推荐）或 md5 计算摘要，十六进制小写输出
///
/// 【param_json】
///   业务参数序列化成标准 JSON，Key 必须按字典序排序（嵌套对象同样要排），
///   放在 POST body 里以 application/json 提交，公共参数放 URL query。
/// ============================================================================
class DouyinApiService {
  DouyinApiService._internal();

  static final DouyinApiService instance = DouyinApiService._internal();

  final http.Client _client = http.Client();

  DouyinCredentials _credentials = const DouyinCredentials();

  DouyinCredentials get credentials => _credentials;

  /// token 刷新串行化，避免多个请求同时刷新
  Future<void>? _refreshing;

  // ---------------------------------------------------------------------------
  // 凭据读写
  // ---------------------------------------------------------------------------
  Future<DouyinCredentials> loadCredentials() async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    final int? expireMillis = sp.getInt(PrefKeys.douyinTokenExpireAt);
    _credentials = DouyinCredentials(
      appKey: sp.getString(PrefKeys.douyinAppKey) ??
          AppConfig.defaultDouyinAppKey,
      appSecret: sp.getString(PrefKeys.douyinAppSecret) ??
          AppConfig.defaultDouyinAppSecret,
      shopId: sp.getString(PrefKeys.douyinShopId) ??
          AppConfig.defaultDouyinShopId,
      accessToken: sp.getString(PrefKeys.douyinAccessToken) ?? '',
      refreshToken: sp.getString(PrefKeys.douyinRefreshToken) ?? '',
      expireAt: expireMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expireMillis),
      shopName: sp.getString(PrefKeys.douyinAuthShopName) ?? '',
    );
    return _credentials;
  }

  /// 保存应用三要素（改动后会清空已有 token，强制重新授权）
  Future<void> saveAppConfig({
    required String appKey,
    required String appSecret,
    required String shopId,
  }) async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    final bool changed = appKey.trim() != _credentials.appKey ||
        appSecret.trim() != _credentials.appSecret ||
        shopId.trim() != _credentials.shopId;

    await sp.setString(PrefKeys.douyinAppKey, appKey.trim());
    await sp.setString(PrefKeys.douyinAppSecret, appSecret.trim());
    await sp.setString(PrefKeys.douyinShopId, shopId.trim());

    if (changed) {
      await sp.remove(PrefKeys.douyinAccessToken);
      await sp.remove(PrefKeys.douyinRefreshToken);
      await sp.remove(PrefKeys.douyinTokenExpireAt);
      await sp.remove(PrefKeys.douyinAuthShopName);
    }
    await loadCredentials();
  }

  Future<void> _saveToken({
    required String accessToken,
    required String refreshToken,
    required int expiresInSeconds,
    String? shopName,
  }) async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    final DateTime expireAt =
        DateTime.now().add(Duration(seconds: expiresInSeconds));
    await sp.setString(PrefKeys.douyinAccessToken, accessToken);
    await sp.setString(PrefKeys.douyinRefreshToken, refreshToken);
    await sp.setInt(
        PrefKeys.douyinTokenExpireAt, expireAt.millisecondsSinceEpoch);
    if (shopName != null && shopName.isNotEmpty) {
      await sp.setString(PrefKeys.douyinAuthShopName, shopName);
    }
    _credentials = _credentials.copyWith(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expireAt: expireAt,
      shopName: shopName ?? _credentials.shopName,
    );
  }

  /// 解除授权，清空本地 token
  Future<void> clearToken() async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    await sp.remove(PrefKeys.douyinAccessToken);
    await sp.remove(PrefKeys.douyinRefreshToken);
    await sp.remove(PrefKeys.douyinTokenExpireAt);
    await sp.remove(PrefKeys.douyinAuthShopName);
    _credentials = _credentials.copyWith(
      accessToken: '',
      refreshToken: '',
      shopName: '',
    );
  }

  // ---------------------------------------------------------------------------
  // 签名
  // ---------------------------------------------------------------------------

  /// 递归按 Key 字典序排序后再序列化，满足官方对 param_json 的要求
  @visibleForTesting
  static String encodeParamJson(Map<String, dynamic> params) {
    return jsonEncode(_sortDeep(params));
  }

  static Object? _sortDeep(Object? value) {
    if (value is Map) {
      final SplayTreeMap<String, Object?> sorted =
          SplayTreeMap<String, Object?>();
      value.forEach((Object? k, Object? v) {
        sorted['$k'] = _sortDeep(v);
      });
      return sorted;
    }
    if (value is List) {
      return value.map(_sortDeep).toList();
    }
    return value;
  }

  /// 抖店要求的时间戳：GMT+8 的 `yyyy-MM-dd HH:mm:ss`
  @visibleForTesting
  static String buildTimestamp([DateTime? now]) {
    final DateTime t = (now ?? DateTime.now()).toUtc().add(
          const Duration(hours: 8),
        );
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  /// 计算签名
  ///
  /// signStr = secret + app_key{v} + method{v} + param_json{v} + timestamp{v} + v{v} + secret
  @visibleForTesting
  static String buildSign({
    required String appKey,
    required String appSecret,
    required String method,
    required String paramJson,
    required String timestamp,
    String version = AppConfig.douyinApiVersion,
    bool useHmac = true,
  }) {
    // 按参数名字典序：app_key < method < param_json < timestamp < v
    final SplayTreeMap<String, String> signParams = SplayTreeMap<String, String>.from(
      <String, String>{
        'app_key': appKey,
        'method': method,
        'param_json': paramJson,
        'timestamp': timestamp,
        'v': version,
      },
    );

    final StringBuffer sb = StringBuffer();
    signParams.forEach((String k, String v) => sb.write('$k$v'));
    final String payload = '$appSecret${sb.toString()}$appSecret';

    if (useHmac) {
      final Hmac hmac = Hmac(sha256, utf8.encode(appSecret));
      return hmac.convert(utf8.encode(payload)).toString();
    }
    return md5.convert(utf8.encode(payload)).toString();
  }

  // ---------------------------------------------------------------------------
  // 通用请求
  // ---------------------------------------------------------------------------

  /// 调用任意抖店接口
  ///
  /// [path] 形如 `/order/searchList`，会自动转换成 method `order.searchList`
  Future<Map<String, dynamic>> call(
    String path,
    Map<String, dynamic> params, {
    bool withToken = true,
    bool allowRetryOnTokenExpired = true,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!_credentials.isConfigured) {
      throw DouyinApiException('尚未配置抖店 AppKey / AppSecret，请先到设置页填写');
    }
    if (withToken) {
      await ensureToken();
    }

    final String method = _pathToMethod(path);
    final String paramJson = encodeParamJson(params);
    final String timestamp = buildTimestamp();
    final String sign = buildSign(
      appKey: _credentials.appKey,
      appSecret: _credentials.appSecret,
      method: method,
      paramJson: paramJson,
      timestamp: timestamp,
    );

    final Map<String, String> query = <String, String>{
      'app_key': _credentials.appKey,
      'method': method,
      'v': AppConfig.douyinApiVersion,
      'timestamp': timestamp,
      'sign_method': 'hmac-sha256',
      'sign': sign,
      if (withToken) 'access_token': _credentials.accessToken,
    };

    final Uri uri = Uri.parse('${AppConfig.douyinGateway}$path')
        .replace(queryParameters: query);

    late http.Response resp;
    try {
      resp = await _client
          .post(
            uri,
            headers: const <String, String>{
              'Content-Type': 'application/json;charset=UTF-8',
              'Accept': 'application/json',
            },
            body: paramJson,
          )
          .timeout(timeout);
    } on TimeoutException {
      throw DouyinApiException('请求超时，请检查网络后重试');
    } catch (e) {
      throw DouyinApiException('网络异常：$e');
    }

    if (resp.statusCode != 200) {
      throw DouyinApiException(
        'HTTP ${resp.statusCode}',
        code: resp.statusCode,
      );
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      throw DouyinApiException('返回内容解析失败：${resp.body}');
    }

    final int code = _asInt(body['code'], -1);
    if (code == 0) {
      final Object? data = body['data'];
      if (data is Map<String, dynamic>) return data;
      return <String, dynamic>{'data': data};
    }

    final String subCode = '${body['sub_code'] ?? ''}';
    final String msg = '${body['msg'] ?? body['sub_msg'] ?? '未知错误'}';

    // token 失效：刷新一次后重试
    final bool tokenInvalid = subCode.contains('token') ||
        msg.contains('token') ||
        code == 10006 ||
        code == 10007;
    if (withToken && allowRetryOnTokenExpired && tokenInvalid) {
      await _forceRefreshToken();
      return call(
        path,
        params,
        withToken: withToken,
        allowRetryOnTokenExpired: false,
        timeout: timeout,
      );
    }

    throw DouyinApiException(
      msg,
      code: code,
      subCode: subCode,
      logId: '${body['log_id'] ?? ''}',
    );
  }

  static String _pathToMethod(String path) {
    String p = path.trim();
    if (p.startsWith('/')) p = p.substring(1);
    return p.replaceAll('/', '.');
  }

  // ---------------------------------------------------------------------------
  // 令牌管理
  // ---------------------------------------------------------------------------

  /// 确保当前持有可用的 access_token
  Future<void> ensureToken() async {
    if (_credentials.hasValidToken) return;
    if (_refreshing != null) {
      await _refreshing;
      return;
    }
    _refreshing = _doRefresh();
    try {
      await _refreshing;
    } finally {
      _refreshing = null;
    }
  }

  Future<void> _forceRefreshToken() async {
    if (_refreshing != null) {
      await _refreshing;
      return;
    }
    _refreshing = _doRefresh(force: true);
    try {
      await _refreshing;
    } finally {
      _refreshing = null;
    }
  }

  Future<void> _doRefresh({bool force = false}) async {
    // 有 refresh_token 就先尝试续期，失败再走重新授权
    if (_credentials.refreshToken.isNotEmpty) {
      try {
        await refreshAccessToken();
        return;
      } catch (_) {
        // 续期失败，继续走自用型授权
      }
    }
    await createAccessTokenForSelfShop();
  }

  /// 自用型应用换取 access_token（grant_type = authorization_self）
  ///
  /// 自用型应用只服务自己的店铺，不需要跳转授权页，直接用 shop_id 换取即可。
  Future<DouyinCredentials> createAccessTokenForSelfShop({
    String? shopIdOverride,
  }) async {
    final String shopId = (shopIdOverride ?? _credentials.shopId).trim();
    if (shopId.isEmpty) {
      throw DouyinApiException('自用型应用需要填写店铺 ID（shop_id）才能获取访问令牌');
    }
    final Map<String, dynamic> data = await call(
      '/token/create',
      <String, dynamic>{
        'code': '',
        'grant_type': 'authorization_self',
        'shop_id': shopId,
      },
      withToken: false,
    );
    await _applyTokenResponse(data);
    return _credentials;
  }

  /// 工具型应用：用商家授权回调拿到的 code 换取 access_token
  Future<DouyinCredentials> createAccessTokenByCode(String code) async {
    if (code.trim().isEmpty) {
      throw DouyinApiException('授权码不能为空');
    }
    final Map<String, dynamic> data = await call(
      '/token/create',
      <String, dynamic>{
        'code': code.trim(),
        'grant_type': 'authorization_code',
      },
      withToken: false,
    );
    await _applyTokenResponse(data);
    return _credentials;
  }

  /// 用 refresh_token 续期
  Future<DouyinCredentials> refreshAccessToken() async {
    if (_credentials.refreshToken.isEmpty) {
      throw DouyinApiException('缺少 refresh_token，无法续期');
    }
    final Map<String, dynamic> data = await call(
      '/token/refresh',
      <String, dynamic>{
        'grant_type': 'refresh_token',
        'refresh_token': _credentials.refreshToken,
      },
      withToken: false,
    );
    await _applyTokenResponse(data);
    return _credentials;
  }

  Future<void> _applyTokenResponse(Map<String, dynamic> data) async {
    final String token = '${data['access_token'] ?? ''}';
    if (token.isEmpty) {
      throw DouyinApiException('未能从返回结果中解析到 access_token');
    }
    await _saveToken(
      accessToken: token,
      refreshToken: '${data['refresh_token'] ?? ''}',
      expiresInSeconds: _asInt(data['expires_in'], 7 * 24 * 3600),
      shopName: '${data['shop_name'] ?? ''}',
    );

    // 授权返回里带了 shop_id 就顺手回填，省去用户手填
    final String shopId = '${data['shop_id'] ?? ''}';
    if (shopId.isNotEmpty && shopId != _credentials.shopId) {
      final SharedPreferences sp = await SharedPreferences.getInstance();
      await sp.setString(PrefKeys.douyinShopId, shopId);
      _credentials = _credentials.copyWith(shopId: shopId);
    }
  }

  /// 连通性自检：拿一次 token 并试探性拉一页订单
  Future<String> testConnection() async {
    await _forceRefreshToken();
    final DateTime end = DateTime.now();
    final DateTime start = end.subtract(const Duration(days: 1));
    final Map<String, dynamic> data = await searchOrders(
      updateTimeStart: start,
      updateTimeEnd: end,
      page: 0,
      size: 1,
    );
    final int total = _asInt(data['total'], 0);
    final String shop = _credentials.shopName.isEmpty
        ? '店铺 ${_credentials.shopId}'
        : _credentials.shopName;
    return '连接成功：$shop（近 1 天有 $total 笔订单变更）';
  }

  // ---------------------------------------------------------------------------
  // 业务接口
  // ---------------------------------------------------------------------------

  /// 订单列表查询 `/order/searchList`
  ///
  /// 增量同步用 update_time 区间；首次全量回溯用 create_time 区间。
  Future<Map<String, dynamic>> searchOrders({
    DateTime? createTimeStart,
    DateTime? createTimeEnd,
    DateTime? updateTimeStart,
    DateTime? updateTimeEnd,
    int page = 0,
    int size = AppConfig.douyinPageSize,
    int? orderStatus,
  }) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'page': page,
      'size': size,
      'order_by': 'update_time',
      'order_asc': true,
      if (createTimeStart != null)
        'create_time_start': _unixSeconds(createTimeStart),
      if (createTimeEnd != null) 'create_time_end': _unixSeconds(createTimeEnd),
      if (updateTimeStart != null)
        'update_time_start': _unixSeconds(updateTimeStart),
      if (updateTimeEnd != null) 'update_time_end': _unixSeconds(updateTimeEnd),
      if (orderStatus != null) 'order_status': orderStatus,
    };
    return call('/order/searchList', params);
  }

  /// 订单详情 `/order/orderDetail`
  Future<Map<String, dynamic>> orderDetail(String shopOrderId) {
    return call('/order/orderDetail', <String, dynamic>{
      'shop_order_id': shopOrderId,
    });
  }

  /// 售后列表 `/afterSale/List`
  Future<Map<String, dynamic>> afterSaleList({
    DateTime? startTime,
    DateTime? endTime,
    int page = 0,
    int size = AppConfig.douyinPageSize,
  }) {
    return call('/afterSale/List', <String, dynamic>{
      'page': page,
      'size': size,
      if (startTime != null) 'start_time': _unixSeconds(startTime),
      if (endTime != null) 'end_time': _unixSeconds(endTime),
    });
  }

  /// 发货回传 `/order/logisticsAdd`
  ///
  /// [orderId] 传子订单号（sku_order_id）或主订单号均可，
  /// [companyCode] 为抖店物流公司编码，[trackingNo] 为快递单号。
  Future<Map<String, dynamic>> uploadLogistics({
    required String orderId,
    required String companyCode,
    required String trackingNo,
  }) {
    return call('/order/logisticsAdd', <String, dynamic>{
      'order_id': orderId,
      'company_code': companyCode,
      'logistics_code': trackingNo,
      'logistics_id': '',
    });
  }

  // ---------------------------------------------------------------------------
  // 工具
  // ---------------------------------------------------------------------------
  static int _unixSeconds(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

  static int _asInt(Object? value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  void dispose() => _client.close();
}
